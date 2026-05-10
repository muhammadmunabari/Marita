import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:uuid/uuid.dart';
import '../models/ai_chat_models.dart';

class AiChatState {
  final List<ChatProject> projects;
  final ChatProject? currentProject;
  final List<ChatMessage> messages;
  final bool isLoading;

  AiChatState({
    this.projects = const [],
    this.currentProject,
    this.messages = const [],
    this.isLoading = false,
  });

  AiChatState copyWith({
    List<ChatProject>? projects,
    ChatProject? currentProject,
    List<ChatMessage>? messages,
    bool? isLoading,
  }) {
    return AiChatState(
      projects: projects ?? this.projects,
      currentProject: currentProject ?? this.currentProject,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AiChatProvider extends Notifier<AiChatState> {
  late final GenerativeModel _model;
  ChatSession? _chatSession;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  AiChatState build() {
    _model = FirebaseVertexAI.instance.generativeModel(
      model: 'gemini-2.5-flash',
    );
    _chatSession = _model.startChat();

    // Load projects asynchronously
    _loadProjects();

    return AiChatState();
  }

  String? get _userId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _projectsRef {
    if (_userId == null) return null;
    return _firestore
        .collection('users')
        .doc(_userId)
        .collection('chat_projects');
  }

  Future<void> _loadProjects() async {
    final ref = _projectsRef;
    if (ref == null) return;

    ref.orderBy('updatedAt', descending: true).snapshots().listen((snapshot) {
      final projects =
          snapshot.docs.map((doc) => ChatProject.fromJson(doc.data())).toList();
      state = state.copyWith(projects: projects);
    });
  }

  Future<void> _loadMessages(String projectId) async {
    final ref = _projectsRef;
    if (ref == null) return;

    final snapshot =
        await ref
            .doc(projectId)
            .collection('messages')
            .orderBy('timestamp', descending: false)
            .get();
    final messages =
        snapshot.docs.map((doc) => ChatMessage.fromJson(doc.data())).toList();

    // Convert previous messages to Gemini history (excluding files for simplicity, or we can include them if we fetched the bytes, but usually we just include text history)
    final history =
        messages.where((m) => !m.isError).map((m) {
          return Content(m.role == MessageRole.user ? 'user' : 'model', [
            TextPart(m.content),
          ]);
        }).toList();

    _chatSession = _model.startChat(history: history);
    state = state.copyWith(messages: messages);
  }

  void startNewChat() {
    _chatSession = _model.startChat();
    state = state.copyWith(messages: [], currentProject: null);
  }

  Future<void> sendMessage(
    String text, {
    List<PlatformFile> files = const [],
  }) async {
    if (text.trim().isEmpty && files.isEmpty) return;
    if (_userId == null) return; // Must be logged in

    // 1. Ensure we have a project
    ChatProject project;
    if (state.currentProject == null) {
      // Create new project with title derived from first message or file
      String title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      if (title.isEmpty && files.isNotEmpty) title = 'Files uploaded';

      project = ChatProject(title: title);
      await _projectsRef!.doc(project.id).set(project.toJson());
      state = state.copyWith(currentProject: project);
    } else {
      project = state.currentProject!;
      project = project.copyWith(updatedAt: DateTime.now());
      await _projectsRef!.doc(project.id).update({
        'updatedAt': Timestamp.now(),
      });
    }

    final projectMessagesRef = _projectsRef!
        .doc(project.id)
        .collection('messages');

    // Prepare to upload and track attachments
    List<ChatAttachment> attachments = [];
    List<Part> geminiParts = [];

    // Pre-UI update to show loading immediately
    final userMessageId = const Uuid().v4();
    final tempUserMessage = ChatMessage(
      id: userMessageId,
      content: text,
      role: MessageRole.user,
      // We don't have URLs yet, so UI might just show "Uploading..." or we wait
    );

    state = state.copyWith(
      messages: [...state.messages, tempUserMessage],
      isLoading: true,
    );

    try {
      // Upload files
      for (var file in files) {
        if (file.bytes == null) continue;

        // Add to Gemini parts (in memory)
        String mimeType = _getMimeType(file.extension ?? '');
        geminiParts.add(InlineDataPart(mimeType, file.bytes!));

        // Upload to Firebase Storage
        final path =
            'users/$_userId/chat_projects/${project.id}/${const Uuid().v4()}_${file.name}';
        final storageRef = _storage.ref().child(path);

        String downloadUrl = '';
        try {
          final metadata = SettableMetadata(contentType: mimeType);
          await storageRef.putData(file.bytes!, metadata);
          downloadUrl = await storageRef.getDownloadURL();
        } catch (e) {
          debugPrint('Firebase Storage upload failed: $e');
          // Continue without a download URL, the file is still sent to Gemini directly
        }

        attachments.add(
          ChatAttachment(name: file.name, url: downloadUrl, mimeType: mimeType),
        );
      }

      // Finalize User message with uploaded URLs
      final finalUserMessage = ChatMessage(
        id: userMessageId,
        content: text,
        role: MessageRole.user,
        attachments: attachments,
      );

      // Update UI with attachments and save to Firestore
      final messages = [...state.messages];
      final uIndex = messages.indexWhere((m) => m.id == userMessageId);
      if (uIndex != -1) {
        messages[uIndex] = finalUserMessage;
        state = state.copyWith(messages: messages);
      }

      await projectMessagesRef
          .doc(finalUserMessage.id)
          .set(finalUserMessage.toJson());

      // Add text part to Gemini
      if (text.isNotEmpty) {
        geminiParts.add(TextPart(text));
      }

      // Prepare AI message
      final aiMessageId = const Uuid().v4();
      final initialAiMessage = ChatMessage(
        id: aiMessageId,
        content: '',
        role: MessageRole.ai,
        isStreaming: true,
      );

      state = state.copyWith(messages: [...state.messages, initialAiMessage]);

      // Send to Gemini
      final responseStream = _chatSession!.sendMessageStream(
        Content.multi(geminiParts),
      );

      String fullContent = '';
      await for (final chunk in responseStream) {
        fullContent += (chunk.text ?? '');
        final currentMessages = [...state.messages];
        final index = currentMessages.indexWhere((m) => m.id == aiMessageId);
        if (index != -1) {
          currentMessages[index] = currentMessages[index].copyWith(
            content: fullContent,
          );
          state = state.copyWith(messages: currentMessages);
        }
      }

      // Mark streaming as done and save to Firestore
      final finalMessages = [...state.messages];
      final index = finalMessages.indexWhere((m) => m.id == aiMessageId);
      if (index != -1) {
        final existing = finalMessages[index];
        final finalMessage = existing.copyWith(
          content: fullContent,
          isStreaming: false,
        );
        finalMessages[index] = finalMessage;

        await projectMessagesRef
            .doc(finalMessage.id)
            .set(finalMessage.toJson());

        state = state.copyWith(messages: finalMessages, isLoading: false);
      }
    } catch (e) {
      final errorMessages = [...state.messages];
      // Simple error handling
      final existingAiIndex = errorMessages.indexWhere(
        (m) => m.role == MessageRole.ai && m.isStreaming,
      );
      if (existingAiIndex != -1) {
        errorMessages[existingAiIndex] = errorMessages[existingAiIndex]
            .copyWith(
              content: 'Error: ${e.toString()}',
              isStreaming: false,
              isError: true,
            );
      } else {
        errorMessages.add(
          ChatMessage(
            content: 'Error: ${e.toString()}',
            role: MessageRole.ai,
            isError: true,
          ),
        );
      }
      state = state.copyWith(messages: errorMessages, isLoading: false);
    }
  }

  Future<void> selectProject(ChatProject project) async {
    state = state.copyWith(
      currentProject: project,
      messages: [],
      isLoading: true,
    );
    await _loadMessages(project.id);
    state = state.copyWith(isLoading: false);
  }

  String _getMimeType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'csv':
        return 'text/csv';
      case 'doc':
      case 'docx':
        return 'application/msword';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      default:
        return 'application/octet-stream';
    }
  }
}

final aiChatProvider = NotifierProvider<AiChatProvider, AiChatState>(() {
  return AiChatProvider();
});

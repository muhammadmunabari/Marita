import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:marita/models/chat_message.dart';
import 'package:marita/models/message_version_group.dart';
import 'package:marita/models/message_feedback.dart';
import 'package:marita/services/ai_pipeline_service.dart';
import 'package:marita/providers/auth_provider.dart';
import 'package:marita/providers/workspace_provider.dart';
import 'package:marita/models/workspace.dart';

class ChatEditingState {
  final String targetGroupId;
  final String originalText;
  final int promptVersion;
  final DateTime? originalTimestamp;

  ChatEditingState({
    required this.targetGroupId,
    required this.originalText,
    required this.promptVersion,
    this.originalTimestamp,
  });
}

class ChatState {
  final String? chatId;
  final String? title;
  final List<MessageVersionGroup> messageGroups;
  final bool isLoading;
  final AIPipelinePhase pipelinePhase;
  final ChatEditingState? editingState;
  final ConversationStatus status;

  ChatState({
    this.chatId,
    this.title,
    this.messageGroups = const [],
    this.isLoading = false,
    this.pipelinePhase = AIPipelinePhase.idle,
    this.editingState,
    this.status = ConversationStatus.draft,
  });

  ChatState copyWith({
    String? chatId,
    String? title,
    List<MessageVersionGroup>? messageGroups,
    bool? isLoading,
    AIPipelinePhase? pipelinePhase,
    ChatEditingState? editingState,
    ConversationStatus? status,
  }) {
    return ChatState(
      chatId: chatId ?? this.chatId,
      title: title ?? this.title,
      messageGroups: messageGroups ?? this.messageGroups,
      isLoading: isLoading ?? this.isLoading,
      pipelinePhase: pipelinePhase ?? this.pipelinePhase,
      editingState: editingState ?? this.editingState,
      status: status ?? this.status,
    );
  }
  
  ChatState clearEditingState() {
    return ChatState(
      chatId: chatId,
      title: title,
      messageGroups: messageGroups,
      isLoading: isLoading,
      pipelinePhase: pipelinePhase,
      editingState: null,
      status: status,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() {
    ref.listen<Workspace?>(activeWorkspaceProvider, (previous, next) {
      if (previous != null && next?.id != previous.id) {
        state = ChatState();
      }
    });
    return ChatState();
  }

  void createNewChat() {
    state = ChatState();
  }

  void loadChat(String chatId, String? title, List<ChatMessage> messages) {
    state = ChatState(
      chatId: chatId, 
      title: title, 
      messageGroups: _groupMessages(messages)
    );
  }

  List<MessageVersionGroup> _groupMessages(List<ChatMessage> messages) {
    final groups = <MessageVersionGroup>[];
    
    final sortedMessages = List<ChatMessage>.from(messages)
      ..sort((a, b) => (a.createdAt ?? DateTime.now()).compareTo(b.createdAt ?? DateTime.now()));

    for (var msg in sortedMessages) {
      if (msg.role == MessageRole.user) {
        if (msg.parentMessageId == null) {
          groups.add(MessageVersionGroup(
            groupId: msg.id,
            promptVersions: [msg],
            responseVersions: [],
            activePromptIndex: 0,
            activeResponseIndex: 0,
          ));
        } else {
          final targetGroupIndex = groups.indexWhere((g) => 
              g.promptVersions.any((p) => p.id == msg.parentMessageId) || g.groupId == msg.parentMessageId);
          
          if (targetGroupIndex != -1) {
            final group = groups[targetGroupIndex];
            final updatedPrompts = List<ChatMessage>.from(group.promptVersions)..add(msg);
            int newActiveIndex = msg.isCurrentVersion ? updatedPrompts.length - 1 : group.activePromptIndex;
            
            groups[targetGroupIndex] = group.copyWith(
              promptVersions: updatedPrompts,
              activePromptIndex: newActiveIndex,
            );
          } else {
            groups.add(MessageVersionGroup(
              groupId: msg.id,
              promptVersions: [msg],
              responseVersions: [],
              activePromptIndex: 0,
              activeResponseIndex: 0,
            ));
          }
        }
      } else {
        if (groups.isEmpty) continue;
        
        if (msg.parentMessageId == null) {
          final targetGroupIndex = groups.length - 1;
          final group = groups[targetGroupIndex];
          final updatedResponses = List<ChatMessage>.from(group.responseVersions)..add(msg);
          int newActiveIndex = msg.isCurrentVersion ? updatedResponses.length - 1 : group.activeResponseIndex;
          
          groups[targetGroupIndex] = group.copyWith(
            responseVersions: updatedResponses,
            activeResponseIndex: newActiveIndex,
          );
        } else {
          final targetGroupIndex = groups.indexWhere((g) => 
              g.promptVersions.any((p) => p.id == msg.parentMessageId) || 
              g.responseVersions.any((r) => r.id == msg.parentMessageId));
              
          if (targetGroupIndex != -1) {
            final group = groups[targetGroupIndex];
            final updatedResponses = List<ChatMessage>.from(group.responseVersions)..add(msg);
            int newActiveIndex = msg.isCurrentVersion ? updatedResponses.length - 1 : group.activeResponseIndex;
            
            groups[targetGroupIndex] = group.copyWith(
              responseVersions: updatedResponses,
              activeResponseIndex: newActiveIndex,
            );
          } else {
            final groupIndex = groups.length - 1;
            final group = groups[groupIndex];
            final updatedResponses = List<ChatMessage>.from(group.responseVersions)..add(msg);
            groups[groupIndex] = group.copyWith(
              responseVersions: updatedResponses,
              activeResponseIndex: msg.isCurrentVersion ? updatedResponses.length - 1 : group.activeResponseIndex,
            );
          }
        }
      }
    }

    return groups;
  }

  void updateTitle(String newTitle) {
    state = state.copyWith(title: newTitle);
  }

  void startEditingMessage(String groupId) {
    final group = state.messageGroups.firstWhere((g) => g.groupId == groupId);
    state = state.copyWith(
      editingState: ChatEditingState(
        targetGroupId: groupId,
        originalText: group.activePrompt.text,
        promptVersion: group.activePromptIndex + 1,
        originalTimestamp: group.activePrompt.createdAt,
      ),
    );
  }

  void cancelEditing() {
    state = state.clearEditingState();
  }

  Future<void> sendEditedMessage(String newText) async {
    final editingState = state.editingState;
    if (editingState == null) return;
    
    final groupId = editingState.targetGroupId;
    final groupIndex = state.messageGroups.indexWhere((g) => g.groupId == groupId);
    if (groupIndex == -1) return;
    
    final group = state.messageGroups[groupIndex];
    final originalPrompt = group.activePrompt;
    
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    
    final firestoreService = ref.read(firestoreServiceProvider);
    final activeChatId = state.chatId;
    if (activeChatId == null) return;

    cancelEditing(); // Clear editing state early

    final promptId = const Uuid().v4();
    final newPrompt = originalPrompt.copyWith(
      id: promptId,
      text: newText,
      version: group.promptVersions.length + 1,
      parentMessageId: groupId, // Link to the original group
      createdAt: DateTime.now(),
    );

    // Add to group and make active
    final updatedPrompts = List<ChatMessage>.from(group.promptVersions)..add(newPrompt);
    final newGroup = group.copyWith(
      promptVersions: updatedPrompts,
      activePromptIndex: updatedPrompts.length - 1,
    );
    
    final newGroups = List<MessageVersionGroup>.from(state.messageGroups);
    newGroups[groupIndex] = newGroup;
    
    state = state.copyWith(
      messageGroups: newGroups,
      isLoading: true,
      pipelinePhase: AIPipelinePhase.retrievingContext,
    );

    await firestoreService.addWorkspaceChatMessage(
      companyId: workspace.id,
      chatId: activeChatId,
      messageMap: newPrompt.toMap(),
    );

    await _generateAiResponse(
      workspaceId: workspace.id,
      activeChatId: activeChatId,
      groupId: groupId,
      promptId: promptId,
      text: newText,
      attachments: newPrompt.attachments,
      userMessage: newPrompt,
    );
  }

  Future<void> regenerateResponse(String groupId) async {
    final groupIndex = state.messageGroups.indexWhere((g) => g.groupId == groupId);
    if (groupIndex == -1) return;
    
    final group = state.messageGroups[groupIndex];
    final activePrompt = group.activePrompt;
    
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    
    final activeChatId = state.chatId;
    if (activeChatId == null) return;

    state = state.copyWith(
      isLoading: true,
      pipelinePhase: AIPipelinePhase.retrievingContext,
    );

    await _generateAiResponse(
      workspaceId: workspace.id,
      activeChatId: activeChatId,
      groupId: groupId,
      promptId: activePrompt.id,
      text: activePrompt.text,
      attachments: activePrompt.attachments,
      userMessage: activePrompt,
    );
  }

  void navigateVersion(String groupId, {required bool isPrompt, required int direction}) {
    final groupIndex = state.messageGroups.indexWhere((g) => g.groupId == groupId);
    if (groupIndex == -1) return;
    
    final group = state.messageGroups[groupIndex];
    if (isPrompt) {
      final newIndex = group.activePromptIndex + direction;
      if (newIndex >= 0 && newIndex < group.promptVersions.length) {
        final newGroups = List<MessageVersionGroup>.from(state.messageGroups);
        newGroups[groupIndex] = group.copyWith(activePromptIndex: newIndex);
        state = state.copyWith(messageGroups: newGroups);
      }
    } else {
      final newIndex = group.activeResponseIndex + direction;
      if (newIndex >= 0 && newIndex < group.responseVersions.length) {
        final newGroups = List<MessageVersionGroup>.from(state.messageGroups);
        newGroups[groupIndex] = group.copyWith(activeResponseIndex: newIndex);
        state = state.copyWith(messageGroups: newGroups);
      }
    }
  }

  Future<void> submitFeedback(MessageFeedback feedback) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    
    try {
      // Save to Firestore (assuming method exists or will be implemented)
      await firestoreService.submitFeedback(feedback);
    } catch (e) {
      debugPrint('Failed to submit feedback: $e');
    }

    // Update local state to reflect that feedback was given
    final groupIndex = state.messageGroups.indexWhere((g) => 
        g.responseVersions.any((r) => r.id == feedback.messageId));
        
    if (groupIndex != -1) {
      final group = state.messageGroups[groupIndex];
      final responseIndex = group.responseVersions.indexWhere((r) => r.id == feedback.messageId);
      
      if (responseIndex != -1) {
        final updatedResponse = group.responseVersions[responseIndex].copyWith(
          feedbackType: feedback.type,
          feedbackSubmitted: true,
        );
        
        final newResponses = List<ChatMessage>.from(group.responseVersions);
        newResponses[responseIndex] = updatedResponse;
        
        final newGroups = List<MessageVersionGroup>.from(state.messageGroups);
        newGroups[groupIndex] = group.copyWith(responseVersions: newResponses);
        
        state = state.copyWith(messageGroups: newGroups);
      }
    }
  }

  Future<void> requestReport(String messageId) async {
    // Placeholder for Phase 1B/2B
  }

  LoadingRequestType _detectRequestType(String message, List<String> fileNames) {
    final lower = message.toLowerCase();
    final allText = '$lower ${fileNames.join(' ').toLowerCase()}';

    if (allText.contains(RegExp(r'annual report|laporan tahunan'))) {
      return LoadingRequestType.annualReport;
    }
    if (allText.contains(RegExp(r'invoice|faktur'))) {
      return LoadingRequestType.invoices;
    }
    if (allText.contains(RegExp(r'receipt|kwitansi|struk'))) {
      return LoadingRequestType.receipts;
    }
    if (allText.contains(RegExp(r'contract|perjanjian|kontrak'))) {
      return LoadingRequestType.contracts;
    }
    if (allText.contains(RegExp(r'financial statement|laporan keuangan|neraca|balance sheet|income statement'))) {
      return LoadingRequestType.financialStatements;
    }
    if (allText.contains(RegExp(r'jurnal|debit|kredit|akuntansi|accounting|cogs|depreciation'))) {
      return LoadingRequestType.accountingQuestion;
    }
    return LoadingRequestType.general;
  }

  void sendMessage(String text, {List<ChatAttachment>? attachments}) async {
    final workspace = ref.read(activeWorkspaceProvider);
    if (workspace == null) return;
    
    final firestoreService = ref.read(firestoreServiceProvider);
    
    String? activeChatId = state.chatId;
    if (activeChatId == null) {
      // First message in a new chat, auto-generate title
      final title = text.length > 30 ? '${text.substring(0, 30)}...' : text;
      final userId = ref.read(currentUserProvider)?.uid ?? 'unknown';
      activeChatId = await firestoreService.createWorkspaceChat(
        companyId: workspace.id,
        userId: userId,
        title: title,
      );
      state = state.copyWith(chatId: activeChatId, title: title);
    }
    
    final promptId = const Uuid().v4();
    final userMessage = ChatMessage(
      id: promptId,
      text: text,
      role: MessageRole.user,
      attachments: attachments ?? [],
      createdAt: DateTime.now(),
      loadingRequestType: _detectRequestType(text, attachments?.map((a) => a.name).toList() ?? []),
    );
    
    // Create new group for the prompt
    final newGroup = MessageVersionGroup(
      groupId: promptId,
      promptVersions: [userMessage],
      responseVersions: [],
      activePromptIndex: 0,
      activeResponseIndex: 0,
    );
    
    state = state.copyWith(
      messageGroups: [...state.messageGroups, newGroup],
      isLoading: true,
      pipelinePhase: AIPipelinePhase.retrievingContext,
    );
    
    await firestoreService.addWorkspaceChatMessage(
      companyId: workspace.id,
      chatId: activeChatId,
      messageMap: userMessage.toMap(),
    );
    
    await _generateAiResponse(
      workspaceId: workspace.id,
      activeChatId: activeChatId,
      groupId: promptId,
      promptId: promptId,
      text: text,
      attachments: attachments ?? const [],
      userMessage: userMessage,
    );
  }

  Future<void> _generateAiResponse({
    required String workspaceId,
    required String activeChatId,
    required String groupId,
    required String promptId,
    required String text,
    required List<ChatAttachment> attachments,
    required ChatMessage userMessage,
  }) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    
    final group = state.messageGroups.firstWhere((g) => g.groupId == groupId);
    final currentVersion = group.responseVersions.length + 1;

    // Setup AI response message
    final aiMessageId = const Uuid().v4();
    ChatMessage aiMessage = ChatMessage(
      id: aiMessageId,
      text: '',
      role: MessageRole.ai,
      isStreaming: true,
      createdAt: DateTime.now(),
      parentMessageId: promptId,
      version: currentVersion,
    );
    
    // Add AI message placeholder to the group
    _updateGroupWithAIResponse(groupId, aiMessage);
    
    try {
      final pipelineService = ref.read(aiPipelineServiceProvider);
      
      // Update phase
      state = state.copyWith(pipelinePhase: AIPipelinePhase.generating);
      
      // We need to pass the context/history. We can flatmap the active messages for context
      final history = state.messageGroups.expand((g) {
        final msgs = <ChatMessage>[];
        if (g.groupId != groupId) {
          msgs.add(g.activePrompt);
          if (g.responseVersions.isNotEmpty) {
            msgs.add(g.activeResponse!);
          }
        }
        return msgs;
      }).toList();
      
      await for (final chunk in pipelineService.processQueryStream(
        workspaceId: workspaceId,
        query: text,
        chatHistory: history,
        attachments: attachments,
      )) {
        if (chunk.isError) {
          aiMessage = aiMessage.copyWith(
            text: 'An error occurred: ${chunk.errorMessage}',
            isStreaming: false,
          );
          _updateGroupWithAIResponse(groupId, aiMessage);
          break;
        }
        
        aiMessage = aiMessage.copyWith(
          text: aiMessage.text + (chunk.textChunk ?? ''),
        );
        _updateGroupWithAIResponse(groupId, aiMessage);
      }
      
      // Finalize message
      final finalResult = pipelineService.lastResult;
      
      // Check if it's an analysis response
      // Show Verification Metrics and Full Analysis Report on ALL prompts,
      // EXCEPT when the AI only provides a short answer and no context was retrieved.
      bool isAnalysis = true;
      final isShort = aiMessage.text.length < 300;
      final noChunks = (finalResult?.retrievedChunksCount ?? 0) == 0;
      
      if (isShort && noChunks) {
        isAnalysis = false;
      }
      
      aiMessage = aiMessage.copyWith(
        isStreaming: false,
        confidenceScore: finalResult?.confidenceScore ?? 1.0,
        evidenceScore: finalResult?.evidenceScore ?? 0.0,
        citations: finalResult?.citations ?? const [],
        verificationIssues: finalResult?.feedback ?? const [],
        fullCorrectCount: finalResult?.fullCorrectCount ?? 0,
        semiCorrectCount: finalResult?.semiCorrectCount ?? 0,
        incorrectCount: finalResult?.incorrectCount ?? 0,
        precisionPercent: finalResult?.precisionPercent ?? 100.0,
        retrievedChunksCount: finalResult?.retrievedChunksCount ?? 0,
        retrievedChunksInfo: finalResult?.retrievedChunksInfo ?? const [],
        isAnalysisResponse: isAnalysis,
        queryType: userMessage.loadingRequestType?.name ?? 'general',
      );
      
      _updateGroupWithAIResponse(groupId, aiMessage);
      
      // Save AI message to firestore
      await firestoreService.addWorkspaceChatMessage(
        companyId: workspaceId,
        chatId: activeChatId,
        messageMap: aiMessage.toMap(),
      );
      
      // Invalidate chat history so the sidebar updates
      ref.invalidate(chatHistoryProvider);
      
    } catch (e) {
      aiMessage = aiMessage.copyWith(
        text: 'An unexpected error occurred.',
        isStreaming: false,
      );
      _updateGroupWithAIResponse(groupId, aiMessage);
    } finally {
      state = state.copyWith(
        isLoading: false,
        pipelinePhase: AIPipelinePhase.idle,
      );
    }
  }
  
  void _updateGroupWithAIResponse(String groupId, ChatMessage aiMessage) {
    final groupIndex = state.messageGroups.indexWhere((g) => g.groupId == groupId);
    if (groupIndex != -1) {
      final group = state.messageGroups[groupIndex];
      
      final responseIndex = group.responseVersions.indexWhere((r) => r.id == aiMessage.id);
      List<ChatMessage> updatedResponses;
      
      if (responseIndex != -1) {
        updatedResponses = List<ChatMessage>.from(group.responseVersions);
        updatedResponses[responseIndex] = aiMessage;
      } else {
        updatedResponses = List<ChatMessage>.from(group.responseVersions)..add(aiMessage);
      }
      
      final updatedGroups = List<MessageVersionGroup>.from(state.messageGroups);
      updatedGroups[groupIndex] = group.copyWith(
        responseVersions: updatedResponses,
        activeResponseIndex: updatedResponses.length - 1, // Focus on the latest
      );
      
      state = state.copyWith(messageGroups: updatedGroups);
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

final chatHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final workspace = ref.watch(activeWorkspaceProvider);
  if (workspace == null) return [];
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getWorkspaceChats(workspace.id);
});


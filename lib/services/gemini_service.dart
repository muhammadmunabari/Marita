import 'package:firebase_ai/firebase_ai.dart';
import 'package:marita/models/chat_message.dart';
import 'dart:io';

class GeminiService {
  // Using FirebaseVertexAI from firebase_ai package
  static final _vertexAI = FirebaseAI.vertexAI(location: 'us-central1');

  // Using Gemini 2.5 Flash as requested fallback
  static const _modelName = 'gemini-2.5-pro';

  static GenerativeModel get _model => _vertexAI.generativeModel(
    model: _modelName,
    generationConfig: GenerationConfig(
      temperature: 0.1,
      topP: 0.95,
      topK: 40,
      maxOutputTokens: 65535,
    ),
  );

  /// Sends a message to Gemini and returns a stream of responses.
  static Stream<String> sendMessageStream(
    String prompt, {
    List<ChatAttachment> attachments = const [],
    List<ChatMessage> history = const [],
  }) async* {
    try {
      final chat = _model.startChat(
        history:
            history
                .map(
                  (msg) => Content(
                    msg.role == MessageRole.user ? 'user' : 'model',
                    [TextPart(msg.text)],
                  ),
                )
                .toList(),
      );

      final List<Part> parts = [TextPart(prompt)];

      // Handle attachments
      for (final attachment in attachments) {
        final file = File(attachment.path);
        if (!await file.exists()) continue;

        if (attachment.type == 'image') {
          final bytes = await file.readAsBytes();
          final mimeType = _getMimeType(attachment.name);
          parts.add(InlineDataPart(mimeType, bytes));
        } else if (attachment.type == 'pdf') {
          final bytes = await file.readAsBytes();
          parts.add(InlineDataPart('application/pdf', bytes));
        } else {
          // Handle as text if it's a known text format
          final ext = attachment.name.split('.').last.toLowerCase();
          final textFormats = ['csv', 'json', 'txt', 'sql', 'md', 'xml'];

          if (textFormats.contains(ext)) {
            try {
              final content = await file.readAsString();
              parts.add(
                TextPart('\nFile Content (${attachment.name}):\n$content'),
              );
            } catch (e) {
              // Fallback to byte part if string reading fails
              final bytes = await file.readAsBytes();
              parts.add(InlineDataPart('text/plain', bytes));
            }
          } else {
            // Generic fallback for other types
            final bytes = await file.readAsBytes();
            parts.add(InlineDataPart('application/octet-stream', bytes));
          }
        }
      }

      final response = chat.sendMessageStream(Content.multi(parts));

      await for (final chunk in response) {
        print('Gemini Stream Chunk received, length: ${chunk.text?.length}');
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
      print('Gemini Stream finished successfully.');
    } catch (e) {
      print('Gemini Stream Error: $e');
      yield 'Error: $e';
    }
  }

  static String _getMimeType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }
}

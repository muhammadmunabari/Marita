import 'package:firebase_ai/firebase_ai.dart';
import 'package:marita/models/chat_message.dart';
import 'dart:io';

class GeminiService {
  // Using FirebaseVertexAI from firebase_ai package
  static final _vertexAI = FirebaseAI.vertexAI(location: 'global');
  
  // Using the new Gemini 3.1 Flash Lite model
  static const _modelName = 'gemini-3.1-flash-lite';

  static GenerativeModel get _model => _vertexAI.generativeModel(
    model: _modelName,
    generationConfig: GenerationConfig(
      temperature: 0.1,
      topP: 0.95,
      topK: 40,
      maxOutputTokens: 8192,
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
        history: history.map((msg) => Content(
          msg.role == MessageRole.user ? 'user' : 'model',
          [TextPart(msg.text)],
        )).toList(),
      );

      final List<Part> parts = [TextPart(prompt)];
      
      // Handle attachments
      for (final attachment in attachments) {
        if (attachment.type == 'image') {
          final bytes = await File(attachment.path).readAsBytes();
          parts.add(InlineDataPart('image/jpeg', bytes));
        } else if (attachment.type == 'pdf') {
          final bytes = await File(attachment.path).readAsBytes();
          parts.add(InlineDataPart('application/pdf', bytes));
        } else {
          if (attachment.name.endsWith('.csv')) {
            final content = await File(attachment.path).readAsString();
            parts.add(TextPart('\nFile Content (${attachment.name}):\n$content'));
          }
        }
      }

      final response = chat.sendMessageStream(Content.multi(parts));
      
      await for (final chunk in response) {
        if (chunk.text != null) {
          yield chunk.text!;
        }
      }
    } catch (e) {
      yield 'Error: $e';
    }
  }
}

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:marita/models/chat_message.dart';
import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

class GeminiService {
  // gemini-3.1-pro-preview is a preview model only available on the global
  // Vertex AI endpoint. gemini-2.5-flash-lite is stable and available
  // regionally in us-central1. Two separate instances are required.
  static final _vertexAIGlobal = FirebaseAI.vertexAI(location: 'global');
  static final _vertexAIRegional = FirebaseAI.vertexAI(location: 'us-central1');

  static const mainModelName = 'gemini-3.1-pro-preview';
  static const judgeModelName = 'gemini-2.5-flash-lite';

  static GenerativeModel getModel(
    String modelName, {
    GenerationConfig? config,
    Content? systemInstruction,
  }) {
    // Route preview models to the global endpoint; stable models to regional.
    final backend =
        modelName == mainModelName ? _vertexAIGlobal : _vertexAIRegional;
    return backend.generativeModel(
      model: modelName,
      generationConfig:
          config ??
          GenerationConfig(
            temperature: 0.1,
            topP: 0.95,
            topK: 40,
            maxOutputTokens: 65535,
          ),
      systemInstruction: systemInstruction,
    );
  }

  /// For unit testing purposes to avoid invoking actual Firebase AI APIs.
  static Future<String> Function({
    required String prompt,
    required String modelName,
    required GenerationConfig? config,
  })? mockGenerateContent;

  /// Generates content directly (not streaming, useful for LLM-as-a-judge).
  static Future<String> generateContent({
    required String prompt,
    String modelName = mainModelName,
    GenerationConfig? config,
  }) async {
    if (mockGenerateContent != null) {
      return mockGenerateContent!(
        prompt: prompt,
        modelName: modelName,
        config: config,
      );
    }
    try {
      final model = getModel(modelName, config: config);
      final response = await model.generateContent([Content.text(prompt)]);
      return response.text ?? '';
    } catch (e) {
      debugPrint('Gemini Generate Content Error: $e');
      rethrow;
    }
  }

  /// Generates content using the streaming API and returns the full accumulated text.
  /// More reliable than generateContent() for long JSON responses because it 
  /// consumes the full stream rather than relying on a single HTTP response body.
  static Future<String> generateContentFull({
    required String prompt,
    String modelName = mainModelName,
    GenerationConfig? config,
  }) async {
    if (mockGenerateContent != null) {
      return mockGenerateContent!(
        prompt: prompt,
        modelName: modelName,
        config: config,
      );
    }
    try {
      final model = getModel(modelName, config: config);
      final stream = model.generateContentStream([Content.text(prompt)]);
      final buffer = StringBuffer();
      await for (final chunk in stream) {
        if (chunk.text != null) {
          buffer.write(chunk.text);
        }
      }
      return buffer.toString();
    } catch (e) {
      debugPrint('Gemini Generate Content Full Error: $e');
      rethrow;
    }
  }

  /// Sends a message to Gemini and returns a stream of responses.
  static Stream<String> sendMessageStream(
    String prompt, {
    List<ChatAttachment> attachments = const [],
    List<ChatMessage> history = const [],
    String modelName = mainModelName,
    Content? systemInstruction,
  }) async* {
    try {
      final chat = getModel(
        modelName,
        systemInstruction: systemInstruction,
      ).startChat(
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

        final ext = attachment.name.split('.').last.toLowerCase();

        if (attachment.type == 'image' ||
            ['jpg', 'jpeg', 'png', 'webp', 'heic', 'heif'].contains(ext)) {
          final bytes = await file.readAsBytes();
          final mimeType = _getMimeType(attachment.name);
          parts.add(InlineDataPart(mimeType, bytes));
        } else if (attachment.type == 'pdf' || ext == 'pdf') {
          final bytes = await file.readAsBytes();
          parts.add(InlineDataPart('application/pdf', bytes));
        } else if (ext == 'xlsx' || ext == 'xls') {
          // Note: 'excel' package mostly handles .xlsx. .xls (legacy) might fail.
          final textContent = await _extractExcelContent(file);
          parts.add(
            TextPart('\n[Excel File: ${attachment.name}]\n$textContent'),
          );
        } else if (ext == 'docx' || ext == 'doc') {
          // Note: .docx is a zip of XMLs. .doc (legacy) is binary and will likely fail here.
          final textContent = await _extractDocxContent(file);
          parts.add(
            TextPart('\n[Word Document: ${attachment.name}]\n$textContent'),
          );
        } else {
          // Handle as text if it's a known text format
          final textFormats = [
            'csv',
            'json',
            'txt',
            'sql',
            'md',
            'xml',
            'dart',
            'html',
            'css',
            'js',
            'ts',
          ];

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
            // Last resort: try to read as text instead of octet-stream
            try {
              final content = await file.readAsString();
              parts.add(
                TextPart('\nFile Content (${attachment.name}):\n$content'),
              );
            } catch (_) {
              debugPrint(
                'Warning: Skipping unsupported binary file ${attachment.name}',
              );
            }
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
      debugPrint('Gemini Stream Error: $e');
      yield 'Error: $e';
    }
  }

  static Future<String> _extractExcelContent(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final excel = excel_pkg.Excel.decodeBytes(bytes);
      final sb = StringBuffer();

      for (var table in excel.tables.keys) {
        sb.writeln('Sheet: $table');
        final sheet = excel.tables[table];
        if (sheet == null) continue;

        for (var row in sheet.rows) {
          final rowData = row
              .map((cell) => cell?.value?.toString() ?? '')
              .join(' | ');
          if (rowData.trim().isNotEmpty) {
            sb.writeln(rowData);
          }
        }
        sb.writeln();
      }
      return sb.toString();
    } catch (e) {
      return 'Error extracting Excel content: $e (Note: .xls legacy format might not be supported, please use .xlsx)';
    }
  }

  static Future<String> _extractDocxContent(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.findFile('word/document.xml');

      if (documentFile == null) {
        return 'Could not parse document structure. (Note: .doc legacy format is not supported, please use .docx)';
      }

      final content = documentFile.content as List<int>;
      final documentXml = XmlDocument.parse(utf8.decode(content));

      // Extract text from <w:p> tags to preserve paragraphs
      final paragraphs = documentXml.findAllElements('w:p');
      return paragraphs
          .map((p) {
            return p.findAllElements('w:t').map((t) => t.innerText).join('');
          })
          .join('\n');
    } catch (e) {
      return 'Error extracting Word content: $e';
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

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:marita/models/chat_message.dart';
import 'dart:io';
import 'dart:convert';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

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

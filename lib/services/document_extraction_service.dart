import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:firebase_ai/firebase_ai.dart';

class ExtractedPage {
  final int pageNumber;
  final String text;

  ExtractedPage({required this.pageNumber, required this.text});
}

class DocumentExtractionService {
  static final _vertexAI = FirebaseAI.vertexAI(location: 'us-central1');
  static const _modelName = 'gemini-2.5-pro';

  static GenerativeModel get _model => _vertexAI.generativeModel(
    model: _modelName,
  );

  /// Extracts text from a file path based on its extension/mimeType.
  static Future<List<ExtractedPage>> extractText(String filePath, String fileName) async {
    final file = File(filePath);
    if (!await file.exists()) {
      throw Exception('File does not exist: $filePath');
    }

    final ext = fileName.split('.').last.toLowerCase();

    try {
      if (ext == 'pdf') {
        return await _extractPdf(file);
      } else if (ext == 'xlsx' || ext == 'xls') {
        final text = await _extractExcel(file);
        return [ExtractedPage(pageNumber: 1, text: text)];
      } else if (ext == 'docx' || ext == 'doc') {
        final text = await _extractDocx(file);
        return [ExtractedPage(pageNumber: 1, text: text)];
      } else if (['png', 'jpg', 'jpeg', 'webp', 'heic', 'heif'].contains(ext)) {
        final text = await _extractImageOCR(file, ext);
        return [ExtractedPage(pageNumber: 1, text: text)];
      } else {
        // Read as plain text
        final text = await file.readAsString();
        return [ExtractedPage(pageNumber: 1, text: text)];
      }
    } catch (e) {
      debugPrint('Error extracting text from $fileName: $e');
      // If reading as string fails (e.g. invalid encoding), try to read as bytes or return empty
      try {
        final bytes = await file.readAsBytes();
        final text = utf8.decode(bytes, allowMalformed: true);
        return [ExtractedPage(pageNumber: 1, text: text)];
      } catch (innerErr) {
        debugPrint('Fallback text extraction failed for $fileName: $innerErr');
        return [];
      }
    }
  }

  static Future<List<ExtractedPage>> _extractPdf(File file) async {
    final bytes = await file.readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final List<ExtractedPage> pages = [];
    
    StringBuffer allText = StringBuffer();

    for (int i = 0; i < document.pages.count; i++) {
      final pageText = extractor.extractText(startPageIndex: i, endPageIndex: i);
      pages.add(ExtractedPage(pageNumber: i + 1, text: pageText));
      allText.write(pageText);
    }
    
    document.dispose();

    // Check if the PDF has virtually no text (OCR/scanned PDF detection)
    if (allText.toString().trim().length < 50 && bytes.isNotEmpty) {
      debugPrint('PDF text is empty or very short, falling back to Gemini OCR');
      final ocrText = await _extractPdfOCR(bytes);
      return [ExtractedPage(pageNumber: 1, text: ocrText)];
    }

    return pages;
  }

  static Future<String> _extractPdfOCR(List<int> bytes) async {
    try {
      final prompt = 'Extract all readable text from this scanned PDF document. Maintain formatting where appropriate. Output only the extracted text.';
      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          InlineDataPart('application/pdf', Uint8List.fromList(bytes)),
        ])
      ]);
      return response.text ?? '';
    } catch (e) {
      debugPrint('Gemini PDF OCR Error: $e');
      return 'PDF OCR extraction failed: $e';
    }
  }

  static Future<String> _extractImageOCR(File file, String ext) async {
    try {
      final bytes = await file.readAsBytes();
      final mimeType = _getMimeType(ext);
      final prompt = 'Extract all readable text from this image. Output only the extracted text. Maintain formatting where appropriate.';
      final response = await _model.generateContent([
        Content.multi([
          TextPart(prompt),
          InlineDataPart(mimeType, bytes),
        ])
      ]);
      return response.text ?? '';
    } catch (e) {
      debugPrint('Gemini Image OCR Error: $e');
      return 'Image OCR extraction failed: $e';
    }
  }

  static String _getMimeType(String ext) {
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

  static Future<String> _extractExcel(File file) async {
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
      return 'Error extracting Excel content: $e';
    }
  }

  static Future<String> _extractDocx(File file) async {
    try {
      final bytes = await file.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentFile = archive.findFile('word/document.xml');

      if (documentFile == null) {
        return 'Could not parse document structure. (Note: legacy .doc is not supported, please use .docx)';
      }

      final content = documentFile.content as List<int>;
      final documentXml = XmlDocument.parse(utf8.decode(content));

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
}

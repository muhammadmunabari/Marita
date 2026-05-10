import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/chat_message.dart';

class ExportService {
  /// Exports a single AI response to PDF with premium branding.
  static Future<void> exportMessageToPdf(String content) async {
    try {
      final pdf = pw.Document();

      // Premium Header Design
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Brand Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'MARITA',
                          style: pw.TextStyle(
                            fontSize: 28,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.black,
                            letterSpacing: 2,
                          ),
                        ),
                        pw.Text(
                          'AI-POWERED FRAUD DETECTION',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'ANALYSIS REPORT',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey900,
                          ),
                        ),
                        pw.Text(
                          'Ref: ${DateTime.now().millisecondsSinceEpoch}',
                          style: const pw.TextStyle(
                            fontSize: 8,
                            color: PdfColors.grey600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Container(height: 2, color: PdfColors.limeAccent700),
                pw.SizedBox(height: 30),

                // Report Date
                pw.Text(
                  'Date: ${DateTime.now().toString().split('.')[0]}',
                  style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.grey800,
                  ),
                ),
                pw.SizedBox(height: 20),

                // Content Section
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey50,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                    border: pw.Border.all(color: PdfColors.grey200),
                  ),
                  child: pw.Text(
                    content,
                    style: const pw.TextStyle(
                      fontSize: 11,
                      lineSpacing: 5,
                      color: PdfColors.black,
                    ),
                  ),
                ),

                pw.Spacer(),

                // Premium Footer
                pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Confidential — Marita Internal Analysis',
                      style: const pw.TextStyle(
                        fontSize: 7,
                        color: PdfColors.grey500,
                      ),
                    ),
                    pw.Text(
                      'marita.ai',
                      style: pw.TextStyle(
                        fontSize: 7,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File("${output.path}/Marita_Report_$timestamp.pdf");
      await file.writeAsBytes(await pdf.save());

      // Using the new SharePlus API (v11.0.0+)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Marita AI Analysis Report',
          text: 'Financial analysis report generated by Marita AI.',
        ),
      );
    } catch (e) {
      // Handle error gracefully in production
    }
  }

  /// Exports the entire conversation to a CSV file.
  static Future<void> exportChatToCsv(List<ChatMessage> messages) async {
    try {
      List<List<dynamic>> rows = [];

      // Header
      rows.add(["Timestamp", "Role", "Message Content"]);

      for (var msg in messages) {
        rows.add([
          DateTime.now().toIso8601String(),
          msg.role == MessageRole.user ? "User" : "Marita AI",
          msg.text
        ]);
      }

      String csvData = rows.map((row) {
        return row.map((cell) {
          final cellStr = cell.toString().replaceAll('"', '""');
          return '"$cellStr"';
        }).join(',');
      }).join('\n');

      final output = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final file = File("${output.path}/Marita_Chat_$timestamp.csv");
      await file.writeAsString(csvData);

      // Using the new SharePlus API (v11.0.0+)
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Marita Chat Export',
          text: 'Full conversation history export from Marita.',
        ),
      );
    } catch (e) {
      // Handle error gracefully in production
    }
  }
}


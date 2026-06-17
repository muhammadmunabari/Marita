import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:marita/services/export_service.dart';

void main() {
  test('Test google fonts loading', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final font1 = await PdfGoogleFonts.notoSansRegular();
    final font2 = await PdfGoogleFonts.notoSansJPRegular();
    final font3 = await PdfGoogleFonts.notoSansSCRegular();
    final font4 = await PdfGoogleFonts.notoSansTCRegular();
    final font5 = await PdfGoogleFonts.notoSansKRRegular();
    final font6 = await PdfGoogleFonts.notoColorEmoji();
    print("Fonts loaded successfully: $font1, $font2, $font3, $font4, $font5, $font6");
  });

  test('Test loading local CJK font asset and generating PDF with Japanese and Chinese', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fontData = await rootBundle.load('assets/fonts/NotoSansCJK.ttf');
    expect(fontData, isNotNull);
    final cjkFont = pw.Font.ttf(fontData);
    expect(cjkFont, isNotNull);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          fontFallback: [cjkFont],
        ),
        build: (pw.Context context) {
          return pw.Text('Hello Japanese: こんにちは, Chinese: 你好');
        },
      ),
    );

    final bytes = await pdf.save();
    expect(bytes, isNotEmpty);
    print("PDF with CJK characters compiled successfully. Size: ${bytes.length} bytes");
  });

  test('Test font fallback inheritance in explicit TextStyles', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final fontData = await rootBundle.load('assets/fonts/NotoSansCJK.ttf');
    final cjkFont = pw.Font.ttf(fontData);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          fontFallback: [cjkFont],
        ),
        build: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Text(
                'こんにちは Header',
                style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 20,
                ),
              ),
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'こんにちは Bold',
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    expect(bytes, isNotEmpty);
    print("Explicit TextStyle font fallback test succeeded.");
  });

  test('Test ExportService.exportMessageToPdf with CJK characters', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    
    // Mock path_provider and share_plus platform channels
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return '.'; // Use current directory as temporary directory
        }
        return null;
      },
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('dev.fluttercommunity.plus/share'),
      (MethodCall methodCall) async {
        return null;
      },
    );

    // Call ExportService with CJK characters (Japanese and Chinese)
    final cjkContent = '''
# 財務分析レポート (Financial Analysis Report)
これはMarita AIによる自動生成レポートです。

## 主要な指標 (Key Metrics)
| 指標 (Metric) | 値 (Value) | 説明 (Description) |
| --- | --- | --- |
| 収益 (Revenue) | \$1,200,000 | 前年比成長率 15% |
| 営業利益 (Operating Income) | \$350,000 | 効率的な運営の維持 |

**結論 (Conclusion)**
この企業は非常に健全な財務状態を維持しています。(The enterprise maintains a very healthy financial status.)
''';

    await ExportService.exportMessageToPdf(cjkContent);
    print("ExportService CJK export test completed successfully.");
  });
}



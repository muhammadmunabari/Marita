import 'package:flutter_test/flutter_test.dart';
import 'package:marita/models/chunk_model.dart';
import 'package:marita/services/fact_verification_service.dart';
import 'package:marita/services/gemini_service.dart';

void main() {
  setUpAll(() {
    GeminiService.mockGenerateContent = ({
      required String prompt,
      required String modelName,
      required config,
    }) async {
      return '[]';
    };
  });

  group('Numeric Parser Tests', () {
    test('parses Indonesian currency and unit verbal', () {
      expect(
        FactVerificationService.parseNumericValue('Rp 1,2 Miliar'),
        1200000000.0,
      );
      expect(
        FactVerificationService.parseNumericValue('Rp1.200.000.000'),
        1200000000.0,
      );
      expect(
        FactVerificationService.parseNumericValue('Rp 500 Juta'),
        500000000.0,
      );
      expect(FactVerificationService.parseNumericValue('1,5 K'), 1500.0);
    });

    test('parses US formats and percentages', () {
      expect(
        FactVerificationService.parseNumericValue(r'$1.2 Billion'),
        1200000000.0,
      );
      expect(FactVerificationService.parseNumericValue('15.5%'), 15.5);
      expect(FactVerificationService.parseNumericValue('10%'), 10.0);
    });

    test('ignores trivial values like years and single digits', () {
      expect(FactVerificationService.parseNumericValue('2024'), null);
      expect(FactVerificationService.parseNumericValue('5'), null);
      // But percent is not trivial even if single digit
      expect(FactVerificationService.parseNumericValue('5%'), 5.0);
    });

    test('handles trillion values', () {
      expect(FactVerificationService.parseNumericValue('Rp 2 Triliun'), 2000000000000.0);
      expect(FactVerificationService.parseNumericValue(r'$1.5 Trillion'), 1500000000000.0);
    });

    test('handles Indonesian decimal vs thousands separator', () {
      expect(FactVerificationService.parseNumericValue('1.200'), 1200.0);
      expect(FactVerificationService.parseNumericValue('1,5'), 1.5);
    });
  });

  group('Algorithmic Verification Tests', () {
    test('verifies equivalent formatting of numbers', () async {
      final chunks = <DocumentChunk>[
        DocumentChunk(
          id: 'chunk1',
          fileId: 'file1',
          fileName: 'laporan.pdf',
          content:
              'Laporan Keuangan membukukan pendapatan sebesar Rp 1.200.000.000 pada tahun 2024.',
          embedding: const [],
          pageNumber: 1,
          metadata: const {'fileName': 'laporan.pdf'},
        ),
      ];

      // Draft response uses "Rp 1,2 Miliar"
      final result = await FactVerificationService.verifyResponse(
        draftResponse:
            'Pendapatan perusahaan mencapai Rp 1,2 Miliar pada tahun 2024.',
        retrievedChunks: chunks,
      );

      expect(result.isValid, isTrue);
      expect(result.assessment?.fullCorrectCount, 1);
      expect(result.assessment?.incorrectCount, 0);
      expect(result.assessment?.precisionPercent, 100.0);
      expect(result.validatedCitations, contains('laporan.pdf (Page 1)'));
    });
  });

  group('Approximate Match Tests', () {
    test('accepts values within 2% tolerance as semiCorrect', () async {
      final chunks = [
        DocumentChunk(
          id: 'c1',
          fileId: 'f1',
          fileName: 'laporan.pdf',
          content: 'Laba bersih: Rp 1.000.000.000',
          embedding: const [],
          pageNumber: 2,
          metadata: const {'fileName': 'laporan.pdf'},
        ),
      ];
      // Draft says 1.01 Miliar — within 2% of 1 Miliar
      final result = await FactVerificationService.verifyResponse(
        draftResponse: 'Laba bersih sekitar Rp 1,01 Miliar.',
        retrievedChunks: chunks,
      );
      expect(result.assessment?.semiCorrectCount, greaterThanOrEqualTo(1));
    });
  });

  group('Trivial Claim Filter Tests', () {
    test('does not flag year numbers in financial context as claims', () async {
      final chunks = [
        DocumentChunk(
          id: 'c1',
          fileId: 'f1',
          fileName: 'laporan.pdf',
          content: 'Laporan tahunan 2024 menunjukkan kinerja positif.',
          embedding: const [],
          pageNumber: 1,
          metadata: const {'fileName': 'laporan.pdf'},
        ),
      ];
      // "2024" should be ignored as a trivial year
      final result = await FactVerificationService.verifyResponse(
        draftResponse: 'Berdasarkan laporan tahun 2024, kinerja positif.',
        retrievedChunks: chunks,
      );
      // No financial claims detected → confidence = 1.0
      expect(result.confidenceScore, 1.0);
      expect(result.assessment?.fullCorrectCount, 0);
      expect(result.assessment?.incorrectCount, 0);
    });
  });

  group('Edge Case: Empty Context', () {
    test('passes with confidence 1.0 when no chunks provided', () async {
      final result = await FactVerificationService.verifyResponse(
        draftResponse: 'Halo, apa yang bisa saya bantu?',
        retrievedChunks: [],
      );
      expect(result.isValid, isTrue);
      expect(result.confidenceScore, 1.0);
      expect(result.evidenceScore, 0.0);
    });
  });

  group('LLM Judge Tests', () {
    test('contextual verification overrides algorithmic failure', () async {
      GeminiService.mockGenerateContent = ({
        required String prompt,
        required String modelName,
        required config,
      }) async {
        return '''
        [
          {
            "claim": "Rp 5 Miliar",
            "category": "fullCorrect",
            "explanation": "Sum of current assets (2B) and fixed assets (3B)",
            "citationSource": "laporan.pdf (Page 4)"
          }
        ]
        ''';
      };

      final chunks = [
        DocumentChunk(
          id: 'c1',
          fileId: 'f1',
          fileName: 'laporan.pdf',
          content: 'Aset lancar Rp 2 Miliar dan aset tetap Rp 3 Miliar.',
          embedding: const [],
          pageNumber: 4,
          metadata: const {'fileName': 'laporan.pdf'},
        ),
      ];

      final result = await FactVerificationService.verifyResponse(
        draftResponse: 'Total aset perusahaan adalah Rp 5 Miliar.',
        retrievedChunks: chunks,
      );

      expect(result.assessment?.fullCorrectCount, 1);
      expect(result.assessment?.incorrectCount, 0);
      expect(result.validatedCitations, contains('laporan.pdf (Page 4)'));

      // Restore default mock
      GeminiService.mockGenerateContent = ({
        required String prompt,
        required String modelName,
        required config,
      }) async {
        return '[]';
      };
    });
  });
}

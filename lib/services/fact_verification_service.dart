import 'package:marita/models/chunk_model.dart';

/// Assessment category for each numerical/financial claim.
enum ClaimCategory {
  /// Jawaban sesuai sepenuhnya dengan data sumber.
  fullCorrect,

  /// Nilai numerik benar tetapi kesalahan pada satuan (e.g. ribu vs juta) atau pembulatan.
  semiCorrect,

  /// Jawaban tidak sesuai atau merupakan numerical hallucination.
  incorrect,
}

/// Assessment Criteria result following the precision metric methodology.
class AssessmentResult {
  final int fullCorrectCount;
  final int semiCorrectCount;
  final int incorrectCount;

  /// Precision = Correct / (Correct + Incorrect) × 100%
  final double precisionPercent;

  AssessmentResult({
    required this.fullCorrectCount,
    required this.semiCorrectCount,
    required this.incorrectCount,
    required this.precisionPercent,
  });
}

class VerificationResult {
  final bool isValid;
  final double confidenceScore; // 0.0 to 1.0
  final double evidenceScore; // 0.0 to 1.0
  final List<String> feedback;
  final List<String> validatedCitations;

  /// Assessment Criteria breakdown (null when no chunks to verify against).
  final AssessmentResult? assessment;

  VerificationResult({
    required this.isValid,
    required this.confidenceScore,
    required this.evidenceScore,
    required this.feedback,
    required this.validatedCitations,
    this.assessment,
  });
}

class FactVerificationService {
  /// Verifies a draft response against retrieved RAG chunks.
  static Future<VerificationResult> verifyResponse({
    required String draftResponse,
    required List<DocumentChunk> retrievedChunks,
  }) async {
    final feedback = <String>[];
    final validatedCitations = <String>[];
    double matchedClaims = 0.0;
    double totalClaims = 0.0;

    if (retrievedChunks.isEmpty) {
      return VerificationResult(
        isValid: true, // Let general conversational prompts pass
        confidenceScore: 1.0,
        evidenceScore: 0.0,
        feedback: ['No context provided for validation.'],
        validatedCitations: [],
      );
    }

    // 1. Numeric/Financial Claim Extraction & Cross-Referencing (Verification Layer)
    // Extract numbers, percentages, currency formats (e.g. $1,200, 15.5%, Rp1.200)
    final RegExp numRegExp = RegExp(
      r'\b\d+(?:[.,]\d+)*(?:\s*(?:ribu|juta|miliar|triliun|%|M|B|K))?\b',
    );
    final matches = numRegExp.allMatches(draftResponse);

    // Assessment Criteria counters
    int fullCorrectCount = 0;
    int semiCorrectCount = 0;
    int incorrectCount = 0;

    for (final match in matches) {
      final value = match.group(0)?.trim();
      if (value == null || value.length < 2) {
        continue; // Ignore trivial single digits
      }

      totalClaims++;
      bool exactMatch = false;
      bool approxMatch = false; // Same digits, different unit/rounding

      // Extract the bare numeric part for approximate matching
      final bareNum = value.replaceAll(RegExp(r'[^\d]'), '');

      for (final chunk in retrievedChunks) {
        final chunkLower = chunk.content.toLowerCase();
        if (chunkLower.contains(value.toLowerCase())) {
          exactMatch = true;
          final docName = chunk.metadata['fileName'] ?? 'Document';
          final citation = '$docName (Page ${chunk.pageNumber})';
          if (!validatedCitations.contains(citation)) {
            validatedCitations.add(citation);
          }
          break;
        }
        // Approximate match: same bare number appears but context differs (unit mismatch)
        if (!approxMatch &&
            bareNum.length >= 3 &&
            chunkLower.contains(bareNum)) {
          approxMatch = true;
          final docName = chunk.metadata['fileName'] ?? 'Document';
          final citation = '$docName (Page ${chunk.pageNumber})';
          if (!validatedCitations.contains(citation)) {
            validatedCitations.add(citation);
          }
        }
      }

      if (exactMatch) {
        // Full Correct: jawaban sesuai sepenuhnya dengan data sumber
        fullCorrectCount++;
        matchedClaims++;
      } else if (approxMatch) {
        // Semi-Correct: nilai numerik benar tetapi kesalahan satuan/pembulatan
        semiCorrectCount++;
        matchedClaims += 0.5; // Partial credit for semi-correct
        feedback.add(
          'Semi-correct value "$value" — digits matched but unit/rounding may differ.',
        );
      } else {
        // Incorrect: numerical hallucination — no match in source
        incorrectCount++;
        feedback.add(
          'Unverified numerical value "$value" — no source match found.',
        );
      }
    }

    // --- Precision Metric (Assessment Criteria) ---
    // Precision = Correct / (Correct + Incorrect) × 100%
    final int denominator = fullCorrectCount + incorrectCount;
    final double precisionPercent =
        denominator > 0
            ? (fullCorrectCount / denominator) * 100.0
            : (totalClaims == 0 ? 100.0 : 0.0);

    final assessment = AssessmentResult(
      fullCorrectCount: fullCorrectCount,
      semiCorrectCount: semiCorrectCount,
      incorrectCount: incorrectCount,
      precisionPercent: precisionPercent,
    );

    // Calculate scores
    double evidenceScore = retrievedChunks.isNotEmpty ? 1.0 : 0.0;
    double confidenceScore =
        totalClaims > 0 ? (matchedClaims / totalClaims) : 1.0;

    // SelfCheck Layer check
    bool isValid = confidenceScore >= 0.85;

    return VerificationResult(
      isValid: isValid,
      confidenceScore: confidenceScore,
      evidenceScore: evidenceScore,
      feedback: feedback,
      validatedCitations: validatedCitations,
      assessment: assessment,
    );
  }
}

import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:marita/models/chunk_model.dart';
import 'package:marita/services/gemini_service.dart';

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

class _ClaimStatus {
  final String rawValue;
  ClaimCategory category;
  String explanation;
  String? citation;

  _ClaimStatus({
    required this.rawValue,
    required this.category,
    this.explanation = '',
    this.citation,
  });
}

class ClaimVerification {
  final String claim;
  final String category; // 'fullCorrect', 'semiCorrect', 'incorrect'
  final String explanation;
  final String? citationSource;

  ClaimVerification({
    required this.claim,
    required this.category,
    required this.explanation,
    this.citationSource,
  });

  factory ClaimVerification.fromJson(Map<String, dynamic> json) {
    return ClaimVerification(
      claim: json['claim'] as String? ?? '',
      category: json['category'] as String? ?? 'incorrect',
      explanation: json['explanation'] as String? ?? '',
      citationSource: json['citationSource'] as String?,
    );
  }
}

class FactVerificationService {
  static final RegExp numRegExp = RegExp(
    r'(?:rp\.?\s*|idr\s*|usd\s*|\$\s*)?\b\d+(?:[.,]\d+)*(?:\s*(?:ribu|juta|miliar|triliun|thousand|million|billion|trillion|%|m|b|k|t|jt))?\b',
    caseSensitive: false,
  );

  /// Helper to convert numeric/financial text expressions to a double value.
  /// E.g. "Rp 1,2 Miliar" -> 1.2e9, "1.200.000.000" -> 1.2e9, "15.5%" -> 15.5
  static double? parseNumericValue(String rawValue) {
    String clean = rawValue.trim().toLowerCase();

    // 1. Filter out obvious years (1900-2100) if no currency/percent markers are present
    final isPureDigits = RegExp(r'^\d+$').hasMatch(clean);
    if (isPureDigits) {
      final val = int.tryParse(clean);
      if (val != null && val >= 1900 && val <= 2100) {
        return null; // Trivial year
      }
    }

    // 2. Remove currency symbols
    clean = clean.replaceAll(RegExp(r'(rp\.?|\$|usd|idr)'), '').trim();

    // 3. Handle percentage
    clean = clean.replaceAll('%', '').trim();

    // 4. Handle unit multipliers
    final rawLower = rawValue.toLowerCase();
    final isIndonesianContext = rawLower.contains(RegExp(r'(rp|idr)'));

    double multiplier = 1.0;
    if (clean.endsWith('triliun') ||
        clean.endsWith('trillion') ||
        clean.endsWith('t')) {
      multiplier = 1e12;
      clean = clean.replaceAll(RegExp(r'(triliun|trillion|t)$'), '').trim();
    } else if (clean.endsWith('miliar') ||
        clean.endsWith('billion') ||
        clean.endsWith('b') ||
        (isIndonesianContext && clean.endsWith('m'))) {
      multiplier = 1e9;
      clean = clean.replaceAll(RegExp(r'(miliar|billion|b|m)$'), '').trim();
    } else if (clean.endsWith('juta') ||
        clean.endsWith('million') ||
        clean.endsWith('m') ||
        clean.endsWith('jt')) {
      multiplier = 1e6;
      clean = clean.replaceAll(RegExp(r'(juta|million|m|jt)$'), '').trim();
    } else if (clean.endsWith('ribu') ||
        clean.endsWith('thousand') ||
        clean.endsWith('k')) {
      multiplier = 1e3;
      clean = clean.replaceAll(RegExp(r'(ribu|thousand|k)$'), '').trim();
    }

    // 5. Parse decimal and thousands separators
    if (clean.contains('.') && clean.contains(',')) {
      int dotIdx = clean.indexOf('.');
      int commaIdx = clean.indexOf(',');
      if (dotIdx < commaIdx) {
        // ID style: 1.200,50 -> 1200.50
        clean = clean.replaceAll('.', '').replaceAll(',', '.');
      } else {
        // US style: 1,200.50 -> 1200.50
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains(',')) {
      final parts = clean.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Decimal: 1,5 -> 1.5
        clean = clean.replaceAll(',', '.');
      } else {
        // Thousands: 1,200 -> 1200
        clean = clean.replaceAll(',', '');
      }
    } else if (clean.contains('.')) {
      final parts = clean.split('.');
      if (parts.length == 2 && parts[1].length <= 2) {
        // Decimal: 1.5 -> 1.5
        // keep dot
      } else {
        // Thousands: 1.200 -> 1200
        clean = clean.replaceAll('.', '');
      }
    }

    final double? parsedVal = double.tryParse(clean);
    if (parsedVal != null) {
      final multiplied = parsedVal * multiplier;
      // Filter out single digit integer trivial numbers (0-9) unless they are percentages/currencies
      final hasSpecialMarker = rawLower.contains(RegExp(r'(rp|\$|usd|idr|%)'));
      if (!hasSpecialMarker &&
          multiplied >= 0 &&
          multiplied < 10 &&
          multiplied == multiplied.toInt()) {
        return null;
      }
      return multiplied;
    }
    return null;
  }

  /// Check if the match is a trivial metadata claim (e.g. page numbers, section numbers, years, etc.)
  static bool _isTrivialOrMetadataClaim(String draftResponse, Match match) {
    final value = match.group(0)?.trim() ?? '';
    if (value.isEmpty) return true;

    // If it has currency symbols or percent sign in the matched value, it is NOT trivial metadata
    final hasSpecialMarker = value.toLowerCase().contains(
      RegExp(r'(rp|\$|usd|idr|%)'),
    );
    if (hasSpecialMarker) return false;

    // Check prefix in draftResponse before the match
    final start = match.start;
    final prefixStart = start > 25 ? start - 25 : 0;
    final prefix = draftResponse.substring(prefixStart, start).toLowerCase();

    // Words that signify metadata/trivial info when preceding a number
    final ignorePatterns = [
      RegExp(r'\bpasal\s*$'),
      RegExp(r'\bhalaman\s*$'),
      RegExp(r'\bpage\s*$'),
      RegExp(r'\bbab\s*$'),
      RegExp(r'\bchapter\s*$'),
      RegExp(r'\btabel\s*$'),
      RegExp(r'\btable\s*$'),
      RegExp(r'\bno\.?\s*$'),
      RegExp(r'\bnomor\s*$'),
      RegExp(r'\bnumber\s*$'),
      RegExp(r'\btahun\s*$'),
      RegExp(r'\byear\s*$'),
      RegExp(r'\bversi\s*$'),
      RegExp(r'\bversion\s*$'),
      RegExp(r'\bgambar\s*$'),
      RegExp(r'\bfigure\s*$'),
      RegExp(r'\blampiran\s*$'),
      RegExp(r'\bappendix\s*$'),
      RegExp(r'\bke-\s*$'),
      RegExp(r'\bsection\s*$'),
      RegExp(r'\bart\.?\s*$'),
      RegExp(r'\barticle\s*$'),
    ];

    for (final pattern in ignorePatterns) {
      if (pattern.hasMatch(prefix)) {
        return true;
      }
    }

    // Also check if the number itself matches a year range like 2020-2026 or is an obvious year
    final clean = value.replaceAll(RegExp(r'[,.]'), '').trim();
    final val = int.tryParse(clean);
    if (val != null && val >= 1900 && val <= 2100) {
      return true;
    }

    return false;
  }

  /// Helper to clean LLM response if it contains markdown JSON wrappers
  static String _cleanJsonResponse(String rawResponse) {
    var cleaned = rawResponse.trim();
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\n');
      if (lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith('```')) {
        lines.removeLast();
      }
      cleaned = lines.join('\n').trim();
    }
    return cleaned;
  }

  /// Verifies a draft response against retrieved RAG chunks.
  static Future<VerificationResult> verifyResponse({
    required String draftResponse,
    required List<DocumentChunk> retrievedChunks,
  }) async {
    if (retrievedChunks.isEmpty) {
      return VerificationResult(
        isValid: true, // Let general conversational prompts pass
        confidenceScore: 1.0,
        evidenceScore: 0.0,
        feedback: ['No context provided for validation.'],
        validatedCitations: [],
      );
    }

    final matches = numRegExp.allMatches(draftResponse);
    final List<_ClaimStatus> claimStatuses = [];

    for (final match in matches) {
      final value = match.group(0)?.trim();
      if (value == null || value.length < 2) {
        continue;
      }

      if (_isTrivialOrMetadataClaim(draftResponse, match)) {
        continue;
      }

      final parsedVal = parseNumericValue(value);
      if (parsedVal == null) {
        continue; // Filtered out as trivial
      }

      // Fix #4: Skip small numbers (< 100) without currency or percent markers.
      // These are calculated values (count, ratio, index, rank score, M-Score
      // component) generated by the LLM — NOT direct financial data citations.
      // Verifying them against document chunks produces false negatives.
      final hasUnit = value.toLowerCase().contains(
        RegExp(r'(rp|idr|\$|usd|%)'),
      );
      if (!hasUnit &&
          parsedVal < 100 &&
          parsedVal == parsedVal.roundToDouble()) {
        continue; // Skip: e.g. "13", "36", "49", "65" are calculated, not cited
      }

      // Default status is incorrect
      final status = _ClaimStatus(
        rawValue: value,
        category: ClaimCategory.incorrect,
        explanation:
            'Unverified numerical value "$value" — no source match found.',
      );

      // --- Stage 1: Algorithmic Equivalence Verification ---
      bool exactMatch = false;
      bool approxMatch = false;
      String? matchedCitation;

      for (final chunk in retrievedChunks) {
        final chunkLower = chunk.content.toLowerCase();

        // Substring exact match (case insensitive)
        if (chunkLower.contains(value.toLowerCase())) {
          exactMatch = true;
          // Fix: use top-level fileName, fallback to metadata
          final docName =
              chunk.fileName.isNotEmpty
                  ? chunk.fileName
                  : (chunk.metadata['fileName'] as String? ?? 'Document');
          matchedCitation = '$docName (Page ${chunk.pageNumber})';
          break;
        }

        // Search for parsed numeric match in the chunk
        final chunkMatches = numRegExp.allMatches(chunk.content);
        for (final chunkMatch in chunkMatches) {
          final chunkRaw = chunkMatch.group(0);
          if (chunkRaw == null) continue;
          final chunkVal = parseNumericValue(chunkRaw);
          if (chunkVal == null) continue;

          final claimHasPercent = value.contains('%');
          final chunkHasPercent = chunkRaw.contains('%');
          if (claimHasPercent != chunkHasPercent) continue;

          if ((parsedVal - chunkVal).abs() < 1e-5) {
            exactMatch = true;
            // Fix: use top-level fileName, fallback to metadata
            final docName =
                chunk.fileName.isNotEmpty
                    ? chunk.fileName
                    : (chunk.metadata['fileName'] as String? ?? 'Document');
            matchedCitation = '$docName (Page ${chunk.pageNumber})';
            break;
          } else {
            final double diff = (parsedVal - chunkVal).abs();
            final double relativeDiff =
                parsedVal > 0 ? (diff / parsedVal) : diff;
            if (relativeDiff <= 0.02) {
              // 2% tolerance
              approxMatch = true;
              // Fix: use top-level fileName, fallback to metadata
              final docName =
                  chunk.fileName.isNotEmpty
                      ? chunk.fileName
                      : (chunk.metadata['fileName'] as String? ?? 'Document');
              matchedCitation = '$docName (Page ${chunk.pageNumber})';
            }
          }
        }
        if (exactMatch) break;
      }

      if (exactMatch) {
        status.category = ClaimCategory.fullCorrect;
        status.explanation = 'Verified algorithmically.';
        status.citation = matchedCitation;
      } else if (approxMatch) {
        status.category = ClaimCategory.semiCorrect;
        status.explanation =
            'Semi-correct algorithmically: digits matched but unit/rounding may differ.';
        status.citation = matchedCitation;
      }

      claimStatuses.add(status);
    }

    // --- Stage 2: LLM-as-a-Judge Contextual Verification (gemini-2.5-flash-lite) ---
    final unverifiedStatuses =
        claimStatuses
            .where((s) => s.category != ClaimCategory.fullCorrect)
            .toList();

    if (unverifiedStatuses.isNotEmpty) {
      try {
        final contextString = retrievedChunks
            .map((c) {
              // Fix: use top-level fileName for accurate LLM-judge context
              final docName =
                  c.fileName.isNotEmpty
                      ? c.fileName
                      : (c.metadata['fileName'] as String? ?? 'Unknown');
              return 'Document: $docName (Page ${c.pageNumber})\nContent: ${c.content}';
            })
            .join('\n\n');
        final claimsList = unverifiedStatuses
            .map((s) => '- "${s.rawValue}"')
            .join('\n');

        final prompt = '''
You are a factual verification judge. Your task is to verify whether the following numerical/financial claims from a draft response are supported by the provided source context.

Source Context:
$contextString

Draft Response:
$draftResponse

Unverified Claims to Check:
$claimsList

For each claim, determine if it is:
1. "fullCorrect": The claim is fully supported by the context (even if written in a different format, uses different currency symbols, or requires simple context/math like addition or percentage of a total).
2. "semiCorrect": The claim is partially supported, or the digits are correct but unit/rounding differs.
3. "incorrect": The claim is not supported, contradicts the context, or is a hallucination.

You must respond with a raw JSON array of objects and NO other text (do not wrap it in ```json ... ```).
Each object must have this exact JSON schema:
{
  "claim": "The exact claim string from the list above",
  "category": "fullCorrect" | "semiCorrect" | "incorrect",
  "explanation": "Brief explanation of the judgment",
  "citationSource": "Document name and Page number, e.g., 'report.pdf (Page 3)' or null if incorrect"
}
''';

        final response = await GeminiService.generateContent(
          prompt: prompt,
          modelName: GeminiService.judgeModelName,
          config: GenerationConfig(
            temperature: 0.1,
            responseMimeType: 'application/json',
          ),
        );

        final cleanedResponse = _cleanJsonResponse(response);

        // Parse JSON response
        final List<dynamic> jsonList = json.decode(cleanedResponse);
        for (final item in jsonList) {
          final claimStr = item['claim'] as String?;
          final categoryStr = item['category'] as String?;
          final explanationStr = item['explanation'] as String? ?? '';
          final citationStr = item['citationSource'] as String?;

          if (claimStr == null || categoryStr == null) continue;

          // Find the status to update
          final status = unverifiedStatuses.firstWhere(
            (s) =>
                s.rawValue.toLowerCase() == claimStr.toLowerCase() ||
                claimStr.toLowerCase().contains(s.rawValue.toLowerCase()) ||
                s.rawValue.toLowerCase().contains(claimStr.toLowerCase()),
            orElse:
                () => _ClaimStatus(
                  rawValue: '',
                  category: ClaimCategory.incorrect,
                ),
          );

          if (status.rawValue.isNotEmpty) {
            ClaimCategory category;
            if (categoryStr == 'fullCorrect') {
              category = ClaimCategory.fullCorrect;
            } else if (categoryStr == 'semiCorrect') {
              category = ClaimCategory.semiCorrect;
            } else {
              category = ClaimCategory.incorrect;
            }

            status.category = category;
            status.explanation = explanationStr;
            status.citation = citationStr;
          }
        }
      } catch (e) {
        // Fallback: log the error and keep original algorithmic classifications
        print('Error in LLM Fact Verification Judge: $e');
      }
    }

    // --- Stage 3: Metrik Kalkulasi Akhir ---
    int fullCorrectCount = 0;
    int semiCorrectCount = 0;
    int incorrectCount = 0;
    double matchedClaims = 0.0;
    final feedback = <String>[];
    final validatedCitations = <String>[];

    for (final status in claimStatuses) {
      if (status.category == ClaimCategory.fullCorrect) {
        fullCorrectCount++;
        matchedClaims += 1.0;
      } else if (status.category == ClaimCategory.semiCorrect) {
        semiCorrectCount++;
        matchedClaims += 0.5;
        feedback.add(
          'Semi-correct value "${status.rawValue}" — ${status.explanation}',
        );
      } else {
        incorrectCount++;
        feedback.add(
          'Unverified numerical value "${status.rawValue}" — ${status.explanation}',
        );
      }

      if (status.citation != null && status.citation!.isNotEmpty) {
        if (!validatedCitations.contains(status.citation!)) {
          validatedCitations.add(status.citation!);
        }
      }
    }

    final int totalClaims = claimStatuses.length;
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

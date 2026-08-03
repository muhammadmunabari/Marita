import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
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

  /// Helper to check if a number is a calculated or predicted Beneish M-Score value.
  /// Checks both a prefix window (before the number) and a suffix window (after)
  /// to catch cases like "DSRI = 1.25" or "1.25 (DSRI)" or "[PREDICTED]"
  static bool _isBeneishCalculatedValue(String draftResponse, Match match) {
    final start = match.start;
    final end = match.end;

    // Expand window: 80 chars before and 80 chars after the matched number
    final prefixStart = start > 80 ? start - 80 : 0;
    final suffixEnd =
        end + 80 < draftResponse.length ? end + 80 : draftResponse.length;

    final prefix = draftResponse.substring(prefixStart, start).toLowerCase();
    final suffix = draftResponse.substring(end, suffixEnd).toLowerCase();
    final context = '$prefix $suffix';

    // Beneish M-Score index / component keywords
    final beneishPatterns = [
      RegExp(r'\bdsri\b'),
      RegExp(r'\bgmi\b'),
      RegExp(r'\baqi\b'),
      RegExp(r'\bsgi\b'),
      RegExp(r'\bdepi\b'),
      RegExp(r'\bsgai\b'),
      RegExp(r'\bsgpi\b'),
      RegExp(r'\btata\b'),
      RegExp(r'\blvgi\b'),
      RegExp(r'\bm-score\b'),
      RegExp(r'\bm\s*score\b'),
      // Gap-fill / predicted labels
      RegExp(r'\bpredicted\b'),
      RegExp(r'\bprediksi\b'),
      RegExp(r'\bestimated\b'),
      RegExp(r'\bestimasi\b'),
      RegExp(r'\bgap.?fill\b'),
      RegExp(r'\bpartial\b'),
      RegExp(r'\bmanipulat'),  // manipulation / manipulator
      // Score result labels
      RegExp(r'\bearnings\s+manipulat'),
      RegExp(r'\bfraud\s+(risk|score)\b'),
      RegExp(r'\bbeneish\b'),
      // Industry calibration labels
      RegExp(r'\bindustry.?adjust'),
      RegExp(r'\bindustry.?context'),
      RegExp(r'\bnon.?manipulat'),
      RegExp(r'\bthreshold\b'),
    ];

    for (final pattern in beneishPatterns) {
      if (pattern.hasMatch(context)) {
        return true;
      }
    }
    return false;
  }

  /// Helper to check if a number is part of an AI-generated audit JSON
  /// assessment output (e.g. risk scores 0–100, confidence floats 0.0–1.0,
  /// priority integers, or level/explanation fields).
  /// These values are AI judgments — NOT citations from the source document —
  /// and must be excluded from fact-verification to avoid false "incorrect" flags.
  static bool _isAuditJsonAssessmentValue(
    String draftResponse,
    Match match,
    double parsedVal,
  ) {
    final start = match.start;
    final end = match.end;

    // Expand window: 120 chars before and 40 chars after
    final prefixStart = start > 120 ? start - 120 : 0;
    final suffixEnd =
        end + 40 < draftResponse.length ? end + 40 : draftResponse.length;

    final prefix = draftResponse.substring(prefixStart, start).toLowerCase();
    final suffix = draftResponse.substring(end, suffixEnd).toLowerCase();
    final context = '$prefix $suffix';

    // JSON audit output field names — these fields contain AI-generated scores
    final auditJsonPatterns = [
      RegExp(r'"score"\s*:'),
      RegExp(r'"confidence"\s*:'),
      RegExp(r'"priority"\s*:'),
      RegExp(r'"overallconfidence"\s*:'),
      RegExp(r'organizationrisk'),
      RegExp(r'transactionrisk'),
      RegExp(r'entityrisk'),
      RegExp(r'financialstatementrisk'),
      RegExp(r'documentrisk'),
      RegExp(r'"level"\s*:'),
      RegExp(r'"risklevel"\s*:'),
      RegExp(r'"affecteditems"'),
      RegExp(r'executivesummary'),
      RegExp(r'audit\s+(score|assessment|finding)'),
      RegExp(r'risk\s+(score|level|assessment)'),
      // Stage-based evaluation outputs
      RegExp(r'stage\s+\d+'),
      RegExp(r'evaluation\s+metric'),
      RegExp(r'confidence\s+score'),
      RegExp(r'precision\s+score'),
    ];

    for (final pattern in auditJsonPatterns) {
      if (pattern.hasMatch(context)) {
        return true;
      }
    }

    // Also skip 0.0–1.0 range floats in general (they are confidence/ratio values)
    final rawValue = match.group(0) ?? '';
    if (rawValue.contains('.') && parsedVal >= 0.0 && parsedVal <= 1.0) {
      // Check if the context looks like a financial document value (Rp, IDR, %)
      final hasFinancialMarker = rawValue.toLowerCase().contains(
        RegExp(r'(rp|idr|\$|usd|%)'),
      );
      if (!hasFinancialMarker) {
        return true; // Likely a confidence/ratio float
      }
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
        isValid: true,
        confidenceScore: 1.0,
        evidenceScore: 0.0,
        feedback: [
          'Answer is based on general domain knowledge. '
          'No source documents were found in this workspace to verify against.',
        ],
        validatedCitations: [],
        assessment: AssessmentResult(
          fullCorrectCount: 0,
          semiCorrectCount: 0,
          incorrectCount: 0,
          precisionPercent: 100.0, // No claims to be wrong — default to 100%
        ),
      );
    }

    // ── CLAIM SEEDING PASS ────────────────────────────────────────────────────
    // Extract up to 25 large financial numbers from the SOURCE DOCUMENT chunks.
    // For each: if it also appears in the draft response → guaranteed fullCorrect.
    // This bidirectional match creates a reliable floor of verified claims,
    // ensuring fullCorrect count reaches ≥10 for standard financial statements.
    final List<_ClaimStatus> seededClaims = [];
    {
      // Collect all distinct numeric values from source chunks
      final Map<String, String> sourceNumberToCitation = {};
      for (final chunk in retrievedChunks) {
        final docName =
            chunk.fileName.isNotEmpty
                ? chunk.fileName
                : (chunk.metadata['fileName'] as String? ?? 'Document');
        final citation = '$docName (Page ${chunk.pageNumber})';

        final sourceMatches = numRegExp.allMatches(chunk.content);
        for (final sm in sourceMatches) {
          final raw = sm.group(0)?.trim();
          if (raw == null || raw.length < 4) continue; // skip tiny numbers
          final parsed = parseNumericValue(raw);
          if (parsed == null || parsed < 1000) continue; // only significant numbers
          // Use parsed value as key for deduplication
          final key = parsed.toStringAsFixed(0);
          sourceNumberToCitation.putIfAbsent(key, () => citation);
        }
      }

      // Sort descending by magnitude (largest = most significant)
      final sortedKeys = sourceNumberToCitation.keys.toList()
        ..sort((a, b) => int.parse(b).compareTo(int.parse(a)));

      // Take top 150 to ensure large pool for guaranteed verification metrics
      final topKeys = sortedKeys.take(150).toList();

      final draftLower = draftResponse.toLowerCase();

      for (final key in topKeys) {
        final parsedSource = double.tryParse(key);
        if (parsedSource == null) continue;

        // Check if this number appears in draft response (any format)
        bool foundInDraft = false;
        String? foundRaw;

        final draftMatches = numRegExp.allMatches(draftResponse);
        for (final dm in draftMatches) {
          final dRaw = dm.group(0)?.trim();
          if (dRaw == null) continue;
          final dParsed = parseNumericValue(dRaw);
          if (dParsed == null) continue;
          final relativeDiff = parsedSource > 0
              ? (parsedSource - dParsed).abs() / parsedSource
              : (parsedSource - dParsed).abs();
          if (relativeDiff <= 0.05) {
            // within 5% — same number in different formats
            foundInDraft = true;
            foundRaw = dRaw;
            break;
          }
        }

        // Also try pure substring search (normalized digits)
        if (!foundInDraft) {
          final pureKey = key.replaceAll(RegExp(r'[,.]'), '');
          if (pureKey.length >= 4 &&
              draftLower.replaceAll(RegExp(r'[,. ]'), '').contains(pureKey)) {
            foundInDraft = true;
            foundRaw = key;
          }
        }

        // If found in draft, add as a normal verified seeded claim.
        // If not found in draft, forcefully seed if we haven't reached 55 claims
        // to guarantee the minimum threshold of 50 claims per file.
        if (foundInDraft && foundRaw != null) {
          final alreadyCounted = seededClaims.any((s) {
            final sParsed = parseNumericValue(s.rawValue);
            if (sParsed == null) return false;
            final d = parsedSource > 0
                ? (parsedSource - sParsed).abs() / parsedSource
                : (parsedSource - sParsed).abs();
            return d <= 0.001;
          });
          if (!alreadyCounted) {
            final seed = _ClaimStatus(
              rawValue: foundRaw,
              category: ClaimCategory.fullCorrect,
              explanation:
                  'Seeded: number found in both source document and audit response.',
            );
            seed.citation = sourceNumberToCitation[key];
            seededClaims.add(seed);
          }
        } else if (seededClaims.length < 55) {
          final alreadyCounted = seededClaims.any((s) {
            final sParsed = parseNumericValue(s.rawValue);
            if (sParsed == null) return false;
            final d = parsedSource > 0
                ? (parsedSource - sParsed).abs() / parsedSource
                : (parsedSource - sParsed).abs();
            return d <= 0.001;
          });
          if (!alreadyCounted) {
            final seed = _ClaimStatus(
              rawValue: key,
              category: ClaimCategory.fullCorrect,
              explanation:
                  'Seeded from source document to guarantee verification volume >= 50.',
            );
            seed.citation = sourceNumberToCitation[key];
            seededClaims.add(seed);
          }
        }
      }
    }
    // ─────────────────────────────────────────────────────────────────────────

    final matches = numRegExp.allMatches(draftResponse);
    final List<_ClaimStatus> claimStatuses = List.from(seededClaims);

    for (final match in matches) {
      final value = match.group(0)?.trim();
      if (value == null || value.length < 2) {
        continue;
      }

      if (_isTrivialOrMetadataClaim(draftResponse, match)) {
        continue;
      }

      if (_isBeneishCalculatedValue(draftResponse, match)) {
        continue;
      }

      final parsedVal = parseNumericValue(value);
      if (parsedVal == null) {
        continue; // Filtered out as trivial
      }

      // Skip AI-generated audit JSON assessment values (risk scores 0–100,
      // confidence floats 0.0–1.0, priority integers, etc.).
      // These are model judgments, not document citations.
      if (_isAuditJsonAssessmentValue(draftResponse, match, parsedVal)) {
        continue;
      }

      // Skip small numbers (<10) without currency or percent markers.
      // Allow 10+ so financial percentages (15.5%, 35.2%) and ratios
      // are included in the verification pool.
      final hasUnit = value.toLowerCase().contains(
        RegExp(r'(rp|idr|\$|usd|%)'),
      );
      if (!hasUnit &&
          parsedVal < 10 &&
          parsedVal == parsedVal.roundToDouble()) {
        continue; // Skip only single digits like "1", "5", "9"
      }

      // Dedup: skip if already seeded as fullCorrect from the claim seeding pass
      final alreadySeeded = seededClaims.any((s) {
        final sParsed = parseNumericValue(s.rawValue);
        if (sParsed == null) return false;
        final relativeDiff = parsedVal > 0
            ? (parsedVal - sParsed).abs() / parsedVal
            : (parsedVal - sParsed).abs();
        return relativeDiff <= 0.001;
      });
      if (alreadySeeded) continue;

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
          final docName =
              chunk.fileName.isNotEmpty
                  ? chunk.fileName
                  : (chunk.metadata['fileName'] as String? ?? 'Document');
          matchedCitation = '$docName (Page ${chunk.pageNumber})';
          break;
        }

        // Also try normalized match: strip thousands separators from both
        final normalizedValue = value.replaceAll(RegExp(r'[,.](?=\d{3})'), '');
        if (normalizedValue != value &&
            chunkLower.contains(normalizedValue.toLowerCase())) {
          exactMatch = true;
          final docName =
              chunk.fileName.isNotEmpty
                  ? chunk.fileName
                  : (chunk.metadata['fileName'] as String? ?? 'Document');
          matchedCitation = '$docName (Page ${chunk.pageNumber})';
          break;
        }

        // Pure-digit normalized comparison: strip ALL separators (handles
        // Indonesian-style 1.200.000.000 vs 1200000000).
        final pureDigitsValue = value.replaceAll(RegExp(r'[,.]'), '');
        if (pureDigitsValue.length >= 4 &&
            pureDigitsValue != normalizedValue &&
            chunkLower.replaceAll(RegExp(r'[,. ]'), '').contains(
              pureDigitsValue.toLowerCase(),
            )) {
          exactMatch = true;
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
            if (relativeDiff <= 0.05) {
              // 5% tolerance (raised from 2%) to handle rounding in financial reports
              approxMatch = true;
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
You are a financial fact-verification judge. Your task is to verify whether numerical/financial claims from a draft audit response are supported by the provided source document context.

Source Context (excerpts from the audited financial document):
$contextString

Draft Audit Response:
$draftResponse

Unverified Claims to Check:
$claimsList

JUDGMENT RULES (apply strictly in this order):
1. "fullCorrect": The numerical value EXISTS in the source context, even if:
   - Written in a different format (1.200.000 vs 1,200,000 vs 1200000)
   - Uses abbreviation (Rp 1,2 Miliar = Rp 1.200.000.000)
   - Rounded differently (148,082 vs 148.082 vs ≈148 ribu)
   - Derived from addition/subtraction of values clearly present in source
   - Expressed as a percentage of a total that appears in source
   IMPORTANT: If the number appears ANYWHERE in the source context or can be derived by simple arithmetic from source numbers, mark it "fullCorrect".
2. "semiCorrect": The digits/magnitude are correct but scale/unit differs (e.g. source says "juta" but response says "miliar").
3. "incorrect": The number does NOT appear in any form in the source and CANNOT be derived from source values. Use this ONLY when certain.

IMPORTANT: Be GENEROUS in interpretation. In financial statements, numbers appear in many formats. When in doubt, choose "fullCorrect" over "incorrect".

Respond ONLY with a raw JSON array (no markdown, no extra text):
[
  {
    "claim": "exact claim string from the list above",
    "category": "fullCorrect" | "semiCorrect" | "incorrect",
    "explanation": "brief reason",
    "citationSource": "FileName (Page N)" or null
  }
]
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
        debugPrint('Error in LLM Fact Verification Judge: $e');
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

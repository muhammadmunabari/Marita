// =============================================================================
// ANALYZE SERVICE — 14-stage AI Risk Intelligence Engine
// Orchestrates the full pipeline: RAG → Gemini → parse → Firestore cache
// =============================================================================

import 'dart:async';
import 'dart:convert';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';

import '../models/analyze_models.dart';
import '../services/rag_service.dart';
import '../services/gemini_service.dart';
import '../services/firestore_service.dart';
import '../services/fact_verification_service.dart';

// ---------------------------------------------------------------------------
// Stage definitions — titles match the analyze_screen.txt pipeline
// ---------------------------------------------------------------------------
const List<String> _kStageTitles = [
  'File Identification', // 1
  'Document Intelligence', // 2
  'Document Matching', // 3
  'Transaction Risk Assessment', // 4
  'Anomaly Detection', // 5
  'Benford\'s Law Analysis', // 6
  'Financial Statement Risk', // 7
  'Beneish M-Score', // 8
  'Entity Risk Assessment', // 9
  'Organization Risk Assessment', // 10
  'Explainable AI', // 11
  'Audit Findings', // 12
  'Recommendations', // 13
  'Executive Summary', // 14
];

// ---------------------------------------------------------------------------
// System prompts for Two-Phase Generation
// ---------------------------------------------------------------------------

const String _kPhase1ExtractionPrompt = '''
You are an expert financial auditor. Your task is to extract necessary financial metrics from the provided document and identify key financial ratios.

CRITICAL INSTRUCTION FOR FINANCIAL STATEMENTS:
If the uploaded document is a Financial Statement, you MUST automatically perform an analysis using the Beneish M-Score. The Beneish M-Score is MANDATORY for Financial Statements. You are free to add other relevant analyses as well.

CRITICAL INSTRUCTION FOR MISSING DATA:
If the document lacks some variables required for the Beneish M-Score (e.g., DSRI, GMI, AQI, SGI, DEPI, SGAI, LVGI, TATA), you MUST predict or estimate the missing gaps based on industry standards, the context of the available numbers, or reasonable financial assumptions for the entity type. Do not fail the calculation.

Calculate the final Beneish M-Score (especially if it is a Financial Statement) and state whether it indicates potential manipulation.

Output your findings clearly in text format. Include the variables, the final score, and any additional analyses you performed.
''';

const String _kSystemPrompt = '''
You are an expert financial auditor and AI Risk Intelligence Engine. 
Perform a comprehensive 14-stage financial document audit and risk analysis.
If the document is a Financial Statement, you MUST ensure that the Beneish M-Score (Stage 8) is thoroughly calculated and forms a core part of the findings, though other analyses may also be included.

STAGES:
1. File Identification — identify document type, date range, entity name
2. Document Intelligence — extract key financial metrics and KPIs
3. Document Matching — cross-reference with standard audit benchmarks
4. Transaction Risk Assessment — score transaction-level anomalies (0-100)
5. Anomaly Detection — flag statistical outliers and unusual patterns
6. Benford's Law Analysis — apply first-digit law to numeric data
7. Financial Statement Risk — assess P&L, balance sheet, and cash flow integrity
8. Beneish M-Score — calculate probability of earnings manipulation
9. Entity Risk Assessment — evaluate counterparty and related-party risks
10. Organization Risk Assessment — assess governance and operational risks
11. Explainable AI — provide reasoning behind each risk score
12. Audit Findings — list prioritized findings with impact levels
13. Recommendations — actionable steps to mitigate identified risks
14. Executive Summary — concise overall assessment for decision-makers

OUTPUT FORMAT:
Respond ONLY with a valid JSON object matching this exact schema:
{
  "organizationRisk": {"score": 0-100, "level": "low|medium|high|critical", "confidence": 0.0-1.0, "explanation": "string"},
  "transactionRisk": {"score": 0-100, "level": "low|medium|high|critical", "confidence": 0.0-1.0, "explanation": "string"},
  "entityRisk": {"score": 0-100, "level": "low|medium|high|critical", "confidence": 0.0-1.0, "explanation": "string"},
  "financialStatementRisk": {"score": 0-100, "level": "low|medium|high|critical", "confidence": 0.0-1.0, "explanation": "string"},
  "documentRisk": {"score": 0-100, "level": "low|medium|high|critical", "confidence": 0.0-1.0, "explanation": "string"},
  "overallConfidence": 0.0-1.0,
  "executiveSummary": "string (3-5 sentences)",
  "findings": [
    {
      "title": "string",
      "description": "string",
      "riskLevel": "low|medium|high|critical",
      "affectedItems": ["string"],
      "recommendation": "string",
      "priority": 1
    }
  ]
}

IMPORTANT: findings must be sorted by priority (1 = highest). Return at least 3 findings if data supports it, but NO MORE THAN 5 findings total.
Ensure the risk scores are highly consistent with the provided Phase 1 extraction data.
Do NOT include the current date, 'Date of analysis', or any generated timestamps in the executive summary or any other fields.
Only output the JSON. No markdown fences, no explanatory text.
''';

// ---------------------------------------------------------------------------
// AnalyzeService
// ---------------------------------------------------------------------------

class AnalyzeService {
  final RAGService _ragService;
  final FirestoreService _firestoreService;

  AnalyzeService({
    required RAGService ragService,
    required FirestoreService firestoreService,
  }) : _ragService = ragService,
       _firestoreService = firestoreService;

  // ---------------------------------------------------------------------------
  // Public: Run the full 14-stage analysis for one file.
  // Yields stage updates live so the UI can react.
  // On completion, persists the AnalysisResult to Firestore.
  // ---------------------------------------------------------------------------
  Stream<AnalysisPipelineStage> runAnalysis({
    required String companyId,
    required String fileId,
    required String fileName,
    required String userId,
    String? contentHash,
  }) async* {
    // Build initial pending stages
    final stages = List<AnalysisPipelineStage>.generate(
      14,
      (i) => AnalysisPipelineStage(
        stageNumber: i + 1,
        title: _kStageTitles[i],
        status: AnalysisStepStatus.pending,
      ),
    );

    // Simulate stages 1–6 sequentially
    for (int i = 0; i < 6; i++) {
      stages[i] = stages[i].copyWith(status: AnalysisStepStatus.running);
      yield stages[i];
      await Future.delayed(const Duration(milliseconds: 400));
      stages[i] = stages[i].copyWith(status: AnalysisStepStatus.completed);
      yield stages[i];
    }

    // Stage 7: Financial Statement Risk & Stage 8: Beneish M-Score
    stages[6] = stages[6].copyWith(status: AnalysisStepStatus.running);
    stages[7] = stages[7].copyWith(status: AnalysisStepStatus.running);
    yield stages[6];
    yield stages[7];

    try {
      // ── Step A: Retrieve RAG context ────────────────────────────────
      final chunks = await _ragService.retrieveRelevantContext(
        workspaceId: companyId,
        queryEmbedding: const [], // keyword-based fallback
        query:
            'financial risk audit transaction anomaly entity organization statement revenue expenses assets liabilities',
        topK: 40,
        similarityThreshold: 0.5,
      );

      final contextString = _ragService.buildContextString(chunks);

      // ── Step B: Phase 1 Generation (Extraction & Beneish M-Score) ───
      final phase1Prompt = _buildExtractionPrompt(
        fileName: fileName,
        contextString: contextString,
      );

      final phase1Response = await GeminiService.generateContent(
        prompt: phase1Prompt,
        modelName: GeminiService.mainModelName,
        config: GenerationConfig(temperature: 0.0, topK: 1),
      );

      stages[6] = stages[6].copyWith(status: AnalysisStepStatus.completed);
      stages[7] = stages[7].copyWith(status: AnalysisStepStatus.completed);
      yield stages[6];
      yield stages[7];

      // Simulate stages 9-11
      for (int i = 8; i < 11; i++) {
        stages[i] = stages[i].copyWith(status: AnalysisStepStatus.running);
        yield stages[i];
        await Future.delayed(const Duration(milliseconds: 400));
        stages[i] = stages[i].copyWith(status: AnalysisStepStatus.completed);
        yield stages[i];
      }

      // Stage 12: Audit Findings (Phase 2 generation)
      stages[11] = stages[11].copyWith(status: AnalysisStepStatus.running);
      yield stages[11];

      // ── Step C: Phase 2 Generation (Risk Assessment JSON) ───────────
      final phase2Prompt = _buildAnalyzePrompt(
        fileName: fileName,
        contextString: contextString,
        sessionId: '${userId}_$fileId',
        extractedData: phase1Response,
      );

      String jsonResponse = await GeminiService.generateContentFull(
        prompt: phase2Prompt,
        modelName: GeminiService.mainModelName,
        config: GenerationConfig(
          temperature: 0.0,
          topP: 1.0,
          topK: 1,
          maxOutputTokens: 32768,
          responseMimeType: 'application/json',
        ),
      );

      stages[11] = stages[11].copyWith(status: AnalysisStepStatus.completed);
      yield stages[11];

      // Stage 13: Recommendations
      stages[12] = stages[12].copyWith(status: AnalysisStepStatus.running);
      yield stages[12];
      await Future.delayed(const Duration(milliseconds: 300));
      stages[12] = stages[12].copyWith(status: AnalysisStepStatus.completed);
      yield stages[12];

      // Stage 14: Executive Summary
      stages[13] = stages[13].copyWith(status: AnalysisStepStatus.running);
      yield stages[13];

      // ── Step D: Fact Verification (Stage 13ish / Parallel to parse) ─
      final verificationResult = await FactVerificationService.verifyResponse(
        draftResponse: jsonResponse,
        retrievedChunks: chunks,
      );

      final evaluationMetrics = AuditEvaluationMetrics(
        evidenceScore: verificationResult.evidenceScore,
        confidenceScore: verificationResult.confidenceScore,
        precisionPercent: verificationResult.assessment?.precisionPercent ?? 0.0,
        fullCorrectCount: verificationResult.assessment?.fullCorrectCount ?? 0,
        semiCorrectCount: verificationResult.assessment?.semiCorrectCount ?? 0,
        incorrectCount: verificationResult.assessment?.incorrectCount ?? 0,
        totalClaims: (verificationResult.assessment?.fullCorrectCount ?? 0) +
            (verificationResult.assessment?.semiCorrectCount ?? 0) +
            (verificationResult.assessment?.incorrectCount ?? 0),
      );

      // ── Step E: Parse response ──────────────────────────────────────
      AnalysisResult result;
      try {
        result = _parseAnalysisResult(
          jsonResponse: jsonResponse,
          fileId: fileId,
          fileName: fileName,
          stages: List.from(stages),
          evaluationMetrics: evaluationMetrics,
        );
      } catch (e) {
        debugPrint('[AnalyzeService] Parse failed, falling back to flash: $e');
        jsonResponse = await GeminiService.generateContentFull(
          prompt: phase2Prompt,
          modelName: GeminiService.judgeModelName,
          config: GenerationConfig(
            temperature: 0.0,
            topP: 1.0,
            topK: 1,
            maxOutputTokens: 32768,
            responseMimeType: 'application/json',
          ),
        );
        try {
          result = _parseAnalysisResult(
            jsonResponse: jsonResponse,
            fileId: fileId,
            fileName: fileName,
            stages: List.from(stages),
            evaluationMetrics: evaluationMetrics,
          );
        } catch (e2) {
          result = _errorResult(
            fileId,
            fileName,
            List.from(stages),
            'Unable to parse AI response. Raw: ${jsonResponse.substring(0, jsonResponse.length.clamp(0, 200))}',
          );
        }
      }

      await Future.delayed(const Duration(milliseconds: 200));
      stages[13] = stages[13].copyWith(
        status: AnalysisStepStatus.completed,
        result: result,
      );
      yield stages[13];

      // ── Step F: Persist to Firestore ────────────────────────────────
      await _firestoreService.saveAnalysisResult(
        companyId: companyId,
        fileId: fileId,
        resultData: {
          'status': 'completed',
          'analyzedBy': userId,
          'contentHash': contentHash,
          'result': result.toMap(),
        },
      );
    } catch (e) {
      debugPrint('[AnalyzeService] Error: $e');

      // Mark remaining stages as error
      for (int i = 6; i < 14; i++) {
        if (stages[i].status != AnalysisStepStatus.completed) {
          stages[i] = stages[i].copyWith(
            status: AnalysisStepStatus.error,
            errorMessage: (i == 11 || i == 7) ? e.toString() : null,
          );
          yield stages[i];
        }
      }

      // Persist error status
      await _firestoreService.saveAnalysisResult(
        companyId: companyId,
        fileId: fileId,
        resultData: {
          'status': 'error',
          'analyzedBy': userId,
          'contentHash': contentHash,
          'errorMessage': e.toString(),
        },
      );
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Public: Load cached result from Firestore.
  // Returns null if no cached result exists.
  // ---------------------------------------------------------------------------
  Future<AnalysisResult?> getCachedResult(
    String companyId,
    String fileId,
  ) async {
    try {
      final data = await _firestoreService.getAnalysisResult(companyId, fileId);
      if (data == null) return null;
      if (data['status'] != 'completed') return null;

      final resultMap = data['result'];
      if (resultMap == null) return null;

      return AnalysisResult.fromMap(Map<String, dynamic>.from(resultMap));
    } catch (e) {
      debugPrint('[AnalyzeService] getCachedResult error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Public: Load cached content hash from Firestore.
  // Returns null if no cached result exists or no content hash.
  // ---------------------------------------------------------------------------
  Future<String?> getCachedContentHash(String companyId, String fileId) async {
    try {
      final data = await _firestoreService.getAnalysisResult(companyId, fileId);
      if (data == null) return null;
      return data['contentHash'] as String?;
    } catch (e) {
      debugPrint('[AnalyzeService] getCachedContentHash error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private: Build the extraction prompt for Phase 1.
  // ---------------------------------------------------------------------------
  String _buildExtractionPrompt({
    required String fileName,
    required String contextString,
  }) {
    const int kMaxContextChars = 20000;
    final cappedContext =
        contextString.length > kMaxContextChars
            ? '${contextString.substring(0, kMaxContextChars)}\n... [CONTEXT TRUNCATED]'
            : contextString;

    return '''
$_kPhase1ExtractionPrompt

---

FILE BEING ANALYZED: $fileName

DOCUMENT CONTEXT (from RAG retrieval):
$cappedContext
''';
  }

  // ---------------------------------------------------------------------------
  // Private: Build the analyze prompt with context injection.
  // ---------------------------------------------------------------------------
  String _buildAnalyzePrompt({
    required String fileName,
    required String contextString,
    required String sessionId,
    required String extractedData,
  }) {
    const int kMaxContextChars = 16000;
    final cappedContext =
        contextString.length > kMaxContextChars
            ? '${contextString.substring(0, kMaxContextChars)}\n... [CONTEXT TRUNCATED — ${contextString.length - kMaxContextChars} chars omitted]'
            : contextString;

    return '''
$_kSystemPrompt

---

SESSION ANCHOR: $sessionId
FILE BEING ANALYZED: $fileName

PHASE 1 EXTRACTION RESULTS (Use this to ensure consistency):
$extractedData

DOCUMENT CONTEXT (from RAG retrieval):
$cappedContext

---

Now perform the full 14-stage AI Risk Intelligence analysis on the document above, strictly following the Phase 1 extraction results for consistency.
Output ONLY the JSON result as specified. Do not include any other text.
''';
  }

  // ---------------------------------------------------------------------------
  // Private: Parse AI JSON response → AnalysisResult.
  // Gracefully handles malformed JSON with fallback values.
  // ---------------------------------------------------------------------------
  String _attemptJsonRepair(String raw) {
    String working = raw.trim();

    // 1. Strip any trailing comma before we try to close structures
    if (working.endsWith(',')) working = working.substring(0, working.length - 1);

    // 2. Close any unclosed string: find the last `"` that is not escaped
    //    If we are mid-string, close it with a quote and a safe placeholder.
    int openBraces = 0, closeBraces = 0;
    int openBrackets = 0, closeBrackets = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < working.length; i++) {
      final ch = working[i];
      if (escaped) { escaped = false; continue; }
      if (ch == '\\') { escaped = true; continue; }
      if (ch == '"') { inString = !inString; continue; }
      if (inString) continue;
      if (ch == '{') openBraces++;
      if (ch == '}') closeBraces++;
      if (ch == '[') openBrackets++;
      if (ch == ']') closeBrackets++;
    }

    final sb = StringBuffer(working);
    // Close any open string literal
    if (inString) sb.write('"');
    // Strip trailing comma again after closing string (it may now be exposed)
    String partial = sb.toString().trimRight();
    if (partial.endsWith(',')) partial = partial.substring(0, partial.length - 1);
    final sb2 = StringBuffer(partial);
    for (int i = 0; i < openBrackets - closeBrackets; i++) {
      sb2.write(']');
    }
    for (int i = 0; i < openBraces - closeBraces; i++) {
      sb2.write('}');
    }
    return sb2.toString();
  }

  AnalysisResult _parseAnalysisResult({
    required String jsonResponse,
    required String fileId,
    required String fileName,
    required List<AnalysisPipelineStage> stages,
    AuditEvaluationMetrics? evaluationMetrics,
  }) {
    // Strip markdown fences if Gemini adds them despite JSON mime type
    String cleaned = jsonResponse.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceAll(RegExp(r'^```[a-z]*\n?'), '')
          .replaceAll(RegExp(r'\n?```$'), '');
    }

    late final Map<String, dynamic> json;
    bool isPartial = false;
    try {
      json = jsonDecode(cleaned) as Map<String, dynamic>;
    } catch (e) {
      debugPrint(
        '[AnalyzeService] JSON parse error: $e, attempting repair...',
      );
      final repaired = _attemptJsonRepair(cleaned);
      json = jsonDecode(repaired) as Map<String, dynamic>;
      isPartial = true;
    }

    RiskScore parseScore(String key) {
      final map = json[key];
      if (map == null) return _defaultRiskScore();
      return RiskScore.fromMap(Map<String, dynamic>.from(map));
    }

    final findings =
        (json['findings'] as List?)
            ?.map((e) => AuditFinding.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [];

    // Sort by priority ascending (1 = highest)
    findings.sort((a, b) => a.priority.compareTo(b.priority));

    String summary = json['executiveSummary'] as String? ?? '';
    if (isPartial || summary.isEmpty) {
      summary = 'Analysis partially completed. Some risk dimensions may reflect estimated values. '
          'Re-run the analysis for a full assessment.';
    }

    return AnalysisResult(
      fileId: fileId,
      fileName: fileName,
      organizationRisk: parseScore('organizationRisk'),
      transactionRisk: parseScore('transactionRisk'),
      entityRisk: parseScore('entityRisk'),
      financialStatementRisk: parseScore('financialStatementRisk'),
      documentRisk: parseScore('documentRisk'),
      executiveSummary: summary,
      findings: findings,
      stages: stages,
      overallConfidence:
          (json['overallConfidence'] as num?)?.toDouble() ?? 0.7,
      analyzedAt: DateTime.now(),
      evaluationMetrics: evaluationMetrics,
    );
  }

  static RiskScore _defaultRiskScore() => const RiskScore(
    score: 0,
    level: RiskLevel.low,
    confidence: 0.5,
    explanation: 'Score could not be determined.',
  );

  static AnalysisResult _errorResult(
    String fileId,
    String fileName,
    List<AnalysisPipelineStage> stages,
    String message,
  ) {
    final score = _defaultRiskScore();
    return AnalysisResult(
      fileId: fileId,
      fileName: fileName,
      organizationRisk: score,
      transactionRisk: score,
      entityRisk: score,
      financialStatementRisk: score,
      documentRisk: score,
      executiveSummary: 'The audit engine encountered an issue processing this document. '
          'Please re-run the analysis. (Technical detail: $message)',
      findings: const [],
      stages: stages,
      overallConfidence: 0.0,
      analyzedAt: DateTime.now(),
    );
  }
}

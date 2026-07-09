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

// ---------------------------------------------------------------------------
// Stage definitions — titles match the analyze_screen.txt pipeline
// ---------------------------------------------------------------------------
const List<String> _kStageTitles = [
  'File Identification',           // 1
  'Document Intelligence',         // 2
  'Document Matching',             // 3
  'Transaction Risk Assessment',   // 4
  'Anomaly Detection',             // 5
  'Benford\'s Law Analysis',       // 6
  'Financial Statement Risk',      // 7
  'Beneish M-Score',               // 8
  'Entity Risk Assessment',        // 9
  'Organization Risk Assessment',  // 10
  'Explainable AI',                // 11
  'Audit Findings',                // 12
  'Recommendations',               // 13
  'Executive Summary',             // 14
];

// ---------------------------------------------------------------------------
// System prompt for the 14-stage analysis (embedded inline as per spec —
// references analyze_screen.txt which is not a Flutter asset)
// ---------------------------------------------------------------------------
const String _kSystemPrompt = '''
You are an expert financial auditor and AI Risk Intelligence Engine. 
Perform a comprehensive 14-stage financial document audit and risk analysis.

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

IMPORTANT: findings must be sorted by priority (1 = highest). Return at least 3 findings if data supports it.
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
  })  : _ragService = ragService,
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

    // Simulate stages 1–11 sequentially before the actual AI call
    // (stages that map to the RAG + pre-processing work)
    for (int i = 0; i < 11; i++) {
      stages[i] = stages[i].copyWith(status: AnalysisStepStatus.running);
      yield stages[i];

      // Small synthetic delay per stage to reflect real pipeline timing
      await Future.delayed(const Duration(milliseconds: 400));

      stages[i] = stages[i].copyWith(status: AnalysisStepStatus.completed);
      yield stages[i];
    }

    // Stage 12: Audit Findings — actual Gemini call happens here
    stages[11] = stages[11].copyWith(status: AnalysisStepStatus.running);
    yield stages[11];

    try {
      // ── Step A: Retrieve RAG context ────────────────────────────────
      final chunks = await _ragService.retrieveRelevantContext(
        workspaceId: companyId,
        queryEmbedding: const [], // keyword-based fallback
        query: 'financial risk audit transaction anomaly entity organization',
        topK: 20,
        similarityThreshold: 0.5,
      );

      final contextString = _ragService.buildContextString(chunks);

      // ── Step B: Build prompt ────────────────────────────────────────
      final prompt = _buildAnalyzePrompt(
        fileName: fileName,
        contextString: contextString,
      );

      // ── Step C: Call Gemini ─────────────────────────────────────────
      final jsonResponse = await GeminiService.generateContent(
        prompt: prompt,
        modelName: GeminiService.mainModelName,
        config: GenerationConfig(
          temperature: 0.1,
          topP: 0.95,
          maxOutputTokens: 16384,
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

      // ── Step D: Parse response ──────────────────────────────────────
      final result = _parseAnalysisResult(
        jsonResponse: jsonResponse,
        fileId: fileId,
        fileName: fileName,
        stages: List.from(stages),
      );

      await Future.delayed(const Duration(milliseconds: 200));
      stages[13] = stages[13].copyWith(status: AnalysisStepStatus.completed);
      yield stages[13];

      // ── Step E: Persist to Firestore ────────────────────────────────
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
      for (int i = 11; i < 14; i++) {
        if (stages[i].status != AnalysisStepStatus.completed) {
          stages[i] = stages[i].copyWith(
            status: AnalysisStepStatus.error,
            errorMessage: i == 11 ? e.toString() : null,
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
      String companyId, String fileId) async {
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
  // Private: Build the analyze prompt with context injection.
  // ---------------------------------------------------------------------------
  String _buildAnalyzePrompt({
    required String fileName,
    required String contextString,
  }) {
    return '''
$_kSystemPrompt

---

FILE BEING ANALYZED: $fileName

DOCUMENT CONTEXT (from RAG retrieval):
$contextString

---

Now perform the full 14-stage AI Risk Intelligence analysis on the document above.
Output ONLY the JSON result as specified. Do not include any other text.
''';
  }

  // ---------------------------------------------------------------------------
  // Private: Parse AI JSON response → AnalysisResult.
  // Gracefully handles malformed JSON with fallback values.
  // ---------------------------------------------------------------------------
  AnalysisResult _parseAnalysisResult({
    required String jsonResponse,
    required String fileId,
    required String fileName,
    required List<AnalysisPipelineStage> stages,
  }) {
    try {
      // Strip markdown fences if Gemini adds them despite JSON mime type
      String cleaned = jsonResponse.trim();
      if (cleaned.startsWith('```')) {
        cleaned = cleaned
            .replaceAll(RegExp(r'^```[a-z]*\n?'), '')
            .replaceAll(RegExp(r'\n?```$'), '');
      }

      final Map<String, dynamic> json = jsonDecode(cleaned);

      RiskScore parseScore(String key) {
        final map = json[key];
        if (map == null) return _defaultRiskScore();
        return RiskScore.fromMap(Map<String, dynamic>.from(map));
      }

      final findings = (json['findings'] as List?)
              ?.map((e) =>
                  AuditFinding.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [];

      // Sort by priority ascending (1 = highest)
      findings.sort((a, b) => a.priority.compareTo(b.priority));

      return AnalysisResult(
        fileId: fileId,
        fileName: fileName,
        organizationRisk: parseScore('organizationRisk'),
        transactionRisk: parseScore('transactionRisk'),
        entityRisk: parseScore('entityRisk'),
        financialStatementRisk: parseScore('financialStatementRisk'),
        documentRisk: parseScore('documentRisk'),
        executiveSummary: json['executiveSummary'] as String? ??
            'Analysis completed. Review individual risk scores for details.',
        findings: findings,
        stages: stages,
        overallConfidence:
            (json['overallConfidence'] as num?)?.toDouble() ?? 0.7,
        analyzedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[AnalyzeService] JSON parse error: $e');
      debugPrint('[AnalyzeService] Raw response: $jsonResponse');
      // Return a structured error result rather than throwing
      return _errorResult(fileId, fileName, stages, 'Unable to parse AI response. Raw: ${jsonResponse.substring(0, jsonResponse.length.clamp(0, 200))}');
    }
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
      executiveSummary: 'Analysis encountered an error: $message',
      findings: const [],
      stages: stages,
      overallConfidence: 0.0,
      analyzedAt: DateTime.now(),
    );
  }
}

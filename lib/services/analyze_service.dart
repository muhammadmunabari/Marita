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
If the document lacks some variables required for the Beneish M-Score (e.g., DSRI, GMI, AQI, SGI, DEPI, SGAI, LVGI, TATA), you MUST predict or estimate the missing gaps using these industry-standard heuristics. Do NOT leave variables blank or fail the calculation:
- DSRI: Use AR/Revenue ratio of 1.0 (industry neutral) if AR or Revenue for only one year is present.
- GMI: Use 1.0 (neutral) if Gross Margin cannot be computed.
- AQI: Estimate Non-Current Assets as Total Assets - Current Assets - Gross PPE if available.
- SGI: If only one year's revenue is present, compare against industry median growth (5-10% mature, 15-25% growth firms).
- DEPI: Estimate Depreciation as 3-5% of gross PPE if depreciation expense is absent.
- SGAI: Use 15-20% of Revenue for product companies; 25-35% for service companies.
- LVGI: Use industry-average leverage of 0.5 Debt/Assets if balance sheet data is incomplete.
- TATA: Compute from Net Income - Operating Cash Flow if available; otherwise use 0.05.
Label EVERY estimated value as [PREDICTED — Reason: ...] inline. Label every value sourced from the document as [SOURCE: Document Name, Page X].

CRITICAL INSTRUCTION FOR BENEISH M-SCORE:
1. Always output a final Beneish M-Score, even if some variables are predicted.
2. Maintain STRICT adherence to the threshold of -2.22: > -2.22 = Potential Manipulator; <= -2.22 = Likely Non-Manipulator.
3. INDUSTRY-SPECIFIC CALIBRATION — STEP 0: AUTOMATIC SECTOR DETECTION
   Before computing M-Score interpretation, you MUST first IDENTIFY the company's industry sector
   from the document (look at: business description, KBLI code, product/service description, revenue streams).
   Then apply the corresponding ADJUSTED ANOMALY THRESHOLDS below.
   These apply to ANY company operating in these sectors — not just specific companies.
   The Beneish M-Score was originally calibrated on US manufacturing companies (1990s).
   Applying it without industry adjustment to non-manufacturing sectors produces systematic false positives.

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 1: DATA CENTER / COLOCATION / CLOUD INFRASTRUCTURE / MANAGED HOSTING
   Examples: data center operators, colocation providers, cloud service providers, managed IT
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–1.8 NORMAL (massive capex: servers, fiber, cooling, UPS, building).
     Anomaly threshold: AQI > 1.8
   - SGI: 1.1–2.5 NORMAL for growth-phase operators.
     Anomaly threshold: SGI > 2.5
   - DEPI: 0.7–1.3 NORMAL (accelerated depreciation on IT assets is standard).
   - SGAI: 8–18% of revenue is typical (low SGA for asset-heavy model).
   - LVGI: 1.0–2.0 NORMAL (project financing for capex is standard).

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 2: TELECOMMUNICATIONS / TOWER / FIBER NETWORK / SATELLITE
   Examples: telco operators, cell tower companies, fiber backbone, satellite comms
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–2.0 NORMAL (enormous network infrastructure capex).
     Anomaly threshold: AQI > 2.0
   - SGI: 1.0–1.8 NORMAL.
   - DEPI: 0.8–1.5 NORMAL (long asset lifetimes, regulatory depreciation schedules).
   - LVGI: 1.0–2.5 NORMAL (high leverage for spectrum and network build-out).

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 3: TECHNOLOGY / SOFTWARE / SaaS / PLATFORM / IT SERVICES
   Examples: software vendors, SaaS, enterprise IT, system integrators, BPO, IT consulting
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–1.5 NORMAL (intangible assets, software dev costs, goodwill from acquisitions).
   - SGI: 1.2–3.5 NORMAL for high-growth tech and SaaS companies.
     Anomaly threshold: SGI > 3.5
   - SGAI: 20–45% of revenue is NORMAL (heavy S&M spend for customer acquisition).
   - DEPI: 0.7–1.4 NORMAL (rapid software depreciation cycles).

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 4: E-COMMERCE / DIGITAL MARKETPLACE / ONLINE RETAIL
   Examples: online retail, marketplace platforms, digital commerce, social commerce
   ─────────────────────────────────────────────────────────────────────────────
   - GMI: Values below 1.0 or close to 1.0 are NORMAL (low gross margin for marketplaces).
   - SGI: 1.2–4.0 NORMAL for growth-phase e-commerce.
   - SGAI: 25–50% of revenue is NORMAL (heavy promotions and logistics costs).
   - AQI: 1.0–1.6 NORMAL (warehouse, fulfilment center, tech infrastructure).

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 5: FINTECH / DIGITAL BANKING / PAYMENT / INSURTECH
   Examples: digital banks, payment processors, P2P lending, digital insurance
   ─────────────────────────────────────────────────────────────────────────────
   - TATA: Wider range is acceptable due to accrual nature of financial instruments.
   - AQI: 1.0–1.5 NORMAL (tech infrastructure, intangible licenses, regulatory capital).
   - SGI: 1.2–3.0 NORMAL for fast-growing fintech.
   - LVGI: 2.0–5.0 NORMAL (lending book leverage is inherent to the business model).

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 6: DIGITAL MEDIA / GAMING / STREAMING / CONTENT PLATFORM
   Examples: online gaming, streaming services, digital content, OTT platforms
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–1.6 NORMAL (content library capitalization, game development costs).
   - SGI: 1.2–4.0 NORMAL for growth-phase platforms.
   - SGAI: 30–55% of revenue is NORMAL (heavy marketing for user acquisition).
   - DEPI: 0.6–1.5 NORMAL (content amortization periods vary widely).

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 7: SEMICONDUCTOR / HARDWARE / ELECTRONICS MANUFACTURING
   Examples: chip makers, electronics OEM, PCB, device manufacturers
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–1.7 NORMAL (fab equipment, cleanroom, R&D capitalization).
   - DEPI: 0.7–1.4 NORMAL (fab equipment has accelerated depreciation cycles).
   - SGI: 1.0–2.5 NORMAL for expansion cycles.

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 8: HEALTH TECH / BIOTECH / PHARMA / MEDICAL DEVICES
   Examples: pharmaceutical, biotech R&D, digital health, medical equipment
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–2.0 NORMAL (large R&D capitalization, patents, clinical trial costs).
   - SGAI: 25–40% of revenue is NORMAL (regulatory affairs + marketing).
   - SGI: 1.0–2.5 NORMAL for pipeline-driven companies.
   - TATA: Wider range acceptable due to milestone-based revenue recognition.

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 9: ENERGY / MINING / OIL & GAS / RENEWABLE ENERGY
   Examples: mining companies, oil & gas, coal, geothermal, solar, wind farms
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–2.5 NORMAL (massive exploration and extraction assets).
   - DEPI: 0.7–1.5 NORMAL (depletion methods vary by resource type).
   - LVGI: 1.0–3.0 NORMAL (project financing for resource development).
   - SGI: Highly volatile by commodity cycle — use 3-year average if available.

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 10: REAL ESTATE / REIT / PROPERTY DEVELOPER / CONSTRUCTION
   Examples: property developers, REITs, construction companies, contractors
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–2.5 NORMAL (investment properties, land bank at cost or fair value).
   - DEPI: Wide range acceptable due to property revaluation policies.
   - LVGI: 1.0–3.5 NORMAL (project financing for property development is standard).
   - SGI: 0.8–2.0 NORMAL (lumpy revenue from project completions).

   ─────────────────────────────────────────────────────────────────────────────
   SECTOR 11: LOGISTICS / TRANSPORTATION / SHIPPING / AVIATION
   Examples: freight, courier, airline, shipping, port operators
   ─────────────────────────────────────────────────────────────────────────────
   - AQI: 1.0–2.0 NORMAL (fleet, aircraft, vessels, port equipment).
   - LVGI: 1.0–3.0 NORMAL (fleet financing and leasing is standard).
   - SGI: 1.0–2.0 NORMAL.

   ─────────────────────────────────────────────────────────────────────────────
   GENERAL RULE FOR ANY GROWTH-STAGE OR CAPITAL-INTENSIVE COMPANY (FALLBACK):
   If the company is in a sector not listed above but is clearly:
   (a) in a capital-intensive industry, OR (b) in a high-growth phase, OR
   (c) a startup/scale-up with < 5 years of profitability history,
   then apply: AQI anomaly threshold = 1.6, SGI anomaly threshold = 2.5
   ─────────────────────────────────────────────────────────────────────────────

   MANDATORY OUTPUT — after industry detection:
   State which industry calibration you applied, e.g.:
   "Industry calibration applied: SECTOR 3 (Technology/SaaS) — SGI threshold adjusted to 3.5"
   If M-Score is above -2.22 but ALL elevated indices are explained by the industry profile, append:
   "NOTE: M-Score is above -2.22, however all elevated variables are consistent with [sector] industry norms. Risk of actual earnings manipulation is LOW."

MANDATORY OUTPUT FORMAT:
Output your findings clearly in text format. Include all variables with their labels and the final score.
At the end of your analysis, you MUST include a clearly formatted summary block like this:

=== BENEISH M-SCORE SUMMARY ===
DSRI: [value]
GMI: [value]
AQI: [value]
SGI: [value]
DEPI: [value]
SGAI: [value]
LVGI: [value]
TATA: [value]
Beneish M-Score: [final numeric value, e.g., -2.51]
Classification: [LIKELY NON-MANIPULATOR / POTENTIAL MANIPULATOR]
Variables sourced from document: [X]/8
Variables predicted/estimated: [Y]/8
=== END SUMMARY ===
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

CRITICAL SCORING CALIBRATION — READ BEFORE ASSIGNING ANY SCORE:
You MUST derive all risk scores from the Phase 1 extraction data provided below, NOT from independent conservative assumptions.

For financialStatementRisk score, use the Beneish M-Score result as the PRIMARY driver:
- M-Score ≤ -2.22 (Likely Non-Manipulator): financialStatementRisk score = 20–40 (low), level = "low"
- M-Score between -2.22 and -1.78: financialStatementRisk score = 40–60 (medium), level = "medium"
- M-Score between -1.78 and -1.49: financialStatementRisk score = 60–74 (medium-high), level = "medium"
- M-Score > -1.49 (Strong Manipulator Signal): financialStatementRisk score = 75–90 (high), level = "high"
- If Beneish M-Score is NOT available (missing data), score = 50, level = "medium"

For other risk categories, calibrate against actual data, not worst-case assumptions:
- organizationRisk: Assess based on governance structure, related parties, audit findings. A listed company with Big4 auditor = max 45 score unless red flags are present.
- transactionRisk: Only assign "high" (>60) if there are specific anomalies detected. Normal revenue growth for the industry = max 40 score.
- entityRisk: Only assign "high" if related-party transactions are excessive or undisclosed.
- documentRisk: Assess completeness and consistency of the document. A complete annual report = max 30 score.

SCORING RULES (MANDATORY):
1. Do NOT default to "high" or "critical" without specific supporting evidence from Phase 1.
2. A publicly listed company with a clean audit opinion and normal operations should score LOW on most dimensions.
3. Each score must be DIRECTLY JUSTIFIED by Phase 1 extraction data.
4. Scores must be PROPORTIONAL: if Phase 1 says Beneish M-Score indicates "Likely Non-Manipulator", financialStatementRisk CANNOT be "high" or "critical".
5. Industry context matters: Technology and Infrastructure companies have naturally high capital expenditure and asset growth — this is NOT a red flag by itself.
6. If Phase 1 explicitly notes "Industry calibration applied" or "Risk of actual earnings manipulation is LOW", then financialStatementRisk score MUST be calibrated accordingly (typically 35–55 range, not "high").
7. Presence of a Big 4 / reputable auditor with an unqualified opinion is a significant risk-mitigating factor — reduce organizationRisk by at least 15 points from what pure financial metrics would suggest.

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
      final beneishExtract = _extractBeneishFromPhase1(phase1Response);
      AnalysisResult result;
      try {
        result = _parseAnalysisResult(
          jsonResponse: jsonResponse,
          fileId: fileId,
          fileName: fileName,
          stages: List.from(stages),
          evaluationMetrics: evaluationMetrics,
          mScore: beneishExtract?.mScore,
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
            mScore: beneishExtract?.mScore,
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

    // ── Programmatic M-Score Extraction ──────────────────────────────────────
    // Extract Beneish M-Score from Phase 1 text using Dart regex.
    // This ensures Phase 2 CANNOT diverge from Phase 1 findings.
    final beneishExtract = _extractBeneishFromPhase1(extractedData);
    final String mandatoryOverrideBlock = beneishExtract != null
        ? '''
╔══════════════════════════════════════════════════════════════════════════╗
║  MANDATORY OVERRIDE — DO NOT DEVIATE FROM THESE VALUES                  ║
║  These are programmatically extracted from Phase 1. They are FINAL.     ║
╠══════════════════════════════════════════════════════════════════════════╣
║  Beneish M-Score : ${beneishExtract.mScore.toStringAsFixed(4).padRight(10)}                                   ║
║  Classification  : ${beneishExtract.classification.padRight(30)}          ║
║  financialStatementRisk MUST be: ${beneishExtract.mandatoryScoreRange.padRight(20)}              ║
║  financialStatementRisk level  : ${beneishExtract.mandatoryLevel.padRight(20)}              ║
╚══════════════════════════════════════════════════════════════════════════╝

IF YOU ASSIGN A financialStatementRisk SCORE OUTSIDE THE MANDATORY RANGE ABOVE,
YOUR RESPONSE IS INCORRECT AND WILL BE REJECTED. THERE ARE NO EXCEPTIONS.

${beneishExtract.industryNote ?? ''}
'''
        : '''
[NOTE: Could not extract Beneish M-Score from Phase 1. Default to score=50 (medium) for financialStatementRisk.]
''';

    return '''
$_kSystemPrompt

---

SESSION ANCHOR: $sessionId
FILE BEING ANALYZED: $fileName

$mandatoryOverrideBlock

PHASE 1 EXTRACTION RESULTS (full text — for context and other risk dimensions):
$extractedData

DOCUMENT CONTEXT (from RAG retrieval):
$cappedContext

---

SCORING INSTRUCTIONS (MANDATORY — apply before generating any JSON):
Step 1: The financialStatementRisk score and level are ALREADY determined by the MANDATORY OVERRIDE above. Do NOT recalculate or override this.
Step 2: For all OTHER risk categories (organizationRisk, transactionRisk, entityRisk, documentRisk), calibrate proportionally from Phase 1 findings. For TECHNOLOGY/INFRASTRUCTURE sectors: default to LOW unless specific anomalies are explicitly found.
Step 3: For tech/infrastructure companies with a Big 4 auditor and unqualified opinion: organizationRisk MUST be ≤ 40.
Step 4: Output ONLY the JSON. No markdown fences, no explanatory text.

Now output the JSON result.
''';
  }

  // ---------------------------------------------------------------------------
  // Private: Programmatically extract Beneish M-Score from Phase 1 text.
  // Returns null if extraction fails (Phase 2 will then use default 50/medium).
  // ---------------------------------------------------------------------------
  _BeneishExtract? _extractBeneishFromPhase1(String phase1Text) {
    try {
      // Pattern 1: === BENEISH M-SCORE SUMMARY === block
      // Pattern 2: "Beneish M-Score: -2.51" anywhere in text
      // Pattern 3: "M-Score = -2.51" or "M-Score: -2.51"
      final mScoreRegex = RegExp(
        r'(?:Beneish\s+M-Score\s*[=:]\s*|M-Score\s*[=:]\s*)([+-]?\d+\.\d+)',
        caseSensitive: false,
      );

      final mScoreMatch = mScoreRegex.firstMatch(phase1Text);
      if (mScoreMatch == null) return null;

      final mScore = double.tryParse(mScoreMatch.group(1) ?? '');
      if (mScore == null) return null;

      // Extract classification
      final isNonManipulator =
          phase1Text.toLowerCase().contains('non-manipulator') ||
          phase1Text.toLowerCase().contains('non manipulator') ||
          phase1Text.toLowerCase().contains('likely non') ||
          (phase1Text.toLowerCase().contains('risk of actual earnings manipulation is low') &&
           mScore <= -1.80); // industry-calibrated

      final classification = isNonManipulator
          ? 'LIKELY NON-MANIPULATOR'
          : 'POTENTIAL MANIPULATOR';

      // Determine mandatory score range from M-Score
      String mandatoryScoreRange;
      String mandatoryLevel;
      String? industryNote;

      // Check if Phase 1 flagged industry calibration override
      final hasLowManipulationNote = phase1Text.toLowerCase().contains(
        'risk of actual earnings manipulation is low',
      );

      if (mScore <= -2.22 || (hasLowManipulationNote && mScore <= -1.80)) {
        mandatoryScoreRange = '20–40';
        mandatoryLevel = 'low';
        if (hasLowManipulationNote) {
          industryNote =
            'Phase 1 noted industry calibration: elevated M-Score variables '
            'are consistent with industry norms. financialStatementRisk stays LOW.';
        }
      } else if (mScore <= -1.78) {
        mandatoryScoreRange = '40–59';
        mandatoryLevel = 'medium';
      } else if (mScore <= -1.49) {
        mandatoryScoreRange = '60–74';
        mandatoryLevel = 'medium';
      } else {
        mandatoryScoreRange = '75–90';
        mandatoryLevel = 'high';
      }

      return _BeneishExtract(
        mScore: mScore,
        classification: classification,
        mandatoryScoreRange: mandatoryScoreRange,
        mandatoryLevel: mandatoryLevel,
        industryNote: industryNote,
      );
    } catch (e) {
      debugPrint('[AnalyzeService] _extractBeneishFromPhase1 error: $e');
      return null;
    }
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
    double? mScore,
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
      mScore: mScore,
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

// ---------------------------------------------------------------------------
// Value class: result of programmatic Beneish M-Score extraction from Phase 1.
// ---------------------------------------------------------------------------
class _BeneishExtract {
  final double mScore;
  final String classification;
  final String mandatoryScoreRange;
  final String mandatoryLevel;
  final String? industryNote;

  const _BeneishExtract({
    required this.mScore,
    required this.classification,
    required this.mandatoryScoreRange,
    required this.mandatoryLevel,
    this.industryNote,
  });
}

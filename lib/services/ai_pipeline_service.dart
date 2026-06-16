import 'package:marita/models/chat_message.dart';
import 'package:marita/models/chunk_model.dart';
import 'package:marita/services/fact_verification_service.dart';
import 'package:marita/services/gemini_service.dart';
import 'package:marita/services/rag_service.dart';

enum QueryType { general, financialAnalysis, fraudDetection, auditRequest }

class PromptRouter {
  static QueryType route(String query) {
    final lower = query.toLowerCase();
    if (lower.contains('fraud') || lower.contains('manipulat') || lower.contains('beneish') || lower.contains('m-score')) {
      return QueryType.fraudDetection;
    } else if (lower.contains('ratio') || lower.contains('revenue') || lower.contains('income') || lower.contains('balance sheet') || lower.contains('financial')) {
      return QueryType.financialAnalysis;
    } else if (lower.contains('audit') || lower.contains('tax') || lower.contains('compliance') || lower.contains('verify')) {
      return QueryType.auditRequest;
    }
    return QueryType.general;
  }
}

class PipelineResult {
  final String responseText;
  final QueryType queryType;
  final double confidenceScore;
  final List<String> citations;
  final bool isVerified;
  final int retrievedChunksCount;
  final List<Map<String, dynamic>> retrievedChunksInfo;
  final List<String> feedback;
  final int? fullCorrectCount;
  final int? semiCorrectCount;
  final int? incorrectCount;
  final double? precisionPercent;

  PipelineResult({
    required this.responseText,
    required this.queryType,
    required this.confidenceScore,
    required this.citations,
    required this.isVerified,
    required this.retrievedChunksCount,
    required this.retrievedChunksInfo,
    required this.feedback,
    this.fullCorrectCount,
    this.semiCorrectCount,
    this.incorrectCount,
    this.precisionPercent,
  });
}
class AIPipelineService {
  final RAGService _ragService = RAGService();

  /// Step 1 & 2: Static Analysis (Routing) and RAG Retrieval
  Future<List<DocumentChunk>> retrieveContext({
    required String query,
    required String workspaceId,
    List<double> queryEmbedding = const [],
  }) async {
    print("======================================================================");
    print("🔍 [AI PIPELINE] STAGE 1: STATIC ANALYSIS & PROMPT ROUTING");
    print("======================================================================");
    final queryType = PromptRouter.route(query);
    print("  ├─ User Query: \"$query\"");
    print("  ├─ Classification: ${queryType.name.toUpperCase()}");
    
    // Find matched keywords for explanation in logs
    final lowerQuery = query.toLowerCase();
    final keywords = <String>[];
    if (lowerQuery.contains('fraud') || lowerQuery.contains('manipulat') || lowerQuery.contains('beneish') || lowerQuery.contains('m-score')) {
      keywords.addAll(['fraud', 'manipulation', 'beneish', 'm-score']);
    }
    if (lowerQuery.contains('ratio') || lowerQuery.contains('revenue') || lowerQuery.contains('income') || lowerQuery.contains('balance sheet') || lowerQuery.contains('financial')) {
      keywords.addAll(['ratio', 'revenue', 'income', 'balance sheet', 'financial']);
    }
    if (lowerQuery.contains('audit') || lowerQuery.contains('tax') || lowerQuery.contains('compliance') || lowerQuery.contains('verify')) {
      keywords.addAll(['audit', 'tax', 'compliance', 'verify']);
    }
    print("  └─ Detected Routing Keywords: ${keywords.isNotEmpty ? keywords.join(', ') : 'none'}");

    print("\n======================================================================");
    print("📚 [AI PIPELINE] STAGE 2: RAG QUERY CONTEXT RETRIEVAL");
    print("======================================================================");
    print("  ├─ Workspace ID: $workspaceId");
    print("  ├─ Retrieval Method: ${queryEmbedding.isNotEmpty ? 'Semantic Vector' : 'Keyword Text Fallback'}");
    print("  ├─ RAG Query (first 120 chars): \"${query.length > 120 ? '${query.substring(0, 120)}...' : query}\"");

    final retrievedChunks = await _ragService.retrieveRelevantContext(
      workspaceId: workspaceId,
      queryEmbedding: queryEmbedding,
      query: query,
    );

    print("  ├─ Retrieved Chunks Count: ${retrievedChunks.length}");
    if (retrievedChunks.isNotEmpty) {
      for (int i = 0; i < retrievedChunks.length; i++) {
        final chunk = retrievedChunks[i];
        final docName = chunk.metadata['fileName'] ?? 'Unknown Document';
        print("  ├─ Chunk [${i + 1}]: File: $docName, Page: ${chunk.pageNumber}");
        final preview = chunk.content.length > 80 ? '${chunk.content.substring(0, 80).replaceAll('\n', ' ')}...' : chunk.content;
        print("  │  └─ Content Preview: \"$preview\"");
      }
    } else {
      print("  ├─ ⚠️  No chunks retrieved — check Firestore path: companies/$workspaceId/files/<id>/chunks");
      print("  └─ Suggestion: Ensure documents have been uploaded and processed into the workspace.");
    }
    print("======================================================================\n");

    return retrievedChunks;
  }

  /// Helper to build augmented prompt
  String buildAugmentedPrompt(String query, QueryType queryType, List<DocumentChunk> chunks) {
    final contextString = _ragService.buildContextString(chunks);
    final augmentedPrompt = StringBuffer();
    augmentedPrompt.writeln("Query Type: ${queryType.name}");
    augmentedPrompt.writeln(contextString);
    augmentedPrompt.writeln("\nUser Query: $query");
    
    print("======================================================================");
    print("✍️ [AI PIPELINE] STAGE 3: PROMPT AUGMENTATION");
    print("======================================================================");
    print("  ├─ Augmented Prompt Length: ${augmentedPrompt.length} characters");
    print("  └─ Status: Formatted and packaged for Gemini 2.5 Pro");
    print("======================================================================\n");
    
    return augmentedPrompt.toString();
  }

  /// Step 5 & 6: Fact Verification and Response Validation
  Future<PipelineResult> verifyAndValidate({
    required String query,
    required QueryType queryType,
    required String draftResponse,
    required List<DocumentChunk> retrievedChunks,
  }) async {
    print("======================================================================");
    print("⚖️ [AI PIPELINE] STAGE 5: FACT VERIFICATION");
    print("======================================================================");
    print("  ├─ Verifying Draft Response against source chunks...");
    print("  ├─ Source Chunks Available: ${retrievedChunks.length}");

    final verification = await FactVerificationService.verifyResponse(
      draftResponse: draftResponse,
      retrievedChunks: retrievedChunks,
    );

    // Compute total claims scanned correctly
    final totalScanned = (verification.assessment?.fullCorrectCount ?? 0) +
        (verification.assessment?.semiCorrectCount ?? 0) +
        (verification.assessment?.incorrectCount ?? 0);

    print("  ├─ Total Numerical/Financial Claims Scanned: $totalScanned");
    print("  ├─ Evidence Score: ${verification.evidenceScore.toStringAsFixed(2)}");
    print("  ├─ Confidence Score: ${(verification.confidenceScore * 100).toStringAsFixed(1)}%");

    if (verification.validatedCitations.isNotEmpty) {
      print("  ├─ Validated Citations:");
      for (final citation in verification.validatedCitations) {
        print("  │  └─ ✅ $citation");
      }
    } else {
      print("  ├─ Validated Citations: (none)");
    }

    if (verification.feedback.isNotEmpty) {
      print("  ├─ Verification Issues (Potential Hallucinations):");
      for (final issue in verification.feedback) {
        print("  │  └─ ⚠️  $issue");
      }
    } else {
      print("  ├─ Fact Check: ✅ All claims verified against source context.");
    }

    // --- Assessment Criteria (Precision Metric) ---
    final assessment = verification.assessment;
    if (assessment != null) {
      print("  ├─ ─────────────────────────────────────────");
      print("  ├─ 📊 ASSESSMENT CRITERIA (Precision Metric)");
      print("  ├─ ─────────────────────────────────────────");
      print("  ├─ [1] Full Correct   : ${assessment.fullCorrectCount} claim(s)");
      print("  │       Jawaban sesuai sepenuhnya dengan data sumber.");
      print("  ├─ [2] Semi-Correct   : ${assessment.semiCorrectCount} claim(s)");
      print("  │       Nilai numerik benar, kesalahan pada satuan/pembulatan.");
      print("  ├─ [3] Incorrect      : ${assessment.incorrectCount} claim(s)");
      print("  │       Jawaban tidak sesuai / numerical hallucination.");
      print("  ├─ ─────────────────────────────────────────");
      print("  ├─ Precision Formula  : Correct / (Correct + Incorrect) × 100%");
      print("  │  = ${assessment.fullCorrectCount} / (${assessment.fullCorrectCount} + ${assessment.incorrectCount}) × 100%");
      print("  └─ Precision Score    : ${assessment.precisionPercent.toStringAsFixed(1)}%");
    } else {
      print("  └─ Assessment Criteria: N/A (no source chunks to compare against).");
    }

    print("\n======================================================================");
    print("🚦 [AI PIPELINE] STAGE 6: RESPONSE VALIDATOR & FALLBACK");
    print("======================================================================");
    print("  ├─ Pipeline Status: ${verification.isValid ? 'PASSED (Confidence >= 85%)' : 'WARNING (Confidence < 85%)'}");

    String finalResponse = draftResponse;
    if (!verification.isValid && verification.confidenceScore < 0.5) {
      finalResponse = "$draftResponse\n\n[Warning: Some values in this response could not be verified against source documents. Please verify from source files.]";
      print("  └─ Action: Fallback appended to response text.");
    } else {
      print("  └─ Action: Response matches validation requirements.");
    }
    print("======================================================================\n");

    return PipelineResult(
      responseText: finalResponse,
      queryType: queryType,
      confidenceScore: verification.confidenceScore,
      citations: verification.validatedCitations,
      isVerified: verification.isValid,
      retrievedChunksCount: retrievedChunks.length,
      retrievedChunksInfo: retrievedChunks.map((chunk) => {
        'fileName': chunk.metadata['fileName'] ?? 'Unknown Document',
        'pageNumber': chunk.pageNumber,
        'content': chunk.content,
      }).toList(),
      feedback: verification.feedback,
      fullCorrectCount: verification.assessment?.fullCorrectCount,
      semiCorrectCount: verification.assessment?.semiCorrectCount,
      incorrectCount: verification.assessment?.incorrectCount,
      precisionPercent: verification.assessment?.precisionPercent,
    );
  }

  /// Executes the full AI Pipeline.
  Future<PipelineResult> execute({
    required String query,
    required String workspaceId,
    List<ChatAttachment> attachments = const [],
    List<ChatMessage> history = const [],
    List<double> queryEmbedding = const [],
  }) async {
    // Stage 1 & 2: Static Analysis and RAG Retrieval
    final queryType = PromptRouter.route(query);
    final retrievedChunks = await retrieveContext(
      query: query,
      workspaceId: workspaceId,
      queryEmbedding: queryEmbedding,
    );

    // Stage 3: Build Augmented Prompt
    final augmentedPrompt = buildAugmentedPrompt(query, queryType, retrievedChunks);

    // Stage 4: Generative Execution
    print("======================================================================");
    print("🤖 [AI PIPELINE] STAGE 4: GEMINI EXECUTION & GENERATIVE STREAM");
    print("======================================================================");
    print("  ├─ Model Target: gemini-2.5-pro");
    print("  └─ Status: Stream started...");

    final responseBuffer = StringBuffer();
    await for (final chunk in GeminiService.sendMessageStream(
      augmentedPrompt,
      attachments: attachments,
      history: history,
    )) {
      responseBuffer.write(chunk);
    }
    print("  └─ Status: Stream generation complete.");
    print("======================================================================\n");

    final draftResponse = responseBuffer.toString();

    // Stage 5 & 6: Fact Verification and Response Validation
    return await verifyAndValidate(
      query: query,
      queryType: queryType,
      draftResponse: draftResponse,
      retrievedChunks: retrievedChunks,
    );
  }
}

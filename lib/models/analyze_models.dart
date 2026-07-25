import 'file_item.dart';

/// Risk levels from Stage 4 & 10 of financial audit analysis.
enum RiskLevel { low, medium, high, critical }

/// Status of each stage in the analysis pipeline.
enum AnalysisStepStatus { pending, running, completed, error }

/// Overall status of the analysis job for a single file or the whole batch.
enum AnalysisStatus { idle, running, completed, error }

/// Represents a single stage in the 14-stage pipeline.
class AnalysisPipelineStage {
  final int stageNumber; // 1–14
  final String title; // e.g., "File Identification"
  final AnalysisStepStatus status;
  final String? errorMessage;

  /// In-memory only: carries the completed [AnalysisResult] on the final stage
  /// (stageNumber == 14, status == completed). Not persisted to Firestore.
  /// This eliminates the write→read race condition by passing the result
  /// directly through the stream rather than re-fetching it.
  final AnalysisResult? result;

  const AnalysisPipelineStage({
    required this.stageNumber,
    required this.title,
    required this.status,
    this.errorMessage,
    this.result,
  });

  AnalysisPipelineStage copyWith({
    int? stageNumber,
    String? title,
    AnalysisStepStatus? status,
    String? errorMessage,
    AnalysisResult? result,
  }) {
    return AnalysisPipelineStage(
      stageNumber: stageNumber ?? this.stageNumber,
      title: title ?? this.title,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      result: result ?? this.result,
    );
  }

  /// Excludes the [result] field — it is in-memory only and must not be
  /// serialized to Firestore (the full AnalysisResult is stored separately).
  Map<String, dynamic> toMap() {
    return {
      'stageNumber': stageNumber,
      'title': title,
      'status': status.name,
      'errorMessage': errorMessage,
    };
  }

  factory AnalysisPipelineStage.fromMap(Map<String, dynamic> map) {
    return AnalysisPipelineStage(
      stageNumber: map['stageNumber'] as int? ?? 0,
      title: map['title'] as String? ?? '',
      status: AnalysisStepStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AnalysisStepStatus.pending,
      ),
      errorMessage: map['errorMessage'] as String?,
      // result is never restored from Firestore — it is transient
    );
  }
}

/// Represents a single finding from the audit.
class AuditFinding {
  final String title;
  final String description;
  final RiskLevel riskLevel;
  final List<String> affectedItems; // transactions, accounts, vendors, etc.
  final String recommendation;
  final int priority; // 1 = highest

  const AuditFinding({
    required this.title,
    required this.description,
    required this.riskLevel,
    required this.affectedItems,
    required this.recommendation,
    required this.priority,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'riskLevel': riskLevel.name,
      'affectedItems': affectedItems,
      'recommendation': recommendation,
      'priority': priority,
    };
  }

  factory AuditFinding.fromMap(Map<String, dynamic> map) {
    return AuditFinding(
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.name == map['riskLevel'],
        orElse: () => RiskLevel.medium,
      ),
      affectedItems: List<String>.from(map['affectedItems'] ?? []),
      recommendation: map['recommendation'] as String? ?? '',
      priority: map['priority'] as int? ?? 1,
    );
  }
}

/// Details of a single risk category score.
class RiskScore {
  final int score; // 0–100
  final RiskLevel level;
  final double confidence; // 0.0–1.0
  final String explanation;

  const RiskScore({
    required this.score,
    required this.level,
    required this.confidence,
    required this.explanation,
  });

  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'level': level.name,
      'confidence': confidence,
      'explanation': explanation,
    };
  }

  factory RiskScore.fromMap(Map<String, dynamic> map) {
    return RiskScore(
      score: map['score'] as int? ?? 0,
      level: RiskLevel.values.firstWhere(
        (e) => e.name == map['level'],
        orElse: () => RiskLevel.low,
      ),
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      explanation: map['explanation'] as String? ?? '',
    );
  }
}

/// Evaluation metrics hasil dari FactVerificationService dalam pipeline audit.
class AuditEvaluationMetrics {
  final double evidenceScore; // 0.0–1.0
  final double confidenceScore; // 0.0–1.0
  final double precisionPercent; // 0.0–100.0
  final int fullCorrectCount;
  final int semiCorrectCount;
  final int incorrectCount;
  final int totalClaims;

  const AuditEvaluationMetrics({
    required this.evidenceScore,
    required this.confidenceScore,
    required this.precisionPercent,
    required this.fullCorrectCount,
    required this.semiCorrectCount,
    required this.incorrectCount,
    required this.totalClaims,
  });

  Map<String, dynamic> toMap() {
    return {
      'evidenceScore': evidenceScore,
      'confidenceScore': confidenceScore,
      'precisionPercent': precisionPercent,
      'fullCorrectCount': fullCorrectCount,
      'semiCorrectCount': semiCorrectCount,
      'incorrectCount': incorrectCount,
      'totalClaims': totalClaims,
    };
  }

  factory AuditEvaluationMetrics.fromMap(Map<String, dynamic> map) {
    return AuditEvaluationMetrics(
      evidenceScore: (map['evidenceScore'] as num?)?.toDouble() ?? 0.0,
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble() ?? 0.0,
      precisionPercent: (map['precisionPercent'] as num?)?.toDouble() ?? 0.0,
      fullCorrectCount: map['fullCorrectCount'] as int? ?? 0,
      semiCorrectCount: map['semiCorrectCount'] as int? ?? 0,
      incorrectCount: map['incorrectCount'] as int? ?? 0,
      totalClaims: map['totalClaims'] as int? ?? 0,
    );
  }
}

/// The overall structured result of a completed document audit.
class AnalysisResult {
  final String fileId;
  final String fileName;
  final RiskScore organizationRisk;
  final RiskScore transactionRisk;
  final RiskScore entityRisk;
  final RiskScore financialStatementRisk;
  final RiskScore documentRisk;
  final String executiveSummary;
  final List<AuditFinding> findings; // sorted by priority
  final List<AnalysisPipelineStage> stages;
  final double overallConfidence;
  final DateTime analyzedAt;
  final AuditEvaluationMetrics? evaluationMetrics;

  const AnalysisResult({
    required this.fileId,
    required this.fileName,
    required this.organizationRisk,
    required this.transactionRisk,
    required this.entityRisk,
    required this.financialStatementRisk,
    required this.documentRisk,
    required this.executiveSummary,
    required this.findings,
    required this.stages,
    required this.overallConfidence,
    required this.analyzedAt,
    this.evaluationMetrics,
  });

  Map<String, dynamic> toMap() {
    return {
      'fileId': fileId,
      'fileName': fileName,
      'organizationRisk': organizationRisk.toMap(),
      'transactionRisk': transactionRisk.toMap(),
      'entityRisk': entityRisk.toMap(),
      'financialStatementRisk': financialStatementRisk.toMap(),
      'documentRisk': documentRisk.toMap(),
      'executiveSummary': executiveSummary,
      'findings': findings.map((e) => e.toMap()).toList(),
      'stages': stages.map((e) => e.toMap()).toList(),
      'overallConfidence': overallConfidence,
      'analyzedAt': analyzedAt.toIso8601String(),
      if (evaluationMetrics != null)
        'evaluationMetrics': evaluationMetrics!.toMap(),
    };
  }

  factory AnalysisResult.fromMap(Map<String, dynamic> map) {
    DateTime parseDateTime(dynamic val) {
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      return DateTime.now();
    }

    return AnalysisResult(
      fileId: map['fileId'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      organizationRisk: RiskScore.fromMap(
        Map<String, dynamic>.from(map['organizationRisk'] ?? {}),
      ),
      transactionRisk: RiskScore.fromMap(
        Map<String, dynamic>.from(map['transactionRisk'] ?? {}),
      ),
      entityRisk: RiskScore.fromMap(
        Map<String, dynamic>.from(map['entityRisk'] ?? {}),
      ),
      financialStatementRisk: RiskScore.fromMap(
        Map<String, dynamic>.from(map['financialStatementRisk'] ?? {}),
      ),
      documentRisk: RiskScore.fromMap(
        Map<String, dynamic>.from(map['documentRisk'] ?? {}),
      ),
      executiveSummary: map['executiveSummary'] as String? ?? '',
      findings:
          (map['findings'] as List?)
              ?.map((e) => AuditFinding.fromMap(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      stages:
          (map['stages'] as List?)
              ?.map(
                (e) =>
                    AnalysisPipelineStage.fromMap(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          [],
      overallConfidence: (map['overallConfidence'] as num?)?.toDouble() ?? 0.0,
      analyzedAt: parseDateTime(map['analyzedAt']),
      evaluationMetrics:
          map['evaluationMetrics'] != null
              ? AuditEvaluationMetrics.fromMap(
                Map<String, dynamic>.from(map['evaluationMetrics']),
              )
              : null,
    );
  }

  /// Composite overall score (average of all 5 dimension scores).
  int get overallScore {
    final scores = [
      organizationRisk.score,
      transactionRisk.score,
      entityRisk.score,
      financialStatementRisk.score,
      documentRisk.score,
    ];
    return (scores.reduce((a, b) => a + b) / scores.length).round();
  }

  /// Highest risk level across all dimensions.
  RiskLevel get highestRiskLevel {
    final levels = [
      organizationRisk.level,
      transactionRisk.level,
      entityRisk.level,
      financialStatementRisk.level,
      documentRisk.level,
    ];
    return levels.reduce((a, b) => b.index > a.index ? b : a);
  }
}

// =============================================================================
// PER-FILE ANALYSIS ENTRY — tracks state of one file in the batch pipeline
// =============================================================================

/// Tracks the full lifecycle of a single file within a batch analysis run.
class FileAnalysisEntry {
  final FileItem file;
  final AnalysisStatus status;
  final List<AnalysisPipelineStage> stages;
  final AnalysisResult? result;
  final String? errorMessage;
  final bool fromCache; // true if result was loaded from Firestore cache
  final bool isStale; // true if cached but hash mismatched (file changed)
  final String? auditedContentHash; // Hash saat file terakhir diaudit

  const FileAnalysisEntry({
    required this.file,
    this.status = AnalysisStatus.idle,
    this.stages = const [],
    this.result,
    this.errorMessage,
    this.fromCache = false,
    this.isStale = false,
    this.auditedContentHash,
  });

  FileAnalysisEntry copyWith({
    FileItem? file,
    AnalysisStatus? status,
    List<AnalysisPipelineStage>? stages,
    AnalysisResult? result,
    String? errorMessage,
    bool? fromCache,
    bool? isStale,
    String? auditedContentHash,
  }) {
    return FileAnalysisEntry(
      file: file ?? this.file,
      status: status ?? this.status,
      stages: stages ?? this.stages,
      result: result ?? this.result,
      errorMessage: errorMessage ?? this.errorMessage,
      fromCache: fromCache ?? this.fromCache,
      isStale: isStale ?? this.isStale,
      auditedContentHash: auditedContentHash ?? this.auditedContentHash,
    );
  }
}

// =============================================================================
// ANALYZE STATE — Riverpod state for the Analyze Screen (batch mode)
// =============================================================================

/// The state managed by Riverpod for the Analyze Screen.
class AnalyzeState {
  /// Per-file entries — one per file in the active workspace.
  final List<FileAnalysisEntry> fileEntries;

  /// Index of the file currently being processed (-1 = none).
  final int currentFileIndex;

  /// Overall batch status.
  final AnalysisStatus status;

  /// Global error message (only used when the batch itself fails to start).
  final String? errorMessage;
  final String workspaceId;

  const AnalyzeState({
    this.fileEntries = const [],
    this.currentFileIndex = -1,
    this.status = AnalysisStatus.idle,
    this.errorMessage,
    required this.workspaceId,
  });

  AnalyzeState copyWith({
    List<FileAnalysisEntry>? fileEntries,
    int? currentFileIndex,
    AnalysisStatus? status,
    String? errorMessage,
    String? workspaceId,
  }) {
    return AnalyzeState(
      fileEntries: fileEntries ?? this.fileEntries,
      currentFileIndex: currentFileIndex ?? this.currentFileIndex,
      status: status ?? this.status,
      errorMessage: errorMessage ?? this.errorMessage,
      workspaceId: workspaceId ?? this.workspaceId,
    );
  }

  // ── Derived helpers ──────────────────────────────────────────────────────

  int get totalFiles => fileEntries.length;

  int get completedCount =>
      fileEntries.where((e) => e.status == AnalysisStatus.completed).length;

  int get errorCount =>
      fileEntries.where((e) => e.status == AnalysisStatus.error).length;

  List<FileAnalysisEntry> get completedEntries =>
      fileEntries.where((e) => e.status == AnalysisStatus.completed).toList();

  /// Average overall score across all completed results (null if none).
  int? get aggregateScore {
    final results =
        completedEntries.map((e) => e.result).whereType<AnalysisResult>();
    if (results.isEmpty) return null;
    final total = results.map((r) => r.overallScore).reduce((a, b) => a + b);
    return (total / results.length).round();
  }

  /// Highest risk level across all completed results.
  RiskLevel? get aggregateRiskLevel {
    final results =
        completedEntries.map((e) => e.result).whereType<AnalysisResult>();
    if (results.isEmpty) return null;
    return results
        .map((r) => r.highestRiskLevel)
        .reduce((a, b) => b.index > a.index ? b : a);
  }

  /// Average Evaluation Metrics across all completed results (null if none).
  AuditEvaluationMetrics? get aggregateEvaluationMetrics {
    final results =
        completedEntries.map((e) => e.result).whereType<AnalysisResult>();
    final resultsWithMetrics =
        results.where((r) => r.evaluationMetrics != null).toList();
    if (resultsWithMetrics.isEmpty) return null;

    double totalEvidence = 0;
    double totalConfidence = 0;
    double totalPrecision = 0;
    int totalFull = 0;
    int totalSemi = 0;
    int totalIncorrect = 0;
    int totalClaimsSum = 0;

    for (final result in resultsWithMetrics) {
      final metrics = result.evaluationMetrics!;
      totalEvidence += metrics.evidenceScore;
      totalConfidence += metrics.confidenceScore;
      totalPrecision += metrics.precisionPercent;
      totalFull += metrics.fullCorrectCount;
      totalSemi += metrics.semiCorrectCount;
      totalIncorrect += metrics.incorrectCount;
      totalClaimsSum += metrics.totalClaims;
    }

    final count = resultsWithMetrics.length;

    return AuditEvaluationMetrics(
      evidenceScore: totalEvidence / count,
      confidenceScore: totalConfidence / count,
      precisionPercent: totalPrecision / count,
      fullCorrectCount:
          totalFull, // we could average or sum, sum makes more sense for raw counts
      semiCorrectCount: totalSemi,
      incorrectCount: totalIncorrect,
      totalClaims: totalClaimsSum,
    );
  }
}

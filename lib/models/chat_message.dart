import 'package:marita/models/message_feedback.dart';

enum MessageRole { user, ai }
enum LoadingRequestType {
  financialStatements,
  invoices,
  receipts,
  contracts,
  annualReport,
  accountingQuestion,
  general,
}

/// Tracks the active stage of the AI pipeline so that [AuditLoadingWidget]
/// can advance its step indicators in sync with actual processing progress.
enum AIPipelinePhase {
  idle,              // No active request
  retrievingContext, // Stage 1 & 2: RAG retrieval
  buildingPrompt,    // Stage 3: build augmented prompt
  generating,        // Stage 4: Gemini stream active
}

enum VersionBadgeType { edited, regenerated, updated, outdated }

enum ConversationStatus { draft, inReview, approved, resolved, archived }

class ChatAttachment {
  final String id;
  final String name;
  final String path;
  final String type; // 'image', 'pdf', 'csv', 'doc'
  final String? url;
  final int? size; // Added size field

  ChatAttachment({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.url,
    this.size,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'url': url,
      'size': size,
    };
  }

  factory ChatAttachment.fromMap(Map<String, dynamic> map) {
    return ChatAttachment(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      type: map['type'] ?? '',
      url: map['url'],
      size: map['size'],
    );
  }

  ChatAttachment copyWith({String? url, int? size}) {
    return ChatAttachment(
      id: id,
      name: name,
      path: path,
      type: type,
      url: url ?? this.url,
      size: size ?? this.size,
    );
  }
}

class ChatMessage {
  final String id;
  final String text;
  final MessageRole role;
  final bool isStreaming;
  final List<ChatAttachment> attachments;
  final DateTime? createdAt;
  final LoadingRequestType? loadingRequestType;

  // Diagnostic fields
  final String? queryType;
  final double? confidenceScore;
  final double? evidenceScore;
  final List<String> citations;
  final List<String> verificationIssues;
  final int? fullCorrectCount;
  final int? semiCorrectCount;
  final int? incorrectCount;
  final double? precisionPercent;
  final int? retrievedChunksCount;
  final List<Map<String, dynamic>> retrievedChunksInfo;

  // Versioning
  final int version;
  final String? parentMessageId;
  final bool isCurrentVersion;
  final String? versionLabel;
  final List<String> allVersionIds;
  final List<String> promptVersionIds;
  final List<String> responseVersionIds;

  // Analysis
  final bool isAnalysisResponse;

  // Feedback
  final FeedbackType? feedbackType;
  final bool feedbackSubmitted;

  // Audit trace
  final String? createdBy;
  final String? updatedAt;

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    this.isStreaming = false,
    this.attachments = const [],
    this.createdAt,
    this.loadingRequestType,
    this.queryType,
    this.confidenceScore,
    this.evidenceScore,
    this.citations = const [],
    this.verificationIssues = const [],
    this.fullCorrectCount,
    this.semiCorrectCount,
    this.incorrectCount,
    this.precisionPercent,
    this.retrievedChunksCount,
    this.retrievedChunksInfo = const [],
    this.version = 1,
    this.parentMessageId,
    this.isCurrentVersion = true,
    this.versionLabel,
    this.allVersionIds = const [],
    this.promptVersionIds = const [],
    this.responseVersionIds = const [],
    this.isAnalysisResponse = false,
    this.feedbackType,
    this.feedbackSubmitted = false,
    this.createdBy,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'role': role.name,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'createdAt':
          createdAt != null
              ? createdAt!.toIso8601String()
              : DateTime.now().toIso8601String(),
      'loadingRequestType': loadingRequestType?.name,
      'queryType': queryType,
      'confidenceScore': confidenceScore,
      'evidenceScore': evidenceScore,
      'citations': citations,
      'verificationIssues': verificationIssues,
      'fullCorrectCount': fullCorrectCount,
      'semiCorrectCount': semiCorrectCount,
      'incorrectCount': incorrectCount,
      'precisionPercent': precisionPercent,
      'retrievedChunksCount': retrievedChunksCount,
      'retrievedChunksInfo': retrievedChunksInfo,
      'version': version,
      'parentMessageId': parentMessageId,
      'isCurrentVersion': isCurrentVersion,
      'versionLabel': versionLabel,
      'allVersionIds': allVersionIds,
      'promptVersionIds': promptVersionIds,
      'responseVersionIds': responseVersionIds,
      'isAnalysisResponse': isAnalysisResponse,
      'feedbackType': feedbackType?.name,
      'feedbackSubmitted': feedbackSubmitted,
      'createdBy': createdBy,
      'updatedAt': updatedAt,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    LoadingRequestType? loadingType;
    if (map['loadingRequestType'] != null) {
      loadingType = LoadingRequestType.values.firstWhere(
        (e) => e.name == map['loadingRequestType'],
        orElse: () => LoadingRequestType.general,
      );
    }

    return ChatMessage(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      role: map['role'] == 'ai' ? MessageRole.ai : MessageRole.user,
      attachments:
          (map['attachments'] as List? ?? [])
              .map((a) => ChatAttachment.fromMap(a as Map<String, dynamic>))
              .toList(),
      createdAt:
          map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
      loadingRequestType: loadingType,
      queryType: map['queryType'] ?? (map['isAnalysisResponse'] == true ? 'analysis' : null),
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble(),
      evidenceScore: (map['evidenceScore'] as num?)?.toDouble(),
      citations: List<String>.from(map['citations'] ?? []),
      verificationIssues: List<String>.from(map['verificationIssues'] ?? []),
      fullCorrectCount: map['fullCorrectCount'] as int?,
      semiCorrectCount: map['semiCorrectCount'] as int?,
      incorrectCount: map['incorrectCount'] as int?,
      precisionPercent: (map['precisionPercent'] as num?)?.toDouble(),
      retrievedChunksCount: map['retrievedChunksCount'] as int?,
      retrievedChunksInfo:
          (map['retrievedChunksInfo'] as List? ?? [])
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList(),
      version: map['version'] ?? 1,
      parentMessageId: map['parentMessageId'],
      isCurrentVersion: map['isCurrentVersion'] ?? true,
      versionLabel: map['versionLabel'],
      allVersionIds: List<String>.from(map['allVersionIds'] ?? []),
      promptVersionIds: List<String>.from(map['promptVersionIds'] ?? []),
      responseVersionIds: List<String>.from(map['responseVersionIds'] ?? []),
      isAnalysisResponse: map['isAnalysisResponse'] ?? false,
      feedbackType: map['feedbackType'] != null
          ? FeedbackType.values.firstWhere(
              (e) => e.name == map['feedbackType'],
              orElse: () => FeedbackType.thumbUp,
            )
          : null,
      feedbackSubmitted: map['feedbackSubmitted'] ?? false,
      createdBy: map['createdBy'],
      updatedAt: map['updatedAt'],
    );
  }

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isStreaming,
    List<ChatAttachment>? attachments,
    DateTime? createdAt,
    LoadingRequestType? loadingRequestType,
    String? queryType,
    double? confidenceScore,
    double? evidenceScore,
    List<String>? citations,
    List<String>? verificationIssues,
    int? fullCorrectCount,
    int? semiCorrectCount,
    int? incorrectCount,
    double? precisionPercent,
    int? retrievedChunksCount,
    List<Map<String, dynamic>>? retrievedChunksInfo,
    int? version,
    String? parentMessageId,
    bool? isCurrentVersion,
    String? versionLabel,
    List<String>? allVersionIds,
    List<String>? promptVersionIds,
    List<String>? responseVersionIds,
    bool? isAnalysisResponse,
    FeedbackType? feedbackType,
    bool? feedbackSubmitted,
    String? createdBy,
    String? updatedAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      role: role,
      isStreaming: isStreaming ?? this.isStreaming,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt ?? this.createdAt,
      loadingRequestType: loadingRequestType ?? this.loadingRequestType,
      queryType: queryType ?? this.queryType,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      evidenceScore: evidenceScore ?? this.evidenceScore,
      citations: citations ?? this.citations,
      verificationIssues: verificationIssues ?? this.verificationIssues,
      fullCorrectCount: fullCorrectCount ?? this.fullCorrectCount,
      semiCorrectCount: semiCorrectCount ?? this.semiCorrectCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      precisionPercent: precisionPercent ?? this.precisionPercent,
      retrievedChunksCount: retrievedChunksCount ?? this.retrievedChunksCount,
      retrievedChunksInfo: retrievedChunksInfo ?? this.retrievedChunksInfo,
      version: version ?? this.version,
      parentMessageId: parentMessageId ?? this.parentMessageId,
      isCurrentVersion: isCurrentVersion ?? this.isCurrentVersion,
      versionLabel: versionLabel ?? this.versionLabel,
      allVersionIds: allVersionIds ?? this.allVersionIds,
      promptVersionIds: promptVersionIds ?? this.promptVersionIds,
      responseVersionIds: responseVersionIds ?? this.responseVersionIds,
      isAnalysisResponse: isAnalysisResponse ?? this.isAnalysisResponse,
      feedbackType: feedbackType ?? this.feedbackType,
      feedbackSubmitted: feedbackSubmitted ?? this.feedbackSubmitted,
      createdBy: createdBy ?? this.createdBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

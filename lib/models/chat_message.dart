enum MessageRole { user, ai }

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

  // Diagnostic fields
  final String? queryType;
  final double? confidenceScore;
  final List<String> citations;
  final List<String> verificationIssues;
  final int? fullCorrectCount;
  final int? semiCorrectCount;
  final int? incorrectCount;
  final double? precisionPercent;
  final int? retrievedChunksCount;
  final List<Map<String, dynamic>> retrievedChunksInfo;

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    this.isStreaming = false,
    this.attachments = const [],
    this.createdAt,
    this.queryType,
    this.confidenceScore,
    this.citations = const [],
    this.verificationIssues = const [],
    this.fullCorrectCount,
    this.semiCorrectCount,
    this.incorrectCount,
    this.precisionPercent,
    this.retrievedChunksCount,
    this.retrievedChunksInfo = const [],
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
      'queryType': queryType,
      'confidenceScore': confidenceScore,
      'citations': citations,
      'verificationIssues': verificationIssues,
      'fullCorrectCount': fullCorrectCount,
      'semiCorrectCount': semiCorrectCount,
      'incorrectCount': incorrectCount,
      'precisionPercent': precisionPercent,
      'retrievedChunksCount': retrievedChunksCount,
      'retrievedChunksInfo': retrievedChunksInfo,
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
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
      queryType: map['queryType'],
      confidenceScore: (map['confidenceScore'] as num?)?.toDouble(),
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
    );
  }

  ChatMessage copyWith({
    String? text,
    bool? isStreaming,
    List<ChatAttachment>? attachments,
    String? queryType,
    double? confidenceScore,
    List<String>? citations,
    List<String>? verificationIssues,
    int? fullCorrectCount,
    int? semiCorrectCount,
    int? incorrectCount,
    double? precisionPercent,
    int? retrievedChunksCount,
    List<Map<String, dynamic>>? retrievedChunksInfo,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      role: role,
      isStreaming: isStreaming ?? this.isStreaming,
      attachments: attachments ?? this.attachments,
      createdAt: createdAt,
      queryType: queryType ?? this.queryType,
      confidenceScore: confidenceScore ?? this.confidenceScore,
      citations: citations ?? this.citations,
      verificationIssues: verificationIssues ?? this.verificationIssues,
      fullCorrectCount: fullCorrectCount ?? this.fullCorrectCount,
      semiCorrectCount: semiCorrectCount ?? this.semiCorrectCount,
      incorrectCount: incorrectCount ?? this.incorrectCount,
      precisionPercent: precisionPercent ?? this.precisionPercent,
      retrievedChunksCount: retrievedChunksCount ?? this.retrievedChunksCount,
      retrievedChunksInfo: retrievedChunksInfo ?? this.retrievedChunksInfo,
    );
  }
}

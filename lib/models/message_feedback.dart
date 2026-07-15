enum FeedbackType { thumbUp, thumbDown }

class MessageFeedback {
  final String feedbackId;
  final String messageId;
  final FeedbackType type;
  final List<String> selectedReasons;
  final String? comment;
  final DateTime createdAt;

  MessageFeedback({
    required this.feedbackId,
    required this.messageId,
    required this.type,
    this.selectedReasons = const [],
    this.comment,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'feedbackId': feedbackId,
      'messageId': messageId,
      'type': type.name,
      'selectedReasons': selectedReasons,
      'comment': comment,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory MessageFeedback.fromMap(Map<String, dynamic> map) {
    return MessageFeedback(
      feedbackId: map['feedbackId'] ?? '',
      messageId: map['messageId'] ?? '',
      type: FeedbackType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => FeedbackType.thumbUp,
      ),
      selectedReasons: List<String>.from(map['selectedReasons'] ?? []),
      comment: map['comment'],
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }
}

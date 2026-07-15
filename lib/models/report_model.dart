enum ReportStatus { generating, ready, outdated, updating, error }

class ReportModel {
  final String reportId;
  final String chatId;
  final String messageId;
  final int responseVersion;
  final int reportVersion;
  final ReportStatus status;
  final String content;
  final DateTime generatedAt;
  final String? shareUrl;

  ReportModel({
    required this.reportId,
    required this.chatId,
    required this.messageId,
    required this.responseVersion,
    required this.reportVersion,
    required this.status,
    required this.content,
    this.shareUrl,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'reportId': reportId,
      'chatId': chatId,
      'messageId': messageId,
      'responseVersion': responseVersion,
      'reportVersion': reportVersion,
      'status': status.name,
      'content': content,
      'shareUrl': shareUrl,
      'generatedAt': generatedAt.toIso8601String(),
    };
  }

  factory ReportModel.fromMap(Map<String, dynamic> map) {
    return ReportModel(
      reportId: map['reportId'] ?? '',
      chatId: map['chatId'] ?? '',
      messageId: map['messageId'] ?? '',
      responseVersion: map['responseVersion'] ?? 1,
      reportVersion: map['reportVersion'] ?? 1,
      status: ReportStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => ReportStatus.error,
      ),
      content: map['content'] ?? '',
      shareUrl: map['shareUrl'],
      generatedAt: map['generatedAt'] != null ? DateTime.parse(map['generatedAt']) : null,
    );
  }
}

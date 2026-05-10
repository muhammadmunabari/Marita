import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

enum MessageRole { user, ai }

class ChatAttachment {
  final String name;
  final String url;
  final String mimeType;

  ChatAttachment({
    required this.name,
    required this.url,
    required this.mimeType,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'url': url,
      'mimeType': mimeType,
    };
  }

  factory ChatAttachment.fromJson(Map<String, dynamic> json) {
    return ChatAttachment(
      name: json['name'] as String? ?? 'Unnamed',
      url: json['url'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? 'application/octet-stream',
    );
  }
}

class ChatMessage {
  final String id;
  final String content;
  final MessageRole role;
  final DateTime timestamp;
  final List<ChatAttachment> attachments;
  final bool isStreaming;
  final bool isError;

  ChatMessage({
    String? id,
    required this.content,
    required this.role,
    DateTime? timestamp,
    this.attachments = const [],
    this.isStreaming = false,
    this.isError = false,
  })  : id = id ?? const Uuid().v4(),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    bool? isError,
  }) {
    return ChatMessage(
      id: id,
      content: content ?? this.content,
      role: role,
      timestamp: timestamp,
      attachments: attachments,
      isStreaming: isStreaming ?? this.isStreaming,
      isError: isError ?? this.isError,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'role': role.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'attachments': attachments.map((a) => a.toJson()).toList(),
      'isStreaming': isStreaming,
      'isError': isError,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String?,
      content: json['content'] as String? ?? '',
      role: MessageRole.values.firstWhere(
        (e) => e.name == json['role'],
        orElse: () => MessageRole.user,
      ),
      timestamp: (json['timestamp'] as Timestamp?)?.toDate(),
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) => ChatAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      isStreaming: json['isStreaming'] as bool? ?? false,
      isError: json['isError'] as bool? ?? false,
    );
  }
}

class ChatProject {
  final String id;
  final String title;
  final DateTime updatedAt;

  ChatProject({
    String? id,
    required this.title,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(),
        updatedAt = updatedAt ?? DateTime.now();

  ChatProject copyWith({
    String? title,
    DateTime? updatedAt,
  }) {
    return ChatProject(
      id: id,
      title: title ?? this.title,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ChatProject.fromJson(Map<String, dynamic> json) {
    return ChatProject(
      id: json['id'] as String?,
      title: json['title'] as String? ?? 'Untitled Project',
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}

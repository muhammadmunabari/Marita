enum MessageRole { user, ai }

class ChatAttachment {
  final String id;
  final String name;
  final String path;
  final String type; // 'image', 'pdf', 'csv', 'doc'
  final String? url;

  ChatAttachment({
    required this.id,
    required this.name,
    required this.path,
    required this.type,
    this.url,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'url': url,
    };
  }

  factory ChatAttachment.fromMap(Map<String, dynamic> map) {
    return ChatAttachment(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      path: map['path'] ?? '',
      type: map['type'] ?? '',
      url: map['url'],
    );
  }

  ChatAttachment copyWith({
    String? url,
  }) {
    return ChatAttachment(
      id: id,
      name: name,
      path: path,
      type: type,
      url: url ?? this.url,
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

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    this.isStreaming = false,
    this.attachments = const [],
    this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'role': role.name,
      'attachments': attachments.map((a) => a.toMap()).toList(),
      'createdAt': createdAt != null ? createdAt!.toIso8601String() : DateTime.now().toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id: map['id'] ?? '',
      text: map['text'] ?? '',
      role: map['role'] == 'ai' ? MessageRole.ai : MessageRole.user,
      attachments: (map['attachments'] as List? ?? [])
          .map((a) => ChatAttachment.fromMap(a as Map<String, dynamic>))
          .toList(),
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : null,
    );
  }

  ChatMessage copyWith({
    String? text,
    bool? isStreaming,
    List<ChatAttachment>? attachments,
  }) {
    return ChatMessage(
      id: id,
      text: text ?? this.text,
      role: role,
      isStreaming: isStreaming ?? this.isStreaming,
      attachments: attachments ?? this.attachments,
    );
  }
}


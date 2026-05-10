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

  ChatMessage({
    required this.id,
    required this.text,
    required this.role,
    this.isStreaming = false,
    this.attachments = const [],
  });

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


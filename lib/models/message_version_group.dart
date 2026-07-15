import 'chat_message.dart';

class MessageVersionGroup {
  final String groupId;
  final List<ChatMessage> promptVersions;
  final List<ChatMessage> responseVersions;
  final int activePromptIndex;
  final int activeResponseIndex;

  MessageVersionGroup({
    required this.groupId,
    required this.promptVersions,
    required this.responseVersions,
    this.activePromptIndex = 0,
    this.activeResponseIndex = 0,
  });

  ChatMessage get activePrompt => promptVersions[activePromptIndex];
  ChatMessage? get activeResponse => responseVersions.isNotEmpty ? responseVersions[activeResponseIndex] : null;
  bool get hasMultiplePrompts => promptVersions.length > 1;
  bool get hasMultipleResponses => responseVersions.length > 1;

  MessageVersionGroup copyWith({
    String? groupId,
    List<ChatMessage>? promptVersions,
    List<ChatMessage>? responseVersions,
    int? activePromptIndex,
    int? activeResponseIndex,
  }) {
    return MessageVersionGroup(
      groupId: groupId ?? this.groupId,
      promptVersions: promptVersions ?? this.promptVersions,
      responseVersions: responseVersions ?? this.responseVersions,
      activePromptIndex: activePromptIndex ?? this.activePromptIndex,
      activeResponseIndex: activeResponseIndex ?? this.activeResponseIndex,
    );
  }
}

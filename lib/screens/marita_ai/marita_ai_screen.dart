import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import 'package:marita/models/chat_message.dart';
import 'package:marita/models/prompt_template.dart';
import 'package:marita/services/attachment_service.dart';
import 'package:marita/services/export_service.dart';
import 'package:marita/services/template_service.dart';
import 'package:marita/services/gemini_service.dart';
import 'package:marita/providers/auth_provider.dart';
import 'package:marita/providers/template_provider.dart';
import 'package:marita/providers/report_provider.dart';
import 'package:uuid/uuid.dart';

// =============================================================================
// STATE & NOTIFIER
class ChatState {
  final String? chatId;
  final String? title;
  final List<ChatMessage> messages;
  final bool isLoading;

  ChatState({this.chatId, this.title, this.messages = const [], this.isLoading = false});

  ChatState copyWith({String? chatId, String? title, List<ChatMessage>? messages, bool? isLoading}) {
    return ChatState(
      chatId: chatId ?? this.chatId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class ChatNotifier extends Notifier<ChatState> {
  @override
  ChatState build() => ChatState();

  void createNewChat() {
    state = ChatState();
  }

  void loadChat(String chatId, String? title, List<ChatMessage> messages) {
    state = ChatState(chatId: chatId, title: title, messages: messages);
  }

  void updateTitle(String newTitle) {
    state = state.copyWith(title: newTitle);
  }

  void sendMessage(String text, {List<ChatAttachment>? attachments}) async {
    final user = ref.read(currentUserProvider);
    final userId = user?.uid ?? 'anonymous';
    final firestoreService = ref.read(firestoreServiceProvider);

    // 1. Initial message with local paths
    final tempId = const Uuid().v4();
    final userMsg = ChatMessage(
      id: tempId,
      text: text,
      role: MessageRole.user,
      attachments: attachments ?? const [],
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, userMsg]);

    // 2. Prepare AI message
    final aiId = '${const Uuid().v4()}_ai';
    final aiMsg = ChatMessage(
      id: aiId,
      text: '',
      role: MessageRole.ai,
      isStreaming: true,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, aiMsg]);

    // 3. Ensure chatId exists
    String? currentChatId = state.chatId;
    if (currentChatId == null && user != null) {
      String generateTitle(String content) {
        final cleanContent = content.replaceAll('\n', ' ').trim();
        final words = cleanContent.split(RegExp(r'\s+'));
        final limitedWords = words.take(4).join(' ');
        if (limitedWords.length > 25) {
          return '${limitedWords.substring(0, 25)}...';
        } else if (words.length > 4) {
          return '$limitedWords...';
        }
        return limitedWords.isEmpty ? 'New chat' : limitedWords;
      }
      final newTitle = generateTitle(text);

      currentChatId = await firestoreService.createChat(
        userId: user.uid,
        initialMessage: text,
        title: newTitle, // Auto-generate title
      );
      state = state.copyWith(chatId: currentChatId, title: newTitle);
      // Invalidate history provider to show new chat in sidebar
      ref.invalidate(chatHistoryProvider);
    }

    // 4. Upload attachments if any
    List<ChatAttachment> uploadedAttachments = attachments ?? [];
    if (attachments != null && attachments.isNotEmpty) {
      List<ChatAttachment> results = [];
      for (var attachment in attachments) {
        final url = await AttachmentService.uploadAttachment(attachment, userId);
        if (url != null) {
          results.add(attachment.copyWith(url: url));
        } else {
          results.add(attachment);
        }
      }
      uploadedAttachments = results;
      
      // Update user message with uploaded URLs
      state = state.copyWith(
        messages: [
          for (final msg in state.messages)
            if (msg.id == tempId) msg.copyWith(attachments: uploadedAttachments) else msg,
        ],
      );
    }

    // 5. Save user message to Firestore
    if (currentChatId != null) {
      final userMsgToSave = state.messages.firstWhere((m) => m.id == tempId);
      await firestoreService.addChatMessage(
        chatId: currentChatId,
        messageMap: userMsgToSave.toMap(),
      );
    }

    // 6. Actual Gemini Stream
    await _processGeminiStream(aiId, text, uploadedAttachments, currentChatId);
  }

  void regenerateMessage(ChatMessage aiMessage) async {
    final index = state.messages.indexOf(aiMessage);
    if (index <= 0) return;
    
    final userMessage = state.messages[index - 1];
    if (userMessage.role != MessageRole.user) return;

    // Remove the old AI message and any subsequent messages
    state = state.copyWith(messages: state.messages.sublist(0, index));

    // Prepare new AI message
    final aiId = '${const Uuid().v4()}_ai';
    final aiMsg = ChatMessage(
      id: aiId,
      text: '',
      role: MessageRole.ai,
      isStreaming: true,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, aiMsg]);

    // Re-trigger Gemini using the same content
    await _processGeminiStream(aiId, userMessage.text, userMessage.attachments, state.chatId);
  }

  Future<void> _processGeminiStream(String aiId, String text, List<ChatAttachment> attachments, String? chatId) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    try {
      var historyList = state.messages
          .where((m) => m.id != aiId && !m.isStreaming) // Don't include current or other streaming messages in history
          .toList();
          
      // Exclude the very last user message because it's passed as the `text` (prompt)
      if (historyList.isNotEmpty && historyList.last.role == MessageRole.user && historyList.last.text == text) {
        historyList = historyList.sublist(0, historyList.length - 1);
      }

      final stream = GeminiService.sendMessageStream(
        text,
        attachments: attachments,
        history: historyList,
      );

      String fullText = "";
      await for (final chunk in stream) {
        fullText += chunk;
        state = state.copyWith(
          messages: [
            for (final msg in state.messages)
              if (msg.id == aiId) msg.copyWith(text: fullText) else msg,
          ],
        );
      }

      // Mark streaming as finished
      final finalAiMsg = ChatMessage(
        id: aiId,
        text: fullText,
        role: MessageRole.ai,
        isStreaming: false,
        createdAt: DateTime.now(),
      );
      
      state = state.copyWith(
        messages: [
          for (final msg in state.messages)
            if (msg.id == aiId) finalAiMsg else msg,
        ],
      );

      // Save AI message to Firestore
      if (chatId != null) {
        await firestoreService.addChatMessage(
          chatId: chatId,
          messageMap: finalAiMsg.toMap(),
        );
        // Refresh history to update last message/timestamp
        ref.invalidate(chatHistoryProvider);
      }
    } catch (e) {
      final errorMsg = ChatMessage(
        id: aiId,
        text: "Sorry, I encountered an error: $e",
        role: MessageRole.ai,
        isStreaming: false,
        createdAt: DateTime.now(),
      );
      state = state.copyWith(
        messages: [
          for (final msg in state.messages)
            if (msg.id == aiId) errorMsg else msg,
        ],
      );
      
      if (chatId != null) {
        await firestoreService.addChatMessage(
          chatId: chatId,
          messageMap: errorMsg.toMap(),
        );
      }
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(ChatNotifier.new);

final chatHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUserChats(user.uid);
});

// =============================================================================
// SCREEN COMPONENT
// =============================================================================

class MaritaAIScreen extends ConsumerStatefulWidget {
  const MaritaAIScreen({super.key});

  @override
  ConsumerState<MaritaAIScreen> createState() => _MaritaAIScreenState();
}

class _MaritaAIScreenState extends ConsumerState<MaritaAIScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.hasClients) {
        final isNearBottom =
            _scrollController.position.maxScrollExtent -
                _scrollController.position.pixels <=
            100;
        if (!isNearBottom && !_showScrollToBottom) {
          setState(() => _showScrollToBottom = true);
        } else if (isNearBottom && _showScrollToBottom) {
          setState(() => _showScrollToBottom = false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final chatState = ref.watch(chatProvider);
    final messages = chatState.messages;

    // Auto-scroll when new messages arrive if already at bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_showScrollToBottom && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.backgroundPrimary,
      drawer: const _MaritaSidebarDrawer(),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNav(context, chatState),
            Expanded(
              child: Stack(
                children: [
                  if (messages.isEmpty) _buildWatermark(context),
                  _buildConversationArea(context, messages),
                  if (_showScrollToBottom)
                    Positioned(
                      right: MaritaSpacing.xl,
                      bottom: 80, // Above input
                      child: FloatingActionButton(
                        mini: true,
                        backgroundColor: colors.backgroundSecondary,
                        foregroundColor: colors.contentPrimary,
                        elevation: 4,
                        onPressed: _scrollToBottom,
                        shape: const CircleBorder(),
                        child: const MaritaIcon(icon: MaritaIcons.arrowDown),
                      ),
                    ),
                  Positioned(
                    left: MaritaSpacing.xl,
                    right: MaritaSpacing.xl,
                    bottom: MaritaSpacing.lg,
                    child: _MaritaAIInputArea(
                      onSend: (text, attachments) {
                        ref.read(chatProvider.notifier).sendMessage(text, attachments: attachments);
                        _scrollToBottom();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopNav(BuildContext context, ChatState chatState) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MaritaSpacing.xl,
        vertical: MaritaSpacing.md,
      ),
      color: Colors.transparent, // Minimal, transparent background
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _MaritaIconButton(
            iconPath: 'assets/icons/iconsax-menu.svg',
            iconData: IconsaxPlusLinear.menu,
            onTap: () {
              _scaffoldKey.currentState?.openDrawer();
            },
          ),
          Expanded(
            child: Center(
              child: _DynamicTitle(title: chatState.title ?? 'New chat'),
            ),
          ),
          const SizedBox(width: 40), // Balance the menu button for centered title
        ],
      ),
    );
  }

  Widget _buildWatermark(BuildContext context) {
    return Center(
      child: Opacity(
        opacity: 0.03, // Very faint
        child: Image.asset(
          'assets/logos/Logomark white.png',
          width: 120,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildConversationArea(
    BuildContext context,
    List<ChatMessage> messages,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(
        left: MaritaSpacing.xl,
        right: MaritaSpacing.xl,
        top: MaritaSpacing.xl,
        bottom: 120, // Space for the floating input area
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _MessageBubble(message: msg);
      },
    );
  }
}

// =============================================================================
// SUB-COMPONENTS
// =============================================================================

class _DynamicTitle extends StatefulWidget {
  final String title;
  const _DynamicTitle({required this.title});

  @override
  State<_DynamicTitle> createState() => _DynamicTitleState();
}

class _DynamicTitleState extends State<_DynamicTitle>
    with SingleTickerProviderStateMixin {
  late String _title;
  String _displayedTitle = "";
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animateTitle();
  }

  @override
  void didUpdateWidget(covariant _DynamicTitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.title != oldWidget.title) {
      _title = widget.title;
      _animateTitle();
    }
  }

  void _animateTitle() async {
    _controller.reset();
    for (int i = 0; i <= _title.length; i++) {
      if (!mounted) return;
      setState(() {
        _displayedTitle = _title.substring(0, i);
      });
      await Future.delayed(const Duration(milliseconds: 30));
    }
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.maritaTypography;
    final colors = context.maritaColors;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.5, end: 1.0).animate(_controller),
      child: Text(
        _displayedTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: typography.bodyLargeBold.copyWith(color: colors.contentPrimary),
      ),
    );
  }
}

class _MaritaSidebarDrawer extends ConsumerWidget {
  const _MaritaSidebarDrawer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;
    final historyAsync = ref.watch(chatHistoryProvider);
    final currentChatId = ref.watch(chatProvider).chatId;

    return Drawer(
      backgroundColor: colors.backgroundPrimary,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: MaritaSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'History',
                      style: typography.titleMedium.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    IconButton(
                      icon: const MaritaIcon(icon: IconsaxPlusLinear.add, size: MaritaIconSize.small),
                      onPressed: () {
                        ref.read(chatProvider.notifier).createNewChat();
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: MaritaSpacing.lg),
              Expanded(
                child: historyAsync.when(
                  data: (chats) {
                    if (chats.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(MaritaSpacing.xl),
                        child: Text(
                          'No recent chats.',
                          style: typography.bodyDefault.copyWith(
                            color: colors.contentTertiary,
                          ),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: chats.length,
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final id = chat['id'] as String;
                        final title = chat['title'] as String?;
                        final lastMsg = chat['lastMessage'] as String? ?? '';
                        final displayTitle = title?.isNotEmpty == true ? title! : (lastMsg.isNotEmpty ? lastMsg : 'New chat');
                        final isSelected = id == currentChatId;

                        String dateText = '';
                        if (chat['updatedAt'] != null) {
                          try {
                            DateTime date = (chat['updatedAt'] as Timestamp).toDate();
                            dateText = DateFormat('dd MMM yyyy, HH:mm').format(date);
                          } catch (e) {
                            // Fallback if parsing fails
                          }
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: MaritaSpacing.xl,
                            vertical: MaritaSpacing.xs,
                          ),
                          title: Text(
                            displayTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.bodyDefault.copyWith(
                              color: isSelected ? colors.interactivePrimary : colors.contentPrimary,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          subtitle: dateText.isNotEmpty ? Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              dateText,
                              style: typography.bodyDefault.copyWith(
                                color: colors.contentTertiary,
                                fontSize: 11,
                              ),
                            ),
                          ) : null,
                          onTap: () {
                            final messagesList = (chat['messages'] as List? ?? [])
                                .map((m) => ChatMessage.fromMap(m as Map<String, dynamic>))
                                .toList();
                            ref.read(chatProvider.notifier).loadChat(id, displayTitle, messagesList);
                            Navigator.pop(context);
                          },
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: MaritaIcon(
                                  icon: IconsaxPlusLinear.edit_2,
                                  size: MaritaIconSize.small,
                                  color: colors.contentTertiary,
                                ),
                                onPressed: () {
                                  _showRenameDialog(context, ref, id, displayTitle);
                                },
                              ),
                              IconButton(
                                icon: MaritaIcon(
                                  icon: IconsaxPlusLinear.trash,
                                  size: MaritaIconSize.small,
                                  color: colors.contentTertiary,
                                ),
                                onPressed: () async {
                                  await ref.read(firestoreServiceProvider).deleteChat(id);
                                  ref.invalidate(chatHistoryProvider);
                                  if (isSelected) {
                                    ref.read(chatProvider.notifier).createNewChat();
                                  }
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, st) => Center(child: Text('Error loading history: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(BuildContext context, WidgetRef ref, String chatId, String currentTitle) {
    final controller = TextEditingController(text: currentTitle);
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text('Rename Chat', style: typography.titleMedium.copyWith(color: colors.contentPrimary)),
          content: TextField(
            controller: controller,
            style: typography.bodyLarge.copyWith(color: colors.contentPrimary),
            decoration: InputDecoration(
              hintText: 'Enter new title',
              hintStyle: typography.bodyLarge.copyWith(color: colors.contentTertiary),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.borderPrimary),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: colors.interactivePrimary),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: typography.bodyDefault.copyWith(color: colors.contentSecondary)),
            ),
            TextButton(
              onPressed: () async {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty && newTitle != currentTitle) {
                  await ref.read(firestoreServiceProvider).updateChatTitle(chatId, newTitle);
                  ref.invalidate(chatHistoryProvider);
                  if (ref.read(chatProvider).chatId == chatId) {
                    ref.read(chatProvider.notifier).updateTitle(newTitle);
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text('Save', style: typography.bodyDefault.copyWith(color: colors.interactivePrimary)),
            ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends ConsumerWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isUser = message.role == MessageRole.user;
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Padding(
      padding: const EdgeInsets.only(bottom: MaritaSpacing.xl),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment:
                isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.88,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: MaritaSpacing.lg,
                    vertical: MaritaSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isUser
                            ? colors.interactivePrimary.withValues(alpha: 0.1)
                            : Colors
                                .transparent, // AI bubble transparent/minimal
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight:
                          isUser
                              ? const Radius.circular(0)
                              : const Radius.circular(16),
                      bottomLeft:
                          !isUser
                              ? const Radius.circular(0)
                              : const Radius.circular(16),
                    ),
                    border:
                        !isUser
                            ? Border.all(color: colors.borderPrimary)
                            : null,
                  ),
                                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (message.attachments.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: MaritaSpacing.md),
                          child: Wrap(
                            spacing: MaritaSpacing.sm,
                            runSpacing: MaritaSpacing.sm,
                            children: message.attachments.map((attachment) {
                              return _AttachmentPreviewBubble(attachment: attachment);
                            }).toList(),
                          ),
                        ),
                      isUser
                          ? Text(
                            message.text,
                            style: typography.bodyLarge.copyWith(
                              color: colors.contentPrimary,
                            ),
                          )
                          : MarkdownBody(
                            data:
                                message.text.isEmpty && message.isStreaming
                                    ? "..."
                                    : message.text,
                            styleSheet: MarkdownStyleSheet(
                              p: typography.bodyLarge.copyWith(
                                color: colors.contentPrimary,
                              ),
                              code: typography.bodyDefault.copyWith(
                                fontFamily: 'monospace',
                                backgroundColor: colors.backgroundSecondary,
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: colors.backgroundSecondary,
                                borderRadius: MaritaRadius.borderMedium,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (!isUser && !message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: MaritaSpacing.sm),
              child: Row(
                children: [
                  _AIActionIcon(
                    icon: IconsaxPlusLinear.copy,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                  const SizedBox(width: MaritaSpacing.md),
                  _AIActionIcon(
                    icon: IconsaxPlusLinear.refresh,
                    onTap: () {
                      ref.read(chatProvider.notifier).regenerateMessage(message);
                    },
                  ),
                  const SizedBox(width: MaritaSpacing.md),
                  _AIActionIcon(
                    icon: IconsaxPlusLinear.export,
                    onTap: () {
                      _showExportBottomSheet(context, ref);
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showExportBottomSheet(BuildContext context, WidgetRef ref) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(MaritaSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Response',
                  style: typography.titleMedium.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                const SizedBox(height: MaritaSpacing.xl),
                ListTile(
                  leading: const MaritaIcon(
                    icon: IconsaxPlusLinear.document_text,
                  ),
                  title: Text(
                    'Export message as PDF',
                    style: typography.bodyLarge,
                  ),
                  subtitle: Text(
                    'Best for sharing analysis',
                    style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ExportService.exportMessageToPdf(message.text);
                  },
                ),
                ListTile(
                  leading: const MaritaIcon(icon: IconsaxPlusLinear.document),
                  title: Text(
                    'Export full chat as CSV',
                    style: typography.bodyLarge,
                  ),
                  subtitle: Text(
                    'Best for spreadsheet records',
                    style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    final chatState = ref.read(chatProvider);
                    ExportService.exportChatToCsv(chatState.messages);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AIActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _AIActionIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: MaritaIcon(
        icon: icon,
        size: MaritaIconSize.small,
        color: context.maritaColors.contentSecondary,
      ),
    );
  }
}

class _MaritaAIInputArea extends ConsumerStatefulWidget {
  final Function(String, List<ChatAttachment>) onSend;
  const _MaritaAIInputArea({required this.onSend});

  @override
  ConsumerState<_MaritaAIInputArea> createState() => _MaritaAIInputAreaState();
}

class _MaritaAIInputAreaState extends ConsumerState<_MaritaAIInputArea> {
  late final TextEditingController _controller;
  bool _isMultiLine = false;
  final GlobalKey _plusButtonKey = GlobalKey();
  List<ChatAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _controller.addListener(_updateState);
  }

  void _updateState() {
    final text = _controller.text;
    final isMultiLine = text.contains('\n') || text.length > 35 || _attachments.isNotEmpty;
    if (isMultiLine != _isMultiLine) {
      setState(() {
        _isMultiLine = isMultiLine;
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleUpload() async {
    final files = await AttachmentService.pickFiles();
    if (files.isNotEmpty) {
      setState(() {
        _attachments = [..._attachments, ...files];
        _updateState();
      });
    }
  }

  void _handleTakePhoto() async {
    final photo = await AttachmentService.takePhoto();
    if (photo != null) {
      setState(() {
        _attachments = [..._attachments, photo];
        _updateState();
      });
    }
  }

  void _showTemplatesSheet() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _TemplatesSheet(),
    );
    if (result != null) {
      if (result == 'trigger_custom') {
        _showCustomTemplateDialog();
      } else {
        setState(() {
          _controller.text = result;
          _updateState();
        });
      }
    }
  }


  void _showPlusMenu() async {
    final RenderBox renderBox =
        _plusButtonKey.currentContext!.findRenderObject() as RenderBox;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    await showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx,
        offset.dy - 220, // Increased height for more items
        MediaQuery.of(context).size.width - offset.dx - size.width,
        MediaQuery.of(context).size.height - offset.dy,
      ),
      color: colors.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderMedium),
      items: [
        PopupMenuItem(
          value: 'camera',
          child: Row(
            children: [
              MaritaIcon(icon: MaritaIcons.camera, size: MaritaIconSize.small),
              const SizedBox(width: MaritaSpacing.md),
              Text('Take Photo', style: typography.bodyDefault),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'upload',
          child: Row(
            children: [
              MaritaIcon(icon: MaritaIcons.upload, size: MaritaIconSize.small),
              const SizedBox(width: MaritaSpacing.md),
              Text('Upload Files', style: typography.bodyDefault),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'templates',
          child: Row(
            children: [
              MaritaIcon(
                icon: IconsaxPlusLinear.document_text,
                size: MaritaIconSize.small,
              ),
              const SizedBox(width: MaritaSpacing.md),
              Text('Prompt Templates', style: typography.bodyDefault),
            ],
          ),
        ),
      ],
    ).then((value) {
      if (value == 'camera') {
        _handleTakePhoto();
      } else if (value == 'upload') {
        _handleUpload();
      } else if (value == 'templates') {
        _showTemplatesSheet();
      }
    });
  }

  void _showCustomTemplateDialog() async {
    final result = await showDialog<PromptTemplate>(
      context: context,
      builder: (context) => const _CreateTemplateDialog(),
    );
    if (result != null) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        // Save to Firestore
        await TemplateService.saveCustomTemplate(user.uid, result);
        // Refresh templates
        ref.invalidate(customTemplatesProvider);
      }
      _controller.text = result.prompt;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.fastOutSlowIn,
      padding: EdgeInsets.symmetric(
        horizontal: MaritaSpacing.md,
        vertical: _isMultiLine ? MaritaSpacing.md : MaritaSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(_isMultiLine ? 16 : 32),
        border: Border.all(color: colors.borderPrimary, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_attachments.isNotEmpty)
            Container(
              height: 80,
              margin: const EdgeInsets.only(bottom: MaritaSpacing.md),
              child: Stack(
                children: [
                  ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(right: 48),
                    itemCount: _attachments.length,
                    itemBuilder: (context, index) {
                      final attachment = _attachments[index];
                      final isImage = attachment.type == 'image';
                      final extension = attachment.name.split('.').last.toUpperCase();
                      
                      return Container(
                        width: 130,
                        margin: const EdgeInsets.only(right: MaritaSpacing.sm),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: MaritaRadius.borderMedium,
                          border: Border.all(color: colors.borderPrimary),
                          boxShadow: [
                            BoxShadow(
                              color: colors.contentPrimary.withValues(alpha: 0.04),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: MaritaRadius.borderMedium,
                          child: Stack(
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 56,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: colors.backgroundSecondary,
                                      border: Border(
                                        right: BorderSide(color: colors.borderPrimary),
                                      ),
                                    ),
                                    child: isImage
                                        ? Image.file(
                                            File(attachment.path),
                                            fit: BoxFit.cover,
                                          )
                                        : Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                MaritaIcon(
                                                  icon: _getAttachmentIcon(attachment.type),
                                                  size: MaritaIconSize.small,
                                                  color: colors.interactivePrimary,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  extension,
                                                  style: typography.bodySmallBold.copyWith(
                                                    fontSize: 8,
                                                    color: colors.contentTertiary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(MaritaSpacing.xs),
                                      child: Text(
                                        attachment.name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: typography.bodySmall.copyWith(
                                          fontSize: 10,
                                          height: 1.2,
                                          color: colors.contentPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Positioned(
                                top: 2,
                                right: 2,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _attachments.removeAt(index);
                                      _updateState();
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: colors.backgroundInverse.withValues(alpha: 0.8),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      Icons.close,
                                      size: 10,
                                      color: colors.backgroundPrimary,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (_attachments.length > 2)
                    Positioned(
                      right: -4,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 56,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              colors.backgroundSecondary.withValues(alpha: 0),
                              colors.backgroundSecondary.withValues(alpha: 0.9),
                              colors.backgroundSecondary,
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.only(left: 12),
                            decoration: BoxDecoration(
                              color: colors.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              icon: Icon(Icons.delete_sweep_rounded, color: colors.error, size: 20),
                              onPressed: () {
                                setState(() {
                                  _attachments = [];
                                  _updateState();
                                });
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _MaritaIconButton(
                key: _plusButtonKey,
                iconPath: 'assets/icons/iconsax-add.svg',
                iconData: MaritaIcons.add,
                onTap: _showPlusMenu,
              ),
              const SizedBox(width: MaritaSpacing.sm),
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 5,
                  keyboardType: TextInputType.multiline,
                  textAlignVertical: TextAlignVertical.center,
                  style: typography.bodyLarge.copyWith(
                    color: colors.contentPrimary,
                    height: 1.0, // Match font size exactly (16px)
                  ),
                  cursorColor: colors.interactivePrimary,
                  decoration: InputDecoration(
                    isCollapsed: true, // Remove all default internal padding
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8), // (32px container - 16px text) / 2 = 8px
                    hintText: 'Ask Marita...',
                    hintStyle: typography.bodyLarge.copyWith(
                      color: colors.contentTertiary,
                      height: 1.0,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                  ),
                ),
              ),
              const SizedBox(width: MaritaSpacing.sm),
              _MaritaIconButton(
                iconPath: 'assets/icons/iconsax-send.svg',
                iconData: IconsaxPlusLinear.send_1,
                onTap: () {
                  if (_controller.text.trim().isEmpty && _attachments.isEmpty) return;
                  widget.onSend(_controller.text, _attachments);
                  _controller.clear();
                  setState(() {
                    _attachments = [];
                    _updateState();
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getAttachmentIcon(String type) {
    switch (type) {
      case 'pdf':
        return IconsaxPlusLinear.document_text;
      case 'image':
        return IconsaxPlusLinear.gallery;
      case 'csv':
      case 'xls':
      case 'text':
      case 'json':
      case 'sql':
      case 'md':
      case 'xml':
        return IconsaxPlusLinear.document;
      default:
        return IconsaxPlusLinear.document_cloud;
    }
  }
}

class _MaritaIconButton extends StatefulWidget {
  final String iconPath;
  final IconData iconData;
  final VoidCallback onTap;

  const _MaritaIconButton({
    super.key,
    required this.iconPath,
    required this.iconData,
    required this.onTap,
  });

  @override
  State<_MaritaIconButton> createState() => _MaritaIconButtonState();
}

class _MaritaIconButtonState extends State<_MaritaIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) {
        _controller.reverse();
        widget.onTap();
      },
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.all(MaritaSpacing.xs),
          color: Colors.transparent, // Increase hit area
          child: MaritaIcon(
            icon: widget.iconData,
            size: MaritaIconSize.medium,
            color: colors.contentPrimary,
          ),
        ),
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  final PromptTemplate template;
  final VoidCallback onTap;

  const _TemplateCard({required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return InkWell(
      onTap: onTap,
      borderRadius: MaritaRadius.borderMedium,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(MaritaSpacing.md),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: MaritaRadius.borderMedium,
          border: Border.all(color: colors.borderPrimary),
          boxShadow: [
            BoxShadow(
              color: colors.contentPrimary.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(MaritaSpacing.sm),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: MaritaRadius.borderSmall,
                    border: Border.all(color: colors.borderPrimary.withValues(alpha: 0.5)),
                  ),
                  child: MaritaIcon(
                    icon: template.icon,
                    size: MaritaIconSize.small,
                    color: colors.interactivePrimary,
                  ),
                ),
                if (template.isCustom)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colors.interactivePrimary.withValues(alpha: 0.1),
                      borderRadius: MaritaRadius.borderSmall,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.person, size: 10, color: colors.interactivePrimary),
                        const SizedBox(width: 2),
                        Text(
                          'YOU',
                          style: typography.bodySmallBold.copyWith(
                            fontSize: 8,
                            color: colors.interactivePrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: MaritaSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodyDefaultBold.copyWith(
                    color: colors.contentPrimary,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  template.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySmall.copyWith(
                    color: colors.contentSecondary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TemplatesSheet extends ConsumerStatefulWidget {
  const _TemplatesSheet();

  @override
  ConsumerState<_TemplatesSheet> createState() => _TemplatesSheetState();
}

class _TemplatesSheetState extends ConsumerState<_TemplatesSheet> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _createNewTemplate(BuildContext context) async {
    final template = await showDialog<PromptTemplate>(
      context: context,
      builder: (context) => const _CreateTemplateDialog(),
    );

    if (template != null) {
      final userId = ref.read(currentUserProvider)?.uid ?? 'anonymous';
      await TemplateService.saveCustomTemplate(userId, template);
      ref.invalidate(customTemplatesProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final allTemplates = ref.watch(allTemplatesProvider);
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final staticTemplates = allTemplates.where((t) {
      final query = _searchQuery.toLowerCase();
      return t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.fromLTRB(
        MaritaSpacing.xl,
        MaritaSpacing.xl,
        MaritaSpacing.xl,
        0,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colors.borderPrimary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: MaritaSpacing.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Prompt Templates',
                    style: typography.titleMedium.copyWith(color: colors.contentPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyze your data faster with pre-built prompts.',
                    style: typography.bodySmall.copyWith(color: colors.contentSecondary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: MaritaSpacing.xl),
          // Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.md),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: MaritaRadius.borderMedium,
              border: Border.all(color: colors.borderPrimary),
            ),
            child: Row(
              children: [
                Icon(IconsaxPlusLinear.search_normal_1, 
                     size: 18, color: colors.contentTertiary),
                const SizedBox(width: MaritaSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: typography.bodyDefault,
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      hintStyle: typography.bodyDefault.copyWith(color: colors.contentTertiary),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close, size: 18, color: colors.contentTertiary),
                  ),
              ],
            ),
          ),
          const SizedBox(height: MaritaSpacing.xl),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: MaritaSpacing.xxl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (staticTemplates.any((t) => !t.isCustom)) ...[
                    _buildSectionTitle(context, 'Pre-built Templates'),
                    const SizedBox(height: MaritaSpacing.md),
                    _buildGrid(context, staticTemplates.where((t) => !t.isCustom).toList()),
                    const SizedBox(height: MaritaSpacing.xl),
                  ],
                  if (staticTemplates.any((t) => t.isCustom)) ...[
                    _buildSectionTitle(context, 'Your Templates'),
                    const SizedBox(height: MaritaSpacing.md),
                    _buildGrid(context, staticTemplates.where((t) => t.isCustom).toList()),
                  ],
                  if (staticTemplates.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MaritaSpacing.xxl),
                        child: Column(
                          children: [
                            Icon(IconsaxPlusLinear.search_status, 
                                 size: 48, color: colors.contentTertiary),
                            const SizedBox(height: MaritaSpacing.md),
                            Text(
                              'No templates found for "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: context.maritaTypography.bodySmallBold.copyWith(
        color: context.maritaColors.contentTertiary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildGrid(BuildContext context, List<PromptTemplate> templates) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: MaritaSpacing.md,
        mainAxisSpacing: MaritaSpacing.md,
        childAspectRatio: 1.25,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _TemplateCard(
          template: template,
          onTap: () {
            Navigator.pop(context, template.prompt);
          },
        );
      },
    );
  }
}

class _AttachmentPreviewBubble extends StatelessWidget {
  final ChatAttachment attachment;

  const _AttachmentPreviewBubble({required this.attachment});

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: MaritaRadius.borderSmall,
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MaritaIcon(
            icon: _getIconForType(attachment.type),
            size: MaritaIconSize.small,
            color: colors.interactivePrimary,
          ),
          const SizedBox(width: 8),
          Text(
            attachment.name,
            style: typography.bodySmall.copyWith(color: colors.contentPrimary),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'pdf':
        return IconsaxPlusLinear.document_text;
      case 'image':
        return IconsaxPlusLinear.gallery;
      case 'csv':
      case 'xls':
      case 'text':
      case 'json':
      case 'sql':
      case 'md':
      case 'xml':
        return IconsaxPlusLinear.document;
      default:
        return IconsaxPlusLinear.document_cloud;
    }
  }
}

class _TemplatePreviewDialog extends StatefulWidget {
  final PromptTemplate template;

  const _TemplatePreviewDialog({required this.template});

  @override
  State<_TemplatePreviewDialog> createState() => _TemplatePreviewDialogState();
}

class _TemplatePreviewDialogState extends State<_TemplatePreviewDialog> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.template.prompt);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Dialog(
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderMedium),
      child: Padding(
        padding: const EdgeInsets.all(MaritaSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                MaritaIcon(
                  icon: widget.template.icon,
                  color: colors.interactivePrimary,
                ),
                const SizedBox(width: MaritaSpacing.md),
                Text(widget.template.title, style: typography.h4),
              ],
            ),
            const SizedBox(height: MaritaSpacing.lg),
            Text(
              'You can customize the prompt before sending it.',
              style: typography.bodySmall.copyWith(color: colors.contentSecondary),
            ),
            const SizedBox(height: MaritaSpacing.md),
            Container(
              decoration: BoxDecoration(
                color: colors.backgroundSecondary,
                borderRadius: MaritaRadius.borderSmall,
                border: Border.all(color: colors.borderPrimary),
              ),
              child: TextField(
                controller: _controller,
                maxLines: 8,
                style: typography.bodyDefault,
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(MaritaSpacing.md),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
            const SizedBox(height: MaritaSpacing.xl),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                  ),
                ),
                const SizedBox(width: MaritaSpacing.md),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, _controller.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.interactivePrimary,
                    foregroundColor: colors.backgroundPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: MaritaRadius.borderSmall,
                    ),
                  ),
                  child: const Text('Use Template'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateTemplateDialog extends StatefulWidget {
  const _CreateTemplateDialog();

  @override
  State<_CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<_CreateTemplateDialog> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _promptController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Dialog(
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderMedium),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(MaritaSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Template', style: typography.h4),
              const SizedBox(height: MaritaSpacing.lg),
              TextField(
                controller: _titleController,
                style: typography.bodyDefault,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g., Financial Report Analysis',
                ),
              ),
              const SizedBox(height: MaritaSpacing.md),
              TextField(
                controller: _descController,
                style: typography.bodyDefault,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What does this template do?',
                ),
              ),
              const SizedBox(height: MaritaSpacing.md),
              TextField(
                controller: _promptController,
                maxLines: 5,
                style: typography.bodyDefault,
                decoration: const InputDecoration(
                  labelText: 'Prompt',
                  hintText: 'Write your prompt here...',
                ),
              ),
              const SizedBox(height: MaritaSpacing.xl),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'Cancel',
                      style: typography.bodyDefault.copyWith(color: colors.contentSecondary),
                    ),
                  ),
                  const SizedBox(width: MaritaSpacing.md),
                  ElevatedButton(
                    onPressed: () {
                      if (_titleController.text.isEmpty || _promptController.text.isEmpty) return;

                      final template = PromptTemplate(
                        id: const Uuid().v4(),
                        title: _titleController.text,
                        description: _descController.text,
                        prompt: _promptController.text,
                        icon: MaritaIcons.magicStar,
                        isCustom: true,
                      );
                      Navigator.pop(context, template);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.interactivePrimary,
                      foregroundColor: colors.backgroundPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: MaritaRadius.borderSmall,
                      ),
                    ),
                    child: const Text('Create'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

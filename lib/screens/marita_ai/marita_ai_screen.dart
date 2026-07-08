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
import 'package:marita/services/ai_pipeline_service.dart';
import 'package:marita/providers/auth_provider.dart';
import 'package:marita/providers/template_provider.dart';
import 'package:marita/providers/workspace_provider.dart';
import 'package:uuid/uuid.dart';
import '../../components/workspace_header_chip.dart';
import '../../components/audit_loading_widget.dart';
import '../../components/verification_metrics_card.dart';

// =============================================================================
// STATE & NOTIFIER
class ChatState {
  final String? chatId;
  final String? title;
  final List<ChatMessage> messages;
  final bool isLoading;
  final AIPipelinePhase pipelinePhase;

  ChatState({
    this.chatId,
    this.title,
    this.messages = const [],
    this.isLoading = false,
    this.pipelinePhase = AIPipelinePhase.idle,
  });

  ChatState copyWith({
    String? chatId,
    String? title,
    List<ChatMessage>? messages,
    bool? isLoading,
    AIPipelinePhase? pipelinePhase,
  }) {
    return ChatState(
      chatId: chatId ?? this.chatId,
      title: title ?? this.title,
      messages: messages ?? this.messages,
      isLoading: isLoading ?? this.isLoading,
      pipelinePhase: pipelinePhase ?? this.pipelinePhase,
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

  /// Detects the audit step category from the user's message text and
  /// attached file names, returning the appropriate [LoadingRequestType].
  LoadingRequestType _detectRequestType(
    String message,
    List<String> fileNames,
  ) {
    final lower = message.toLowerCase();
    final allText = '$lower ${fileNames.join(' ').toLowerCase()}';

    if (allText.contains(RegExp(r'annual report|laporan tahunan'))) {
      return LoadingRequestType.annualReport;
    }
    if (allText.contains(RegExp(r'invoice|faktur'))) {
      return LoadingRequestType.invoices;
    }
    if (allText.contains(RegExp(r'receipt|kwitansi|struk'))) {
      return LoadingRequestType.receipts;
    }
    if (allText.contains(RegExp(r'contract|perjanjian|kontrak'))) {
      return LoadingRequestType.contracts;
    }
    if (allText.contains(RegExp(
      r'financial statement|laporan keuangan|neraca|balance sheet|income statement',
    ))) {
      return LoadingRequestType.financialStatements;
    }
    if (allText.contains(RegExp(
      r'jurnal|debit|kredit|akuntansi|accounting|cogs|depreciation',
    ))) {
      return LoadingRequestType.accountingQuestion;
    }
    return LoadingRequestType.general;
  }

  void sendMessage(String text, {List<ChatAttachment>? attachments}) async {
    final user = ref.read(currentUserProvider);
    final userId = user?.uid ?? 'anonymous';
    final firestoreService = ref.read(firestoreServiceProvider);

    // 0. Detect the loading request type from message + file names
    final requestType = _detectRequestType(
      text,
      (attachments ?? []).map((a) => a.name).toList(),
    );

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

    // 2. Prepare AI message — carry the detected requestType for the loading widget
    final aiId = '${const Uuid().v4()}_ai';
    final aiMsg = ChatMessage(
      id: aiId,
      text: '',
      role: MessageRole.ai,
      isStreaming: true,
      loadingRequestType: requestType,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [...state.messages, aiMsg]);

    // 3. Ensure chatId exists
    String? currentChatId = state.chatId;
    if (currentChatId == null && user != null) {
      final workspace = ref.read(activeWorkspaceProvider);
      if (workspace == null) return;

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

      currentChatId = await firestoreService.createWorkspaceChat(
        companyId: workspace.id,
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
        final url = await AttachmentService.uploadAttachment(
          attachment,
          userId,
        );
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
            if (msg.id == tempId)
              msg.copyWith(attachments: uploadedAttachments)
            else
              msg,
        ],
      );
    }

    // 5. Save user message to Firestore
    if (currentChatId != null) {
      final workspace = ref.read(activeWorkspaceProvider);
      if (workspace != null) {
        final userMsgToSave = state.messages.firstWhere((m) => m.id == tempId);
        await firestoreService.addWorkspaceChatMessage(
          companyId: workspace.id,
          chatId: currentChatId,
          messageMap: userMsgToSave.toMap(),
        );
      }
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
    await _processGeminiStream(
      aiId,
      userMessage.text,
      userMessage.attachments,
      state.chatId,
    );
  }

  Future<void> _processGeminiStream(
    String aiId,
    String text,
    List<ChatAttachment> attachments,
    String? chatId,
  ) async {
    final firestoreService = ref.read(firestoreServiceProvider);
    try {
      var historyList =
          state.messages
              .where(
                (m) => m.id != aiId && !m.isStreaming,
              ) // Don't include current or other streaming messages in history
              .toList();

      // Exclude the very last user message because it's passed as the `text` (prompt)
      if (historyList.isNotEmpty &&
          historyList.last.role == MessageRole.user &&
          historyList.last.text == text) {
        historyList = historyList.sublist(0, historyList.length - 1);
      }

      final workspace = ref.read(activeWorkspaceProvider);
      final workspaceId = workspace?.id ?? 'default';

      final pipelineService = AIPipelineService();

      // Stage 1 & 2: Static Analysis and RAG Retrieval
      state = state.copyWith(pipelinePhase: AIPipelinePhase.retrievingContext);
      final retrievedChunks = await pipelineService.retrieveContext(
        query: text,
        workspaceId: workspaceId,
        queryEmbedding:
            const [], // Using empty vector to trigger keyword fallback search
      );

      // Stage 3: Build Augmented Prompt
      state = state.copyWith(pipelinePhase: AIPipelinePhase.buildingPrompt);
      final queryType = PromptRouter.route(text);
      final augmentedPrompt = pipelineService.buildAugmentedPrompt(
        text,
        queryType,
        retrievedChunks,
      );

      // Stage 4: Generative Execution Stream
      state = state.copyWith(pipelinePhase: AIPipelinePhase.generating);
      debugPrint(
        "======================================================================",
      );
      debugPrint("🤖 [AI PIPELINE] STAGE 4: GEMINI EXECUTION & GENERATIVE STREAM");
      debugPrint(
        "======================================================================",
      );
      debugPrint("  ├─ Model Target: gemini-2.5-flash-lite");
      debugPrint("  └─ Status: Stream started...");

      final stream = GeminiService.sendMessageStream(
        augmentedPrompt,
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

      debugPrint("  └─ Status: Stream generation complete.");
      debugPrint(
        "======================================================================\n",
      );

      // Stage 5 & 6: Fact Verification and Response Validation
      final pipelineResult = await pipelineService.verifyAndValidate(
        query: text,
        queryType: queryType,
        draftResponse: fullText,
        retrievedChunks: retrievedChunks,
      );

      final verifiedResponse = pipelineResult.responseText;

      // Mark streaming as finished with final verified/fallback text
      final finalAiMsg = ChatMessage(
        id: aiId,
        text: verifiedResponse,
        role: MessageRole.ai,
        isStreaming: false,
        createdAt: DateTime.now(),
        queryType: pipelineResult.queryType.name,
        confidenceScore: pipelineResult.confidenceScore,
        evidenceScore: pipelineResult.evidenceScore,
        citations: pipelineResult.citations,
        verificationIssues: pipelineResult.feedback,
        fullCorrectCount: pipelineResult.fullCorrectCount,
        semiCorrectCount: pipelineResult.semiCorrectCount,
        incorrectCount: pipelineResult.incorrectCount,
        precisionPercent: pipelineResult.precisionPercent,
        retrievedChunksCount: pipelineResult.retrievedChunksCount,
        retrievedChunksInfo: pipelineResult.retrievedChunksInfo,
      );

      state = state.copyWith(
        messages: [
          for (final msg in state.messages)
            if (msg.id == aiId) finalAiMsg else msg,
        ],
        pipelinePhase: AIPipelinePhase.idle,
      );

      // Save AI message to Firestore
      if (chatId != null) {
        if (workspace != null) {
          await firestoreService.addWorkspaceChatMessage(
            companyId: workspace.id,
            chatId: chatId,
            messageMap: finalAiMsg.toMap(),
          );
          // Refresh history to update last message/timestamp
          ref.invalidate(chatHistoryProvider);
        }
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
        pipelinePhase: AIPipelinePhase.idle,
      );

      if (chatId != null) {
        final workspace = ref.read(activeWorkspaceProvider);
        if (workspace != null) {
          await firestoreService.addWorkspaceChatMessage(
            companyId: workspace.id,
            chatId: chatId,
            messageMap: errorMsg.toMap(),
          );
        }
      }
    }
  }
}

final chatProvider = NotifierProvider<ChatNotifier, ChatState>(
  ChatNotifier.new,
);

final chatHistoryProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final workspace = ref.watch(activeWorkspaceProvider);
  if (workspace == null) return [];
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getWorkspaceChats(workspace.id);
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
                        ref
                            .read(chatProvider.notifier)
                            .sendMessage(text, attachments: attachments);
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DynamicTitle(title: chatState.title ?? 'New chat'),
                const SizedBox(height: MaritaSpacing.xs),
                const WorkspaceHeaderChip(),
              ],
            ),
          ),
          const SizedBox(
            width: 40,
          ), // Balance the menu button for centered title
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
                padding: const EdgeInsets.symmetric(
                  horizontal: MaritaSpacing.xl,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'History',
                      style: typography.titleMedium.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    if (ref.watch(canWriteRobustProvider))
                      IconButton(
                        icon: const MaritaIcon(
                          icon: IconsaxPlusLinear.add,
                          size: MaritaIconSize.small,
                        ),
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
                        final displayTitle =
                            title?.isNotEmpty == true
                                ? title!
                                : (lastMsg.isNotEmpty ? lastMsg : 'New chat');
                        final isSelected = id == currentChatId;

                        String dateText = '';
                        if (chat['updatedAt'] != null) {
                          try {
                            DateTime date =
                                (chat['updatedAt'] as Timestamp).toDate();
                            dateText = DateFormat(
                              'dd MMM yyyy, HH:mm',
                            ).format(date);
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
                              color:
                                  isSelected
                                      ? colors.interactivePrimary
                                      : colors.contentPrimary,
                              fontWeight:
                                  isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                            ),
                          ),
                          subtitle:
                              dateText.isNotEmpty
                                  ? Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      dateText,
                                      style: typography.bodyDefault.copyWith(
                                        color: colors.contentTertiary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  )
                                  : null,
                          onTap: () {
                            final messagesList =
                                (chat['messages'] as List? ?? [])
                                    .map(
                                      (m) => ChatMessage.fromMap(
                                        m as Map<String, dynamic>,
                                      ),
                                    )
                                    .toList();
                            ref
                                .read(chatProvider.notifier)
                                .loadChat(id, displayTitle, messagesList);
                            Navigator.pop(context);
                          },
                          trailing:
                              ref.watch(canWriteRobustProvider)
                                  ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: MaritaIcon(
                                          icon: IconsaxPlusLinear.edit_2,
                                          size: MaritaIconSize.small,
                                          color: colors.contentTertiary,
                                        ),
                                        onPressed: () {
                                          _showRenameDialog(
                                            context,
                                            ref,
                                            id,
                                            displayTitle,
                                          );
                                        },
                                      ),
                                      IconButton(
                                        icon: MaritaIcon(
                                          icon: IconsaxPlusLinear.trash,
                                          size: MaritaIconSize.small,
                                          color: colors.contentTertiary,
                                        ),
                                        onPressed: () async {
                                          final workspace = ref.read(
                                            activeWorkspaceProvider,
                                          );
                                          if (workspace != null) {
                                            await ref
                                                .read(firestoreServiceProvider)
                                                .deleteWorkspaceChat(
                                                  workspace.id,
                                                  id,
                                                );
                                            ref.invalidate(chatHistoryProvider);
                                            if (isSelected) {
                                              ref
                                                  .read(chatProvider.notifier)
                                                  .createNewChat();
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  )
                                  : null,
                        );
                      },
                    );
                  },
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error:
                      (e, st) =>
                          Center(child: Text('Error loading history: $e')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    String chatId,
    String currentTitle,
  ) {
    final controller = TextEditingController(text: currentTitle);
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: colors.backgroundSecondary,
          title: Text(
            'Rename Chat',
            style: typography.titleMedium.copyWith(
              color: colors.contentPrimary,
            ),
          ),
          content: TextField(
            controller: controller,
            style: typography.bodyLarge.copyWith(color: colors.contentPrimary),
            decoration: InputDecoration(
              hintText: 'Enter new title',
              hintStyle: typography.bodyLarge.copyWith(
                color: colors.contentTertiary,
              ),
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
              child: Text(
                'Cancel',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final newTitle = controller.text.trim();
                if (newTitle.isNotEmpty && newTitle != currentTitle) {
                  final workspace = ref.read(activeWorkspaceProvider);
                  if (workspace != null) {
                    await ref
                        .read(firestoreServiceProvider)
                        .updateWorkspaceChatTitle(
                          workspace.id,
                          chatId,
                          newTitle,
                        );
                    ref.invalidate(chatHistoryProvider);
                    if (ref.read(chatProvider).chatId == chatId) {
                      ref.read(chatProvider.notifier).updateTitle(newTitle);
                    }
                  }
                }
                if (context.mounted) Navigator.pop(context);
              },
              child: Text(
                'Save',
                style: typography.bodyDefault.copyWith(
                  color: colors.interactivePrimary,
                ),
              ),
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
    // Read the live pipeline phase so AuditLoadingWidget advances in sync
    final pipelinePhase = ref.watch(
      chatProvider.select((s) => s.pipelinePhase),
    );

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
                          padding: const EdgeInsets.only(
                            bottom: MaritaSpacing.md,
                          ),
                          child: Wrap(
                            spacing: MaritaSpacing.sm,
                            runSpacing: MaritaSpacing.sm,
                            children:
                                message.attachments.map((attachment) {
                                  return _AttachmentPreviewBubble(
                                    attachment: attachment,
                                  );
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
                          // AI bubble — show loading widget while streaming
                          // and no text has arrived yet; switch to markdown
                          // once the first token lands (AnimatedSwitcher handles
                          // the fade transition automatically).
                          : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child:
                                (!message.isStreaming || message.text.isNotEmpty)
                                    ? MarkdownBody(
                                      key: const ValueKey('md'),
                                      data: message.text,
                                      styleSheet: MarkdownStyleSheet(
                                        p: typography.bodyLarge.copyWith(
                                          color: colors.contentPrimary,
                                        ),
                                        code: typography.bodyDefault.copyWith(
                                          fontFamily: 'monospace',
                                          backgroundColor:
                                              colors.backgroundSecondary,
                                        ),
                                        codeblockDecoration: BoxDecoration(
                                          color: colors.backgroundSecondary,
                                          borderRadius:
                                              MaritaRadius.borderMedium,
                                        ),
                                      ),
                                    )
                                    : AuditLoadingWidget(
                                      key: ValueKey(
                                        'loading_${message.id}',
                                      ),
                                      requestType:
                                          message.loadingRequestType ??
                                          LoadingRequestType.general,
                                      phase: pipelinePhase,
                                    ),
                          ),

                    ],
                  ),
                ),
              ),
            ],
          ),
          // ── Verification Metrics Card — outside bubble, above action buttons
          if (!isUser &&
              !message.isStreaming &&
              _hasMetrics(message))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: VerificationMetricsCard(message: message),
            ),
          if (!isUser && !message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 12),
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
                  if (ref.watch(canWriteRobustProvider)) ...[
                    _AIActionIcon(
                      icon: IconsaxPlusLinear.refresh,
                      onTap: () {
                        ref
                            .read(chatProvider.notifier)
                            .regenerateMessage(message);
                      },
                    ),
                    const SizedBox(width: MaritaSpacing.md),
                  ],
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

  /// Returns true when the message has at least one non-null metric score
  /// and belongs to a non-general query type.
  bool _hasMetrics(ChatMessage m) =>
      m.queryType != null &&
      m.queryType != 'general' &&
      (m.evidenceScore != null ||
          m.confidenceScore != null ||
          m.precisionPercent != null);

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
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ExportService.exportMessageToPdf(message);
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
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                    ),
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
    final isMultiLine =
        text.contains('\n') || text.length > 35 || _attachments.isNotEmpty;
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
                  'Select Image Source',
                  style: typography.titleMedium.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                const SizedBox(height: MaritaSpacing.xl),
                ListTile(
                  leading: const MaritaIcon(icon: MaritaIcons.camera),
                  title: Text('Take Photo', style: typography.bodyLarge),
                  subtitle: Text(
                    'Use camera to snap a picture',
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final photo = await AttachmentService.takePhoto();
                    if (photo != null) {
                      setState(() {
                        _attachments = [..._attachments, photo];
                        _updateState();
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const MaritaIcon(icon: MaritaIcons.gallery),
                  title: Text(
                    'Choose from Gallery',
                    style: typography.bodyLarge,
                  ),
                  subtitle: Text(
                    'Upload an image from your library',
                    style: typography.bodyDefault.copyWith(
                      color: colors.contentSecondary,
                    ),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final image = await AttachmentService.pickImage();
                    if (image != null) {
                      setState(() {
                        _attachments = [..._attachments, image];
                        _updateState();
                      });
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
              Text('Upload Image', style: typography.bodyDefault),
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
    final canWrite = ref.watch(canWriteRobustProvider);

    if (!canWrite) {
      return Container(
        padding: const EdgeInsets.all(MaritaSpacing.lg),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: colors.borderPrimary),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            MaritaIcon(
              icon: IconsaxPlusLinear.eye,
              color: colors.contentTertiary,
              size: MaritaIconSize.small,
            ),
            const SizedBox(width: MaritaSpacing.sm),
            Flexible(
              child: Text(
                'View Only — you cannot send messages',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentTertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }

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
              height: 56, // Adjusted height for pill-shape
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
                      final extension =
                          attachment.name.split('.').last.toUpperCase();

                      String fileSizeStr = '';
                      try {
                        final file = File(attachment.path);
                        if (file.existsSync()) {
                          final bytes = file.lengthSync();
                          if (bytes < 1024) {
                            fileSizeStr = '${bytes}B';
                          } else if (bytes < 1024 * 1024) {
                            fileSizeStr =
                                '${(bytes / 1024).toStringAsFixed(2)}KB';
                          } else {
                            fileSizeStr =
                                '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
                          }
                        }
                      } catch (_) {}

                      return Container(
                        margin: const EdgeInsets.only(right: MaritaSpacing.sm),
                        padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary, // Dark capsule
                          borderRadius: BorderRadius.circular(
                            100,
                          ), // Pill shape
                          border: Border.all(color: colors.borderPrimary),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Icon Container
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color:
                                    extension == 'CSV' ||
                                            extension == 'XLS' ||
                                            extension == 'XLSX'
                                        ? const Color(0xFF107C41)
                                        : colors.interactivePrimary,
                                shape: BoxShape.circle,
                              ),
                              child:
                                  isImage
                                      ? ClipOval(
                                        child: Image.file(
                                          File(attachment.path),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                      : Center(
                                        child: MaritaIcon(
                                          icon: _getAttachmentIcon(
                                            attachment.type,
                                          ),
                                          size: MaritaIconSize.small,
                                          color: Colors.white,
                                        ),
                                      ),
                            ),
                            const SizedBox(width: MaritaSpacing.sm),
                            // Text Info
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 100, // Constrain text width
                                  child: Text(
                                    attachment.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: typography.bodyDefaultBold.copyWith(
                                      color:
                                          colors
                                              .interactivePrimary, // Blue text
                                    ),
                                  ),
                                ),
                                Text(
                                  fileSizeStr.isNotEmpty
                                      ? '$extension $fileSizeStr'
                                      : extension,
                                  style: typography.bodySmall.copyWith(
                                    color: colors.contentSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: MaritaSpacing.md),
                            // Close Button
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _attachments.removeAt(index);
                                  _updateState();
                                });
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: colors.borderPrimary,
                                  ),
                                ),
                                child: Icon(
                                  Icons.close,
                                  size: 14,
                                  color: colors.contentPrimary,
                                ),
                              ),
                            ),
                          ],
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
                              icon: Icon(
                                Icons.delete_sweep_rounded,
                                color: colors.error,
                                size: 20,
                              ),
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
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 8,
                    ), // (32px container - 16px text) / 2 = 8px
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
                  if (_controller.text.trim().isEmpty && _attachments.isEmpty) {
                    return;
                  }
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
}

IconData _getAttachmentIcon(String type) {
  switch (type) {
    case 'pdf':
      return IconsaxPlusLinear.document_text;
    case 'image':
      return IconsaxPlusLinear.gallery;
    case 'csv':
    case 'xls':
    case 'xlsx':
    case 'text':
    case 'json':
    case 'sql':
    case 'md':
    case 'xml':
      return IconsaxPlusLinear.document;
    case 'doc':
    case 'docx':
      return IconsaxPlusLinear.document_text;
    default:
      return IconsaxPlusLinear.document_cloud;
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
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TemplateCard({
    required this.template,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    template.title,
                    style: typography.bodyDefaultBold.copyWith(
                      color: colors.contentPrimary,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    template.description,
                    style: typography.bodySmall.copyWith(
                      color: colors.contentSecondary,
                      height: 1.2,
                    ),
                  ),
                  if (template.requiredInput.isNotEmpty) ...[
                    const SizedBox(height: MaritaSpacing.md),
                    Text(
                      'Required Input',
                      style: typography.bodySmallBold.copyWith(
                        color: colors.contentTertiary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      template.requiredInput,
                      style: typography.bodySmall.copyWith(
                        color: colors.contentSecondary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (template.isCustom) ...[
              const SizedBox(width: MaritaSpacing.sm),
              Column(
                children: [
                  _TemplateActionButton(
                    icon: IconsaxPlusLinear.edit_2,
                    onTap: onEdit ?? () {},
                  ),
                  const SizedBox(height: MaritaSpacing.xs),
                  _TemplateActionButton(
                    icon: IconsaxPlusLinear.trash,
                    color: colors.error,
                    onTap: onDelete ?? () {},
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TemplateActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _TemplateActionButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        // Prevent tapping the card itself
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.maritaColors.backgroundPrimary,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          size: 14,
          color: color ?? context.maritaColors.contentSecondary,
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

  void _createNewTemplate() async {
    final result = await showDialog<PromptTemplate>(
      context: context,
      builder: (context) => const _CreateTemplateDialog(),
    );
    if (result != null) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          await TemplateService.saveCustomTemplate(user.uid, result);
          ref.invalidate(customTemplatesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template created successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error creating template: $e')),
            );
          }
        }
      }
    }
  }

  void _editTemplate(PromptTemplate template) async {
    final result = await showDialog<PromptTemplate>(
      context: context,
      builder: (context) => _CreateTemplateDialog(template: template),
    );
    if (result != null) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          await TemplateService.updateCustomTemplate(user.uid, result);
          ref.invalidate(customTemplatesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template updated successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating template: $e')),
            );
          }
        }
      }
    }
  }

  void _deleteTemplate(PromptTemplate template) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: context.maritaColors.backgroundPrimary,
            title: Text('Delete Template', style: context.maritaTypography.h4),
            content: Text(
              'Are you sure you want to delete "${template.title}"?',
              style: context.maritaTypography.bodyDefault,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: context.maritaColors.contentSecondary,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.maritaColors.error,
                ),
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );

    if (confirm == true) {
      final user = ref.read(currentUserProvider);
      if (user != null) {
        try {
          await TemplateService.deleteCustomTemplate(user.uid, template.id);
          ref.invalidate(customTemplatesProvider);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Template deleted successfully')),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting template: $e')),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final staticTemplates =
        TemplateService.getStaticTemplates().where((t) {
          final query = _searchQuery.toLowerCase();
          return t.title.toLowerCase().contains(query) ||
              t.description.toLowerCase().contains(query);
        }).toList();

    final categoriesOrder = [
      'Document Summary',
      'Fraud Detection',
      'Investment Analysis',
      'Business Analysis',
      'Generate Reports',
    ];

    final categoryIcons = {
      'Document Summary': IconsaxPlusLinear.document_text,
      'Fraud Detection': IconsaxPlusLinear.shield_search,
      'Investment Analysis': IconsaxPlusLinear.chart_2,
      'Business Analysis': IconsaxPlusLinear.briefcase,
      'Generate Reports': IconsaxPlusLinear.document_favorite,
    };

    final templatesByCategory = <String, List<PromptTemplate>>{};
    for (final category in categoriesOrder) {
      final templates =
          staticTemplates.where((t) => t.category == category).toList();
      if (templates.isNotEmpty) {
        templatesByCategory[category] = templates;
      }
    }

    final customTemplatesAsync = ref.watch(customTemplatesProvider);

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
                    style: typography.titleMedium.copyWith(
                      color: colors.contentPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Analyze your data faster with pre-built prompts.',
                    style: typography.bodySmall.copyWith(
                      color: colors.contentSecondary,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _createNewTemplate,
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.interactivePrimary,
                    borderRadius: MaritaRadius.borderSmall,
                  ),
                  child: Icon(
                    IconsaxPlusLinear.add,
                    color: colors.backgroundPrimary,
                    size: 20,
                  ),
                ),
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
                Icon(
                  IconsaxPlusLinear.search_normal_1,
                  size: 18,
                  color: colors.contentTertiary,
                ),
                const SizedBox(width: MaritaSpacing.md),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    style: typography.bodyDefault,
                    decoration: InputDecoration(
                      hintText: 'Search templates...',
                      hintStyle: typography.bodyDefault.copyWith(
                        color: colors.contentTertiary,
                      ),
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
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: colors.contentTertiary,
                    ),
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
                  if (staticTemplates.isNotEmpty) ...[
                    for (final category in categoriesOrder)
                      if (templatesByCategory.containsKey(category)) ...[
                        _buildCategoryHeader(
                          context,
                          category,
                          categoryIcons[category] ?? IconsaxPlusLinear.document,
                        ),
                        const SizedBox(height: MaritaSpacing.md),
                        _buildList(context, templatesByCategory[category]!),
                        const SizedBox(height: MaritaSpacing.xl),
                      ],
                  ],
                  customTemplatesAsync.when(
                    data: (customTemplates) {
                      final filteredCustom =
                          customTemplates.where((t) {
                            final query = _searchQuery.toLowerCase();
                            return t.title.toLowerCase().contains(query) ||
                                t.description.toLowerCase().contains(query);
                          }).toList();

                      if (filteredCustom.isEmpty) {
                        return const SizedBox.shrink();
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionTitle(context, 'Your Templates'),
                          const SizedBox(height: MaritaSpacing.md),
                          _buildList(context, filteredCustom),
                        ],
                      );
                    },
                    loading:
                        () => const Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: MaritaSpacing.md,
                            ),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    error:
                        (err, stack) => Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: MaritaSpacing.md,
                          ),
                          child: Text(
                            'Error loading templates: $err',
                            style: typography.bodySmall.copyWith(
                              color: colors.error,
                            ),
                          ),
                        ),
                  ),
                  if (staticTemplates.isEmpty &&
                      (customTemplatesAsync.value ?? []).where((t) {
                        final query = _searchQuery.toLowerCase();
                        return t.title.toLowerCase().contains(query) ||
                            t.description.toLowerCase().contains(query);
                      }).isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MaritaSpacing.xxl),
                        child: Column(
                          children: [
                            Icon(
                              IconsaxPlusLinear.search_status,
                              size: 48,
                              color: colors.contentTertiary,
                            ),
                            const SizedBox(height: MaritaSpacing.md),
                            Text(
                              'No templates found for "$_searchQuery"',
                              textAlign: TextAlign.center,
                              style: typography.bodyDefault.copyWith(
                                color: colors.contentSecondary,
                              ),
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

  Widget _buildCategoryHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Row(
      children: [
        Icon(icon, size: 16, color: colors.contentTertiary),
        const SizedBox(width: MaritaSpacing.xs),
        Text(
          title.toUpperCase(),
          style: typography.bodySmallBold.copyWith(
            color: colors.contentTertiary,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildList(BuildContext context, List<PromptTemplate> templates) {
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: templates.length,
      separatorBuilder:
          (context, index) => const SizedBox(height: MaritaSpacing.md),
      itemBuilder: (context, index) {
        final template = templates[index];
        return _TemplateCard(
          template: template,
          onTap: () {
            Navigator.pop(context, template.prompt);
          },
          onEdit: template.isCustom ? () => _editTemplate(template) : null,
          onDelete: template.isCustom ? () => _deleteTemplate(template) : null,
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

    final isImage = attachment.type == 'image';
    final extension = attachment.name.split('.').last.toUpperCase();

    String fileSizeStr = '';
    if (attachment.size != null) {
      final bytes = attachment.size!;
      if (bytes < 1024) {
        fileSizeStr = '${bytes}B';
      } else if (bytes < 1024 * 1024) {
        fileSizeStr = '${(bytes / 1024).toStringAsFixed(2)}KB';
      } else {
        fileSizeStr = '${(bytes / (1024 * 1024)).toStringAsFixed(2)}MB';
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary, // Dark capsule
        borderRadius: BorderRadius.circular(100), // Pill shape
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon Container
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color:
                  extension == 'CSV' ||
                          extension == 'XLS' ||
                          extension == 'XLSX'
                      ? const Color(0xFF107C41)
                      : colors.interactivePrimary,
              shape: BoxShape.circle,
            ),
            child:
                isImage
                    ? ClipOval(
                      child:
                          (attachment.url != null && attachment.url!.isNotEmpty)
                              ? Image.network(
                                attachment.url!,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Center(
                                      child: MaritaIcon(
                                        icon: _getAttachmentIcon(
                                          attachment.type,
                                        ),
                                        size: MaritaIconSize.extraSmall,
                                        color: Colors.white,
                                      ),
                                    ),
                              )
                              : Image.file(
                                File(attachment.path),
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) => Center(
                                      child: MaritaIcon(
                                        icon: _getAttachmentIcon(
                                          attachment.type,
                                        ),
                                        size: MaritaIconSize.extraSmall,
                                        color: Colors.white,
                                      ),
                                    ),
                              ),
                    )
                    : Center(
                      child: MaritaIcon(
                        icon: _getAttachmentIcon(attachment.type),
                        size: MaritaIconSize.extraSmall,
                        color: Colors.white,
                      ),
                    ),
          ),
          const SizedBox(width: MaritaSpacing.sm),
          // Text Info
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: typography.bodySmallBold.copyWith(
                    color: colors.interactivePrimary, // Blue text
                  ),
                ),
              ),
              Text(
                fileSizeStr.isNotEmpty ? '$extension $fileSizeStr' : extension,
                style: typography.bodySmall.copyWith(
                  color: colors.contentSecondary,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateTemplateDialog extends StatefulWidget {
  final PromptTemplate? template;
  const _CreateTemplateDialog({this.template});

  @override
  State<_CreateTemplateDialog> createState() => _CreateTemplateDialogState();
}

class _CreateTemplateDialogState extends State<_CreateTemplateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _promptController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.template != null) {
      _titleController.text = widget.template!.title;
      _descController.text = widget.template!.description;
      _promptController.text = widget.template!.prompt;
    }
  }

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
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.xl),
      shape: RoundedRectangleBorder(
        borderRadius: MaritaRadius.borderLarge,
        side: BorderSide(color: colors.borderPrimary),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(MaritaSpacing.xl),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.template == null
                                ? 'New Template'
                                : 'Edit Template',
                            style: typography.h4,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Create a reusable prompt for your analysis.',
                            style: typography.bodySmall.copyWith(
                              color: colors.contentTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: colors.contentSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: MaritaSpacing.xl),

                TextFormField(
                  controller: _titleController,
                  style: typography.bodyDefault,
                  maxLength: 50,
                  validator:
                      (v) =>
                          (v == null || v.isEmpty) ? 'Title is required' : null,
                  decoration: InputDecoration(
                    labelText: 'Template Title',
                    hintText: 'e.g., Financial Report Analysis',
                    filled: true,
                    fillColor: colors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(
                        color: colors.interactivePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MaritaSpacing.lg),
                TextFormField(
                  controller: _descController,
                  style: typography.bodyDefault,
                  maxLength: 100,
                  decoration: InputDecoration(
                    labelText: 'Description (Optional)',
                    hintText: 'What does this template do?',
                    filled: true,
                    fillColor: colors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(
                        color: colors.interactivePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MaritaSpacing.lg),
                TextFormField(
                  controller: _promptController,
                  maxLines: 6,
                  maxLength: 1000,
                  style: typography.bodyDefault,
                  validator:
                      (v) =>
                          (v == null || v.isEmpty)
                              ? 'Prompt is required'
                              : null,
                  decoration: InputDecoration(
                    labelText: 'Prompt',
                    hintText: 'Write your instructions here...',
                    alignLabelWithHint: true,
                    filled: true,
                    fillColor: colors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(color: colors.borderPrimary),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: MaritaRadius.borderSmall,
                      borderSide: BorderSide(
                        color: colors.interactivePrimary,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: MaritaSpacing.xxl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_formKey.currentState?.validate() ?? false) {
                        final template = PromptTemplate(
                          id: widget.template?.id ?? const Uuid().v4(),
                          title: _titleController.text.trim(),
                          description: _descController.text.trim(),
                          prompt: _promptController.text.trim(),
                          icon: widget.template?.icon ?? MaritaIcons.magicStar,
                          isCustom: true,
                        );
                        Navigator.pop(context, template);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.interactivePrimary,
                      foregroundColor: colors.backgroundPrimary,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: MaritaRadius.borderMedium,
                      ),
                    ),
                    child: Text(
                      widget.template == null
                          ? 'Create Template'
                          : 'Save Changes',
                      style: typography.bodyDefaultBold.copyWith(
                        color: colors.backgroundPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

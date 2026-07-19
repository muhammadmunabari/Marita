import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import '../../design_system/marita_design_system.dart';
import '../../design_system/marita_icons.dart';
import 'package:marita/models/message_version_group.dart';
import 'widgets/chat_message_bubble.dart';
import 'widgets/chat_input_area.dart';
import 'package:marita/providers/chat_provider.dart';
import 'widgets/sidebar_drawer.dart';

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
    final messageGroups = chatState.messageGroups;

    // Auto-scroll when new messages arrive if already at bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_showScrollToBottom && _scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopNav(context, chatState),
            Expanded(
              child: Stack(
                children: [
                  if (messageGroups.isEmpty) _buildWatermark(context),
                  _buildConversationArea(context, messageGroups),
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
                    child: ChatInputArea(
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
          MaritaIconButton(
            iconPath: 'assets/icons/iconsax-menu.svg',
            iconData: IconsaxPlusLinear.menu,
            onTap: () {
              Navigator.of(context, rootNavigator: true).push(
                PageRouteBuilder(
                  pageBuilder:
                      (context, animation, secondaryAnimation) =>
                          const SidebarDrawer(),
                  transitionsBuilder: (
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ) {
                    const begin = Offset(-1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeOutCubic;
                    var tween = Tween(
                      begin: begin,
                      end: end,
                    ).chain(CurveTween(curve: curve));
                    return SlideTransition(
                      position: animation.drive(tween),
                      child: child,
                    );
                  },
                ),
              );
            },
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [_DynamicTitle(title: chatState.title ?? 'New chat')],
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
    List<MessageVersionGroup> messageGroups,
  ) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.only(
        left: MaritaSpacing.xl,
        right: MaritaSpacing.xl,
        top: MaritaSpacing.xl,
        bottom: 120, // Space for the floating input area
      ),
      itemCount: messageGroups.length,
      itemBuilder: (context, index) {
        final group = messageGroups[index];
        // Note: this passes the active prompt for now, we will update it to handle both prompt and response later
        return Column(
          children: [
            ChatMessageBubble(
              message: group.activePrompt,
              group: group,
              isPrompt: true,
            ),
            if (group.activeResponse != null)
              ChatMessageBubble(
                message: group.activeResponse!,
                group: group,
                isPrompt: false,
              ),
          ],
        );
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

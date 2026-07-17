import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/design_system/marita_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:marita/providers/workspace_provider.dart';
import 'package:marita/providers/chat_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:marita/models/chat_message.dart';
import 'package:marita/providers/settings_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';

class SidebarDrawer extends ConsumerStatefulWidget {
  const SidebarDrawer({super.key});

  @override
  ConsumerState<SidebarDrawer> createState() => _SidebarDrawerState();
}

class _SidebarDrawerState extends ConsumerState<SidebarDrawer> {
  bool _isConversationsExpanded = true;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  bool _isSearchFocused = false;

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      setState(() {
        _isSearchFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, colors, typography),
            const SizedBox(height: MaritaSpacing.md),
            Expanded(child: _buildBody(context, colors, typography)),
            _buildBottomBar(context, colors, typography),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MaritaColorPalette colors,
    MaritaTypographyAccessor typography,
  ) {
    final userProfileAsync = ref.watch(userProfileModelProvider);
    final userProfile = userProfileAsync.value;
    final displayName =
        (userProfile?.name.isNotEmpty ?? false) ? userProfile!.name : 'User';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MaritaSpacing.xl,
        MaritaSpacing.xl,
        MaritaSpacing.xl,
        MaritaSpacing.sm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colors.backgroundSecondary,
            backgroundImage:
                (userProfile?.photoUrl?.isNotEmpty ?? false)
                    ? NetworkImage(userProfile!.photoUrl!) as ImageProvider
                    : const AssetImage('assets/logos/Logomark.png'),
            onBackgroundImageError: (exception, stackTrace) {},
            child: const SizedBox(),
          ),
          const SizedBox(width: MaritaSpacing.md),
          Expanded(
            child: Text(
              displayName,
              style: typography.titleSmall.copyWith(
                color: colors.contentPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(32),
            child: Container(
              padding: const EdgeInsets.all(MaritaSpacing.sm),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.backgroundSecondary,
              ),
              child: SvgPicture.asset(
                'assets/icons/close.svg',
                width: 24,
                height: 24,
                colorFilter: ColorFilter.mode(
                  colors.contentPrimary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    MaritaColorPalette colors,
    MaritaTypographyAccessor typography,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _isConversationsExpanded = !_isConversationsExpanded;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MaritaSpacing.xl,
              vertical: MaritaSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Conversations',
                  style: typography.bodyLarge.copyWith(
                    color: colors.contentSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                MaritaIcon(
                  icon:
                      _isConversationsExpanded
                          ? IconsaxPlusLinear.arrow_up_1
                          : IconsaxPlusLinear.arrow_down,
                  size: MaritaIconSize.medium,
                  color: colors.contentSecondary,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child:
                _isConversationsExpanded
                    ? _buildConversationList(context, colors, typography)
                    : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildConversationList(
    BuildContext context,
    MaritaColorPalette colors,
    MaritaTypographyAccessor typography,
  ) {
    final historyAsync = ref.watch(chatHistoryProvider);
    final currentChatId = ref.watch(chatProvider).chatId;

    return historyAsync.when(
      data: (chats) {
        var filteredChats = chats;
        if (_searchQuery.isNotEmpty) {
          filteredChats =
              chats.where((c) {
                final title = (c['title'] as String?)?.toLowerCase() ?? '';
                final lastMsg =
                    (c['lastMessage'] as String?)?.toLowerCase() ?? '';
                final query = _searchQuery.toLowerCase();
                return title.contains(query) || lastMsg.contains(query);
              }).toList();
        }

        if (filteredChats.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(MaritaSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _searchQuery.isEmpty
                      ? 'No conversations yet'
                      : 'No conversations found',
                  style: typography.titleSmall.copyWith(
                    color: colors.contentPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: MaritaSpacing.xs),
                Text(
                  _searchQuery.isEmpty
                      ? 'Start a new chat with Marita AI.'
                      : 'Try another keyword.',
                  style: typography.bodyDefault.copyWith(
                    color: colors.contentSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.md),
          itemCount: filteredChats.length,
          itemBuilder: (context, index) {
            final chat = filteredChats[index];
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
                DateTime date = (chat['updatedAt'] as Timestamp).toDate();
                if (DateTime.now().difference(date).inDays == 0 &&
                    DateTime.now().day == date.day) {
                  dateText = DateFormat('hh:mm a').format(date);
                } else if (DateTime.now().difference(date).inDays < 7) {
                  dateText = DateFormat('EEEE').format(date);
                } else {
                  dateText = DateFormat('dd MMM').format(date);
                }
              } catch (e) {
                // Fallback
              }
            }

            return _ConversationTile(
              title: displayTitle,
              dateText: dateText,
              isSelected: isSelected,
              onTap: () {
                final messagesList =
                    (chat['messages'] as List? ?? [])
                        .map(
                          (m) => ChatMessage.fromMap(m as Map<String, dynamic>),
                        )
                        .toList();
                ref
                    .read(chatProvider.notifier)
                    .loadChat(id, displayTitle, messagesList);
                Navigator.pop(context);
              },
              onMoreTap:
                  ref.watch(canWriteRobustProvider)
                      ? () => _showMoreOptions(context, id, displayTitle)
                      : null,
            );
          },
        );
      },
      loading: () => _buildSkeletonLoader(colors),
      error:
          (e, st) => Center(
            child: Text(
              'Error: $e',
              style: typography.bodyDefault.copyWith(color: colors.error),
            ),
          ),
    );
  }

  Widget _buildSkeletonLoader(MaritaColorPalette colors) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: MaritaSpacing.md),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MaritaSpacing.md,
            vertical: MaritaSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 200,
                height: 16,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: MaritaSpacing.xs),
              Container(
                width: 80,
                height: 12,
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    MaritaColorPalette colors,
    MaritaTypographyAccessor typography,
  ) {
    return Padding(
      padding: const EdgeInsets.all(MaritaSpacing.lg),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 48,
              decoration: BoxDecoration(
                color: colors.backgroundSecondary,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                focusNode: _searchFocusNode,
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                style: typography.bodyDefault.copyWith(
                  color: colors.contentPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: typography.bodyDefault.copyWith(
                    color: colors.contentTertiary,
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MaritaSpacing.md,
                    ),
                    child: MaritaIcon(
                      icon: IconsaxPlusLinear.search_normal,
                      color: colors.contentSecondary,
                      size: MaritaIconSize.small,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: MaritaSpacing.md,
                    vertical: 14,
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            child:
                _isSearchFocused || !ref.watch(canWriteRobustProvider)
                    ? const SizedBox(width: 0)
                    : Row(
                      children: [
                        const SizedBox(width: MaritaSpacing.md),
                        InkWell(
                          onTap: () {
                            ref.read(chatProvider.notifier).createNewChat();
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colors.backgroundSecondary,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                'assets/icons/chat-linear.svg',
                                width: 24,
                                height: 24,
                                colorFilter: ColorFilter.mode(
                                  colors.contentPrimary,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }

  void _showMoreOptions(
    BuildContext context,
    String chatId,
    String currentTitle,
  ) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showModalBottomSheet(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: MaritaSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colors.borderPrimary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: MaritaSpacing.lg),
                ListTile(
                  leading: MaritaIcon(
                    icon: IconsaxPlusLinear.trash,
                    color: colors.error,
                  ),
                  title: Text(
                    'Delete',
                    style: typography.bodyLarge.copyWith(color: colors.error),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showDeleteConfirmDialog(context, chatId);
                  },
                ),
                ListTile(
                  leading: MaritaIcon(
                    icon: IconsaxPlusLinear.edit_2,
                    color: colors.contentPrimary,
                  ),
                  title: Text(
                    'Rename',
                    style: typography.bodyLarge.copyWith(
                      color: colors.contentPrimary,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(bottomSheetContext);
                    _showRenameDialog(context, chatId, currentTitle);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRenameDialog(
    BuildContext context,
    String chatId,
    String currentTitle,
  ) {
    final controller = TextEditingController(text: currentTitle);
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.backgroundPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
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
              onPressed: () => Navigator.pop(dialogContext),
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
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(
                'Save',
                style: typography.bodyDefault.copyWith(
                  color: colors.interactivePrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDeleteConfirmDialog(BuildContext context, String chatId) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: colors.backgroundPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Delete Conversation?',
            style: typography.titleMedium.copyWith(
              color: colors.contentPrimary,
            ),
          ),
          content: Text(
            'This action cannot be undone.',
            style: typography.bodyDefault.copyWith(
              color: colors.contentSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: typography.bodyDefault.copyWith(
                  color: colors.contentSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                final workspace = ref.read(activeWorkspaceProvider);
                if (workspace != null) {
                  await ref
                      .read(firestoreServiceProvider)
                      .deleteWorkspaceChat(workspace.id, chatId);
                  ref.invalidate(chatHistoryProvider);
                  if (ref.read(chatProvider).chatId == chatId) {
                    ref.read(chatProvider.notifier).createNewChat();
                  }
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: Text(
                'Delete',
                style: typography.bodyDefault.copyWith(
                  color: colors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConversationTile extends StatefulWidget {
  final String title;
  final String dateText;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;

  const _ConversationTile({
    required this.title,
    required this.dateText,
    required this.isSelected,
    required this.onTap,
    this.onMoreTap,
  });

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            MaritaSpacing.md,
            MaritaSpacing.sm,
            MaritaSpacing.sm,
            MaritaSpacing.sm,
          ),
          decoration: BoxDecoration(
            color:
                (widget.isSelected || _isHovered)
                    ? colors.backgroundSecondary
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: typography.bodyDefault.copyWith(
                        color:
                            widget.isSelected
                                ? colors.interactivePrimary
                                : colors.contentPrimary,
                        fontWeight:
                            widget.isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                      ),
                    ),
                    if (widget.dateText.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.dateText,
                        style: typography.bodyDefault.copyWith(
                          color: colors.contentTertiary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.onMoreTap != null)
                IconButton(
                  icon: MaritaIcon(
                    icon: IconsaxPlusLinear.more,
                    size: MaritaIconSize.small,
                    color: colors.contentSecondary,
                  ),
                  onPressed: widget.onMoreTap,
                  splashRadius: 20,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

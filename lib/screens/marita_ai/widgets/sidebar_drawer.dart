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

class SidebarDrawer extends ConsumerWidget {
  const SidebarDrawer({super.key});

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

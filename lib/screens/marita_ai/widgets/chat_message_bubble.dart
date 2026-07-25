import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:marita/models/chat_message.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/design_system/marita_icons.dart';
import 'chat_input_area.dart'; // for getAttachmentIcon
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:marita/providers/chat_provider.dart';
import 'package:marita/providers/workspace_provider.dart';
import '../../../components/audit_loading_widget.dart';
import '../../../components/evaluation_metrics_card.dart';
import '../../../components/version_navigator.dart';
import '../../../components/version_badge.dart';
import '../../../components/see_full_analysis_button.dart';
import 'package:marita/models/message_version_group.dart';
import 'package:marita/models/message_feedback.dart';
import 'feedback_dialog.dart';

class ChatMessageBubble extends ConsumerWidget {
  final ChatMessage message;
  final MessageVersionGroup group;
  final bool isPrompt;

  const ChatMessageBubble({
    super.key,
    required this.message,
    required this.group,
    required this.isPrompt,
  });

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
                      if (isUser && group.promptVersions.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: MaritaSpacing.sm,
                          ),
                          child: const VersionBadge(
                            type: VersionBadgeType.edited,
                          ),
                        ),
                      if (!isUser && group.responseVersions.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: MaritaSpacing.sm,
                          ),
                          child: const VersionBadge(
                            type: VersionBadgeType.regenerated,
                          ),
                        ),
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
                                  return AttachmentPreviewBubble(
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
                                (!message.isStreaming ||
                                        message.text.isNotEmpty)
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
                                      key: ValueKey('loading_${message.id}'),
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
          // ── Evaluation Metrics Card — outside bubble, above action buttons
          if (!isUser && !message.isStreaming && _hasMetrics(message))
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: EvaluationMetricsCard(message: message),
            ),
          if (isUser)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (group.promptVersions.length > 1)
                    VersionNavigator(
                      currentVersion: group.activePromptIndex + 1,
                      totalVersions: group.promptVersions.length,
                      label: 'Prompt',
                      onPrevious:
                          () => ref
                              .read(chatProvider.notifier)
                              .navigateVersion(
                                group.groupId,
                                isPrompt: true,
                                direction: -1,
                              ),
                      onNext:
                          () => ref
                              .read(chatProvider.notifier)
                              .navigateVersion(
                                group.groupId,
                                isPrompt: true,
                                direction: 1,
                              ),
                    ),
                  if (group.promptVersions.length > 1) const Spacer(),
                  AIActionIcon(
                    icon: IconsaxPlusLinear.copy,
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: message.text));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                  const SizedBox(width: MaritaSpacing.md),
                  AIActionIcon(
                    icon: IconsaxPlusLinear.edit,
                    onTap: () {
                      ref
                          .read(chatProvider.notifier)
                          .startEditingMessage(group.groupId);
                    },
                  ),
                ],
              ),
            ),
          if (!isUser && !message.isStreaming)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      if (group.responseVersions.length > 1)
                        VersionNavigator(
                          currentVersion: group.activeResponseIndex + 1,
                          totalVersions: group.responseVersions.length,
                          label: 'Response',
                          onPrevious:
                              () => ref
                                  .read(chatProvider.notifier)
                                  .navigateVersion(
                                    group.groupId,
                                    isPrompt: false,
                                    direction: -1,
                                  ),
                          onNext:
                              () => ref
                                  .read(chatProvider.notifier)
                                  .navigateVersion(
                                    group.groupId,
                                    isPrompt: false,
                                    direction: 1,
                                  ),
                        ),
                      if (group.responseVersions.length > 1)
                        const SizedBox(width: MaritaSpacing.md),
                      AIActionIcon(
                        icon: IconsaxPlusLinear.copy,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: message.text));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied to clipboard'),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: MaritaSpacing.md),
                      if (ref.watch(canWriteRobustProvider)) ...[
                        AIActionIcon(
                          icon: IconsaxPlusLinear.refresh,
                          onTap: () {
                            ref
                                .read(chatProvider.notifier)
                                .regenerateResponse(group.groupId);
                          },
                        ),
                        const SizedBox(width: MaritaSpacing.md),
                      ],
                      // Thumbs up
                      AIActionIcon(
                        icon:
                            message.feedbackType == FeedbackType.thumbUp
                                ? IconsaxPlusBold.like_1
                                : IconsaxPlusLinear.like_1,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => FeedbackDialog(
                                  type: FeedbackType.thumbUp,
                                  messageId: message.id,
                                  onSubmitted: (feedback) {
                                    ref
                                        .read(chatProvider.notifier)
                                        .submitFeedback(feedback);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Thank you for your feedback!',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          );
                        },
                      ),
                      const SizedBox(width: MaritaSpacing.md),
                      // Thumbs down
                      AIActionIcon(
                        icon:
                            message.feedbackType == FeedbackType.thumbDown
                                ? IconsaxPlusBold.dislike
                                : IconsaxPlusLinear.dislike,
                        onTap: () {
                          showDialog(
                            context: context,
                            builder:
                                (context) => FeedbackDialog(
                                  type: FeedbackType.thumbDown,
                                  messageId: message.id,
                                  onSubmitted: (feedback) {
                                    ref
                                        .read(chatProvider.notifier)
                                        .submitFeedback(feedback);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Thank you for your feedback!',
                                        ),
                                      ),
                                    );
                                  },
                                ),
                          );
                        },
                      ),
                    ],
                  ),
                  if (message.isAnalysisResponse == true) ...[
                    const SizedBox(height: MaritaSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: SeeFullAnalysisButton(
                        onTap: () {
                          context.push('/report/${message.id}');
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Returns true when the message has at least one non-null metric score
  /// and belongs to a non-general query type.
  bool _hasMetrics(ChatMessage m) => m.isAnalysisResponse == true;
}

class AIActionIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const AIActionIcon({super.key, required this.icon, required this.onTap});

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

class AttachmentPreviewBubble extends StatelessWidget {
  final ChatAttachment attachment;

  const AttachmentPreviewBubble({super.key, required this.attachment});

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
                                        icon: getAttachmentIcon(
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
                                        icon: getAttachmentIcon(
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
                        icon: getAttachmentIcon(attachment.type),
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

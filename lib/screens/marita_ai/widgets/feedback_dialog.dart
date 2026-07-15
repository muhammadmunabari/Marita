import 'package:flutter/material.dart';

import '../../../components/marita_primary_button.dart';
import '../../../components/marita_text_input.dart';
import '../../../design_system/marita_design_system.dart';
import '../../../models/message_feedback.dart';

/// Dialog feedback untuk 👍 dan 👎.
/// Tidak pernah submit langsung — selalu buka dialog terlebih dahulu.
class FeedbackDialog extends StatefulWidget {
  final FeedbackType type;
  final String messageId;
  final void Function(MessageFeedback) onSubmitted;

  const FeedbackDialog({
    super.key,
    required this.type,
    required this.messageId,
    required this.onSubmitted,
  });

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final List<String> _selectedReasons = [];
  final TextEditingController _commentController = TextEditingController();

  List<String> get _options {
    if (widget.type == FeedbackType.thumbUp) {
      return [
        'Accurate',
        'Helpful',
        'Easy to Understand',
        'Good Explanation',
        'Fast',
        'Other'
      ];
    } else {
      return [
        'Incorrect',
        'Hallucination',
        'Missing Information',
        'Poor Reasoning',
        'Poor Formatting',
        'Outdated',
        'Other'
      ];
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _submit() {
    final feedback = MessageFeedback(
      feedbackId: DateTime.now().millisecondsSinceEpoch.toString(),
      messageId: widget.messageId,
      type: widget.type,
      selectedReasons: _selectedReasons,
      comment: _commentController.text.trim().isEmpty
          ? null
          : _commentController.text.trim(),
    );
    widget.onSubmitted(feedback);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isThumbUp = widget.type == FeedbackType.thumbUp;
    final title = isThumbUp ? 'Provide additional feedback' : 'What was the issue?';
    final colors = context.maritaColors;

    return Dialog(
      backgroundColor: colors.backgroundSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: MaritaRadius.borderMedium,
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: MaritaSpacing.xl,
                  right: MaritaSpacing.xl,
                  top: MaritaSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: MaritaTypography.heading4.copyWith(
                        color: colors.contentPrimary,
                      ),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),
                    Wrap(
                      spacing: MaritaSpacing.sm,
                      runSpacing: MaritaSpacing.sm,
                      children: _options.map((option) {
                        final isSelected = _selectedReasons.contains(option);
                        return FilterChip(
                          label: Text(option),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedReasons.add(option);
                              } else {
                                _selectedReasons.remove(option);
                              }
                            });
                          },
                          selectedColor: colors.interactivePrimary.withValues(alpha: 0.2),
                          checkmarkColor: colors.interactivePrimary,
                          backgroundColor: colors.backgroundPrimary,
                          side: BorderSide(
                            color: isSelected ? colors.interactivePrimary : colors.borderPrimary,
                          ),
                          labelStyle: MaritaTypography.bodyDefault.copyWith(
                            color: isSelected
                                ? colors.interactivePrimary
                                : colors.contentSecondary,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: MaritaSpacing.lg),
                    MaritaTextInput(
                      controller: _commentController,
                      label: 'Comment (Optional)',
                      hint: 'Provide additional details...',
                      maxLines: 4,
                    ),
                  ],
                ),
              ),
            ),
              Padding(
                padding: const EdgeInsets.all(MaritaSpacing.xl),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MaritaSpacing.lg,
                          vertical: MaritaSpacing.md,
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: MaritaTypography.bodyLargeBold.copyWith(
                          color: colors.contentSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: MaritaSpacing.md),
                    SizedBox(
                      width: 120,
                      child: MaritaPrimaryButton(
                        label: 'Submit',
                        onPressed: _submit,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ),
    );
  }
}

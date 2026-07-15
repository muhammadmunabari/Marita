import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';
import 'package:intl/intl.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/design_system/marita_icons.dart';

class EditingBanner extends StatelessWidget {
  final DateTime? originalTimestamp;
  final int promptVersion;
  final VoidCallback onCancel;

  const EditingBanner({
    super.key,
    this.originalTimestamp,
    required this.promptVersion,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    final dateStr = originalTimestamp != null
        ? DateFormat('HH:mm').format(originalTimestamp!)
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MaritaSpacing.md,
        vertical: MaritaSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderPrimary),
      ),
      child: Row(
        children: [
          MaritaIcon(
            icon: IconsaxPlusLinear.edit_2,
            size: MaritaIconSize.small,
            color: colors.contentSecondary,
          ),
          const SizedBox(width: MaritaSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Editing message',
                  style: typography.bodySmallBold.copyWith(
                    color: colors.contentPrimary,
                  ),
                ),
                if (dateStr.isNotEmpty)
                  Text(
                    'Sent at $dateStr',
                    style: typography.bodySmall.copyWith(
                      color: colors.contentSecondary,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onCancel,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: colors.backgroundSecondary,
              ),
              child: Icon(
                Icons.close,
                size: 14,
                color: colors.contentSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

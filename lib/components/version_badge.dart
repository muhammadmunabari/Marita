import 'package:flutter/material.dart';

import '../design_system/marita_design_system.dart';
import '../models/chat_message.dart';

/// Badge kecil untuk menandai status versi.
/// Variants: Edited | Regenerated | Updated | Outdated
class VersionBadge extends StatelessWidget {
  final VersionBadgeType type;

  const VersionBadge({
    super.key,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;

    Color backgroundColor;
    Color textColor;
    String label;

    switch (type) {
      case VersionBadgeType.edited:
        backgroundColor = colors.interactivePrimary;
        textColor = colors.contentInverse;
        label = 'Edited';
        break;
      case VersionBadgeType.regenerated:
        backgroundColor = colors.backgroundSecondary;
        textColor = colors.contentSecondary;
        label = 'Regenerated';
        break;
      case VersionBadgeType.updated:
        backgroundColor = colors.success;
        textColor = colors.contentInverse;
        label = 'Updated';
        break;
      case VersionBadgeType.outdated:
        backgroundColor = colors.warning;
        textColor = colors.contentInverse;
        label = 'Outdated';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MaritaSpacing.sm,
        vertical: 2.0,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: MaritaRadius.borderSmall,
      ),
      child: Text(
        label,
        style: MaritaTypography.bodySmallBold.copyWith(
          color: textColor,
          height: 1.2,
        ),
      ),
    );
  }
}

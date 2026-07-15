import 'package:flutter/material.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/design_system/marita_icons.dart';

class SeeFullAnalysisButton extends StatelessWidget {
  final VoidCallback onTap;

  const SeeFullAnalysisButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return InkWell(
      onTap: onTap,
      borderRadius: MaritaRadius.borderMedium,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: MaritaSpacing.md,
          vertical: MaritaSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: colors.interactivePrimary.withValues(alpha: 0.1),
          borderRadius: MaritaRadius.borderMedium,
          border: Border.all(
            color: colors.interactivePrimary.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MaritaIcon(
              icon: MaritaIcons.chart, // Ensure icon exists or use a fallback
              size: MaritaIconSize.small,
              color: colors.interactivePrimary,
            ),
            const SizedBox(width: MaritaSpacing.sm),
            Text(
              'See Full Analysis',
              style: typography.bodyDefaultBold.copyWith(
                color: colors.interactivePrimary,
              ),
            ),
            const SizedBox(width: MaritaSpacing.xs),
            MaritaIcon(
              icon: MaritaIcons.arrowRight, // Ensure icon exists
              size: MaritaIconSize.small,
              color: colors.interactivePrimary,
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../design_system/marita_design_system.dart';
import '../design_system/marita_icons.dart';

/// Komponen navigasi versi untuk Prompt dan Response.
/// Menampilkan panah kiri/kanan dan teks "Prompt X of Y".
class VersionNavigator extends StatelessWidget {
  final int currentVersion;
  final int totalVersions;
  final String label; // "Prompt" or "Response"
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const VersionNavigator({
    super.key,
    required this.currentVersion,
    required this.totalVersions,
    required this.label,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final isFirst = currentVersion <= 1;
    final isLast = currentVersion >= totalVersions;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Semantics(
          label: 'Previous version',
          button: true,
          enabled: !isFirst,
          child: InkWell(
            onTap: isFirst ? null : onPrevious,
            borderRadius: MaritaRadius.borderFull,
            child: Padding(
              padding: const EdgeInsets.all(MaritaSpacing.xs),
              child: MaritaIcon(
                icon: MaritaIcons.arrowLeft,
                size: MaritaIconSize.small,
                color: isFirst ? colors.contentDisabled : colors.contentSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(width: MaritaSpacing.xs),
        Text(
          '$label $currentVersion of $totalVersions',
          style: MaritaTypography.bodySmall.copyWith(
            color: colors.contentTertiary,
          ),
        ),
        const SizedBox(width: MaritaSpacing.xs),
        Semantics(
          label: 'Next version',
          button: true,
          enabled: !isLast,
          child: InkWell(
            onTap: isLast ? null : onNext,
            borderRadius: MaritaRadius.borderFull,
            child: Padding(
              padding: const EdgeInsets.all(MaritaSpacing.xs),
              child: MaritaIcon(
                icon: MaritaIcons.arrowRight,
                size: MaritaIconSize.small,
                color: isLast ? colors.contentDisabled : colors.contentSecondary,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

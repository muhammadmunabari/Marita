import 'package:flutter/material.dart';
import '../../../design_system/marita_design_system.dart';

class ReportOutdatedBanner extends StatelessWidget {
  final VoidCallback onRegenerate;

  const ReportOutdatedBanner({
    super.key,
    required this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250), // durationNormal
      curve: Curves.easeInOut, // curveStandard
      color: context.maritaColors.warning.withValues(alpha: 0.1),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(
            Icons.warning_rounded,
            color: context.maritaColors.warning,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Prompt has been edited. Report may be outdated.',
              style: context.maritaTypography.labelSmall.copyWith(
                color: context.maritaColors.warning,
              ),
            ),
          ),
          TextButton(
            onPressed: onRegenerate,
            style: TextButton.styleFrom(
              foregroundColor: context.maritaColors.interactivePrimary,
              textStyle: context.maritaTypography.labelSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Regenerate'),
                const SizedBox(width: 4),
                Icon(Icons.arrow_forward_rounded, size: 16, color: context.maritaColors.interactivePrimary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

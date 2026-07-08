// =============================================================================
// RISK LEVEL BADGE — Reusable presentational component
// No Riverpod dependency. Safe to use in any screen or export card.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/analyze_models.dart';
import '../design_system/tokens/semantic_tokens.dart';

/// A compact pill badge that communicates a [RiskLevel] using semantic colors.
///
/// Uses WCAG AAA–compliant pairings from [SemanticColors]:
/// - Low  : green900 on green50   (18.6:1)
/// - Medium: shadow900 on yellow50 (18.1:1)
/// - High : red900 on red50       (12.3:1)
/// - Critical: cloud50 on red700   (7.0:1)
class RiskLevelBadge extends StatelessWidget {
  final RiskLevel level;

  /// When [compact] is true the badge uses smaller padding (8×4 vs 12×6).
  final bool compact;

  const RiskLevelBadge({
    super.key,
    required this.level,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = _resolve(level);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SemanticRadius.radiusPill),
      ),
      child: Text(
        label,
        style: SemanticTypography.textLabelSmall.copyWith(
          color: fg,
          fontWeight: FontWeight.w700,
          fontSize: compact ? 10.0 : 11.0,
        ),
      ),
    );
  }

  static (String label, Color bg, Color fg) _resolve(RiskLevel level) {
    switch (level) {
      case RiskLevel.low:
        return (
          'LOW',
          SemanticColors.colorRiskLowBackground,
          SemanticColors.colorRiskLowText,
        );
      case RiskLevel.medium:
        return (
          'MEDIUM',
          SemanticColors.colorRiskMediumBackground,
          SemanticColors.colorRiskMediumText,
        );
      case RiskLevel.high:
        return (
          'HIGH',
          SemanticColors.colorRiskHighBackground,
          SemanticColors.colorRiskHighText,
        );
      case RiskLevel.critical:
        return (
          'CRITICAL',
          SemanticColors.colorRiskCriticalBackground,
          SemanticColors.colorRiskCriticalText,
        );
    }
  }
}

/// Returns the primary foreground color for a risk level (for use outside badges).
Color riskLevelColor(RiskLevel level) {
  switch (level) {
    case RiskLevel.low:
      return SemanticColors.colorRiskLow;
    case RiskLevel.medium:
      return SemanticColors.colorRiskMedium;
    case RiskLevel.high:
      return SemanticColors.colorRiskHigh;
    case RiskLevel.critical:
      return SemanticColors.colorRiskCritical;
  }
}

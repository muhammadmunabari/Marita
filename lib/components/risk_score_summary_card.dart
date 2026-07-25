// =============================================================================
// RISK SCORE SUMMARY CARD — Animated horizontal bar + badge
// No Riverpod dependency. Pure presentational widget.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/analyze_models.dart';
import '../design_system/marita_design_system.dart';
import 'risk_level_badge.dart';

/// A compact card showing one risk category: title, animated bar, score % and badge.
///
/// Uses the same [TweenAnimationBuilder] animated bar pattern as
/// [_MetricRow] in `evaluation_metrics_card.dart`.
class RiskScoreSummaryCard extends StatelessWidget {
  final String title;
  final RiskScore score;
  final String? description;

  const RiskScoreSummaryCard({
    super.key,
    required this.title,
    required this.score,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.maritaColors;
    final typography = context.maritaTypography;
    final fillColor = riskLevelColor(score.level);
    final progress = (score.score / 100).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.backgroundSecondary,
        borderRadius: BorderRadius.circular(SemanticRadius.radiusCard),
        border: Border.all(color: palette.borderPrimary),
        boxShadow: SemanticElevation.shadowCard,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: title + score number ──────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: typography.bodyDefault.copyWith(
                    color: palette.contentSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${score.score}',
                style: typography.bodyLargeBold.copyWith(
                  color: fillColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Animated progress bar ─────────────────────────────────────
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: progress),
            duration: SemanticMotion.durationSlow,
            curve: SemanticMotion.curveDecelerate,
            builder: (context, value, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 6,
                  backgroundColor: palette.borderPrimary,
                  valueColor: AlwaysStoppedAnimation<Color>(fillColor),
                ),
              );
            },
          ),
          const SizedBox(height: 10),

          // ── Footer: badge + confidence ────────────────────────────────
          Row(
            children: [
              RiskLevelBadge(level: score.level, compact: true),
              const Spacer(),
              Text(
                '${(score.confidence * 100).toStringAsFixed(0)}% conf.',
                style: typography.bodyDefault.copyWith(
                  color: palette.contentSecondary,
                  fontSize: 11,
                ),
              ),
            ],
          ),

          if (description != null) ...[
            const SizedBox(height: 8),
            Text(
              description!,
              style: typography.bodyDefault.copyWith(
                color: palette.contentSecondary,
                fontSize: 11,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

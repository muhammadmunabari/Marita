// =============================================================================
// AUDIT FINDING CARD — Expandable card with AnimatedSize
// No Riverpod dependency. Pure presentational widget.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/analyze_models.dart';
import '../design_system/marita_design_system.dart';
import 'risk_level_badge.dart';

/// An expandable card displaying one [AuditFinding].
///
/// - Collapsed: priority number + title + [RiskLevelBadge] + truncated description
/// - Expanded: full description + affected items chips + recommendation box
/// - Expand/collapse uses [AnimatedSize] with arrow rotation
class AuditFindingCard extends StatefulWidget {
  final AuditFinding finding;
  final bool initiallyExpanded;

  const AuditFindingCard({
    super.key,
    required this.finding,
    this.initiallyExpanded = false,
  });

  @override
  State<AuditFindingCard> createState() => _AuditFindingCardState();
}

class _AuditFindingCardState extends State<AuditFindingCard>
    with SingleTickerProviderStateMixin {
  late bool _expanded;
  late AnimationController _arrowController;
  late Animation<double> _arrowRotation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _expanded ? 1.0 : 0.0,
    );
    _arrowRotation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _arrowController.forward();
    } else {
      _arrowController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.maritaColors;
    final typography = context.maritaTypography;
    final f = widget.finding;

    return GestureDetector(
      onTap: _toggle,
      child: AnimatedContainer(
        duration: SemanticMotion.durationNormal,
        curve: SemanticMotion.curveStandard,
        decoration: BoxDecoration(
          color: palette.backgroundSecondary,
          borderRadius: BorderRadius.circular(SemanticRadius.radiusCard),
          border: Border.all(color: palette.borderPrimary),
          boxShadow: SemanticElevation.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Priority circle
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: riskLevelColor(f.riskLevel).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${f.priority}',
                        style: typography.bodyDefault.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: riskLevelColor(f.riskLevel),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Title
                  Expanded(
                    child: Text(
                      f.title,
                      style: typography.bodyDefaultBold.copyWith(
                        color: palette.contentPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Badge
                  RiskLevelBadge(level: f.riskLevel, compact: true),
                  const SizedBox(width: 8),

                  // Expand arrow
                  RotationTransition(
                    turns: _arrowRotation,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: palette.contentSecondary,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),

            // ── Collapsed description excerpt ────────────────────────────
            if (!_expanded)
              Padding(
                padding: const EdgeInsets.only(left: 14, right: 14, bottom: 12),
                child: Text(
                  f.description,
                  style: typography.bodyDefault.copyWith(
                    color: palette.contentSecondary,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            // ── Expanded body ────────────────────────────────────────────
            AnimatedSize(
              duration: SemanticMotion.durationNormal,
              curve: SemanticMotion.curveDecelerate,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(
                        left: 14,
                        right: 14,
                        bottom: 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Full description
                          Text(
                            f.description,
                            style: typography.bodyDefault.copyWith(
                              color: palette.contentSecondary,
                              fontSize: 13,
                            ),
                          ),

                          // Affected items chips
                          if (f.affectedItems.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              'Affected Items',
                              style: typography.bodyDefault.copyWith(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: palette.contentSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: f.affectedItems.map((item) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: palette.backgroundPrimary,
                                    borderRadius: BorderRadius.circular(
                                      SemanticRadius.radiusChip,
                                    ),
                                    border: Border.all(
                                      color: palette.borderPrimary,
                                    ),
                                  ),
                                  child: Text(
                                    item,
                                    style: typography.bodyDefault.copyWith(
                                      fontSize: 11,
                                      color: palette.contentPrimary,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],

                          // Recommendation box
                          if (f.recommendation.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: SemanticColors.colorRiskLowBackground,
                                borderRadius: BorderRadius.circular(
                                  SemanticRadius.radiusCard,
                                ),
                                border: Border.all(
                                  color: SemanticColors.colorRiskLow
                                      .withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.lightbulb_outline_rounded,
                                    size: 14,
                                    color: SemanticColors.colorRiskLow,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      f.recommendation,
                                      style: typography.bodyDefault.copyWith(
                                        fontSize: 12,
                                        color: SemanticColors.colorRiskLowText,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

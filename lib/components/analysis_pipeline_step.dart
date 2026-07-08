// =============================================================================
// ANALYSIS PIPELINE STEP — Single stage in the 14-step pipeline timeline
// No Riverpod dependency. Pure presentational widget.
// =============================================================================

import 'package:flutter/material.dart';
import '../models/analyze_models.dart';
import '../design_system/marita_design_system.dart';

/// Renders a single [AnalysisPipelineStage] as a vertical timeline item.
///
/// States:
/// - `pending`  → grey outline circle
/// - `running`  → pulsing blue circle (looping animation)
/// - `completed`→ green circle with checkmark
/// - `error`    → red circle with X
///
/// Set [isLast] to `true` on the final step to hide the connector line.
class AnalysisPipelineStep extends StatefulWidget {
  final AnalysisPipelineStage stage;
  final bool isLast;

  const AnalysisPipelineStep({
    super.key,
    required this.stage,
    this.isLast = false,
  });

  @override
  State<AnalysisPipelineStep> createState() => _AnalysisPipelineStepState();
}

class _AnalysisPipelineStepState extends State<AnalysisPipelineStep>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;
  late Animation<double> _pulseOpacity;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulseScale = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
    _pulseOpacity = Tween<double>(begin: 0.6, end: 0.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );

    if (widget.stage.status == AnalysisStepStatus.running) {
      _pulseController.repeat();
    }
  }

  @override
  void didUpdateWidget(AnalysisPipelineStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stage.status == AnalysisStepStatus.running &&
        !_pulseController.isAnimating) {
      _pulseController.repeat();
    } else if (widget.stage.status != AnalysisStepStatus.running &&
        _pulseController.isAnimating) {
      _pulseController.stop();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.maritaColors;
    final typography = context.maritaTypography;
    final status = widget.stage.status;

    final (circleColor, icon, iconColor, borderColor) = _resolveStyle(status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Timeline column ────────────────────────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              children: [
                _buildIndicator(status, circleColor, icon, iconColor, borderColor),
                if (!widget.isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: palette.borderPrimary,
                      margin: const EdgeInsets.only(top: 4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // ── Stage content ──────────────────────────────────────────────
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Stage ${widget.stage.stageNumber}',
                        style: typography.bodyDefault.copyWith(
                          fontSize: 10.0,
                          color: palette.contentSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                      if (status == AnalysisStepStatus.running)
                        _RunningChip(typography: typography),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.stage.title,
                    style: typography.bodyDefaultBold.copyWith(
                      color: _titleColor(status, palette),
                      fontSize: 13.0,
                    ),
                  ),
                  if (status == AnalysisStepStatus.error &&
                      widget.stage.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        widget.stage.errorMessage!,
                        style: typography.bodyDefault.copyWith(
                          fontSize: 11.0,
                          color: SemanticColors.colorRiskHigh,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(
    AnalysisStepStatus status,
    Color circleColor,
    IconData? icon,
    Color iconColor,
    Color borderColor,
  ) {
    final indicator = Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: status == AnalysisStepStatus.pending
            ? Colors.transparent
            : circleColor,
        border: status == AnalysisStepStatus.pending
            ? Border.all(color: borderColor, width: 2)
            : null,
      ),
      child: icon != null
          ? Icon(icon, size: 14, color: iconColor)
          : null,
    );

    if (status == AnalysisStepStatus.running) {
      return AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Pulse ring
              Transform.scale(
                scale: _pulseScale.value,
                child: Opacity(
                  opacity: _pulseOpacity.value,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleColor,
                    ),
                  ),
                ),
              ),
              child!,
            ],
          );
        },
        child: indicator,
      );
    }

    return indicator;
  }

  static (Color, IconData?, Color, Color) _resolveStyle(
      AnalysisStepStatus status) {
    switch (status) {
      case AnalysisStepStatus.pending:
        return (
          Colors.transparent,
          null,
          Colors.transparent,
          SemanticColors.colorBorderSubtle,
        );
      case AnalysisStepStatus.running:
        return (
          const Color(0xFF3B82F6), // blue500
          null,
          Colors.transparent,
          const Color(0xFF3B82F6),
        );
      case AnalysisStepStatus.completed:
        return (
          SemanticColors.colorRiskLow,
          Icons.check_rounded,
          Colors.white,
          SemanticColors.colorRiskLow,
        );
      case AnalysisStepStatus.error:
        return (
          SemanticColors.colorRiskHigh,
          Icons.close_rounded,
          Colors.white,
          SemanticColors.colorRiskHigh,
        );
    }
  }

  Color _titleColor(AnalysisStepStatus status, dynamic palette) {
    switch (status) {
      case AnalysisStepStatus.pending:
        return palette.contentSecondary;
      case AnalysisStepStatus.running:
        return palette.contentPrimary;
      case AnalysisStepStatus.completed:
        return palette.contentPrimary;
      case AnalysisStepStatus.error:
        return SemanticColors.colorRiskHigh;
    }
  }
}

class _RunningChip extends StatelessWidget {
  final dynamic typography;
  const _RunningChip({required this.typography});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(SemanticRadius.radiusPill),
      ),
      child: Text(
        'Running…',
        style: typography.bodyDefault.copyWith(
          fontSize: 9.0,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF3B82F6),
        ),
      ),
    );
  }
}

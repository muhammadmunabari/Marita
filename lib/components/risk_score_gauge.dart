// =============================================================================
// RISK SCORE GAUGE — Animated circular arc gauge using CustomPainter
// No Riverpod dependency. Pure presentational widget.
// =============================================================================

import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/analyze_models.dart';
import '../design_system/tokens/semantic_tokens.dart';
import 'risk_level_badge.dart';

/// Circular arc gauge displaying a risk score (0–100) with animated entrance.
///
/// - Arc spans 270° starting from the bottom-left (~225° from 3-o'clock).
/// - Track color: [SemanticColors.colorBorderSubtle]
/// - Fill color: risk-level semantic color
/// - Entrance animation: sweep 0 → score in [SemanticMotion.durationSlow] (400ms)
class RiskScoreGauge extends StatefulWidget {
  final int score; // 0–100
  final RiskLevel level;
  final double size; // diameter; default 140
  final bool showLabel;

  const RiskScoreGauge({
    super.key,
    required this.score,
    required this.level,
    this.size = 140,
    this.showLabel = true,
  });

  @override
  State<RiskScoreGauge> createState() => _RiskScoreGaugeState();
}

class _RiskScoreGaugeState extends State<RiskScoreGauge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _sweepAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: SemanticMotion.durationSlow,
    );
    _sweepAnimation = Tween<double>(
      begin: 0,
      end: widget.score / 100,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: SemanticMotion.curveDecelerate,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(RiskScoreGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _sweepAnimation = Tween<double>(
        begin: _sweepAnimation.value,
        end: widget.score / 100,
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: SemanticMotion.curveDecelerate,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fillColor = riskLevelColor(widget.level);
    final palette = Theme.of(context).extension<_ThemeExt>()?.borderSubtle ??
        SemanticColors.colorBorderSubtle;

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _sweepAnimation,
        builder: (context, child) {
          return CustomPaint(
            painter: _GaugePainter(
              progress: _sweepAnimation.value,
              fillColor: fillColor,
              trackColor: palette,
              strokeWidth: widget.size * 0.085,
            ),
            child: child,
          );
        },
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.score}',
                style: SemanticTypography.textHeadingXLarge.copyWith(
                  color: fillColor,
                  fontWeight: FontWeight.w800,
                  fontSize: widget.size * 0.22,
                ),
              ),
              if (widget.showLabel) ...[
                const SizedBox(height: 4),
                RiskLevelBadge(level: widget.level, compact: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final double progress; // 0.0–1.0
  final Color fillColor;
  final Color trackColor;
  final double strokeWidth;

  const _GaugePainter({
    required this.progress,
    required this.fillColor,
    required this.trackColor,
    required this.strokeWidth,
  });

  // Arc starts at 225° (bottom-left) and sweeps 270° clockwise
  static const double _startAngle = 135 * math.pi / 180; // 225° from 12-o-clock = 135° from 3-o-clock
  static const double _sweepAngle = 270 * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Draw track
    canvas.drawArc(rect, _startAngle, _sweepAngle, false, trackPaint);

    // Draw fill
    if (progress > 0) {
      canvas.drawArc(
        rect,
        _startAngle,
        _sweepAngle * progress,
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.progress != progress ||
      old.fillColor != fillColor ||
      old.trackColor != trackColor;
}

// Minimal theme extension stub — fallback to semantic token directly
class _ThemeExt extends ThemeExtension<_ThemeExt> {
  final Color borderSubtle;
  const _ThemeExt({required this.borderSubtle});

  @override
  ThemeExtension<_ThemeExt> copyWith({Color? borderSubtle}) =>
      _ThemeExt(borderSubtle: borderSubtle ?? this.borderSubtle);

  @override
  ThemeExtension<_ThemeExt> lerp(_ThemeExt? other, double t) => this;
}

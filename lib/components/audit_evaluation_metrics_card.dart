import 'package:flutter/material.dart';
import 'package:marita/design_system/marita_design_system.dart';
import 'package:marita/models/analyze_models.dart';

// =============================================================================
// AUDIT EVALUATION METRICS CARD
// =============================================================================

/// Card for displaying Evaluation Metrics (Evidence, Confidence, Precision)
/// inside the Analyze screen.
class AuditEvaluationMetricsCard extends StatefulWidget {
  final AuditEvaluationMetrics metrics;
  final bool showDetailedBreakdown;

  const AuditEvaluationMetricsCard({
    super.key,
    required this.metrics,
    this.showDetailedBreakdown = false,
  });

  @override
  State<AuditEvaluationMetricsCard> createState() =>
      _AuditEvaluationMetricsCardState();
}

class _AuditEvaluationMetricsCardState extends State<AuditEvaluationMetricsCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.08), // +8% slide from below
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // Fire entrance animation on next frame so it's visible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Score → semantic color (spec thresholds)
  // > 60%  → success (green)
  // > 30%  → warning (orange)
  // ≤ 30%  → error   (red)
  // ---------------------------------------------------------------------------
  Color _scoreColor(MaritaColorPalette palette, double? pct) {
    if (pct == null) return palette.contentTertiary;
    if (pct > 80) return palette.success;
    if (pct > 30) return palette.warning;
    return palette.error;
  }

  // ---------------------------------------------------------------------------
  // Responsive max-width per spec
  // ---------------------------------------------------------------------------
  double _maxWidth(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1024) return 720;
    if (w >= 600) return 640;
    return double.infinity;
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<MaritaColorPalette>()!;
    final typography = context.maritaTypography;

    // Convert to 0–100 scale where appropriate
    final evidencePct = widget.metrics.evidenceScore * 100;
    final confidencePct = widget.metrics.confidenceScore * 100;
    final precisionPct = widget.metrics.precisionPercent;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _maxWidth(context)),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.backgroundSecondary,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: palette.borderSecondary),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Card header ──────────────────────────────────────────
                _CardHeader(palette: palette, typography: typography),
                const SizedBox(height: 12),

                // ── Metric rows ──────────────────────────────────────────
                _MetricRow(
                  label: 'Evidence Score',
                  pct: evidencePct,
                  barColor: _scoreColor(palette, evidencePct),
                  trackColor: palette.borderSecondary,
                  palette: palette,
                  typography: typography,
                ),
                const SizedBox(height: 12),
                _MetricRow(
                  label: 'Confidence Score',
                  pct: confidencePct,
                  barColor: _scoreColor(palette, confidencePct),
                  trackColor: palette.borderSecondary,
                  palette: palette,
                  typography: typography,
                ),
                const SizedBox(height: 12),
                _MetricRow(
                  label: 'Precision Score',
                  pct: precisionPct,
                  barColor: _scoreColor(palette, precisionPct),
                  trackColor: palette.borderSecondary,
                  palette: palette,
                  typography: typography,
                ),

                if (widget.showDetailedBreakdown) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  _DetailedBreakdown(
                    metrics: widget.metrics,
                    palette: palette,
                    typography: typography,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// CARD HEADER
// =============================================================================

class _CardHeader extends StatelessWidget {
  final MaritaColorPalette palette;
  final MaritaTypographyAccessor typography;

  const _CardHeader({required this.palette, required this.typography});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.verified_rounded,
          size: 16,
          color: palette.interactivePrimary,
        ),
        const SizedBox(width: 6),
        Text(
          'Evaluation Metrics',
          style: typography.bodyLargeBold.copyWith(
            color: palette.contentPrimary,
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// METRIC ROW
// =============================================================================

class _MetricRow extends StatelessWidget {
  final String label;
  final double? pct; // 0–100, nullable = N/A
  final Color barColor;
  final Color trackColor;
  final MaritaColorPalette palette;
  final MaritaTypographyAccessor typography;

  const _MetricRow({
    required this.label,
    required this.pct,
    required this.barColor,
    required this.trackColor,
    required this.palette,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    final progress = pct != null ? (pct! / 100).clamp(0.0, 1.0) : 0.0;
    final displayText = pct != null ? '${pct!.toStringAsFixed(1)}%' : 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          label,
          style: typography.bodyDefault.copyWith(
            color: palette.contentSecondary,
          ),
        ),
        const SizedBox(height: 6),
        // Bar + percentage on same row
        Row(
          children: [
            // Animated progress bar
            Expanded(
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: progress),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                builder: (context, value, _) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(100),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 8,
                      backgroundColor: trackColor,
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            // Percentage value — fixed width so bars align
            SizedBox(
              width: 52,
              child: Text(
                displayText,
                textAlign: TextAlign.right,
                style: typography.bodyLargeBold.copyWith(color: barColor),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// DETAILED BREAKDOWN
// =============================================================================

class _DetailedBreakdown extends StatelessWidget {
  final AuditEvaluationMetrics metrics;
  final MaritaColorPalette palette;
  final MaritaTypographyAccessor typography;

  const _DetailedBreakdown({
    required this.metrics,
    required this.palette,
    required this.typography,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        _Indicator(
          icon: Icons.check_circle_rounded,
          color: palette.success,
          text: '${metrics.fullCorrectCount} fully correct',
          typography: typography,
          palette: palette,
        ),
        _Indicator(
          icon: Icons.info_rounded,
          color: palette.warning,
          text: '${metrics.semiCorrectCount} partial/approx',
          typography: typography,
          palette: palette,
        ),
        _Indicator(
          icon: Icons.cancel_rounded,
          color: palette.error,
          text: '${metrics.incorrectCount} incorrect',
          typography: typography,
          palette: palette,
        ),
      ],
    );
  }
}

class _Indicator extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final MaritaTypographyAccessor typography;
  final MaritaColorPalette palette;

  const _Indicator({
    required this.icon,
    required this.color,
    required this.text,
    required this.typography,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: typography.bodySmall.copyWith(color: palette.contentSecondary),
        ),
      ],
    );
  }
}

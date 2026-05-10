// =============================================================================
// MARITA LOADING INDICATOR
// =============================================================================
//
// A reusable loading indicator using Marita Design System tokens.
//
// Provides three variants:
//   - Inline spinner (for buttons, inputs, small areas)
//   - Full-area overlay (for cards, sections)
//   - Full-screen overlay (for page-level loading)
//
// Usage:
//   // Inline spinner
//   MaritaLoadingIndicator()
//
//   // With label
//   MaritaLoadingIndicator(
//     label: 'Analyzing report...',
//   )
//
//   // Full-screen overlay
//   MaritaLoadingIndicator.fullScreen(
//     label: 'Processing financial data...',
//   )
//
// Rules (from ui_component_developer.md):
//   - No hardcoded values
//   - Use semantic color tokens
//   - Must be reusable
//
// =============================================================================

import 'package:flutter/material.dart';

import '../design_system/marita_design_system.dart';

/// The size variant of the loading indicator.
enum MaritaLoadingSize {
  /// Small — 16px. For inline use inside buttons, badges.
  small,

  /// Medium — 24px. Default for standalone indicators.
  medium,

  /// Large — 32px. For empty states, overlays.
  large,
}

/// Marita's standard loading indicator.
///
/// Uses [context.maritaColors.interactiveSecondary] as the spinner color to maintain
/// visibility on both primary and secondary backgrounds.
///
/// ```dart
/// MaritaLoadingIndicator(
///   label: 'Loading...',
///   size: MaritaLoadingSize.medium,
/// )
/// ```
class MaritaLoadingIndicator extends StatelessWidget {
  const MaritaLoadingIndicator({
    super.key,
    this.label,
    this.size = MaritaLoadingSize.medium,
    this.color,
  });

  /// Full-screen centered loading overlay.
  ///
  /// Renders as a centered column with spinner + optional label,
  /// filling the available space.
  ///
  /// ```dart
  /// MaritaLoadingIndicator.fullScreen(
  ///   label: 'Analyzing financial data...',
  /// )
  /// ```
  const MaritaLoadingIndicator.fullScreen({super.key, this.label, this.color})
    : size = MaritaLoadingSize.large;

  /// Optional label shown below the spinner.
  final String? label;

  /// Size variant. Defaults to [MaritaLoadingSize.medium].
  final MaritaLoadingSize size;

  /// Custom spinner color. Defaults to [context.maritaColors.interactiveSecondary].
  final Color? color;

  double get _dimension {
    switch (size) {
      case MaritaLoadingSize.small:
        return MaritaSizing.iconSmall;
      case MaritaLoadingSize.medium:
        return MaritaSizing.iconMedium;
      case MaritaLoadingSize.large:
        return MaritaSizing.iconLarge;
    }
  }

  double get _strokeWidth {
    switch (size) {
      case MaritaLoadingSize.small:
        return 2.0;
      case MaritaLoadingSize.medium:
        return 2.5;
      case MaritaLoadingSize.large:
        return 3.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color spinnerColor =
        color ?? context.maritaColors.interactiveSecondary;

    final Widget spinner = SizedBox(
      width: _dimension,
      height: _dimension,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(spinnerColor),
      ),
    );

    // Inline (no label) — just return the spinner
    if (label == null) {
      return spinner;
    }

    // With label — stack vertically
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        spinner,
        const SizedBox(height: MaritaSpacing.md),
        Text(
          label!,
          style: MaritaTypography.bodyDefault.copyWith(
            color: context.maritaColors.contentSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

/// A full-screen loading overlay that can be shown on top of content.
///
/// Renders a semi-transparent barrier with a centered [MaritaLoadingIndicator].
///
/// ```dart
/// Stack(
///   children: [
///     PageContent(),
///     if (isLoading) MaritaLoadingOverlay(label: 'Please wait...'),
///   ],
/// )
/// ```
class MaritaLoadingOverlay extends StatelessWidget {
  const MaritaLoadingOverlay({super.key, this.label});

  /// Optional label displayed below the spinner.
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.maritaColors.backgroundPrimary.withValues(alpha: 0.85),
      child: Center(child: MaritaLoadingIndicator.fullScreen(label: label)),
    );
  }
}

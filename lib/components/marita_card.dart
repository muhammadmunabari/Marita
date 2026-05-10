// =============================================================================
// MARITA CARD
// =============================================================================
//
// A reusable surface container using Marita Design System tokens.
//
// Supports states: default, loading, error, disabled.
//
// Usage:
//   MaritaCard(
//     child: Text('Revenue summary'),
//   )
//
//   MaritaCard(
//     title: 'Beneish M-Score',
//     subtitle: 'Financial health indicator',
//     trailing: MaritaIcon(icon: MaritaIcons.chart),
//     onTap: () => navigateToDetail(),
//     child: ScoreWidget(),
//   )
//
//   MaritaCard.error(
//     title: 'Analysis Failed',
//     subtitle: 'Unable to process financial data.',
//     child: RetryButton(),
//   )
//
// Rules (from ui_component_developer.md):
//   - No screen-specific styling
//   - Must be reusable
//   - Must support: default, loading, error, disabled
//   - No hardcoded values
//
// =============================================================================

import 'package:flutter/material.dart';

import '../design_system/marita_design_system.dart';
import '../design_system/marita_icons.dart';

/// The visual state of a [MaritaCard].
enum MaritaCardState {
  /// Normal interactive state.
  defaultState,

  /// Loading — shows shimmer/spinner overlay.
  loading,

  /// Error — highlights border in error color.
  error,

  /// Disabled — reduced opacity, non-interactive.
  disabled,
}

/// Marita's standard surface container.
///
/// A flexible card widget that can display a title/subtitle header, trailing
/// widget, and arbitrary child content. Fully compliant with Marita tokens.
///
/// ```dart
/// MaritaCard(
///   title: 'Revenue',
///   subtitle: 'Q3 2026',
///   child: RevenueChart(),
/// )
/// ```
class MaritaCard extends StatelessWidget {
  const MaritaCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.child,
    this.onTap,
    this.state = MaritaCardState.defaultState,
    this.padding,
  });

  /// Convenience constructor for the **error** state with a pre-configured
  /// error icon in the trailing position.
  const MaritaCard.error({
    super.key,
    this.title,
    this.subtitle,
    this.child,
    this.onTap,
    this.padding,
  }) : state = MaritaCardState.error,
       trailing = null;

  /// Convenience constructor for the **loading** state.
  const MaritaCard.loading({
    super.key,
    this.title,
    this.subtitle,
    this.child,
    this.padding,
  }) : state = MaritaCardState.loading,
       trailing = null,
       onTap = null;

  /// Optional title displayed in the card header.
  final String? title;

  /// Optional subtitle displayed below the title.
  final String? subtitle;

  /// Optional trailing widget in the header row (e.g. icon, badge).
  final Widget? trailing;

  /// The main content of the card.
  final Widget? child;

  /// Callback when the card is tapped. `null` makes it non-tappable.
  final VoidCallback? onTap;

  /// The visual state of the card.
  final MaritaCardState state;

  /// Custom padding override. Defaults to [MaritaSpacing.lg] all around.
  final EdgeInsetsGeometry? padding;

  bool get _isDisabled => state == MaritaCardState.disabled;
  bool get _isLoading => state == MaritaCardState.loading;
  bool get _isError => state == MaritaCardState.error;

  @override
  Widget build(BuildContext context) {
    final bool hasHeader =
        title != null || subtitle != null || trailing != null;

    final Widget content = Padding(
      padding: padding ?? const EdgeInsets.all(MaritaSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header row
          if (hasHeader) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (title != null)
                        Text(
                          title!,
                          style: MaritaTypography.bodyLargeBold.copyWith(
                            color:
                                _isDisabled
                                    ? context.maritaColors.contentTertiary
                                    : _isError
                                    ? context.maritaColors.error
                                    : context.maritaColors.contentPrimary,
                          ),
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: MaritaSpacing.xs),
                        Text(
                          subtitle!,
                          style: MaritaTypography.bodyDefault.copyWith(
                            color:
                                _isDisabled
                                    ? context.maritaColors.contentTertiary
                                    : context.maritaColors.contentSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Trailing widget or error/loading indicator
                if (_isError)
                  MaritaIcon(
                    icon: MaritaIcons.warningActive,
                    size: MaritaIconSize.medium,
                    color: context.maritaColors.error,
                  )
                else if (_isLoading)
                  SizedBox(
                    width: MaritaIconSize.medium,
                    height: MaritaIconSize.medium,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.maritaColors.contentTertiary,
                      ),
                    ),
                  )
                else if (trailing != null)
                  trailing!,
              ],
            ),

            // Separator between header and content
            if (child != null) const SizedBox(height: MaritaSpacing.md),
          ],

          // Child content
          if (child != null) child!,
        ],
      ),
    );

    return Opacity(
      opacity: _isDisabled ? 0.5 : 1.0,
      child: Material(
        color: context.maritaColors.backgroundPrimary,
        elevation: MaritaElevation.low,
        borderRadius: MaritaRadius.borderMedium,
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: MaritaRadius.borderMedium,
            border: Border.all(
              color:
                  _isError
                      ? context.maritaColors.error
                      : context.maritaColors.borderPrimary,
            ),
          ),
          child:
              onTap != null && !_isDisabled && !_isLoading
                  ? InkWell(
                    onTap: onTap,
                    borderRadius: MaritaRadius.borderMedium,
                    splashColor: context.maritaColors.interactivePrimary
                        .withValues(alpha: 0.12),
                    highlightColor: context.maritaColors.interactivePrimary
                        .withValues(alpha: 0.06),
                    child: content,
                  )
                  : content,
        ),
      ),
    );
  }
}

// =============================================================================
// MARITA PRIMARY BUTTON
// =============================================================================
//
// A reusable primary action button using Marita Design System tokens.
//
// Supports states: default, loading, disabled, with optional icon.
//
// Usage:
//   MaritaPrimaryButton(
//     label: 'Analyze',
//     onPressed: () => doSomething(),
//   )
//
//   MaritaPrimaryButton(
//     label: 'Upload Report',
//     icon: MaritaIcons.uploadActive,  // Bold for primary buttons
//     isLoading: true,
//     onPressed: null,
//   )
//
// Rules (from ui_component_developer.md):
//   - Primary Button icon → Bold style
//   - Minimum tap area: 44px (satisfied — height is 48px)
//   - No hardcoded values
//   - Must support: default, loading, disabled
//
// =============================================================================

import 'package:flutter/material.dart';

import '../design_system/marita_design_system.dart';
import '../design_system/marita_icons.dart';

/// Marita's primary call-to-action button.
///
/// Renders with [MaritaColors.interactivePrimary] background and
/// [MaritaColors.contentPrimary] foreground. Automatically handles
/// loading, disabled, and icon states.
///
/// ```dart
/// MaritaPrimaryButton(
///   label: 'Submit',
///   onPressed: _submit,
/// )
/// ```
class MaritaPrimaryButton extends StatelessWidget {
  const MaritaPrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.isExpanded = true,
  });

  /// The button label text.
  final String label;

  /// Callback when the button is tapped. Pass `null` to disable.
  final VoidCallback? onPressed;

  /// Optional leading icon. Must use **Bold** variant from [MaritaIcons].
  final IconData? icon;

  /// When `true`, shows a loading spinner and disables interaction.
  final bool isLoading;

  /// When `true`, the button stretches to fill available width.
  /// Defaults to `true`.
  final bool isExpanded;

  /// Whether the button is functionally disabled.
  bool get _isDisabled => onPressed == null || isLoading;

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;

    final Widget child;
    if (isLoading) {
      child = SizedBox(
        width: MaritaIconSize.medium,
        height: MaritaIconSize.medium,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            colors.contentInverse,
          ),
        ),
      );
    } else if (icon != null) {
      child = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          MaritaIcon(
            icon: icon!,
            size: MaritaIconSize.medium,
            color: _isDisabled ? colors.contentTertiary : colors.contentInverse,
          ),
          const SizedBox(width: MaritaSpacing.sm),
          Text(label),
        ],
      );
    } else {
      child = Text(label);
    }

    final ButtonStyle style = ElevatedButton.styleFrom(
      backgroundColor:
          _isDisabled ? colors.interactiveDisabled : colors.interactivePrimary,
      foregroundColor:
          _isDisabled ? colors.contentTertiary : colors.contentInverse,
      disabledBackgroundColor: colors.interactiveDisabled,
      disabledForegroundColor: colors.contentTertiary,
      minimumSize:
          isExpanded
              ? const Size.fromHeight(MaritaSizing.buttonHeight)
              : const Size(0, MaritaSizing.buttonHeight),
      padding: const EdgeInsets.symmetric(
        horizontal: MaritaSpacing.xl,
        vertical: MaritaSpacing.md,
      ),
      shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderFull),
      textStyle: MaritaTypography.bodyLargeBold,
      elevation: 0,
    );

    return ElevatedButton(
      style: style,
      onPressed: _isDisabled ? null : onPressed,
      child: child,
    );
  }
}

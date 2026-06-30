// =============================================================================
// MARITA TEXT INPUT
// =============================================================================
//
// A reusable text input field using Marita Design System tokens.
//
// Supports states: default, focused, error, disabled, loading.
//
// Usage:
//   MaritaTextInput(
//     label: 'Company Name',
//     hint: 'e.g. PT Marita Teknologi',
//     controller: _nameController,
//   )
//
//   MaritaTextInput(
//     label: 'Revenue',
//     prefixIcon: MaritaIcons.chart,  // Linear for input prefix
//     errorText: 'Revenue is required',
//     controller: _revenueController,
//   )
//
// Rules (from ui_component_developer.md):
//   - Input prefix → Linear icon style
//   - Error icon → Bold (error color)
//   - No hardcoded values
//   - Must support: default, focused, error, disabled, loading
//
// =============================================================================

import 'package:flutter/material.dart';

import '../design_system/marita_design_system.dart';
import '../design_system/marita_icons.dart';

/// Marita's standard text input field.
///
/// Wraps [TextField] with full design system compliance — semantic colors,
/// typography, spacing, radius, and icon usage.
///
/// ```dart
/// MaritaTextInput(
///   label: 'Email',
///   hint: 'you@example.com',
///   controller: _emailController,
///   keyboardType: TextInputType.emailAddress,
/// )
/// ```
class MaritaTextInput extends StatelessWidget {
  const MaritaTextInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.errorText,
    this.helperText,
    this.prefixIcon,
    this.prefixWidget,
    this.suffixIcon,
    this.onSuffixIconTap,
    this.obscureText = false,
    this.enabled = true,
    this.isLoading = false,
    this.readOnly = false,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.autofillHints,
  });

  /// Text editing controller.
  final TextEditingController? controller;

  /// Floating label above the input.
  final String? label;

  /// Placeholder text when the input is empty.
  final String? hint;

  /// Error message. When non-null, the input enters **error** state.
  final String? errorText;

  /// Helper text shown below the input in default state.
  final String? helperText;

  /// Optional leading icon. Must use **Linear** variant from [MaritaIcons].
  final IconData? prefixIcon;

  /// Optional custom widget for leading area. Overrides prefixIcon if provided.
  final Widget? prefixWidget;

  /// Optional trailing icon (e.g. visibility toggle, clear).
  final IconData? suffixIcon;

  /// Callback when suffix icon is tapped.
  final VoidCallback? onSuffixIconTap;

  /// Whether to obscure text (for password fields).
  final bool obscureText;

  /// Whether the input is enabled. `false` = disabled state.
  final bool enabled;

  /// When `true`, shows a loading indicator in the suffix position.
  final bool isLoading;

  /// When `true`, the field is read-only but visually enabled.
  final bool readOnly;

  /// Number of visible lines. Set >1 for textarea behavior.
  final int maxLines;

  /// Keyboard type hint.
  final TextInputType? keyboardType;

  /// Action button on the soft keyboard.
  final TextInputAction? textInputAction;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits (e.g. presses Enter).
  final ValueChanged<String>? onSubmitted;

  /// Focus node for programmatic focus management.
  final FocusNode? focusNode;

  /// Autofill hints for the platform.
  final Iterable<String>? autofillHints;

  /// Whether the field is in error state.
  bool get _hasError => errorText != null && errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label
        if (label != null) ...[
          Text(
            label!,
            style: MaritaTypography.bodyDefaultBold.copyWith(
              color:
                  _hasError
                      ? context.maritaColors.error
                      : enabled
                      ? context.maritaColors.contentPrimary
                      : context.maritaColors.contentTertiary,
            ),
          ),
          const SizedBox(height: MaritaSpacing.sm),
        ],

        // Input field
        SizedBox(
          height: maxLines > 1 ? null : MaritaSizing.inputHeight,
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            enabled: enabled && !isLoading,
            readOnly: readOnly,
            maxLines: maxLines,
            keyboardType: keyboardType,
            textInputAction: textInputAction,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            autofillHints: autofillHints,
            style: MaritaTypography.bodyLarge.copyWith(
              color:
                  enabled
                      ? context.maritaColors.contentPrimary
                      : context.maritaColors.contentTertiary,
            ),
            cursorColor: context.maritaColors.interactivePrimary,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: MaritaTypography.bodyDefault.copyWith(
                color: context.maritaColors.contentTertiary,
              ),
              filled: true,
              fillColor:
                  enabled
                      ? context.maritaColors.backgroundPrimary
                      : context.maritaColors.backgroundSecondary,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: MaritaSpacing.lg,
                vertical: MaritaSpacing.md,
              ),

              // Prefix icon — Linear style
              prefixIcon:
                  prefixWidget ??
                  (prefixIcon != null
                      ? Padding(
                        padding: const EdgeInsets.only(
                          left: MaritaSpacing.lg,
                          right: MaritaSpacing.sm,
                        ),
                        child: MaritaIcon(
                          icon: prefixIcon!,
                          size: MaritaIconSize.medium,
                          color:
                              _hasError
                                  ? context.maritaColors.error
                                  : enabled
                                  ? context.maritaColors.contentSecondary
                                  : context.maritaColors.contentDisabled,
                        ),
                      )
                      : null),
              prefixIconConstraints:
                  (prefixIcon != null || prefixWidget != null)
                      ? const BoxConstraints(
                        minWidth: MaritaIconSize.medium,
                        minHeight: MaritaIconSize.medium,
                      )
                      : null,

              // Suffix: loading spinner OR icon
              suffixIcon: _buildSuffix(context),
              suffixIconConstraints: const BoxConstraints(
                minWidth: MaritaIconSize.medium,
                minHeight: MaritaIconSize.medium,
              ),

              // Borders
              border: OutlineInputBorder(
                borderRadius: MaritaRadius.borderMedium,
                borderSide: BorderSide(
                  color: context.maritaColors.borderPrimary,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: MaritaRadius.borderMedium,
                borderSide: BorderSide(
                  color:
                      _hasError
                          ? context.maritaColors.error
                          : context.maritaColors.borderPrimary,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: MaritaRadius.borderMedium,
                borderSide: BorderSide(
                  color:
                      _hasError
                          ? context.maritaColors.error
                          : context.maritaColors.interactivePrimary,
                  width: 2,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: MaritaRadius.borderMedium,
                borderSide: BorderSide(
                  color: context.maritaColors.borderPrimary,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: MaritaRadius.borderMedium,
                borderSide: BorderSide(color: context.maritaColors.error),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: MaritaRadius.borderMedium,
                borderSide: BorderSide(
                  color: context.maritaColors.error,
                  width: 2,
                ),
              ),
            ),
          ),
        ),

        // Error text
        if (_hasError) ...[
          const SizedBox(height: MaritaSpacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Error icon → Bold style per directive
              Padding(
                padding: const EdgeInsets.only(top: 2.0),
                child: MaritaIcon(
                  icon: MaritaIcons.warningActive,
                  size: MaritaIconSize.small,
                  color: context.maritaColors.error,
                ),
              ),
              const SizedBox(width: MaritaSpacing.xs),
              Expanded(
                child: Text(
                  errorText!,
                  style: MaritaTypography.bodyDefault.copyWith(
                    color: context.maritaColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Helper text
        if (!_hasError && helperText != null) ...[
          const SizedBox(height: MaritaSpacing.xs),
          Text(
            helperText!,
            style: MaritaTypography.bodyDefault.copyWith(
              color: context.maritaColors.contentTertiary,
            ),
          ),
        ],
      ],
    );
  }

  Widget? _buildSuffix(BuildContext context) {
    final colors = context.maritaColors;

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.only(
          right: MaritaSpacing.lg,
          left: MaritaSpacing.sm,
        ),
        child: SizedBox(
          width: MaritaIconSize.small,
          height: MaritaIconSize.small,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              colors.contentDisabled,
            ),
          ),
        ),
      );
    }

    if (suffixIcon != null) {
      return GestureDetector(
        onTap: onSuffixIconTap,
        child: Padding(
          padding: const EdgeInsets.only(
            right: MaritaSpacing.lg,
            left: MaritaSpacing.sm,
          ),
          child: MaritaIcon(
            icon: suffixIcon!,
            size: MaritaIconSize.medium,
            color: _hasError ? colors.error : colors.contentSecondary,
          ),
        ),
      );
    }

    // Error state shows trailing warning icon automatically
    if (_hasError) {
      return Padding(
        padding: const EdgeInsets.only(
          right: MaritaSpacing.lg,
          left: MaritaSpacing.sm,
        ),
        child: MaritaIcon(
          icon: MaritaIcons.warningActive,
          size: MaritaIconSize.medium,
          color: colors.error,
        ),
      );
    }

    return null;
  }
}

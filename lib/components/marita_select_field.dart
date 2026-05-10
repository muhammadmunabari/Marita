import 'package:flutter/material.dart';
import '../design_system/marita_design_system.dart';
import '../design_system/marita_icons.dart';

/// A selector field for the Marita Design System.
/// 
/// Matches the style of MaritaTextInput but optimized for selection (dropdowns).
/// Displays a value and a label inside the field container.
class MaritaSelectField extends StatelessWidget {
  const MaritaSelectField({
    super.key,
    required this.label,
    required this.value,
    this.onTap,
    this.enabled = true,
    this.errorText,
    this.suffixWidget,
  });

  /// The label shown at the bottom of the field.
  final String label;

  /// The current value shown at the top of the field.
  final String value;

  /// Callback when the field is tapped.
  final VoidCallback? onTap;

  /// Whether the field is interactive.
  final bool enabled;

  /// Optional error message.
  final String? errorText;

  /// Optional custom suffix widget (e.g. "Rp" text or specific icon).
  final Widget? suffixWidget;

  bool get _hasError => errorText != null && errorText!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = context.maritaColors;
    final typography = context.maritaTypography;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            height: 56, // Slightly taller to fit two lines of text comfortably
            padding: const EdgeInsets.symmetric(
              horizontal: MaritaSpacing.lg,
              vertical: MaritaSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: enabled ? colors.backgroundPrimary : colors.backgroundSecondary,
              borderRadius: MaritaRadius.borderMedium,
              border: Border.all(
                color: _hasError 
                  ? colors.error 
                  : colors.borderPrimary,
                width: _hasError ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        value,
                        style: typography.bodyLarge.copyWith(
                          color: enabled ? colors.contentPrimary : colors.contentTertiary,
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: typography.bodyDefault.copyWith(
                          color: _hasError ? colors.error : colors.contentSecondary,
                          fontSize: 10, // Explicitly smaller for the inner label
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),
                if (suffixWidget != null) ...[
                  suffixWidget!,
                  const SizedBox(width: MaritaSpacing.xs),
                ],
                MaritaIcon(
                  icon: MaritaIcons.arrowDown,
                  size: MaritaIconSize.medium,
                  color: _hasError ? colors.error : colors.contentSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_hasError) ...[
          const SizedBox(height: MaritaSpacing.xs),
          Row(
            children: [
              MaritaIcon(
                icon: MaritaIcons.warningActive,
                size: MaritaIconSize.small,
                color: colors.error,
              ),
              const SizedBox(width: MaritaSpacing.xs),
              Expanded(
                child: Text(
                  errorText!,
                  style: typography.bodyDefault.copyWith(color: colors.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

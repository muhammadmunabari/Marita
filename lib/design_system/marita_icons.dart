// =============================================================================
// MARITA ICONS v1.0
// =============================================================================
//
// Icon system wrapper over Iconsax.
//
// Rules (from design_system_architect.md):
//   - Use Iconsax ONLY — no Material Icons
//   - Linear style = default state
//   - Bold style = active / selected state
//   - Do NOT mix icon styles within a single screen
//   - All icons must use size & color tokens from MaritaSizing / MaritaColors
//
// Usage:
//   MaritaIcons.home              → Linear (default)
//   MaritaIcons.homeActive        → Bold (active/selected)
//
//   MaritaIcon(
//     icon: MaritaIcons.chart,
//     size: MaritaIconSize.medium,
//     color: MaritaColors.contentPrimary,
//   )
//
// Dependency: iconsax_plus (add to pubspec.yaml)
//   dependencies:
//     iconsax_plus: ^2.0.0
//
// =============================================================================

import 'package:flutter/material.dart';
import 'package:iconsax_plus/iconsax_plus.dart';

import 'marita_design_system.dart';

// =============================================================================
// ICON SIZE TOKENS
// =============================================================================

/// Semantic icon size tokens aligned with [MaritaSizing].
///
/// Always use these instead of raw double values.
class MaritaIconSize {
  MaritaIconSize._();

  /// Extra small icon — 12px.
  static const double extraSmall = MaritaSizing.iconExtraSmall;

  /// Small icon — 16px. For inline indicators, badges.
  static const double small = MaritaSizing.iconSmall;

  /// Medium icon — 24px. Default size for UI icons.
  static const double medium = MaritaSizing.iconMedium;

  /// Large icon — 32px. For hero icons, empty states.
  static const double large = MaritaSizing.iconLarge;
}

// =============================================================================
// ICON COLOR TOKENS
// =============================================================================

/// Semantic icon color tokens derived from [MaritaColors] content layer.
///
/// Use these to ensure icons follow the same semantic meaning as text.
/// Semantic icon color tokens derived from [MaritaColors] content layer.
///
/// Use these to ensure icons follow the same semantic meaning as text.
/// Prefer using [context.maritaColors] directly or omitting color in [MaritaIcon]
/// to use the default primary color.
class MaritaIconColor {
  MaritaIconColor._();

  /// Primary icon color getter.
  static Color primary(BuildContext context) =>
      context.maritaColors.contentPrimary;

  /// Secondary icon color getter.
  static Color secondary(BuildContext context) =>
      context.maritaColors.contentSecondary;

  /// Inverse icon color getter.
  static Color inverse(BuildContext context) =>
      context.maritaColors.contentInverse;

  /// Disabled icon color getter.
  static Color disabled(BuildContext context) =>
      context.maritaColors.contentDisabled;

  /// Success icon color getter.
  static Color success(BuildContext context) => context.maritaColors.success;

  /// Warning icon color getter.
  static Color warning(BuildContext context) => context.maritaColors.warning;

  /// Error icon color getter.
  static Color error(BuildContext context) => context.maritaColors.error;
}

// =============================================================================
// ICON MAPPINGS
// =============================================================================

/// Centralized icon registry for the Marita app.
///
/// Each icon has two variants:
///   - **Default** (Linear) — Used for unselected / idle states.
///   - **Active** (Bold) — Used for selected / active states.
///
/// ⚠️ Do NOT use `Icons.*` (Material) anywhere in the app.
/// ⚠️ Do NOT mix Linear and Bold icons on the same screen.
class MaritaIcons {
  MaritaIcons._();

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  /// Home — default (Linear)
  static const IconData home = IconsaxPlusLinear.home_2;

  /// Home — active (Bold)
  static const IconData homeActive = IconsaxPlusBold.home_2;

  // ---------------------------------------------------------------------------
  // Analytics
  // ---------------------------------------------------------------------------

  /// Chart — default (Linear)
  static const IconData chart = IconsaxPlusLinear.chart_2;

  /// Chart — active (Bold)
  static const IconData chartActive = IconsaxPlusBold.chart_2;

  // ---------------------------------------------------------------------------
  // Reports
  // ---------------------------------------------------------------------------

  /// Report — default (Linear)
  static const IconData report = IconsaxPlusLinear.document_text;

  /// Report — active (Bold)
  static const IconData reportActive = IconsaxPlusBold.document_text;

  /// folder — default (Linear)
  static const IconData folder = IconsaxPlusLinear.folder_2;

  /// folder — active (Bold)
  static const IconData folderActive = IconsaxPlusBold.folder_2;

  // ---------------------------------------------------------------------------
  // Upload / Import
  // ---------------------------------------------------------------------------

  /// Upload — default (Linear)
  static const IconData upload = IconsaxPlusLinear.document_upload;

  /// Upload — active (Bold)
  static const IconData uploadActive = IconsaxPlusBold.document_upload;

  // ---------------------------------------------------------------------------
  // User / Profile
  // ---------------------------------------------------------------------------

  /// User — default (Linear)
  static const IconData user = IconsaxPlusLinear.profile_circle;

  /// User — active (Bold)
  static const IconData userActive = IconsaxPlusBold.profile_circle;

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  /// Settings — default (Linear)
  static const IconData settings = IconsaxPlusLinear.setting_2;

  /// Settings — active (Bold)
  static const IconData settingsActive = IconsaxPlusBold.setting_2;

  // ---------------------------------------------------------------------------
  // Sentiment / Status
  // ---------------------------------------------------------------------------

  /// Warning — default (Linear)
  static const IconData warning = IconsaxPlusLinear.warning_2;

  /// Warning — active (Bold)
  static const IconData warningActive = IconsaxPlusBold.warning_2;

  /// Success / Check — default (Linear)
  static const IconData success = IconsaxPlusLinear.tick_circle;

  /// Success / Check — active (Bold)
  static const IconData successActive = IconsaxPlusBold.tick_circle;

  // ---------------------------------------------------------------------------
  // Common utility icons
  // ---------------------------------------------------------------------------

  /// Arrow left / back — default (Linear)
  static const IconData arrowLeft = IconsaxPlusLinear.arrow_left_1;

  /// Arrow right / forward — default (Linear)
  static const IconData arrowRight = IconsaxPlusLinear.arrow_right_1;

  /// Close / dismiss — default (Linear)
  static const IconData close = IconsaxPlusLinear.close_circle;

  /// Search — default (Linear)
  static const IconData search = IconsaxPlusLinear.search_normal;

  /// Notification — default (Linear)
  static const IconData notification = IconsaxPlusLinear.notification;

  /// Notification — active (Bold)
  static const IconData notificationActive = IconsaxPlusBold.notification;

  /// More / overflow menu — default (Linear)
  static const IconData more = IconsaxPlusLinear.more;

  /// Calendar — default (Linear)
  static const IconData calendar = IconsaxPlusLinear.calendar;

  /// Calendar — active (Bold)
  static const IconData calendarActive = IconsaxPlusBold.calendar;

  /// Info — default (Linear)
  static const IconData info = IconsaxPlusLinear.info_circle;

  /// Logout — default (Linear)
  static const IconData logout = IconsaxPlusLinear.logout;

  /// Add / create — default (Linear)
  static const IconData add = IconsaxPlusLinear.add_circle;

  /// Trash / delete — default (Linear)
  static const IconData trash = IconsaxPlusLinear.trash;

  /// Edit — default (Linear)
  static const IconData edit = IconsaxPlusLinear.edit_2;

  /// Eye / visibility — default (Linear)
  static const IconData eye = IconsaxPlusLinear.eye;

  /// Arrow up — default (Linear)
  static const IconData arrowUp = IconsaxPlusLinear.arrow_up_1;

  /// Magic star / AI — default (Linear)
  static const IconData magicStar = IconsaxPlusLinear.magic_star;

  /// Eye slash / hide — default (Linear)
  static const IconData eyeSlash = IconsaxPlusLinear.eye_slash;

  /// Arrow Down — default (Linear)
  static const IconData arrowDown = IconsaxPlusLinear.arrow_down_1;

  /// Camera — default (Linear)
  static const IconData camera = IconsaxPlusLinear.camera;

  /// Camera — active (Bold)
  static const IconData cameraActive = IconsaxPlusBold.camera;

  /// Document — default (Linear)
  static const IconData document = IconsaxPlusLinear.document;

  /// Document — active (Bold)
  static const IconData documentActive = IconsaxPlusBold.document;

  /// Gallery / Image — default (Linear)
  static const IconData gallery = IconsaxPlusLinear.gallery;

  /// Gallery / Image — active (Bold)
  static const IconData galleryActive = IconsaxPlusBold.gallery;

  /// Folder Add — default (Linear)
  static const IconData folderAdd = IconsaxPlusLinear.folder_add;

  /// Shield / Security — default (Linear)
  static const IconData shield = IconsaxPlusLinear.shield_security;

  /// Shield / Security — active (Bold)
  static const IconData shieldActive = IconsaxPlusBold.shield_security;

  /// Finger Scan / Biometric — default (Linear)
  static const IconData fingerScan = IconsaxPlusLinear.finger_scan;

  /// Profile Edit — default (Linear)
  static const IconData profileEdit = IconsaxPlusLinear.user_edit;

  /// Copy — default (Linear)
  static const IconData copy = IconsaxPlusLinear.copy;

  /// Download — default (Linear)
  static const IconData download = IconsaxPlusLinear.document_download;

  /// Buildings / Workspace — default (Linear)
  static const IconData buildings = IconsaxPlusLinear.buildings;

  /// Buildings / Workspace — active (Bold)
  static const IconData buildingsActive = IconsaxPlusBold.buildings;

  /// People / Members — default (Linear)
  static const IconData people = IconsaxPlusLinear.people;

  /// Crown / Owner — default (Linear)
  static const IconData crown = IconsaxPlusLinear.crown;

  /// Search — active (Bold)
  static const IconData searchActive = IconsaxPlusBold.search_normal_1;

  /// Grid layout — default (Linear)
  static const IconData grid = IconsaxPlusLinear.grid_1;

  /// List layout — default (Linear)
  static const IconData list = IconsaxPlusLinear.textalign_justifyleft;
}

// =============================================================================
// MARITA ICON WIDGET
// =============================================================================

/// A convenience widget that renders an icon using Marita's design tokens.
///
/// Ensures consistent sizing and coloring across the entire app.
///
/// ```dart
/// MaritaIcon(
///   icon: MaritaIcons.home,
///   size: MaritaIconSize.medium,
///   color: MaritaIconColor.primary,
/// )
/// ```
class MaritaIcon extends StatelessWidget {
  const MaritaIcon({
    super.key,
    required this.icon,
    this.size = MaritaIconSize.medium,
    this.color,
    this.semanticLabel,
  });

  /// The [IconData] to render. Must come from [MaritaIcons].
  final IconData icon;

  /// Icon size. Must come from [MaritaIconSize]. Defaults to medium (24px).
  final double size;

  /// Icon color. Defaults to [context.maritaColors.contentPrimary] if null.
  final Color? color;

  /// Optional accessibility label for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Icon(
      icon,
      size: size,
      color: color ?? context.maritaColors.contentPrimary,
      semanticLabel: semanticLabel,
    );
  }
}

// =============================================================================
// BUILD CONTEXT EXTENSION
// =============================================================================

/// Convenience extension for quick icon access via context.
///
/// ```dart
/// context.maritaIcon(MaritaIcons.home)
/// ```
extension MaritaContextIcons on BuildContext {
  /// Creates a [MaritaIcon] with sensible defaults.
  Widget maritaIcon(
    IconData icon, {
    double size = MaritaIconSize.medium,
    Color? color,
    String? semanticLabel,
  }) {
    return MaritaIcon(
      icon: icon,
      size: size,
      color: color,
      semanticLabel: semanticLabel,
    );
  }
}

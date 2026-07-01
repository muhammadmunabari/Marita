// =============================================================================
// MARITA DESIGN SYSTEM v1.0
// =============================================================================
//
// Production-ready Flutter design system for Marita.
//
// Principles:
//   - No hardcoded values in UI layer
//   - Semantic tokens ONLY
//   - Plus Jakarta Sans exclusively
//   - 4px spacing grid
//
// Usage:
//   import 'package:marita/design_system/marita_design_system.dart';
//
//   // Via class:
//   MaritaColors.contentPrimary
//   MaritaTypography.titleLarge
//   MaritaSpacing.lg
//
//   // Via extension:
//   context.maritaColors.contentPrimary  (requires MaritaTheme ancestor)
//
// =============================================================================

import 'package:flutter/material.dart';

export 'tokens/base_tokens.dart';
export 'tokens/semantic_tokens.dart';
export 'tokens/marita_light_theme.dart';
export 'tokens/marita_dark_theme.dart';

// =============================================================================
// COLORS
// =============================================================================

/// Marita's complete semantic color system.
///
/// Colors are organized into layers:
///   - **Core** — Brand identity primitives (not for direct UI use)
///   - **Content** — Text & icon colors
///   - **Background** — Surface colors
///   - **Interactive** — Buttons, links, tappable elements
///   - **Border** — Dividers, outlines, separators
///   - **Sentiment** — Feedback states (success, warning, error)
class MaritaColors {
  MaritaColors._();

  // ---------------------------------------------------------------------------
  // Core (Brand primitives — prefer semantic tokens via context.maritaColors)
  // ---------------------------------------------------------------------------

  static const Color black = Color(0xFF12120D);
  static const Color white = Color(0xFFFFFFEB);
  static const Color lime = Color(0xFFE4FF1A);

  static const Color cloud100 = Color(0xFFFFFFFD);
  static const Color cloud600 = Color(0xFFFFFFEB);
  static const Color cloud700 = Color(0xFFE8E8D6);
  static const Color cloud800 = Color(0xFFB5B5A7);
  static const Color cloud900 = Color(0xFF8C8C81);

  static const Color shadow100 = Color(0xFFB8B8B6);
  static const Color shadow300 = Color(0xFF656661);
  static const Color shadow400 = Color(0xFF474842);
  static const Color shadow500 = Color(0xFF22231A);
  static const Color shadow700 = Color(0xFF181811);

  static const Color earth500 = Color(0xFF5B6F01);

  static const Color mint500 = Color(0xFF73BA9B);
  static const Color red500 = Color(0xFFF91D30);
  static const Color orange500 = Color(0xFFFF5714);
  static const Color orange700 = Color(0xFFB53E0E);

  static const Color lime100 = Color(0xFFF7FFB8);
  static const Color lime800 = Color(0xFF7D8C0E);
}

/// Marita's semantic color palette that adapts to the current theme.
class MaritaColorPalette extends ThemeExtension<MaritaColorPalette> {
  final Color contentPrimary;
  final Color contentSecondary;
  final Color contentTertiary;
  final Color contentInverse;
  final Color contentDisabled;
  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color backgroundInverse;
  final Color interactivePrimary;
  final Color interactiveSecondary;
  final Color interactiveDisabled;
  final Color borderPrimary;
  final Color borderSecondary;
  final Color success;
  final Color warning;
  final Color error;

  const MaritaColorPalette({
    required this.contentPrimary,
    required this.contentSecondary,
    required this.contentTertiary,
    required this.contentInverse,
    required this.contentDisabled,
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.backgroundInverse,
    required this.interactivePrimary,
    required this.interactiveSecondary,
    required this.interactiveDisabled,
    required this.borderPrimary,
    required this.borderSecondary,
    required this.success,
    required this.warning,
    required this.error,
  });

  @override
  ThemeExtension<MaritaColorPalette> copyWith({
    Color? contentPrimary,
    Color? contentSecondary,
    Color? contentTertiary,
    Color? contentInverse,
    Color? contentDisabled,
    Color? backgroundPrimary,
    Color? backgroundSecondary,
    Color? backgroundInverse,
    Color? interactivePrimary,
    Color? interactiveSecondary,
    Color? interactiveDisabled,
    Color? borderPrimary,
    Color? borderSecondary,
    Color? success,
    Color? warning,
    Color? error,
  }) {
    return MaritaColorPalette(
      contentPrimary: contentPrimary ?? this.contentPrimary,
      contentSecondary: contentSecondary ?? this.contentSecondary,
      contentTertiary: contentTertiary ?? this.contentTertiary,
      contentInverse: contentInverse ?? this.contentInverse,
      contentDisabled: contentDisabled ?? this.contentDisabled,
      backgroundPrimary: backgroundPrimary ?? this.backgroundPrimary,
      backgroundSecondary: backgroundSecondary ?? this.backgroundSecondary,
      backgroundInverse: backgroundInverse ?? this.backgroundInverse,
      interactivePrimary: interactivePrimary ?? this.interactivePrimary,
      interactiveSecondary: interactiveSecondary ?? this.interactiveSecondary,
      interactiveDisabled: interactiveDisabled ?? this.interactiveDisabled,
      borderPrimary: borderPrimary ?? this.borderPrimary,
      borderSecondary: borderSecondary ?? this.borderSecondary,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      error: error ?? this.error,
    );
  }

  @override
  ThemeExtension<MaritaColorPalette> lerp(
    ThemeExtension<MaritaColorPalette>? other,
    double t,
  ) {
    if (other is! MaritaColorPalette) return this;
    return MaritaColorPalette(
      contentPrimary: Color.lerp(contentPrimary, other.contentPrimary, t)!,
      contentSecondary:
          Color.lerp(contentSecondary, other.contentSecondary, t)!,
      contentTertiary: Color.lerp(contentTertiary, other.contentTertiary, t)!,
      contentInverse: Color.lerp(contentInverse, other.contentInverse, t)!,
      contentDisabled: Color.lerp(contentDisabled, other.contentDisabled, t)!,
      backgroundPrimary:
          Color.lerp(backgroundPrimary, other.backgroundPrimary, t)!,
      backgroundSecondary:
          Color.lerp(backgroundSecondary, other.backgroundSecondary, t)!,
      backgroundInverse:
          Color.lerp(backgroundInverse, other.backgroundInverse, t)!,
      interactivePrimary:
          Color.lerp(interactivePrimary, other.interactivePrimary, t)!,
      interactiveSecondary:
          Color.lerp(interactiveSecondary, other.interactiveSecondary, t)!,
      interactiveDisabled:
          Color.lerp(interactiveDisabled, other.interactiveDisabled, t)!,
      borderPrimary: Color.lerp(borderPrimary, other.borderPrimary, t)!,
      borderSecondary: Color.lerp(borderSecondary, other.borderSecondary, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      error: Color.lerp(error, other.error, t)!,
    );
  }
}

// =============================================================================
// TYPOGRAPHY
// =============================================================================

/// Marita's typography system using Plus Jakarta Sans exclusively.
///
/// Scale layers:
///   - **Display** — Hero headings (96 / 64 / 40). UPPERCASE enforced.
///   - **Title** — Section headings (32 / 24 / 20).
///   - **Body** — Paragraph & UI text (16 / 14).
///   - **Link** — Inline link style (14, underlined).
///
/// Line-height uses tight density as per brand guidelines.
/// Letter-spacing values are expressed as `em` multipliers scaled to px.
class MaritaTypography {
  MaritaTypography._();

  /// The single typeface used throughout the app.
  static const String fontFamily = 'PlusJakartaSans';

  // ---------------------------------------------------------------------------
  // Display — Hero / splash text (always uppercase in usage)
  // ---------------------------------------------------------------------------

  /// Display Large — 96px / height ×0.85 / spacing +0.02em / Bold
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 96,
    height: 0.85,
    letterSpacing: 96 * 0.02, // ≈ 1.92px
    fontWeight: FontWeight.w700,
  );

  /// Display Medium — 64px / height ×0.85 / spacing +0.015em / Bold
  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 64,
    height: 0.85,
    letterSpacing: 64 * 0.015, // ≈ 0.96px
    fontWeight: FontWeight.w700,
  );

  /// Display Small — 40px / height ×0.85 / spacing +0.015em / Bold
  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40,
    height: 0.85,
    letterSpacing: 40 * 0.015, // ≈ 0.60px
    fontWeight: FontWeight.w700,
  );

  // ---------------------------------------------------------------------------
  // Titles — Section headings
  // ---------------------------------------------------------------------------

  /// Title Large — 32px / line-height 36px / spacing -0.02em / SemiBold
  static const TextStyle titleLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 32,
    height: 36 / 32, // 1.125
    letterSpacing: 32 * -0.02, // ≈ -0.64px
    fontWeight: FontWeight.w600,
  );

  /// Title Medium — 24px / line-height 28px / spacing -0.015em / SemiBold
  static const TextStyle titleMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    height: 28 / 24, // ≈ 1.167
    letterSpacing: 24 * -0.015, // ≈ -0.36px
    fontWeight: FontWeight.w600,
  );

  /// Title Small — 20px / line-height 24px / spacing -0.01em / SemiBold
  static const TextStyle titleSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    height: 24 / 20, // 1.2
    letterSpacing: 20 * -0.01, // ≈ -0.20px
    fontWeight: FontWeight.w600,
  );

  // ---------------------------------------------------------------------------
  // Body — Paragraph & UI text
  // ---------------------------------------------------------------------------

  /// Body Large Bold — 16px / line-height 24px / spacing -0.005em / SemiBold
  static const TextStyle bodyLargeBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16, // 1.5
    letterSpacing: 16 * -0.005, // ≈ -0.08px
    fontWeight: FontWeight.w600,
  );

  /// Body Large — 16px / line-height 24px / spacing -0.005em / Regular
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    height: 24 / 16, // 1.5
    letterSpacing: 16 * -0.005, // ≈ -0.08px
    fontWeight: FontWeight.w400,
  );

  /// Body Default Bold — 14px / line-height 20px / spacing +0.01em / SemiBold
  static const TextStyle bodyDefaultBold = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14, // ≈ 1.429
    letterSpacing: 14 * 0.01, // ≈ 0.14px
    fontWeight: FontWeight.w600,
  );

  /// Body Default — 14px / line-height 20px / spacing +0.01em / Regular
  static const TextStyle bodyDefault = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14, // ≈ 1.429
    letterSpacing: 14 * 0.01, // ≈ 0.14px
    fontWeight: FontWeight.w400,
  );

  // ---------------------------------------------------------------------------
  // Link
  // ---------------------------------------------------------------------------

  /// Link Default — 14px / line-height 20px / underline / SemiBold
  static const TextStyle linkDefault = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    height: 20 / 14, // ≈ 1.429
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.underline,
  );
}

// =============================================================================
// SPACING
// =============================================================================

/// Marita's spacing system based on a 4px grid.
///
/// Use these tokens exclusively — never use arbitrary pixel values.
class MaritaSpacing {
  MaritaSpacing._();

  /// 4px — Tight internal padding, icon-to-label gaps.
  static const double xs = 4;

  /// 8px — Small padding, compact list gaps.
  static const double sm = 8;

  /// 12px — Medium padding, card internal spacing.
  static const double md = 12;

  /// 16px — Standard padding, section gaps.
  static const double lg = 16;

  /// 24px — Large padding, between major sections.
  static const double xl = 24;

  /// 32px — Extra-large padding, page-level margins.
  static const double xxl = 32;
}

// =============================================================================
// RADIUS
// =============================================================================

/// Marita's border radius tokens.
class MaritaRadius {
  MaritaRadius._();

  static const double small = 4;
  static const double medium = 8;
  static const double large = 12;
  static const double xlarge = 16;
  static const double full = 999;

  /// Convenience [BorderRadius] values.
  static final BorderRadius borderSmall = BorderRadius.circular(small);
  static final BorderRadius borderMedium = BorderRadius.circular(medium);
  static final BorderRadius borderLarge = BorderRadius.circular(large);
  static final BorderRadius borderXLarge = BorderRadius.circular(xlarge);
  static final BorderRadius borderFull = BorderRadius.circular(full);
}

// =============================================================================
// SIZING
// =============================================================================

/// Marita's fixed sizing tokens for interactive elements and icons.
class MaritaSizing {
  MaritaSizing._();

  /// Standard button height — 48px.
  static const double buttonHeight = 48;

  /// Standard input field height — 48px.
  static const double inputHeight = 48;

  /// Extra small icon size — 12px.
  static const double iconExtraSmall = 12;

  /// Small icon size — 16px.
  static const double iconSmall = 16;

  /// Medium icon size — 24px (default).
  static const double iconMedium = 24;

  /// Large icon size — 32px.
  static const double iconLarge = 32;
}

// =============================================================================
// ELEVATION
// =============================================================================

/// Marita's elevation tokens for shadow depth layering.
class MaritaElevation {
  MaritaElevation._();

  /// Low elevation — subtle lift (e.g. cards).
  static const double low = 2;

  /// Medium elevation — moderate lift (e.g. dropdowns).
  static const double medium = 4;

  /// High elevation — prominent lift (e.g. modals, FABs).
  static const double high = 8;
}

// =============================================================================
// THEME DATA BUILDER
// =============================================================================

/// Generates a [ThemeData] that enforces Marita's design system globally.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: MaritaTheme.dark(),
/// )
/// ```
class MaritaTheme {
  MaritaTheme._();

  /// Builds the dark-mode [ThemeData] aligned with Marita brand.
  static ThemeData dark() {
    const palette = MaritaColorPalette(
      contentPrimary: MaritaColors.cloud100, // Cloud-100 (#FFFFFD)
      contentSecondary: MaritaColors.cloud900, // Cloud-900 (#8C8C81)
      contentTertiary: MaritaColors.cloud900, // Placeholder = textSecondary
      contentInverse: MaritaColors.black,
      contentDisabled: MaritaColors.shadow300, // buttonDisabled text
      backgroundPrimary: MaritaColors.black, // Marita Black (#12120D)
      backgroundSecondary: MaritaColors.shadow500, // Shadow-500 (#22231A)
      backgroundInverse: MaritaColors.cloud100,
      interactivePrimary: MaritaColors.lime,
      interactiveSecondary: MaritaColors.earth500,
      interactiveDisabled: MaritaColors.shadow100, // buttonDisabled background
      borderPrimary: MaritaColors.shadow300, // inputfield stroke
      borderSecondary: MaritaColors.shadow400,
      success: MaritaColors.mint500,
      warning: MaritaColors.orange500,
      error: MaritaColors.red500,
    );

    return _buildTheme(Brightness.dark, palette);
  }

  static ThemeData _buildTheme(
    Brightness brightness,
    MaritaColorPalette palette,
  ) {
    return ThemeData(
      useMaterial3: true,
      fontFamily: MaritaTypography.fontFamily,
      brightness: brightness,
      extensions: [palette],

      // Scaffold
      scaffoldBackgroundColor: palette.backgroundPrimary,

      // Color scheme
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.interactivePrimary,
        onPrimary: palette.contentPrimary,
        secondary: palette.interactiveSecondary,
        onSecondary: palette.contentInverse,
        surface: palette.backgroundPrimary,
        onSurface: palette.contentPrimary,
        error: palette.error,
        onError: palette.contentInverse,
        outline: palette.borderPrimary,
        outlineVariant: palette.borderSecondary,
      ),

      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: palette.backgroundPrimary,
        foregroundColor: palette.contentPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: MaritaTypography.fontFamily,
          fontSize: 20,
          height: 24 / 20,
          letterSpacing: 20 * -0.01,
          fontWeight: FontWeight.w600,
          color: palette.contentPrimary,
        ),
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: MaritaTypography.displayLarge,
        displayMedium: MaritaTypography.displayMedium,
        displaySmall: MaritaTypography.displaySmall,
        headlineLarge: MaritaTypography.titleLarge,
        headlineMedium: MaritaTypography.titleMedium,
        headlineSmall: MaritaTypography.titleSmall,
        titleLarge: MaritaTypography.titleLarge,
        titleMedium: MaritaTypography.titleMedium,
        titleSmall: MaritaTypography.titleSmall,
        bodyLarge: MaritaTypography.bodyLarge,
        bodyMedium: MaritaTypography.bodyDefault,
        bodySmall: MaritaTypography.bodyDefault,
        labelLarge: MaritaTypography.bodyLargeBold,
        labelMedium: MaritaTypography.bodyDefaultBold,
        labelSmall: MaritaTypography.bodyDefaultBold,
      ).apply(
        bodyColor: palette.contentPrimary,
        displayColor: palette.contentPrimary,
      ),

      // Divider
      dividerTheme: DividerThemeData(
        color: palette.borderPrimary,
        thickness: 1,
        space: 0,
      ),

      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: palette.backgroundSecondary,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: MaritaSpacing.lg,
          vertical: MaritaSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: MaritaRadius.borderMedium,
          borderSide: BorderSide(color: palette.borderPrimary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: MaritaRadius.borderMedium,
          borderSide: BorderSide(color: palette.borderPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: MaritaRadius.borderMedium,
          borderSide: BorderSide(color: palette.interactivePrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: MaritaRadius.borderMedium,
          borderSide: BorderSide(color: palette.error),
        ),
        hintStyle: MaritaTypography.bodyDefault.copyWith(
          color: palette.contentTertiary,
        ),
        labelStyle: MaritaTypography.bodyDefaultBold.copyWith(
          color: palette.contentSecondary,
        ),
      ),

      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.interactivePrimary,
          foregroundColor: MaritaColors.black,
          disabledBackgroundColor: palette.interactiveDisabled,
          disabledForegroundColor: palette.contentDisabled,
          minimumSize: const Size.fromHeight(MaritaSizing.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderFull),
          textStyle: MaritaTypography.bodyLargeBold,
          elevation: 0,
        ),
      ),

      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: palette.interactiveSecondary,
          textStyle: MaritaTypography.bodyDefaultBold,
        ),
      ),

      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.contentPrimary,
          minimumSize: const Size.fromHeight(MaritaSizing.buttonHeight),
          shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderFull),
          side: BorderSide(color: palette.borderSecondary),
          textStyle: MaritaTypography.bodyLargeBold,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: palette.backgroundSecondary,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderMedium),
        margin: const EdgeInsets.all(MaritaSpacing.sm),
      ),

      // Bottom navigation
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: palette.backgroundPrimary,
        selectedItemColor: palette.interactivePrimary,
        unselectedItemColor: palette.contentTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: MaritaTypography.bodyDefaultBold,
        unselectedLabelStyle: MaritaTypography.bodyDefault,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.backgroundInverse,
        contentTextStyle: MaritaTypography.bodyDefault.copyWith(
          color: palette.contentInverse,
        ),
        shape: RoundedRectangleBorder(borderRadius: MaritaRadius.borderMedium),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// =============================================================================
// BUILD CONTEXT EXTENSIONS
// =============================================================================

/// Convenience extensions on [BuildContext] for quick access to Marita tokens.
///
/// Usage:
/// ```dart
/// Text(
///   'Hello',
///   style: context.maritaTypography.titleLarge
///       .copyWith(color: context.maritaColors.contentPrimary),
/// )
/// ```
extension MaritaContextColors on BuildContext {
  /// Access Marita color tokens from the current theme.
  MaritaColorPalette get maritaColors {
    final extension = Theme.of(this).extension<MaritaColorPalette>();
    if (extension == null) {
      throw Exception(
        'MaritaColorPalette not found in Theme. Ensure MaritaTheme is used.',
      );
    }
    return extension;
  }
}

extension MaritaContextTypography on BuildContext {
  /// Access Marita typography tokens.
  MaritaTypographyAccessor get maritaTypography =>
      MaritaTypographyAccessor(this);
}

extension MaritaContextSpacing on BuildContext {
  /// Access Marita spacing tokens.
  MaritaSpacingAccessor get maritaSpacing => const MaritaSpacingAccessor();
}

// ---------------------------------------------------------------------------
// Accessor classes
// ---------------------------------------------------------------------------

class MaritaTypographyAccessor {
  final BuildContext context;
  const MaritaTypographyAccessor(this.context);

  // Display
  TextStyle get displayLarge => MaritaTypography.displayLarge;
  TextStyle get displayMedium => MaritaTypography.displayMedium;
  TextStyle get displaySmall => MaritaTypography.displaySmall;

  // Title
  TextStyle get titleLarge => MaritaTypography.titleLarge;
  TextStyle get titleMedium => MaritaTypography.titleMedium;
  TextStyle get titleSmall => MaritaTypography.titleSmall;
  TextStyle get h3 => MaritaTypography.titleSmall;
  TextStyle get h4 => MaritaTypography.titleSmall.copyWith(fontSize: 18);

  // Body
  TextStyle get bodyLargeBold => MaritaTypography.bodyLargeBold;
  TextStyle get bodyLarge => MaritaTypography.bodyLarge;
  TextStyle get bodyDefaultBold => MaritaTypography.bodyDefaultBold;
  TextStyle get bodyDefault => MaritaTypography.bodyDefault;
  TextStyle get bodySmallBold =>
      MaritaTypography.bodyDefaultBold.copyWith(fontSize: 12);
  TextStyle get bodySmall =>
      MaritaTypography.bodyDefault.copyWith(fontSize: 12);
  TextStyle get bodyDisabled => MaritaTypography.bodyDefault.copyWith(
    color: context.maritaColors.contentDisabled,
  );

  // Link
  TextStyle get linkDefault => MaritaTypography.linkDefault;
}

class MaritaSpacingAccessor {
  const MaritaSpacingAccessor();

  double get xs => MaritaSpacing.xs;
  double get sm => MaritaSpacing.sm;
  double get md => MaritaSpacing.md;
  double get lg => MaritaSpacing.lg;
  double get xl => MaritaSpacing.xl;
  double get xxl => MaritaSpacing.xxl;
}

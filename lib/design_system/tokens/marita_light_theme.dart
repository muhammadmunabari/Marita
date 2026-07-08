import 'package:flutter/material.dart';
import 'package:marita/design_system/marita_design_system.dart';

/// Marita's light theme generator.
/// Maps the design token specifications (SemanticColors) to [MaritaColorPalette]
/// and provides the global [ThemeData] in a Forced Light Mode context.
class MaritaLightTheme {
  MaritaLightTheme._();

  /// Builds the light-mode [ThemeData] aligned with the new semantic tokens.
  static ThemeData build() {
    const palette = MaritaColorPalette(
      contentPrimary: SemanticColors.colorTextDefault,
      contentSecondary: SemanticColors.colorTextMuted,
      contentTertiary: SemanticColors.colorTextSubtle,
      contentInverse: SemanticColors.colorTextInverse,
      contentDisabled: SemanticColors.colorTextDisabled,
      backgroundPrimary: SemanticColors.colorBackgroundPage,
      backgroundSecondary: SemanticColors.colorBackgroundSurface,
      backgroundInverse: SemanticColors.colorBackgroundInverse,
      interactivePrimary: SemanticColors.colorButtonPrimaryBackground,
      interactiveSecondary: SemanticColors.colorButtonTextForeground,
      interactiveDisabled: SemanticColors.colorButtonPrimaryDisabledBackground,
      borderPrimary: SemanticColors.colorBorderInput,
      borderSecondary: SemanticColors.colorBorderDefault,
      success: SemanticColors.colorTextSuccess,
      warning: SemanticColors.colorTextWarning,
      error: SemanticColors.colorTextDanger,
    );

    return _buildTheme(Brightness.light, palette);
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

      // Scaffold background
      scaffoldBackgroundColor: palette.backgroundPrimary,

      // Color scheme
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: palette.interactivePrimary,
        onPrimary: palette.contentInverse,
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
          foregroundColor: palette.contentInverse,
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

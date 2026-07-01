import 'package:flutter/material.dart';

// ==========================================
// COLORS
// ==========================================

/// Base color palettes for the Marita AI Design System.
///
/// Contains primitive values only without semantic meaning.
abstract final class BaseColors {
  // Neutral - Cloud (Light gray/white backgrounds and surfaces)
  static const Color cloud50 = Color(0xFFFFFFFF);
  static const Color cloud100 = Color(0xFFFCFCFB);
  static const Color cloud200 = Color(0xFFF8F8F6);
  static const Color cloud300 = Color(0xFFF4F4F2);
  static const Color cloud400 = Color(0xFFEEEEEB);
  static const Color cloud500 = Color(0xFFE7E7E2);
  static const Color cloud600 = Color(0xFFD6D6D0);
  static const Color cloud700 = Color(0xFFC3C3BC);
  static const Color cloud800 = Color(0xFFA8A8A0);
  static const Color cloud900 = Color(0xFF8B8B83);

  // Neutral - Shadow (Dark text, borders, shadows)
  static const Color shadow50 = Color(0xFFF6F6F5);
  static const Color shadow100 = Color(0xFFE5E5E2);
  static const Color shadow200 = Color(0xFFCFCFCA);
  static const Color shadow300 = Color(0xFFA5A69E);
  static const Color shadow400 = Color(0xFF7A7B73);
  static const Color shadow500 = Color(0xFF5C5D55);
  static const Color shadow600 = Color(0xFF474842);
  static const Color shadow700 = Color(0xFF32332E);
  static const Color shadow800 = Color(0xFF22231A);
  static const Color shadow900 = Color(0xFF141510);

  // Brand (Deep professional dark greens)
  static const Color brand50 = Color(0xFFE8ECEA);
  static const Color brand100 = Color(0xFFB9C4BF);
  static const Color brand200 = Color(0xFF97A8A0);
  static const Color brand300 = Color(0xFF688075);
  static const Color brand400 = Color(0xFF4A685A);
  static const Color brand500 = Color(0xFF1D4231);
  static const Color brand600 = Color(0xFF1A3C2D);
  static const Color brand700 = Color(0xFF152F23);
  static const Color brand800 = Color(0xFF10241B);
  static const Color brand900 = Color(0xFF0C1C15);

  // Functional - Blue
  static const Color blue50 = Color(0xFFEFF6FF);
  static const Color blue100 = Color(0xFFDBEAFE);
  static const Color blue200 = Color(0xFFBFDBFE);
  static const Color blue300 = Color(0xFF93C5FD);
  static const Color blue400 = Color(0xFF60A5FA);
  static const Color blue500 = Color(0xFF3B82F6);
  static const Color blue600 = Color(0xFF2563EB);
  static const Color blue700 = Color(0xFF1D4ED8);
  static const Color blue800 = Color(0xFF1E40AF);
  static const Color blue900 = Color(0xFF1E3A8A);

  // Functional - Green
  static const Color green50 = Color(0xFFEFF8F0);
  static const Color green100 = Color(0xFFCEEAD0);
  static const Color green200 = Color(0xFFB6DFB9);
  static const Color green300 = Color(0xFF95D199);
  static const Color green400 = Color(0xFF81C885);
  static const Color green500 = Color(0xFF61BA67);
  static const Color green600 = Color(0xFF58A95E);
  static const Color green700 = Color(0xFF458449);
  static const Color green800 = Color(0xFF356639);
  static const Color green900 = Color(0xFF294E2B);

  // Functional - Red
  static const Color red50 = Color(0xFFFEE8EA);
  static const Color red100 = Color(0xFFFDB9BF);
  static const Color red200 = Color(0xFFFC97A0);
  static const Color red300 = Color(0xFFFB6874);
  static const Color red400 = Color(0xFFFA4A59);
  static const Color red500 = Color(0xFFF91D30);
  static const Color red600 = Color(0xFFE31A2C);
  static const Color red700 = Color(0xFFB11522);
  static const Color red800 = Color(0xFF89101A);
  static const Color red900 = Color(0xFF690C14);

  // Functional - Yellow
  static const Color yellow50 = Color(0xFFFEFBEE);
  static const Color yellow100 = Color(0xFFFCF2C9);
  static const Color yellow200 = Color(0xFFFAECAF);
  static const Color yellow300 = Color(0xFFF8E38B);
  static const Color yellow400 = Color(0xFFF6DD75);
  static const Color yellow500 = Color(0xFFF4D552);
  static const Color yellow600 = Color(0xFFDEC24B);
  static const Color yellow700 = Color(0xFFAD973A);
  static const Color yellow800 = Color(0xFF86752D);
  static const Color yellow900 = Color(0xFF665922);

  // Brand - Lime (dark mode primary brand color, #E4FF1A base)
  static const Color lime100 = Color(0xFFF7FFB8);
  static const Color lime200 = Color(0xFFF2FF8A);
  static const Color lime300 = Color(0xFFECFF5C);
  static const Color lime400 = Color(0xFFE8FF38);
  static const Color lime500 = Color(0xFFE4FF1A); // base lime
  static const Color lime600 = Color(0xFFBDD614);
  static const Color lime700 = Color(0xFF96AC0F);
  static const Color lime800 = Color(0xFF70830B);
  static const Color lime900 = Color(0xFF4A5907);
}

// ==========================================
// OPACITY
// ==========================================

/// Base opacity tokens for overlays, alpha blending, and disabled states.
abstract final class BaseOpacity {
  static const double opacity00 = 0.0;
  static const double opacity04 = 0.04;
  static const double opacity08 = 0.08;
  static const double opacity12 = 0.12;
  static const double opacity16 = 0.16;
  static const double opacity24 = 0.24;
  static const double opacity32 = 0.32;
  static const double opacity48 = 0.48;
  static const double opacity64 = 0.64;
  static const double opacity72 = 0.72;
  static const double opacity80 = 0.80;
  static const double opacity90 = 0.90;
  static const double opacity100 = 1.0;
}

// ==========================================
// SPACE
// ==========================================

/// Base spacing tokens to drive padding, margins, gaps, and positioning.
abstract final class BaseSpacing {
  static const double space0 = 0.0;
  static const double space2 = 2.0;
  static const double space4 = 4.0;
  static const double space6 = 6.0;
  static const double space8 = 8.0;
  static const double space10 = 10.0;
  static const double space12 = 12.0;
  static const double space14 = 14.0;
  static const double space16 = 16.0;
  static const double space20 = 20.0;
  static const double space24 = 24.0;
  static const double space28 = 28.0;
  static const double space32 = 32.0;
  static const double space36 = 36.0;
  static const double space40 = 40.0;
  static const double space48 = 48.0;
  static const double space56 = 56.0;
  static const double space64 = 64.0;
  static const double space72 = 72.0;
  static const double space80 = 80.0;
  static const double space96 = 96.0;
  static const double space112 = 112.0;
  static const double space128 = 128.0;
  static const double space144 = 144.0;
  static const double space160 = 160.0;
  static const double space192 = 192.0;
}

// ==========================================
// RADIUS
// ==========================================

/// Base border radius tokens to shape elements.
abstract final class BaseRadius {
  static const double none = 0.0;
  static const double xxsmall = 2.0;
  static const double xsmall = 4.0;
  static const double small = 6.0;
  static const double medium = 8.0;
  static const double large = 12.0;
  static const double xlarge = 16.0;
  static const double xxlarge = 20.0;
  static const double xxxlarge = 24.0;
  static const double full = 9999.0;
}

// ==========================================
// STROKE
// ==========================================

/// Base border and line stroke width tokens.
abstract final class BaseStroke {
  static const double none = 0.0;
  static const double xthin = 0.5;
  static const double thin = 1.0;
  static const double medium = 1.5;
  static const double thick = 2.0;
  static const double xthick = 3.0;
  static const double xxthick = 4.0;
}

// ==========================================
// ELEVATION
// ==========================================

/// Base elevation tokens providing standard shadow properties.
abstract final class BaseElevation {
  // Raw elevation double values (used for Material widget elevation)
  static const double none = 0.0;
  static const double level1 = 1.0;
  static const double level2 = 2.0;
  static const double level3 = 4.0;
  static const double level4 = 6.0;
  static const double level5 = 8.0;
  static const double level6 = 12.0;

  // BoxShadow properties for light mode rendering
  static const Color shadowColor = Color(0x12141510); // Shadow900 at 7% opacity
  static const Color shadowColorAmbient = Color(
    0x0A141510,
  ); // Shadow900 at 4% opacity

  static const List<BoxShadow> shadowNone = [];

  static const List<BoxShadow> shadowLevel1 = [
    BoxShadow(
      color: shadowColor,
      blurRadius: 2.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 1.0),
    ),
  ];

  static const List<BoxShadow> shadowLevel2 = [
    BoxShadow(
      color: shadowColor,
      blurRadius: 4.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 2.0),
    ),
    BoxShadow(
      color: shadowColorAmbient,
      blurRadius: 2.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 1.0),
    ),
  ];

  static const List<BoxShadow> shadowLevel3 = [
    BoxShadow(
      color: shadowColor,
      blurRadius: 8.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 4.0),
    ),
    BoxShadow(
      color: shadowColorAmbient,
      blurRadius: 4.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 2.0),
    ),
  ];

  static const List<BoxShadow> shadowLevel4 = [
    BoxShadow(
      color: shadowColor,
      blurRadius: 16.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 8.0),
    ),
    BoxShadow(
      color: shadowColorAmbient,
      blurRadius: 8.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 4.0),
    ),
  ];

  static const List<BoxShadow> shadowLevel5 = [
    BoxShadow(
      color: shadowColor,
      blurRadius: 24.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 12.0),
    ),
    BoxShadow(
      color: shadowColorAmbient,
      blurRadius: 12.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 6.0),
    ),
  ];

  static const List<BoxShadow> shadowLevel6 = [
    BoxShadow(
      color: shadowColor,
      blurRadius: 32.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 16.0),
    ),
    BoxShadow(
      color: shadowColorAmbient,
      blurRadius: 16.0,
      spreadRadius: 0.0,
      offset: Offset(0.0, 8.0),
    ),
  ];
}

// ==========================================
// BLUR
// ==========================================

/// Base backdrop blur filter tokens.
abstract final class BaseBlur {
  static const double none = 0.0;
  static const double small = 4.0;
  static const double medium = 8.0;
  static const double large = 16.0;
  static const double xlarge = 24.0;
  static const double xxlarge = 32.0;
}

// ==========================================
// MOTION
// ==========================================

/// Base motion and transition tokens.
abstract final class BaseMotion {
  // Durations
  static const Duration durationInstant = Duration.zero;
  static const Duration durationFast = Duration(milliseconds: 100);
  static const Duration durationNormal = Duration(milliseconds: 200);
  static const Duration durationSlow = Duration(milliseconds: 350);
  static const Duration durationSlower = Duration(milliseconds: 500);
  static const Duration durationSlowest = Duration(milliseconds: 700);

  // Curves
  static const Curve curveStandard = Curves.easeInOut;
  static const Curve curveDecelerate = Curves.easeOut;
  static const Curve curveAccelerate = Curves.easeIn;
  static const Curve curveEmphasized = Curves.easeInOutCubic;
  static const Curve curveEntrance = Curves.easeOutCubic;
  static const Curve curveExit = Curves.easeInCubic;
}

// ==========================================
// SIZE
// ==========================================

/// General base dimension and sizing tokens.
abstract final class BaseSize {
  static const double size0 = 0.0;
  static const double size2 = 2.0;
  static const double size4 = 4.0;
  static const double size6 = 6.0;
  static const double size8 = 8.0;
  static const double size10 = 10.0;
  static const double size12 = 12.0;
  static const double size14 = 14.0;
  static const double size16 = 16.0;
  static const double size18 = 18.0;
  static const double size20 = 20.0;
  static const double size24 = 24.0;
  static const double size28 = 28.0;
  static const double size32 = 32.0;
  static const double size36 = 36.0;
  static const double size40 = 40.0;
  static const double size44 = 44.0;
  static const double size48 = 48.0;
  static const double size56 = 56.0;
  static const double size64 = 64.0;
  static const double size72 = 72.0;
  static const double size80 = 80.0;
  static const double size96 = 96.0;
  static const double size112 = 112.0;
  static const double size128 = 128.0;
}

// ==========================================
// ICON SIZES
// ==========================================

/// Base size tokens for icons.
abstract final class BaseIconSizes {
  static const double xxsmall = 12.0;
  static const double xsmall = 16.0;
  static const double small = 20.0;
  static const double medium = 24.0;
  static const double large = 32.0;
  static const double xlarge = 40.0;
  static const double xxlarge = 48.0;
}

// ==========================================
// AVATAR SIZES
// ==========================================

/// Base size tokens for avatars and profile pictures.
abstract final class BaseAvatarSizes {
  static const double xs = 24.0;
  static const double sm = 32.0;
  static const double md = 40.0;
  static const double lg = 48.0;
  static const double xl = 56.0;
  static const double xxl = 64.0;
}

// ==========================================
// BREAKPOINTS
// ==========================================

/// Base screen-size responsiveness breakpoints.
abstract final class BaseBreakpoints {
  static const double compact = 0.0;
  static const double medium = 600.0;
  static const double expanded = 840.0;
  static const double large = 1200.0;
  static const double xlarge = 1440.0;
}

// ==========================================
// Z-INDEX
// ==========================================

/// Base depth stacking order values.
abstract final class BaseZIndex {
  static const int background = -1;
  static const int content = 0;
  static const int sticky = 100;
  static const int dropdown = 200;
  static const int popover = 300;
  static const int dialog = 400;
  static const int bottomSheet = 500;
  static const int toast = 600;
  static const int tooltip = 700;
  static const int modal = 800;
  static const int overlay = 900;
}

// ==========================================
// TYPOGRAPHY
// ==========================================

/// Primitive typography definitions utilizing Plus Jakarta Sans font.
abstract final class BaseTypography {
  static const String fontFamily = 'PlusJakartaSans';

  // Display Styles (Uppercase/Hero elements)
  static const TextStyle displayLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 96.0,
    height: 0.85,
    letterSpacing: 96.0 * 0.02,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle displayMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 64.0,
    height: 0.85,
    letterSpacing: 64.0 * 0.015,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle displaySmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 40.0,
    height: 0.85,
    letterSpacing: 40.0 * 0.015,
    fontWeight: FontWeight.w700,
  );

  // Heading Styles
  static const TextStyle headingXXL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 36.0,
    height: 44.0 / 36.0,
    letterSpacing: 36.0 * -0.02,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headingXL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 30.0,
    height: 38.0 / 30.0,
    letterSpacing: 30.0 * -0.02,
    fontWeight: FontWeight.w700,
  );

  static const TextStyle headingL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24.0,
    height: 32.0 / 24.0,
    letterSpacing: 24.0 * -0.015,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headingM = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20.0,
    height: 28.0 / 20.0,
    letterSpacing: 20.0 * -0.01,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headingS = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    height: 24.0 / 16.0,
    letterSpacing: 16.0 * -0.005,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle headingXS = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 20.0 / 14.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w600,
  );

  // Title Styles
  static const TextStyle titleL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20.0,
    height: 28.0 / 20.0,
    letterSpacing: 20.0 * -0.01,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleM = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    height: 24.0 / 16.0,
    letterSpacing: 16.0 * -0.005,
    fontWeight: FontWeight.w600,
  );

  static const TextStyle titleS = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 20.0 / 14.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w600,
  );

  // Body Styles
  static const TextStyle bodyXL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18.0,
    height: 26.0 / 18.0,
    letterSpacing: 18.0 * -0.01,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    height: 24.0 / 16.0,
    letterSpacing: 16.0 * -0.005,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyM = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 20.0 / 14.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyS = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    height: 16.0 / 12.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle bodyXS = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.0,
    height: 14.0 / 10.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  // Label Styles
  static const TextStyle labelL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    height: 24.0 / 16.0,
    letterSpacing: 16.0 * -0.005,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelM = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 20.0 / 14.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle labelS = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    height: 16.0 / 12.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w500,
  );

  // Caption Styles
  static const TextStyle captionL = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    height: 16.0 / 12.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  static const TextStyle captionM = TextStyle(
    fontFamily: fontFamily,
    fontSize: 10.0,
    height: 14.0 / 10.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w400,
  );

  // Link Styles
  static const TextStyle linkLarge = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16.0,
    height: 24.0 / 16.0,
    letterSpacing: 16.0 * -0.005,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.underline,
  );

  static const TextStyle linkMedium = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14.0,
    height: 20.0 / 14.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.underline,
  );

  static const TextStyle linkSmall = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12.0,
    height: 16.0 / 12.0,
    letterSpacing: 0.0,
    fontWeight: FontWeight.w500,
    decoration: TextDecoration.underline,
  );
}

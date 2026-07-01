import 'package:flutter/material.dart';
import 'base_tokens.dart';

// ==========================================
// SEMANTIC COLORS
// ==========================================

/// Semantic color tokens for Marita AI, referencing only primitive tokens from [BaseColors].
///
/// Designed to follow high contrast accessibility standards (WCAG AA & AAA).
abstract final class SemanticColors {
  // --- Text Colors ---
  static const Color colorTextDefault = BaseColors.shadow900;
  static const Color colorTextMuted = BaseColors.shadow700;
  static const Color colorTextSubtle = BaseColors.shadow600;
  static const Color colorTextDisabled = BaseColors.shadow400;
  static const Color colorTextInverse = BaseColors.cloud50;
  static const Color colorTextBrand = BaseColors.brand700;
  static const Color colorTextSuccess = BaseColors.green800;
  static const Color colorTextWarning = BaseColors.yellow900;
  static const Color colorTextDanger = BaseColors.red600;
  static const Color colorTextInformation = BaseColors.blue800;
  static const Color colorTextPlaceholder = BaseColors.shadow400;
  static const Color colorTextLink = BaseColors.blue700;
  static const Color colorTextVisited = BaseColors.brand600;
  static const Color colorTextSelected = BaseColors.brand700;

  // --- Icon Colors ---
  static const Color colorIconDefault = BaseColors.shadow800;
  static const Color colorIconMuted = BaseColors.shadow600;
  static const Color colorIconDisabled = BaseColors.shadow300;
  static const Color colorIconInverse = BaseColors.cloud50;
  static const Color colorIconBrand = BaseColors.brand700;
  static const Color colorIconSuccess = BaseColors.green700;
  static const Color colorIconWarning = BaseColors.yellow800;
  static const Color colorIconDanger = BaseColors.red600;
  static const Color colorIconInformation = BaseColors.blue700;

  // --- Background Colors ---
  static const Color colorBackgroundCanvas = BaseColors.cloud200;
  static const Color colorBackgroundPage = BaseColors.cloud200;
  static const Color colorBackgroundSurface = BaseColors.cloud50;
  static const Color colorBackgroundSurfaceHover = BaseColors.cloud200;
  static const Color colorBackgroundSurfacePressed = BaseColors.cloud300;
  static const Color colorBackgroundRaisedSurface = BaseColors.cloud50;
  static const Color colorBackgroundFloatingSurface = BaseColors.cloud50;
  static const Color colorBackgroundCard = BaseColors.cloud50;
  static const Color colorBackgroundCardHover = BaseColors.cloud200;
  static const Color colorBackgroundCardSelected = BaseColors.brand50;
  static const Color colorBackgroundInverse = BaseColors.shadow900;
  static const Color colorBackgroundBrand = BaseColors.brand500;
  static const Color colorBackgroundBrandHover = BaseColors.brand600;
  static const Color colorBackgroundBrandPressed = BaseColors.brand700;
  static const Color colorBackgroundSuccess = BaseColors.green50;
  static const Color colorBackgroundWarning = BaseColors.yellow50;
  static const Color colorBackgroundDanger = BaseColors.red50;
  static const Color colorBackgroundInformation = BaseColors.blue50;
  static const Color colorBackgroundSidebar = BaseColors.cloud200;
  static const Color colorBackgroundTopbar = BaseColors.cloud50;
  static const Color colorBackgroundBottomNavigation = BaseColors.cloud50;
  static const Color colorBackgroundWorkspace = BaseColors.cloud100;
  static const Color colorBackgroundChat = BaseColors.cloud100;
  static const Color colorBackgroundUserBubble = BaseColors.brand50;
  static const Color colorBackgroundAIBubble = BaseColors.cloud50;
  static const Color colorBackgroundReasoningBubble = BaseColors.cloud300;
  static const Color colorBackgroundStreamingBubble = BaseColors.cloud200;
  static const Color colorBackgroundInput = BaseColors.cloud50;
  static const Color colorBackgroundInputDisabled = BaseColors.cloud300;
  static const Color colorBackgroundSelection = BaseColors.brand100;
  static const Color colorBackgroundOverlay = BaseColors.cloud50;
  static final Color colorBackgroundBlanket = BaseColors.shadow900.withValues(
    alpha: BaseOpacity.opacity48,
  );
  static final Color colorBackgroundScrim = BaseColors.shadow900.withValues(
    alpha: BaseOpacity.opacity32,
  );

  // --- Border Colors ---
  static const Color colorBorderDefault = BaseColors.cloud400;
  static const Color colorBorderSubtle = BaseColors.cloud300;
  static const Color colorBorderMuted = BaseColors.cloud200;
  static const Color colorBorderDivider = BaseColors.cloud300;
  static const Color colorBorderInput = BaseColors.cloud500;
  static const Color colorBorderInputFocus = BaseColors.brand500;
  static const Color colorBorderInputError = BaseColors.red500;
  static const Color colorBorderCard = BaseColors.cloud400;
  static const Color colorBorderBrand = BaseColors.brand500;
  static const Color colorBorderSuccess = BaseColors.green500;
  static const Color colorBorderWarning = BaseColors.yellow500;
  static const Color colorBorderDanger = BaseColors.red500;
  static const Color colorBorderDisabled = BaseColors.cloud300;
  static const Color colorBorderSelected = BaseColors.brand500;
  static const Color colorBorderInverse = BaseColors.shadow900;

  // --- Button Colors ---
  static const Color colorButtonPrimaryBackground = BaseColors.brand500;
  static const Color colorButtonPrimaryForeground = BaseColors.cloud50;
  static const Color colorButtonPrimaryBorder = Colors.transparent;
  static const Color colorButtonPrimaryHover = BaseColors.brand600;
  static const Color colorButtonPrimaryPressed = BaseColors.brand700;
  static const Color colorButtonPrimaryFocusedBorder = BaseColors.brand700;
  static const Color colorButtonPrimaryDisabledBackground = BaseColors.cloud300;
  static const Color colorButtonPrimaryDisabledForeground =
      BaseColors.shadow300;
  static const Color colorButtonPrimaryDisabledBorder = Colors.transparent;

  static const Color colorButtonSecondaryBackground = BaseColors.cloud300;
  static const Color colorButtonSecondaryForeground = BaseColors.shadow900;
  static const Color colorButtonSecondaryBorder = Colors.transparent;
  static const Color colorButtonSecondaryHover = BaseColors.cloud400;
  static const Color colorButtonSecondaryPressed = BaseColors.cloud500;
  static const Color colorButtonSecondaryFocusedBorder = BaseColors.shadow700;
  static const Color colorButtonSecondaryDisabledBackground =
      BaseColors.cloud200;
  static const Color colorButtonSecondaryDisabledForeground =
      BaseColors.shadow300;
  static const Color colorButtonSecondaryDisabledBorder = Colors.transparent;

  static const Color colorButtonGhostBackground = Colors.transparent;
  static const Color colorButtonGhostForeground = BaseColors.shadow900;
  static const Color colorButtonGhostBorder = Colors.transparent;
  static const Color colorButtonGhostHover = BaseColors.cloud200;
  static const Color colorButtonGhostPressed = BaseColors.cloud300;
  static const Color colorButtonGhostFocusedBorder = BaseColors.shadow700;
  static const Color colorButtonGhostDisabledBackground = Colors.transparent;
  static const Color colorButtonGhostDisabledForeground = BaseColors.shadow300;
  static const Color colorButtonGhostDisabledBorder = Colors.transparent;

  static const Color colorButtonTextBackground = Colors.transparent;
  static const Color colorButtonTextForeground = BaseColors.brand700;
  static const Color colorButtonTextBorder = Colors.transparent;
  static const Color colorButtonTextHover = BaseColors.brand50;
  static const Color colorButtonTextPressed = BaseColors.brand100;
  static const Color colorButtonTextFocusedBorder = BaseColors.brand700;
  static const Color colorButtonTextDisabledBackground = Colors.transparent;
  static const Color colorButtonTextDisabledForeground = BaseColors.shadow300;
  static const Color colorButtonTextDisabledBorder = Colors.transparent;

  static const Color colorButtonOutlinedBackground = Colors.transparent;
  static const Color colorButtonOutlinedForeground = BaseColors.shadow900;
  static const Color colorButtonOutlinedBorder = BaseColors.cloud400;
  static const Color colorButtonOutlinedHover = BaseColors.cloud200;
  static const Color colorButtonOutlinedPressed = BaseColors.cloud300;
  static const Color colorButtonOutlinedFocusedBorder = BaseColors.shadow700;
  static const Color colorButtonOutlinedDisabledBackground = Colors.transparent;
  static const Color colorButtonOutlinedDisabledForeground =
      BaseColors.shadow300;
  static const Color colorButtonOutlinedDisabledBorder = BaseColors.cloud300;

  static const Color colorButtonDangerBackground = BaseColors.red500;
  static const Color colorButtonDangerForeground = BaseColors.cloud50;
  static const Color colorButtonDangerBorder = Colors.transparent;
  static const Color colorButtonDangerHover = BaseColors.red600;
  static const Color colorButtonDangerPressed = BaseColors.red700;
  static const Color colorButtonDangerFocusedBorder = BaseColors.red700;
  static const Color colorButtonDangerDisabledBackground = BaseColors.cloud300;
  static const Color colorButtonDangerDisabledForeground = BaseColors.shadow300;
  static const Color colorButtonDangerDisabledBorder = Colors.transparent;

  static const Color colorButtonSuccessBackground = BaseColors.green500;
  static const Color colorButtonSuccessForeground = BaseColors.cloud50;
  static const Color colorButtonSuccessBorder = Colors.transparent;
  static const Color colorButtonSuccessHover = BaseColors.green600;
  static const Color colorButtonSuccessPressed = BaseColors.green700;
  static const Color colorButtonSuccessFocusedBorder = BaseColors.green700;
  static const Color colorButtonSuccessDisabledBackground = BaseColors.cloud300;
  static const Color colorButtonSuccessDisabledForeground =
      BaseColors.shadow300;
  static const Color colorButtonSuccessDisabledBorder = Colors.transparent;

  static const Color colorButtonWarningBackground = BaseColors.yellow500;
  static const Color colorButtonWarningForeground = BaseColors.shadow900;
  static const Color colorButtonWarningBorder = Colors.transparent;
  static const Color colorButtonWarningHover = BaseColors.yellow600;
  static const Color colorButtonWarningPressed = BaseColors.yellow700;
  static const Color colorButtonWarningFocusedBorder = BaseColors.yellow700;
  static const Color colorButtonWarningDisabledBackground = BaseColors.cloud300;
  static const Color colorButtonWarningDisabledForeground =
      BaseColors.shadow300;
  static const Color colorButtonWarningDisabledBorder = Colors.transparent;

  static const Color colorButtonDisabledBackground = BaseColors.cloud300;
  static const Color colorButtonDisabledForeground = BaseColors.shadow300;
  static const Color colorButtonDisabledBorder = Colors.transparent;
  static const Color colorButtonDisabledHover = BaseColors.cloud300;
  static const Color colorButtonDisabledPressed = BaseColors.cloud300;
  static const Color colorButtonDisabledFocusedBorder = Colors.transparent;
  static const Color colorButtonDisabledDisabledBackground =
      BaseColors.cloud300;
  static const Color colorButtonDisabledDisabledForeground =
      BaseColors.shadow300;
  static const Color colorButtonDisabledDisabledBorder = Colors.transparent;

  // --- Input Specifics ---
  static const Color colorInputBackground = BaseColors.cloud50;
  static const Color colorInputBorder = BaseColors.cloud500;
  static const Color colorInputBorderFocus = BaseColors.brand500;
  static const Color colorInputBorderError = BaseColors.red500;
  static const Color colorInputCursor = BaseColors.brand500;
  static const Color colorInputSelection = BaseColors.brand100;
  static const Color colorInputPlaceholder = BaseColors.shadow400;
  static const Color colorInputText = BaseColors.shadow900;
  static const Color colorInputDisabledBackground = BaseColors.cloud200;
  static const Color colorInputDisabledText = BaseColors.shadow400;
  static const Color colorInputDisabledBorder = BaseColors.cloud300;
  static const Color colorInputReadOnlyBackground = BaseColors.cloud100;
  static const Color colorInputReadOnlyText = BaseColors.shadow900;
  static const Color colorInputReadOnlyBorder = BaseColors.cloud400;

  // --- Chat specific ---
  static const Color colorChatUserBubbleBackground = BaseColors.brand500;
  static const Color colorChatUserBubbleForeground = BaseColors.cloud50;
  static const Color colorChatAssistantBubbleBackground = BaseColors.cloud200;
  static const Color colorChatAssistantBubbleForeground = BaseColors.shadow900;
  static const Color colorChatThinkingBubbleBackground = BaseColors.cloud300;
  static const Color colorChatReasoningBadgeBackground = BaseColors.brand50;
  static const Color colorChatReasoningBadgeForeground = BaseColors.brand700;
  static const Color colorChatStreamingCursor = BaseColors.brand500;
  static const Color colorChatTypingIndicator = BaseColors.brand500;
  static const Color colorChatMarkdownText = BaseColors.shadow900;
  static const Color colorChatQuoteBackground = BaseColors.cloud300;
  static const Color colorChatQuoteBorder = BaseColors.brand500;
  static const Color colorChatTableHeaderBackground = BaseColors.cloud300;
  static const Color colorChatTableBorder = BaseColors.cloud400;
  static const Color colorChatInlineCodeBackground = BaseColors.cloud300;
  static const Color colorChatInlineCodeForeground = BaseColors.red600;
  static const Color colorChatCodeBlockBackground = BaseColors.shadow900;
  static const Color colorChatCodeBlockForeground = BaseColors.cloud50;
  static const Color colorChatAttachmentBackground = BaseColors.cloud300;
  static const Color colorChatImageBorder = BaseColors.cloud400;
  static const Color colorChatPDFPreviewBackground = BaseColors.red50;
  static const Color colorChatSpreadsheetPreviewBackground = BaseColors.green50;
  static const Color colorChatTimestampForeground = BaseColors.shadow500;
  static const Color colorChatReactionBackground = BaseColors.cloud300;
  static const Color colorChatReactionSelectedBackground = BaseColors.brand100;
  static const Color colorChatMessageDividerLine = BaseColors.cloud400;

  // --- AI States ---
  static const Color colorAIStateThinking = BaseColors.blue500;
  static const Color colorAIStateAnalyzing = BaseColors.blue600;
  static const Color colorAIStateReasoning = BaseColors.brand500;
  static const Color colorAIStateSearching = BaseColors.yellow600;
  static const Color colorAIStateStreaming = BaseColors.brand400;
  static const Color colorAIStateCompleted = BaseColors.green500;
  static const Color colorAIStateError = BaseColors.red500;
  static const Color colorAIStateCancelled = BaseColors.shadow500;

  // --- Navigation specific ---
  static const Color colorNavigationSidebarBackground = BaseColors.cloud200;
  static const Color colorNavigationTopbarBackground = BaseColors.cloud50;
  static const Color colorNavigationItemForeground = BaseColors.shadow700;
  static const Color colorNavigationItemForegroundSelected =
      BaseColors.brand500;
  static const Color colorNavigationItemHoverBackground = BaseColors.cloud300;
  static const Color colorNavigationItemPressedBackground = BaseColors.cloud400;
  static const Color colorNavigationBadgeBackground = BaseColors.red500;
  static const Color colorNavigationBadgeForeground = BaseColors.cloud50;
  static const Color colorNavigationIndicator = BaseColors.brand500;

  // --- Status specific ---
  static const Color colorStatusSuccessBackground = BaseColors.green50;
  static const Color colorStatusSuccessForeground = BaseColors.green900;
  static const Color colorStatusSuccessBorder = BaseColors.green200;

  static const Color colorStatusWarningBackground = BaseColors.yellow50;
  static const Color colorStatusWarningForeground = BaseColors.yellow900;
  static const Color colorStatusWarningBorder = BaseColors.yellow200;

  static const Color colorStatusDangerBackground = BaseColors.red50;
  static const Color colorStatusDangerForeground = BaseColors.red900;
  static const Color colorStatusDangerBorder = BaseColors.red200;

  static const Color colorStatusInfoBackground = BaseColors.blue50;
  static const Color colorStatusInfoForeground = BaseColors.blue900;
  static const Color colorStatusInfoBorder = BaseColors.blue200;

  static const Color colorStatusNeutralBackground = BaseColors.cloud300;
  static const Color colorStatusNeutralForeground = BaseColors.shadow900;
  static const Color colorStatusNeutralBorder = BaseColors.cloud500;

  // --- Overlay specific ---
  static const Color colorOverlayDialogBackground = BaseColors.cloud50;
  static const Color colorOverlayBottomSheetBackground = BaseColors.cloud50;
  static const Color colorOverlayPopoverBackground = BaseColors.cloud50;
  static const Color colorOverlayMenuBackground = BaseColors.cloud50;
  static const Color colorOverlayTooltipBackground = BaseColors.shadow900;
  static const Color colorOverlayTooltipForeground = BaseColors.cloud50;
  static const Color colorOverlayToastBackground = BaseColors.shadow800;
  static const Color colorOverlaySnackbarBackground = BaseColors.shadow800;
  static final Color colorOverlayModalBarrier = BaseColors.shadow900.withValues(
    alpha: BaseOpacity.opacity48,
  );
}

// ==========================================
// SEMANTIC SPACING
// ==========================================

/// Semantic spacing tokens for unified layouts, referencing only primitive tokens from [BaseSpacing].
abstract final class SemanticSpacing {
  static const double spaceScreenPadding = BaseSpacing.space16;
  static const double spacePagePadding = BaseSpacing.space24;
  static const double spaceSectionGap = BaseSpacing.space32;
  static const double spaceCardPadding = BaseSpacing.space16;
  static const double spaceButtonPaddingHorizontal = BaseSpacing.space16;
  static const double spaceButtonPaddingVertical = BaseSpacing.space12;
  static const double spaceInputPaddingHorizontal = BaseSpacing.space16;
  static const double spaceInputPaddingVertical = BaseSpacing.space12;
  static const double spaceDialogPadding = BaseSpacing.space24;
  static const double spaceBottomSheetPadding = BaseSpacing.space24;
  static const double spaceNavigationGap = BaseSpacing.space12;
  static const double spaceSidebarPadding = BaseSpacing.space16;
  static const double spaceListGap = BaseSpacing.space12;
  static const double spaceGridGap = BaseSpacing.space16;
  static const double spaceChatBubblePaddingHorizontal = BaseSpacing.space14;
  static const double spaceChatBubblePaddingVertical = BaseSpacing.space10;
  static const double spaceMessageGap = BaseSpacing.space12;
  static const double spaceAIResponseGap = BaseSpacing.space20;
  static const double spaceWorkspacePadding = BaseSpacing.space16;
}

// ==========================================
// SEMANTIC RADIUS
// ==========================================

/// Semantic border radius tokens for unified shapes, referencing only primitive tokens from [BaseRadius].
abstract final class SemanticRadius {
  static const double radiusButton = BaseRadius.full;
  static const double radiusCard = BaseRadius.large;
  static const double radiusInput = BaseRadius.medium;
  static const double radiusDialog = BaseRadius.xlarge;
  static const double radiusBottomSheet = BaseRadius.xlarge;
  static const double radiusAvatar = BaseRadius.full;
  static const double radiusImage = BaseRadius.medium;
  static const double radiusChatBubble = BaseRadius.large;
  static const double radiusChatBubbleUser = BaseRadius.large;
  static const double radiusChatBubbleAssistant = BaseRadius.large;
  static const double radiusPill = BaseRadius.full;
  static const double radiusBadge = BaseRadius.small;
  static const double radiusChip = BaseRadius.full;
}

// ==========================================
// SEMANTIC SIZES
// ==========================================

/// Semantic size tokens for widgets and assets, referencing primitive size tokens.
abstract final class SemanticSizes {
  // Icons
  static const double sizeIconXXSmall = BaseIconSizes.xxsmall;
  static const double sizeIconXSmall = BaseIconSizes.xsmall;
  static const double sizeIconSmall = BaseIconSizes.small;
  static const double sizeIconMedium = BaseIconSizes.medium;
  static const double sizeIconLarge = BaseIconSizes.large;
  static const double sizeIconXLarge = BaseIconSizes.xlarge;
  static const double sizeIconXXLarge = BaseIconSizes.xxlarge;

  // Avatars
  static const double sizeAvatarXS = BaseAvatarSizes.xs;
  static const double sizeAvatarSM = BaseAvatarSizes.sm;
  static const double sizeAvatarMD = BaseAvatarSizes.md;
  static const double sizeAvatarLG = BaseAvatarSizes.lg;
  static const double sizeAvatarXL = BaseAvatarSizes.xl;
  static const double sizeAvatarXXL = BaseAvatarSizes.xxl;

  // Layout Dimensions
  static const double sizeButtonHeightDefault = BaseSize.size48;
  static const double sizeButtonHeightSmall = BaseSize.size36;
  static const double sizeInputHeightDefault = BaseSize.size48;
  static const double sizeNavigationHeight = BaseSize.size56;
  static const double sizeToolbarHeight = BaseSize.size64;
  static const double sizeFAB = BaseSize.size56;
  static const double sizeCheckbox = BaseSize.size20;
  static const double sizeRadio = BaseSize.size20;
  static const double sizeSwitchWidth = BaseSize.size44;
  static const double sizeSwitchHeight = BaseSize.size24;
  static const double sizeLoadingIndicatorDefault = BaseSize.size32;
  static const double sizeProgressIndicatorHeight = BaseSize.size4;
  static const double sizeChatAvatar = BaseAvatarSizes.sm;
  static const double sizeAttachmentPreview = BaseSize.size64;
}

// ==========================================
// SEMANTIC TYPOGRAPHY
// ==========================================

/// Semantic text styles mapping, referencing only primitive styles from [BaseTypography].
abstract final class SemanticTypography {
  static const TextStyle textDisplayLarge = BaseTypography.displayLarge;
  static const TextStyle textDisplayMedium = BaseTypography.displayMedium;
  static const TextStyle textDisplaySmall = BaseTypography.displaySmall;

  static const TextStyle textHeadingXXLarge = BaseTypography.headingXXL;
  static const TextStyle textHeadingXLarge = BaseTypography.headingXL;
  static const TextStyle textHeadingLarge = BaseTypography.headingL;
  static const TextStyle textHeadingMedium = BaseTypography.headingM;
  static const TextStyle textHeadingSmall = BaseTypography.headingS;
  static const TextStyle textHeadingXSmall = BaseTypography.headingXS;

  static const TextStyle textTitleLarge = BaseTypography.titleL;
  static const TextStyle textTitleMedium = BaseTypography.titleM;
  static const TextStyle textTitleSmall = BaseTypography.titleS;

  static const TextStyle textBodyXLarge = BaseTypography.bodyXL;
  static const TextStyle textBodyLarge = BaseTypography.bodyL;
  static const TextStyle textBodyDefault = BaseTypography.bodyM;
  static const TextStyle textBodySmall = BaseTypography.bodyS;
  static const TextStyle textBodyXSmall = BaseTypography.bodyXS;

  static const TextStyle textLabelLarge = BaseTypography.labelL;
  static const TextStyle textLabelMedium = BaseTypography.labelM;
  static const TextStyle textLabelSmall = BaseTypography.labelS;

  static const TextStyle textCaptionLarge = BaseTypography.captionL;
  static const TextStyle textCaptionMedium = BaseTypography.captionM;

  static const TextStyle textLinkLarge = BaseTypography.linkLarge;
  static const TextStyle textLinkMedium = BaseTypography.linkMedium;
  static const TextStyle textLinkSmall = BaseTypography.linkSmall;
}

// ==========================================
// SEMANTIC MOTION
// ==========================================

/// Semantic motion and transition configurations, referencing primitive tokens from [BaseMotion].
abstract final class SemanticMotion {
  static const Duration durationInstant = BaseMotion.durationInstant;
  static const Duration durationFast = BaseMotion.durationFast;
  static const Duration durationNormal = BaseMotion.durationNormal;
  static const Duration durationSlow = BaseMotion.durationSlow;
  static const Duration durationSlower = BaseMotion.durationSlower;
  static const Duration durationSlowest = BaseMotion.durationSlowest;

  static const Curve curveStandard = BaseMotion.curveStandard;
  static const Curve curveDecelerate = BaseMotion.curveDecelerate;
  static const Curve curveAccelerate = BaseMotion.curveAccelerate;
  static const Curve curveEmphasized = BaseMotion.curveEmphasized;
  static const Curve curveEntrance = BaseMotion.curveEntrance;
  static const Curve curveExit = BaseMotion.curveExit;
}

// ==========================================
// SEMANTIC ELEVATION
// ==========================================

/// Semantic elevation shadow presets, referencing [BaseElevation].
abstract final class SemanticElevation {
  static const double elevationNone = BaseElevation.none;
  static const double elevationCard = BaseElevation.level1;
  static const double elevationDropdown = BaseElevation.level2;
  static const double elevationPopover = BaseElevation.level3;
  static const double elevationMenu = BaseElevation.level2;
  static const double elevationDialog = BaseElevation.level4;
  static const double elevationBottomSheet = BaseElevation.level4;
  static const double elevationTooltip = BaseElevation.none;
  static const double elevationToast = BaseElevation.level5;
  static const double elevationSnackbar = BaseElevation.level5;
  static const double elevationModalBarrier = BaseElevation.none;

  static const List<BoxShadow> shadowNone = BaseElevation.shadowNone;
  static const List<BoxShadow> shadowCard = BaseElevation.shadowLevel1;
  static const List<BoxShadow> shadowDropdown = BaseElevation.shadowLevel2;
  static const List<BoxShadow> shadowPopover = BaseElevation.shadowLevel3;
  static const List<BoxShadow> shadowMenu = BaseElevation.shadowLevel2;
  static const List<BoxShadow> shadowDialog = BaseElevation.shadowLevel4;
  static const List<BoxShadow> shadowBottomSheet = BaseElevation.shadowLevel4;
  static const List<BoxShadow> shadowTooltip = BaseElevation.shadowNone;
  static const List<BoxShadow> shadowToast = BaseElevation.shadowLevel5;
  static const List<BoxShadow> shadowSnackbar = BaseElevation.shadowLevel5;
  static const List<BoxShadow> shadowModalBarrier = BaseElevation.shadowNone;
}

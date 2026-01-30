import 'dart:ui';
import 'package:flutter/material.dart';

class ClubBlackoutTheme {
  static const neonBlue = Color(0xFF00D1FF);
  static const electricBlue = Color(0xFF2E5BFF);

  static const String neonGlowFontFamily = 'NeonGlow';
  static const TextStyle neonGlowFont = TextStyle(fontFamily: neonGlowFontFamily);

  static const neonRed = Color(0xFFFF2E63);
  static const crimsonRed = neonRed;

  static const neonGreen = Color(0xFF00FF9A);
  static const neonMint = Color(0xFF98FF98);
  static const neonPurple = Color(0xFFB400FF);
  static const neonPink = Color(0xFFFF4FD8);
  static const neonOrange = Color(0xFFFFA500);
  static const neonGold = Color(0xFFFFD700);

  // Role / feature accents
  static const secondWindPink = Color(0xFFDE3163);

  // UI accents / effects
  static const rumourLavender = Color(0xFFE6E6FA);
  static const hologramRedChannel = Color(0xFFFF0000);
  static const hologramCyanChannel = Color(0xFF00FFFF);

  // Contrast primitives
  static const pureWhite = Color(0xFFFFFFFF);
  static const pureBlack = Color(0xFF000000);

  // Design Language Constants
  static const double defaultGlowSpread = 2.0;
  static const double defaultGlowBlur = 18.0;
  static const double thinBorderWidth = 1.0;
  static const double thickBorderWidth = 2.5;

  // Global layout constants
  static const double radiusSm = 12;
  static const double radiusMd = 16;
  static const double radiusLg = 24;
  static const double radiusSheet = 28;

  static const BorderRadius borderRadiusXs = BorderRadius.all(Radius.circular(8));
  static const BorderRadius borderRadiusSmAll = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMdAll = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusLgAll = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusControl = BorderRadius.all(Radius.circular(14));

  static const RoundedRectangleBorder roundedShapeMd =
      RoundedRectangleBorder(borderRadius: borderRadiusMdAll);

  static const double controlHeight = 48;
  static const EdgeInsets pagePadding = EdgeInsets.fromLTRB(16, 0, 16, 24);
  static const EdgeInsets sheetPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  static const EdgeInsets cardPadding = EdgeInsets.all(12);
  static const EdgeInsets cardPaddingDense = EdgeInsets.all(12);

  static const EdgeInsets controlPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  static const EdgeInsets fieldPadding = EdgeInsets.symmetric(horizontal: 12, vertical: 12);
  static const EdgeInsets fieldPaddingLoose = EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    static const EdgeInsets inset12 = EdgeInsets.all(12);
  static const EdgeInsets inset16 = EdgeInsets.all(16);
  static const EdgeInsets inset24 = EdgeInsets.all(24);
  static const EdgeInsets insetH16 = EdgeInsets.symmetric(horizontal: 16);
  static const EdgeInsets insetH16V24 = EdgeInsets.symmetric(horizontal: 16, vertical: 24);
  static const EdgeInsets sectionDividerPadding = EdgeInsets.fromLTRB(16, 16, 16, 8);
  static const EdgeInsets bottomInset8 = EdgeInsets.only(bottom: 8);
  static const EdgeInsets buttonPaddingTall = EdgeInsets.symmetric(vertical: 24);
  static const EdgeInsets buttonPaddingWide = EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    static const EdgeInsets topInset16 = EdgeInsets.only(top: 16);
    static const EdgeInsets topInset24 = EdgeInsets.only(top: 24);

    // Common card paddings (use these instead of ad-hoc EdgeInsets)
    static const EdgeInsets scriptCardPaddingBulletin =
      EdgeInsets.symmetric(horizontal: 12, vertical: 10);
    static const EdgeInsets scriptCardPaddingDense =
      EdgeInsets.symmetric(horizontal: 16, vertical: 14);
    static const EdgeInsets scriptCardPadding =
      EdgeInsets.symmetric(horizontal: 18, vertical: 16);

    static const EdgeInsets cardMarginVertical8 = EdgeInsets.symmetric(vertical: 8);

  // Common screen/building-block paddings
  static const EdgeInsets rowPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 8);
  static const EdgeInsets dialogInsetPadding = inset16;
  static const EdgeInsets alertTitlePadding = EdgeInsets.fromLTRB(24, 20, 24, 0);
  static const EdgeInsets alertContentPadding = EdgeInsets.fromLTRB(24, 16, 24, 0);
  static const EdgeInsets alertActionsPadding = EdgeInsets.fromLTRB(16, 8, 16, 12);

  static const SizedBox gap4 = SizedBox(height: 4);
  static const SizedBox gap8 = SizedBox(height: 8);
  static const SizedBox gap12 = SizedBox(height: 12);
  static const SizedBox gap16 = SizedBox(height: 16);
  static const SizedBox gap24 = SizedBox(height: 24);
  static const SizedBox gap28 = SizedBox(height: 28);
  static const SizedBox gap32 = SizedBox(height: 32);
  static const SizedBox gap40 = SizedBox(height: 40);

  static const SizedBox hGap4 = SizedBox(width: 4);
  static const SizedBox hGap8 = SizedBox(width: 8);
  static const SizedBox hGap12 = SizedBox(width: 12);
  static const SizedBox hGap16 = SizedBox(width: 16);

  static Color contrastOn(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? pureWhite
        : pureBlack;
  }

  static TextStyle get primaryFont => const TextStyle();

  static TextStyle get headingStyle => const TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      );

  // --- Bulletin / Report Styling ---

  static TextStyle bulletinHeaderStyle(Color color) {
    return headingStyle.copyWith(
      fontSize: 20,
      color: color,
      shadows: textGlow(color),
    );
  }

  static TextStyle bulletinBodyStyle(Color onSurface) {
    return TextStyle(
      color: onSurface.withValues(alpha: 0.95),
      fontSize: 14,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      height: 1.4,
    );
  }

  static BoxDecoration bulletinItemDecoration({
    required Color color,
    double opacity = 0.15,
  }) {
    return neonFrame(
      color: color,
      opacity: opacity,
      borderRadius: 16,
      borderWidth: 1.2,
      showGlow: true,
    );
  }

  static List<Shadow> textGlow(Color c, {double intensity = 1.0}) => [
        Shadow(
          color: c.withValues(alpha: 0.65 * intensity),
          blurRadius: 10 * intensity,
        ),
        Shadow(
          color: c.withValues(alpha: 0.35 * intensity),
          blurRadius: 20 * intensity,
        ),
      ];

  /// Convenience style for glowing text.
  ///
  /// Use [glowColor] when the glow should differ from the text color.
  static TextStyle glowTextStyle({
    TextStyle? base,
    required Color color,
    Color? glowColor,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double glowIntensity = 1.0,
    bool glow = true,
  }) {
    final effectiveBase = base ?? const TextStyle();
    final effectiveGlowColor = glowColor ?? color;
    return effectiveBase.copyWith(
      color: color,
      fontSize: fontSize ?? effectiveBase.fontSize,
      fontWeight: fontWeight ?? effectiveBase.fontWeight,
      letterSpacing: letterSpacing ?? effectiveBase.letterSpacing,
      shadows: glow ? textGlow(effectiveGlowColor, intensity: glowIntensity) : null,
    );
  }

  /// Convenience style for the NeonGlow brand font.
  ///
  /// Intended for headings and key labels that should read as "neon" text.
  /// Uses [textGlow] by default; set [glow] to false for non-glowing labels.
  static TextStyle neonGlowTextStyle({
    TextStyle? base,
    required Color color,
    double? fontSize,
    FontWeight? fontWeight,
    double? letterSpacing,
    double glowIntensity = 1.0,
    bool glow = true,
  }) {
    return glowTextStyle(
      base: (base ?? const TextStyle()).copyWith(fontFamily: neonGlowFontFamily),
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      glowIntensity: glowIntensity,
      glow: glow,
    ).copyWith(
      fontFamily: neonGlowFontFamily,
    );
  }

  static List<Shadow> iconGlow(Color c, {double intensity = 1.0}) =>
      textGlow(c, intensity: intensity);

  static List<BoxShadow> circleGlow(Color c, {double intensity = 1.0}) => [
        BoxShadow(
          color: c.withValues(alpha: 0.40 * intensity),
          blurRadius: 16 * intensity,
          spreadRadius: 2 * intensity,
        ),
      ];

  /// Glow shadow list for rectangular surfaces.
  ///
  /// Some legacy widgets in the app expect this helper.
  static List<BoxShadow> boxGlow(Color c, {double intensity = 1.0}) => [
        BoxShadow(
          color: c.withValues(alpha: 0.35 * intensity),
          blurRadius: 18 * intensity,
          spreadRadius: 2 * intensity,
        ),
        BoxShadow(
          color: c.withValues(alpha: 0.18 * intensity),
          blurRadius: 36 * intensity,
          spreadRadius: 4 * intensity,
        ),
      ];

  /// The standard "Neon Frame" decoration for the Club Blackout design language.
  /// Combines a dark surface, a neon border, and an outer glow.
  static BoxDecoration neonFrame({
    required Color color,
    double opacity = 0.85,
    double borderRadius = 16,
    double borderWidth = 1.2,
    bool showGlow = true,
  }) {
    return BoxDecoration(
      color: pureBlack.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: borderWidth > 0
          ? Border.all(
              color: color.withValues(alpha: 0.8),
              width: borderWidth,
            )
          : null,
      boxShadow: showGlow && borderWidth > 0
          ? [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 12,
                spreadRadius: 1,
              ),
            ]
          : null,
    );
  }

  static BoxDecoration cardDecoration({
    required Color glowColor,
    double glowIntensity = 1.0,
    double borderRadius = 16,
    Color? surfaceColor,
  }) {
    final baseSurface = surfaceColor ?? pureBlack;
    return BoxDecoration(
      color: baseSurface.withValues(alpha: 0.75),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: glowColor.withValues(alpha: 0.8), width: 1.5),
      boxShadow: [
        BoxShadow(
          color: glowColor.withValues(alpha: 0.3 * glowIntensity),
          blurRadius: 15 * glowIntensity,
          spreadRadius: 1 * glowIntensity,
        ),
      ],
    );
  }

  static BoxDecoration glassmorphism({
    required Color color,
    double opacity = 0.85,
    Color borderColor = const Color(0x3DFFFFFF),
    double borderRadius = 16,
    double borderWidth = 1.0,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: borderWidth),
    );
  }

  static Widget centeredConstrained(
      {required Widget child, double maxWidth = 820}) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  static ButtonStyle neonButtonStyle(Color color, {bool isPrimary = false}) {
    final fg = contrastOn(color);

    return FilledButton.styleFrom(
      backgroundColor: color.withValues(alpha: isPrimary ? 0.95 : 0.85),
      foregroundColor: fg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  static ShapeBorder neonDialogShape(Color accent) {
    return RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radiusLg),
      side: BorderSide(color: accent.withValues(alpha: 0.55), width: 1.5),
    );
  }

  static BoxDecoration neonBottomSheetDecoration(
    BuildContext context, {
    required Color accent,
    double opacity = 0.92,
  }) {
    final cs = Theme.of(context).colorScheme;
    return BoxDecoration(
      color: pureBlack.withValues(alpha: opacity),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(radiusSheet)),
      border: Border.all(color: accent.withValues(alpha: 0.45), width: 1),
      boxShadow: [
        BoxShadow(
          color: accent.withValues(alpha: 0.18),
          blurRadius: 18,
          spreadRadius: 1,
        ),
      ],
    ).copyWith(
      // Slight lift from the background if surface tint differs.
      color: cs.surface.withValues(alpha: 0.90),
    );
  }

  static Widget blurredBackdrop({required Widget child, double sigma = 12}) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
        child: child,
      ),
    );
  }

  static ThemeData createTheme(ColorScheme colorScheme) {
    // Material 3: theme should be derived from a ColorScheme.
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: colorScheme.brightness,
    );

    final onSurface = colorScheme.onSurface;
    final onSurfaceVariant = colorScheme.onSurfaceVariant;
    final primary = colorScheme.primary;

    final textTheme = base.textTheme.apply(
      bodyColor: onSurface,
      displayColor: onSurface,
    ).copyWith(
      displayLarge: const TextStyle(letterSpacing: 2.0),
      displayMedium: const TextStyle(letterSpacing: 1.5),
      displaySmall: const TextStyle(letterSpacing: 1.2),
      headlineLarge: const TextStyle(fontWeight: FontWeight.bold),
      titleLarge: const TextStyle(fontWeight: FontWeight.w600, fontSize: 22),
    );

    final defaultRadius = BorderRadius.circular(16);
    final faintDivider = onSurface.withValues(alpha: 0.14);
    final faintSurface = pureWhite.withValues(alpha: 0.06);

    return base.copyWith(
      scaffoldBackgroundColor: pureBlack,
      splashFactory: InkSparkle.splashFactory,
      visualDensity: VisualDensity.standard,
      textSelectionTheme: base.textSelectionTheme.copyWith(
        cursorColor: primary,
        selectionColor: primary.withValues(alpha: 0.28),
        selectionHandleColor: primary,
      ),
      iconTheme: base.iconTheme.copyWith(
        color: onSurface.withValues(alpha: 0.9),
        size: 22,
      ),
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: colorScheme.surface,
        scrolledUnderElevation: 3,
        centerTitle: true,
        foregroundColor: onSurface,
        titleTextStyle: neonGlowTextStyle(
          base: textTheme.titleLarge,
          color: primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
      ),
      drawerTheme: base.drawerTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        iconColor: primary,
        textColor: onSurface,
        titleTextStyle: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      dialogTheme: base.dialogTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHigh,
        insetPadding: dialogInsetPadding,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: primary.withValues(alpha: 0.3), width: 1.0),
        ),
        titleTextStyle: textTheme.headlineSmall?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: onSurfaceVariant,
        ),
      ),
      snackBarTheme: base.snackBarTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.95),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primary, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
          foregroundColor: onSurface,
          shape: RoundedRectangleBorder(borderRadius: defaultRadius),
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
          ),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? primary.withValues(alpha: 0.14)
                : null,
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: onSurface.withValues(alpha: 0.92),
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.all(12),
          shape: RoundedRectangleBorder(borderRadius: defaultRadius),
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.pressed)
                ? primary.withValues(alpha: 0.12)
                : null,
          ),
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: colorScheme.surfaceContainer,
        elevation: 1,
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          minimumSize: const Size(64, 40),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),
      progressIndicatorTheme: base.progressIndicatorTheme.copyWith(
        color: primary,
        linearTrackColor: colorScheme.surfaceContainerHighest,
      ),
      dividerTheme: base.dividerTheme.copyWith(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 16,
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedColor: colorScheme.primaryContainer,
        disabledColor: onSurface.withValues(alpha: 0.12),
        checkmarkColor: colorScheme.onPrimaryContainer,
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        labelStyle: textTheme.labelLarge?.copyWith(
          color: onSurfaceVariant,
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: colorScheme.onPrimaryContainer,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: base.bottomSheetTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainer,
        modalBackgroundColor: colorScheme.surfaceContainer,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      navigationBarTheme: base.navigationBarTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationDrawerTheme: base.navigationDrawerTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerLow,
        indicatorColor: colorScheme.secondaryContainer,
        tileHeight: 56,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      bottomAppBarTheme: base.bottomAppBarTheme.copyWith(
        color: colorScheme.surfaceContainer,
        elevation: 0,
      ),
      tabBarTheme: base.tabBarTheme.copyWith(
        labelColor: primary,
        unselectedLabelColor: onSurface.withValues(alpha: 0.75),
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
        unselectedLabelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorColor: primary,
        dividerColor: faintDivider,
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        decoration: BoxDecoration(
          color: pureBlack.withValues(alpha: 0.92),
          borderRadius: ClubBlackoutTheme.borderRadiusSmAll,
          border: Border.all(color: primary.withValues(alpha: 0.5), width: 1),
          boxShadow: [
            BoxShadow(
              color: primary.withValues(alpha: 0.25),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        textStyle: textTheme.bodySmall?.copyWith(
          color: onSurface.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        color: pureBlack.withValues(alpha: 0.92),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: primary.withValues(alpha: 0.45), width: 1),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(
          color: onSurface.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            pureBlack.withValues(alpha: 0.92),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: primary.withValues(alpha: 0.45), width: 1),
            ),
          ),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(vertical: 8)),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        inputDecorationTheme: base.inputDecorationTheme,
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            pureBlack.withValues(alpha: 0.92),
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: primary.withValues(alpha: 0.45), width: 1),
            ),
          ),
        ),
        textStyle: textTheme.bodyMedium?.copyWith(
          color: onSurface.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: defaultRadius),
          side: BorderSide(color: primary, width: 1.5),
          foregroundColor: primary,
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: defaultRadius),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        side: BorderSide(color: onSurface.withValues(alpha: 0.45), width: 1.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : Colors.transparent,
        ),
        checkColor: const WidgetStatePropertyAll(pureBlack),
      ),
      radioTheme: base.radioTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : onSurface.withValues(alpha: 0.65),
        ),
      ),
      switchTheme: base.switchTheme.copyWith(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary
              : onSurface.withValues(alpha: 0.55),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.35)
              : onSurface.withValues(alpha: 0.22),
        ),
        trackOutlineColor: WidgetStatePropertyAll(onSurface.withValues(alpha: 0.25)),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: primary,
        inactiveTrackColor: faintSurface,
        thumbColor: primary,
        overlayColor: primary.withValues(alpha: 0.18),
        valueIndicatorColor: pureBlack.withValues(alpha: 0.92),
        valueIndicatorTextStyle: textTheme.labelMedium?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w800,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: pureBlack.withValues(alpha: 0.5),
        contentPadding: fieldPadding,
        border: OutlineInputBorder(
          borderRadius: defaultRadius,
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: defaultRadius,
          borderSide: BorderSide(color: onSurface.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: defaultRadius,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.7)),
        hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.4)),
      ),
    );
  }

  static InputDecoration neonInputDecoration(
    BuildContext context, {
    required String hint,
    required Color color,
    IconData? icon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: cs.onSurface.withValues(alpha: 0.3),
        letterSpacing: 1.2,
      ),
      prefixIcon: icon != null
          ? Icon(
              icon,
              color: color.withValues(alpha: 0.6),
            )
          : null,
      filled: true,
      fillColor: cs.surface.withValues(alpha: 0.4),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: color.withValues(alpha: 0.4),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: color,
          width: 2,
        ),
      ),
    );
  }
}

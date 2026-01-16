import 'package:flutter/material.dart';

class ClubBlackoutTheme {
  static const Color backgroundBlack = Color(0xFF000000);
  static const Color neonPink = Color(0xFFFF00FF);
  static const Color neonBlue = Color(0xFF00FFEF);
  static const Color neonGreen = Color(0xFF39FF14);
  static const Color neonRed = Color(0xFFFF0000);
  static const Color neonOrange = Color(0xFFFF9933);
  static const Color neonPurple = Color(0xFFBF00FF);

  // Legacy/compat aliases used by some widgets
  static const Color crimsonRed = neonRed;
  static const Color electricBlue = neonBlue;

  // Shared typography used by some widgets
  static const TextStyle primaryFont = TextStyle(fontFamily: 'Hyperwave');

  static TextStyle get headingStyle => const TextStyle(
        fontFamily: 'Hyperwave',
        fontSize: 24,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      );

  // Enhanced glow effects
  static List<Shadow> iconGlow(Color color, {double intensity = 1.0}) => textGlow(color, intensity: intensity);
  
  static List<Shadow> textGlow(Color color, {double intensity = 1.0}) => [
        Shadow(color: color, blurRadius: 8 * intensity),
        Shadow(color: color.withOpacity(0.8), blurRadius: 16 * intensity),
        Shadow(color: color.withOpacity(0.5), blurRadius: 24 * intensity),
      ];

  static List<BoxShadow> boxGlow(Color color, {double intensity = 1.0}) => [
        BoxShadow(
          color: color.withOpacity(0.6 * intensity),
          blurRadius: 12,
          spreadRadius: 2,
        ),
        BoxShadow(
          color: color.withOpacity(0.4 * intensity),
          blurRadius: 24,
          spreadRadius: 4,
        ),
        BoxShadow(
          color: color.withOpacity(0.2 * intensity),
          blurRadius: 32,
          spreadRadius: 0,
        ),
      ];

  // Circular glow without square shadow
  static List<BoxShadow> circleGlow(Color color, {double intensity = 1.0}) => [
        BoxShadow(
          color: color.withOpacity(0.6 * intensity),
          blurRadius: 10,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: color.withOpacity(0.35 * intensity),
          blurRadius: 20,
          spreadRadius: 0,
        ),
        BoxShadow(
          color: color.withOpacity(0.18 * intensity),
          blurRadius: 32,
          spreadRadius: 0,
        ),
      ];

  /// Centers content and constrains width for better readability on tablets/web.
  static Widget centeredConstrained({
    required Widget child,
    double maxWidth = 720,
  }) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }

  // Enhanced glassmorphism effect
  static BoxDecoration glassmorphism({
    Color? color,
    double blur = 10,
    double opacity = 0.1,
    Color borderColor = Colors.white24,
    double borderWidth = 1,
    double borderRadius = 16,
  }) {
    return BoxDecoration(
      color: (color ?? Colors.white).withOpacity(opacity),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: borderColor, width: borderWidth),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.3),
          blurRadius: 20,
          offset: const Offset(0, 10),
        ),
      ],
    );
  }

  // Gradient backgrounds
  static LinearGradient neonGradient(Color color1, Color color2) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        color1,
        color2,
        color1.withOpacity(0.7),
      ],
      stops: const [0.0, 0.5, 1.0],
    );
  }

  static ButtonStyle neonButtonStyle(Color color, {bool isPrimary = false}) {
    return FilledButton.styleFrom(
      backgroundColor: Colors.black,
      foregroundColor: color,
      side: BorderSide(color: color, width: isPrimary ? 2.5 : 2),
      shadowColor: color.withOpacity(0.5),
      elevation: isPrimary ? 8 : 6,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      textStyle: TextStyle(
        fontSize: isPrimary ? 22 : 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    ).copyWith(
      overlayColor: MaterialStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(MaterialState.pressed)) {
            return color.withOpacity(0.3);
          }
          if (states.contains(MaterialState.hovered)) {
            return color.withOpacity(0.1);
          }
          return null;
        },
      ),
    );
  }

  // Card decoration with enhanced depth
  static BoxDecoration cardDecoration({
    required Color glowColor,
    double glowIntensity = 1.0,
    double borderRadius = 20,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.black,
          const Color(0xFF0A0A0A),
          Colors.black,
        ],
      ),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(color: glowColor.withOpacity(0.6), width: 2),
      boxShadow: [
        ...boxGlow(glowColor, intensity: glowIntensity),
        BoxShadow(
          color: Colors.black.withOpacity(0.5),
          blurRadius: 30,
          offset: const Offset(0, 15),
        ),
      ],
    );
  }

  static ThemeData createTheme(ColorScheme? dynamicColorScheme) {
    final Color seed = dynamicColorScheme?.primary ?? neonBlue;

    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF1C1C1E),
    ).copyWith(surface: const Color(0xFF1C1C1E));

    return ThemeData(
      useMaterial3: true,
      splashFactory: InkSparkle.splashFactory,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundBlack,

      textTheme: TextTheme(
        displayLarge: TextStyle(
          fontSize: 74,
          height: 1.12,
          letterSpacing: -0.2,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurface,
        ),
        displayMedium: TextStyle(
          fontSize: 59,
          height: 1.16,
          letterSpacing: 0,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurface,
        ),
        displaySmall: TextStyle(
          fontSize: 47,
          height: 1.22,
          letterSpacing: 0,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurface,
        ),
        headlineLarge: TextStyle(
          fontSize: 42,
          height: 1.25,
          letterSpacing: 0,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurface,
        ),
        headlineMedium: TextStyle(
          fontSize: 36,
          height: 1.29,
          letterSpacing: 0,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: 31,
          height: 1.33,
          letterSpacing: 0,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurface,
        ),
        titleLarge: TextStyle(
          fontSize: 29,
          height: 1.27,
          letterSpacing: 0,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 21,
          height: 1.5,
          letterSpacing: 0.15,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 18,
          height: 1.43,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        labelLarge: TextStyle(
          fontSize: 15,
          height: 1.43,
          letterSpacing: 0.1,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        labelMedium: TextStyle(
          fontSize: 13,
          height: 1.33,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          height: 1.45,
          letterSpacing: 0.5,
          fontWeight: FontWeight.w500,
          color: colorScheme.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          height: 1.5,
          letterSpacing: 0.5,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurfaceVariant,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.43,
          letterSpacing: 0.25,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurfaceVariant,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          height: 1.33,
          letterSpacing: 0.4,
          fontWeight: FontWeight.normal,
          color: colorScheme.onSurfaceVariant,
        ),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: backgroundBlack,
          foregroundColor: Colors.white,
          side: BorderSide.none,
          shadowColor: const Color(0x40FFFFFF),
          elevation: 8,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundBlack,
          foregroundColor: Colors.white,
          side: BorderSide.none,
          shadowColor: const Color(0x40FFFFFF),
          elevation: 8,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: const StadiumBorder(),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white, width: 2),
        ),
        contentPadding: const EdgeInsets.all(16),
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
      ),

      cardTheme: CardThemeData(
        color: colorScheme.surfaceVariant.withOpacity(0.6),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: MaterialStateProperty.all(
          TextStyle(color: colorScheme.onSurface),
        ),
        iconTheme: MaterialStateProperty.all(
          IconThemeData(color: colorScheme.onSurfaceVariant),
        ),
      ),

      iconTheme: IconThemeData(color: colorScheme.primary, size: 24),

      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: backgroundBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(28)),
          side: BorderSide.none,
        ),
        titleTextStyle: TextStyle(
          fontSize: 29,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        contentTextStyle: TextStyle(fontSize: 18, color: Colors.white),
      ),

      drawerTheme: const DrawerThemeData(
        backgroundColor: backgroundBlack,
        width: 300,
      ),

      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: backgroundBlack,
        indicatorColor: colorScheme.secondaryContainer,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return TextStyle(
              color: colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            );
          }
          return TextStyle(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return IconThemeData(color: colorScheme.onSecondaryContainer);
          }
          return IconThemeData(color: colorScheme.onSurfaceVariant);
        }),
      ),

      popupMenuTheme: PopupMenuThemeData(
        color: backgroundBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: neonBlue, width: 1),
        ),
        textStyle: const TextStyle(color: Colors.white),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.surfaceVariant,
        contentTextStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        actionTextColor: colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primaryContainer;
          }
          return colorScheme.surfaceVariant;
        }),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(color: colorScheme.outline),
      ),

      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline;
        }),
      ),

      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
    );
  }
}

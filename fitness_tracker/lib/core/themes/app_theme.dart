import 'package:flutter/material.dart';

/// Application theme configuration
/// Centralizes all color and style definitions to avoid hardcoding
class AppTheme {
  AppTheme._();

  // ==================== COLOR PALETTE ====================
  // Primary Colors
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color primaryOrangeDark = Color(0xFFE55A2B);
  static const Color primaryOrangeLight = Color(0xFFFF8C5A);

  // Background Colors
  static const Color backgroundDark = Color(0xFF0A0A0A);
  static const Color surfaceDark = Color(0xFF1A1A1A);
  static const Color surfaceMedium = Color(0xFF2A2A2A);
  static const Color surfaceLight = Color(0xFF3A3A3A);

  // Text Colors
  static const Color textLight = Color(0xFFFFFFFF);
  static const Color textMedium = Color(0xFFBBBBBB);
  static const Color textDim = Color(0xFF888888);
  static const Color textDisabled = Color(0xFF555555);

  // Border Colors
  static const Color borderDark = Color(0xFF2A2A2A);
  static const Color borderMedium = Color(0xFF3A3A3A);
  static const Color borderLight = Color(0xFF4A4A4A);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFFA726);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF29B6F6);

  // Status color aliases used by Phase 7 widgets and nutrition UI
  // These forward to the canonical names above.
  static const Color successGreen = success;
  static const Color warningAmber = warning;
  static const Color errorRed = error;

  // Web Phone Frame Colors
  static const Color webFrameBackground = Color(0xFF111111);
  static const Color webFrameNotch = Color(0xFF252525);
  static const Color webFrameShadow = Color(0x66000000);

  // Muscle Visualization Colors
  static const Color intensityNone = Color(0xFF2A2A2A);
  static const Color intensityLow = Color(0xFF4A5F4A);
  static const Color intensityMedium = Color(0xFF7A9F7A);
  static const Color intensityHigh = Color(0xFFAADFAA);
  static const Color intensityVeryHigh = Color(0xFFDAFFDA);

  // ==================== DARK THEME ====================
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: backgroundDark,
    primaryColor: primaryOrange,

    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: primaryOrange,
      secondary: primaryOrangeLight,
      surface: surfaceDark,
      error: error,
      onPrimary: textLight,
      onSecondary: textLight,
      onSurface: textLight,
      onError: textLight,
    ),

    // AppBar Theme
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundDark,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: textLight,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      iconTheme: IconThemeData(color: textLight),
    ),

    // Card Theme
    cardTheme: CardThemeData(
      color: surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: borderDark, width: 1),
      ),
    ),

    // Text Theme
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: textLight,
        fontSize: 32,
        fontWeight: FontWeight.bold,
      ),
      headlineMedium: TextStyle(
        color: textLight,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      headlineSmall: TextStyle(
        color: textLight,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      titleLarge: TextStyle(
        color: textLight,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        color: textLight,
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      titleSmall: TextStyle(
        color: textMedium,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: TextStyle(color: textLight, fontSize: 16),
      bodyMedium: TextStyle(color: textMedium, fontSize: 14),
      bodySmall: TextStyle(color: textDim, fontSize: 12),
      labelLarge: TextStyle(
        color: textLight,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      labelMedium: TextStyle(color: textMedium, fontSize: 12),
      labelSmall: TextStyle(color: textDim, fontSize: 10),
    ),

    // Input Decoration Theme
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderMedium),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: borderMedium),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: primaryOrange, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: error),
      ),
      labelStyle: const TextStyle(color: textMedium),
      hintStyle: const TextStyle(color: textDim),
    ),

    // Button Themes
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryOrange,
        foregroundColor: textLight,
        elevation: 2,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryOrange,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryOrange,
        side: const BorderSide(color: primaryOrange),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),

    // Icon Theme
    iconTheme: const IconThemeData(color: textLight, size: 24),

    // Divider Theme
    dividerTheme: const DividerThemeData(
      color: borderDark,
      thickness: 1,
      space: 1,
    ),

    // Slider Theme
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryOrange,
      inactiveTrackColor: borderMedium,
      thumbColor: primaryOrange,
      overlayColor: primaryOrange.withValues(alpha: 0.2),
      valueIndicatorColor: primaryOrange,
      valueIndicatorTextStyle: const TextStyle(
        color: textLight,
        fontSize: 14,
        fontWeight: FontWeight.bold,
      ),
    ),

    // Switch Theme
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryOrange;
        }
        return textDim;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryOrange.withValues(alpha: 0.5);
        }
        return borderMedium;
      }),
    ),

    // Checkbox Theme
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryOrange;
        }
        return Colors.transparent;
      }),
      checkColor: const WidgetStatePropertyAll(textLight),
      side: const BorderSide(color: borderMedium, width: 2),
    ),

    // Radio Theme
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryOrange;
        }
        return borderMedium;
      }),
    ),

    // Bottom Navigation Bar Theme
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surfaceDark,
      selectedItemColor: primaryOrange,
      unselectedItemColor: textDim,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),

    // Dialog Theme
    dialogTheme: DialogThemeData(
      backgroundColor: surfaceDark,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      titleTextStyle: const TextStyle(
        color: textLight,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
      contentTextStyle: const TextStyle(color: textMedium, fontSize: 16),
    ),

    // Snackbar Theme
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: surfaceMedium,
      contentTextStyle: TextStyle(color: textLight),
      behavior: SnackBarBehavior.floating,
      elevation: 4,
    ),
  );

  // ==================== CUSTOM GRADIENTS ====================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryOrange, primaryOrangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [surfaceDark, surfaceMedium],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ==================== CUSTOM SHADOWS ====================
  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> elevatedShadow = [
    BoxShadow(color: Color(0x60000000), blurRadius: 12, offset: Offset(0, 4)),
  ];
}

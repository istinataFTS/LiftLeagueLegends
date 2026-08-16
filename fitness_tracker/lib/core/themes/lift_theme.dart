// lib/core/themes/lift_theme.dart  (token classes only — LiftTheme lands in Task 3)
import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';

/// Deep Mist palette. Every surface above [LiftGround] is translucent so the
/// two-tone ground shows through — do not give a screen an opaque background.
class LiftColors {
  LiftColors._();

  // Ground
  static const Color groundLight = Color(0xFF2E3944);
  static const Color groundDark = Color(0xFF141A21);
  static const Color groundMid = Color(0xFF28323B);

  /// Flat fallback for chrome that cannot take a gradient.
  static const Color background = Color(0xFF1B222A);

  // Surfaces
  static const Color surface = Color(0x12FFFFFF); // 7%
  static const Color surfaceRaised = Color(0x1FFFFFFF); // 12%
  static const Color surfaceSunken = Color(0x0AFFFFFF); // 4%

  // Modal panels — near-opaque so text stays legible over content.
  static const Color panelTop = Color(0xF01E262F);
  static const Color panelBottom = Color(0xF0151B22);
  static const Color scrim = Color(0x990A0E12);

  // Borders
  static const Color borderStrong = Color(0x4DFFFFFF); // 30%
  static const Color border = Color(0x42FFFFFF); // 26%
  static const Color rule = Color(0x2BFFFFFF); // 17%
  static const Color hairline = Color(0x21FFFFFF); // 13%

  // Text
  static const Color textPrimary = Color(0xFFEEF2F6);
  static const Color textStrong = Color(0xD1EEF2F6);
  static const Color textSecondary = Color(0xB3EEF2F6);
  static const Color textDim = Color(0x99EEF2F6);
  static const Color textFaint = Color(0x80EEF2F6);
  static const Color textDisabled = Color(0x6BEEF2F6);

  // Action — two roles, never interchanged.
  static const Color actionFill = Color(0xFF226096);
  static const Color actionFillPressed = Color(0xFF1A4B77);
  static const Color actionTint = Color(0xFF7BB6EB);
  static const Color actionWash = Color(0x1F7BB6EB);

  // Status
  static const Color success = Color(0xFF5FD08A);
  static const Color warning = Color(0xFFF0A93B);
  static const Color error = Color(0xFFE5675B);
  static const Color info = Color(0xFF7BB6EB);

  // Macros
  static const Color protein = Color(0xFFA78BFA);
  static const Color carbs = Color(0xFF5FD08A);
  static const Color fats = Color(0xFFF0A93B);

  /// Muscle-map fatigue. Brighter = more fatigued. A body state, not a choice.
  static const List<Color> fatigue = <Color>[
    Color(0x0DFFFFFF),
    Color(0x33FFFFFF),
    Color(0x61FFFFFF),
    Color(0x94FFFFFF),
    Color(0xE6FFFFFF),
  ];

  /// Effort, in two deliberately different encodings. The picker
  /// (`LogIntensitySelector`) gives rung height the value: its six rungs
  /// grow taller left to right and only the selected one takes [effortOn].
  /// The set row (`ExerciseSetRow`) gives count the value: its five marks
  /// are all the same size and fill cumulatively, marks below the level
  /// taking [effortOn]. Everything not filled takes [effortOff]. Hue never
  /// changes in either — only which of the two tokens applies.
  static const Color effortOn = actionTint;
  static const Color effortOff = Color(0x1FFFFFFF);
}

/// The two-tone ground, painted once behind every screen via
/// `MaterialApp.builder`.
class LiftGround extends StatelessWidget {
  const LiftGround({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[LiftColors.groundMid, LiftColors.groundDark],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(-0.7, -0.9),
            radius: 1.25,
            colors: <Color>[LiftColors.groundLight, Color(0x002E3944)],
            stops: <double>[0.0, 0.64],
          ),
        ),
        child: child,
      ),
    );
  }
}

class LiftShape {
  LiftShape._();

  static const double radiusButton = 8;
  static const double radiusPanel = 0;
  static const double radiusInput = 0;
  static const double radiusChip = 0;
  static const double borderWidth = 1.5;
  static const double borderWidthActive = 2.5;
}

class LiftElevation {
  LiftElevation._();

  /// Panels are separated by borders and rules, never by shadow.
  static const List<BoxShadow> card = <BoxShadow>[];

  /// Only modals lift off the page.
  static const List<BoxShadow> elevated = <BoxShadow>[
    BoxShadow(color: Color(0x800A0E12), blurRadius: 48, offset: Offset(0, 22)),
  ];
}

class LiftText {
  LiftText._();

  static const String _uiFamily = 'SpaceGrotesk';
  static const String _monoFamily = 'JetBrainsMono';

  static const TextStyle headlineLarge = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    height: 1.05,
    letterSpacing: -0.8,
  );
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    height: 1.1,
    letterSpacing: -0.65,
  );
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 21,
    fontWeight: FontWeight.w700,
    height: 1.15,
    letterSpacing: -0.4,
  );
  static const TextStyle titleLarge = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.2,
  );
  static const TextStyle titleMedium = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );
  static const TextStyle titleSmall = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    height: 1.2,
  );

  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 12.5,
    fontWeight: FontWeight.w400,
    height: 1.5,
  );
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _uiFamily,
    fontSize: 11.5,
    fontWeight: FontWeight.w400,
    height: 1.45,
  );

  /// Labels are uppercase letterspaced mono. NEVER used for a value.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.8,
  );
  static const TextStyle labelMedium = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 9.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 2.1,
  );
  static const TextStyle labelSmall = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 8.5,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
  );

  // Data styles — every quantity in the app uses one of these.
  static const TextStyle dataHero = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.6,
  );
  static const TextStyle dataLarge = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.3,
  );
  static const TextStyle dataMedium = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.8,
  );
  static const TextStyle dataSmall = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
  );
  static const TextStyle dataMeta = TextStyle(
    fontFamily: _monoFamily,
    fontSize: 12,
    fontWeight: FontWeight.w700,
  );

  static const List<FontFeature> dataFeatures = <FontFeature>[
    FontFeature.tabularFigures(),
  ];
}

class LiftTheme {
  static ThemeData dark() {
    final ThemeData base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: Colors.transparent, // LiftGround paints it
      colorScheme: const ColorScheme.dark(
        primary: LiftColors.actionFill,
        onPrimary: Colors.white,
        primaryContainer: LiftColors.actionFillPressed,
        secondary: LiftColors.actionTint,
        onSecondary: LiftColors.background,
        surface: LiftColors.background,
        onSurface: LiftColors.textPrimary,
        error: LiftColors.error,
        onError: Colors.white,
        outline: LiftColors.border,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: LiftText.headlineMedium.copyWith(
          color: LiftColors.textPrimary,
        ),
        iconTheme: const IconThemeData(color: LiftColors.textDim, size: 21),
        shape: const Border(
          bottom: BorderSide(
            color: LiftColors.rule,
            width: LiftShape.borderWidth,
          ),
        ),
      ),

      textTheme: base.textTheme.copyWith(
        headlineLarge: LiftText.headlineLarge.copyWith(
          color: LiftColors.textPrimary,
        ),
        headlineMedium: LiftText.headlineMedium.copyWith(
          color: LiftColors.textPrimary,
        ),
        headlineSmall: LiftText.headlineSmall.copyWith(
          color: LiftColors.textPrimary,
        ),
        titleLarge: LiftText.titleLarge.copyWith(color: LiftColors.textPrimary),
        titleMedium: LiftText.titleMedium.copyWith(
          color: LiftColors.textPrimary,
        ),
        titleSmall: LiftText.titleSmall.copyWith(color: LiftColors.textPrimary),
        bodyLarge: LiftText.bodyLarge.copyWith(color: LiftColors.textSecondary),
        bodyMedium: LiftText.bodyMedium.copyWith(
          color: LiftColors.textSecondary,
        ),
        bodySmall: LiftText.bodySmall.copyWith(color: LiftColors.textDim),
        labelLarge: LiftText.labelLarge.copyWith(color: LiftColors.textStrong),
        labelMedium: LiftText.labelMedium.copyWith(
          color: LiftColors.textStrong,
        ),
        labelSmall: LiftText.labelSmall.copyWith(color: LiftColors.textDim),
      ),

      // Panels: translucent fill + visible border, no shadow, square corners.
      cardTheme: CardThemeData(
        color: LiftColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(
          side: BorderSide(
            color: LiftColors.border,
            width: LiftShape.borderWidth,
          ),
          borderRadius: BorderRadius.zero,
        ),
      ),

      dividerTheme: const DividerThemeData(
        color: LiftColors.rule,
        thickness: LiftShape.borderWidth,
        space: LiftShape.borderWidth,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: false,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        hintStyle: LiftText.bodyLarge.copyWith(color: LiftColors.textFaint),
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: LiftColors.border,
            width: LiftShape.borderWidth,
          ),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: LiftColors.border,
            width: LiftShape.borderWidth,
          ),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: LiftColors.actionTint,
            width: LiftShape.borderWidthActive,
          ),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(
            color: LiftColors.error,
            width: LiftShape.borderWidth,
          ),
        ),
        errorStyle: LiftText.bodySmall.copyWith(color: LiftColors.error),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: LiftColors.actionFill,
          foregroundColor: Colors.white,
          disabledBackgroundColor: LiftColors.surface,
          disabledForegroundColor: LiftColors.textDisabled,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LiftShape.radiusButton),
          ),
          textStyle: LiftText.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LiftColors.textStrong,
          side: const BorderSide(
            color: LiftColors.border,
            width: LiftShape.borderWidth,
          ),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(LiftShape.radiusButton),
          ),
          textStyle: LiftText.labelLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: LiftColors.actionTint,
          textStyle: LiftText.labelMedium,
        ),
      ),

      // Chips are FILTERS ONLY. Never use a chip to display a value.
      chipTheme: ChipThemeData(
        backgroundColor: Colors.transparent,
        selectedColor: LiftColors.actionFill,
        side: const BorderSide(
          color: LiftColors.border,
          width: LiftShape.borderWidth,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        labelStyle: LiftText.labelMedium.copyWith(
          color: LiftColors.textSecondary,
        ),
        secondaryLabelStyle: LiftText.labelMedium.copyWith(color: Colors.white),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        showCheckmark: false,
      ),

      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: LiftColors.surface,
        selectedItemColor: LiftColors.actionTint,
        unselectedItemColor: LiftColors.textDim,
        selectedLabelStyle: LiftText.labelSmall.copyWith(
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: LiftText.labelSmall,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: LiftColors.panelTop,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          side: BorderSide(
            color: LiftColors.borderStrong,
            width: LiftShape.borderWidth,
          ),
          borderRadius: BorderRadius.zero,
        ),
        titleTextStyle: LiftText.titleLarge.copyWith(
          color: LiftColors.textPrimary,
        ),
        contentTextStyle: LiftText.bodyMedium.copyWith(
          color: LiftColors.textSecondary,
        ),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: LiftColors.surface,
        modalBackgroundColor: LiftColors.panelTop,
        elevation: 0,
        modalElevation: 0,
        shape: RoundedRectangleBorder(
          side: BorderSide(
            color: LiftColors.border,
            width: LiftShape.borderWidth,
          ),
          borderRadius: BorderRadius.zero,
        ),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: LiftColors.panelTop,
        contentTextStyle: LiftText.bodyMedium.copyWith(
          color: LiftColors.textPrimary,
        ),
        actionTextColor: LiftColors.actionTint,
        behavior: SnackBarBehavior.floating,
        shape: const RoundedRectangleBorder(
          side: BorderSide(
            color: LiftColors.border,
            width: LiftShape.borderWidth,
          ),
          borderRadius: BorderRadius.zero,
        ),
      ),

      sliderTheme: SliderThemeData(
        activeTrackColor: LiftColors.actionTint,
        inactiveTrackColor: LiftColors.effortOff,
        thumbColor: LiftColors.actionTint,
        overlayColor: LiftColors.actionWash,
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        showValueIndicator: ShowValueIndicator.never,
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? Colors.white
              : LiftColors.textDim,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? LiftColors.actionFill
              : LiftColors.surfaceRaised,
        ),
        trackOutlineColor: WidgetStateProperty.all(LiftColors.border),
      ),

      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? LiftColors.actionFill
              : Colors.transparent,
        ),
        checkColor: WidgetStateProperty.all(Colors.white),
        side: const BorderSide(
          color: LiftColors.border,
          width: LiftShape.borderWidth,
        ),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> s) => s.contains(WidgetState.selected)
              ? LiftColors.actionTint
              : LiftColors.border,
        ),
      ),

      tabBarTheme: TabBarThemeData(
        labelColor: LiftColors.textPrimary,
        unselectedLabelColor: LiftColors.textDim,
        labelStyle: LiftText.labelLarge,
        unselectedLabelStyle: LiftText.labelLarge,
        indicatorColor: LiftColors.actionTint,
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: LiftColors.rule,
      ),

      iconTheme: const IconThemeData(color: LiftColors.textDim, size: 21),
    );
  }
}

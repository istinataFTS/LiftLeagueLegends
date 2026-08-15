import 'package:flutter/material.dart';

import 'lift_theme.dart';

/// Legacy palette, retained only so the 424 existing call sites keep compiling
/// while the Deep Mist restyle lands screen by screen. Every member forwards to
/// a [LiftColors] token.
///
/// Do not add members. Do not use in new code — use [LiftColors] directly.
/// Deleted in the final restyle PR (B7), which also adds a convention rule
/// preventing its return.
///
/// Deliberately NOT annotated `@Deprecated` — that fires
/// `deprecated_member_use_from_same_package` at all 424 call sites, which
/// `flutter analyze` treats as a warning and CI fails on. The doc comment and
/// the B7 convention rule carry the same message without breaking the build.
class AppTheme {
  AppTheme._();

  // Accent — the overwhelming majority of call sites use primaryOrange as a
  // foreground (icon/text color), so it carries the tint role. The few
  // genuine filled surfaces name LiftColors.actionFill directly instead of
  // going through this bridge.
  static const Color primaryOrange = LiftColors.actionTint;
  static const Color primaryOrangeDark = LiftColors.actionFillPressed;
  static const Color primaryOrangeLight = LiftColors.actionTint;

  // Backgrounds
  static const Color backgroundDark = LiftColors.background;
  static const Color surfaceDark = LiftColors.surface;
  static const Color surfaceMedium = LiftColors.surfaceRaised;
  static const Color surfaceLight = LiftColors.surfaceRaised;

  // Text
  static const Color textLight = LiftColors.textPrimary;
  static const Color textMedium = LiftColors.textSecondary;
  static const Color textDim = LiftColors.textDim;
  static const Color textDisabled = LiftColors.textDisabled;

  // Borders
  static const Color borderDark = LiftColors.hairline;
  static const Color borderMedium = LiftColors.rule;
  static const Color borderLight = LiftColors.border;

  // Status
  static const Color success = LiftColors.success;
  static const Color warning = LiftColors.warning;
  static const Color error = LiftColors.error;
  static const Color info = LiftColors.info;
  static const Color successGreen = success;
  static const Color warningAmber = warning;
  static const Color errorRed = error;

  // Muscle visualisation — white density, no longer a green ramp.
  // `static final`, not `const`: indexing a const List is not a constant
  // expression in Dart, so `LiftColors.fatigue[n]` cannot be a `const`
  // initializer even though `fatigue` itself is `static const`.
  static final Color intensityNone = LiftColors.fatigue[0];
  static final Color intensityLow = LiftColors.fatigue[1];
  static final Color intensityMedium = LiftColors.fatigue[2];
  static final Color intensityHigh = LiftColors.fatigue[3];
  static final Color intensityVeryHigh = LiftColors.fatigue[4];

  static const LinearGradient primaryGradient = LinearGradient(
    colors: <Color>[LiftColors.actionFill, LiftColors.actionFillPressed],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceGradient = LinearGradient(
    colors: <Color>[LiftColors.surface, LiftColors.surfaceRaised],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const List<BoxShadow> cardShadow = LiftElevation.card;
  static const List<BoxShadow> elevatedShadow = LiftElevation.elevated;
}

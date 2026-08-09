import 'package:flutter/material.dart';

import '../../../../../core/themes/lift_theme.dart';

/// Legacy Log palette, retained only so existing call sites keep compiling
/// while the Deep Mist restyle lands. Every member forwards to [LiftColors].
///
/// Do not add members. Deleted in B7. Not annotated `@Deprecated`, for the
/// same reason as [AppTheme] — it would fail `flutter analyze` at every call
/// site.
class LogUiColors {
  LogUiColors._();

  static const Color rowSurface = LiftColors.surfaceSunken;

  static const Color protein = LiftColors.protein;
  static const Color carbs = LiftColors.carbs;
  static const Color fats = LiftColors.fats;

  /// Effort no longer encodes with hue — the count of filled rungs carries the
  /// value. Six identical stops keep any surviving gradient flat until the
  /// widgets are rebuilt as rungs in Task 10.
  static const List<Color> intensityRamp = <Color>[
    LiftColors.effortOn,
    LiftColors.effortOn,
    LiftColors.effortOn,
    LiftColors.effortOn,
    LiftColors.effortOn,
    LiftColors.effortOn,
  ];
}

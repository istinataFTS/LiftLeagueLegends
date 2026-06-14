import 'package:flutter/material.dart';

import '../../../../../core/themes/app_theme.dart';

/// Color constants for the Log feature UI.
/// New tokens not yet in [AppTheme] live here as named constants.
/// Calories reuse [AppTheme.primaryOrangeLight] directly.
class LogUiColors {
  LogUiColors._();

  /// #141414 — between background and surface; used for list/feed rows.
  static const Color rowSurface = Color(0xFF141414);

  /// Macro segment colors — used by composition bar, macro inputs, and meal-row micro-macros.
  static const Color protein = Color(0xFF5DA9F0);
  static const Color carbs = Color(0xFF97C459);
  static const Color fats = Color(0xFFEF9F27);

  /// Intensity ramp, index == intensity level 0–5.
  /// index 0: warm-up (= textDim); index 5: max effort.
  static const List<Color> intensityRamp = <Color>[
    Color(0xFF888888), // 0 Warm-up
    Color(0xFF1D9E75), // 1 Very Light
    Color(0xFF97C459), // 2 Light
    Color(0xFFEF9F27), // 3 Moderate
    Color(0xFFD85A30), // 4 Hard
    Color(0xFFE24B4A), // 5 Max Effort
  ];
}

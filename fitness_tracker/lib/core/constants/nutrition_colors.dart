import 'package:flutter/material.dart';

class NutritionColors {
  NutritionColors._(); // Private constructor - utility class

  // ==================== PRIMARY MACRO COLORS ====================

  /// Protein display color (blue)
  /// Used for protein values, icons, and charts
  static const Color protein = Colors.blue;

  /// Carbohydrates display color (green)
  /// Used for carbs values, icons, and charts
  static const Color carbs = Colors.green;

  /// Fats display color (orange)
  /// Used for fats values, icons, and charts
  static const Color fats = Colors.orange;

  // ==================== LIGHT VARIANTS (with opacity) ====================

  /// Light protein color for backgrounds
  static Color get proteinLight => protein.withValues(alpha: 0.1);

  /// Light carbs color for backgrounds
  static Color get carbsLight => carbs.withValues(alpha: 0.1);

  /// Light fats color for backgrounds
  static Color get fatsLight => fats.withValues(alpha: 0.1);

  // ==================== HELPER METHOD ====================

  /// Get color for a specific macro type
  ///
  /// Usage:
  /// ```dart
  /// final color = NutritionColors.getMacroColor('protein');
  /// ```
  static Color getMacroColor(String macroType) {
    switch (macroType.toLowerCase()) {
      case 'protein':
        return protein;
      case 'carbs':
      case 'carbohydrates':
        return carbs;
      case 'fats':
      case 'fat':
        return fats;
      default:
        return Colors.grey;
    }
  }

  /// Get light variant color for a specific macro type
  static Color getMacroColorLight(String macroType) {
    switch (macroType.toLowerCase()) {
      case 'protein':
        return proteinLight;
      case 'carbs':
      case 'carbohydrates':
        return carbsLight;
      case 'fats':
      case 'fat':
        return fatsLight;
      default:
        return Colors.grey.withValues(alpha: 0.1);
    }
  }
}

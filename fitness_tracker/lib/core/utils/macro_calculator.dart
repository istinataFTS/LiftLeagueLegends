/// Centralized macro calculation utilities
///
/// Provides constants and helper methods for macronutrient calculations.
/// Ensures consistency across the app for calorie and macro computations.
class MacroCalculator {
  MacroCalculator._(); // Private constructor - utility class

  // ==================== CONSTANTS ====================

  /// Calories per gram of carbohydrates
  static const double caloriesPerGramCarbs = 4.0;

  /// Calories per gram of protein
  static const double caloriesPerGramProtein = 4.0;

  /// Calories per gram of fat
  static const double caloriesPerGramFat = 9.0;

  /// Tolerance for calorie validation (in calories)
  /// Allows for minor rounding differences
  static const double calorieTolerance = 1.0;

  // ==================== CALCULATIONS ====================

  /// Calculate total calories from macronutrients
  ///
  /// Formula: (carbs × 4) + (protein × 4) + (fat × 9)
  ///
  /// Parameters:
  /// - [carbs]: Grams of carbohydrates
  /// - [protein]: Grams of protein
  /// - [fat]: Grams of fat
  ///
  /// Returns: Total calories
  static double calculateCalories({
    required double carbs,
    required double protein,
    required double fat,
  }) {
    return (carbs * caloriesPerGramCarbs) +
        (protein * caloriesPerGramProtein) +
        (fat * caloriesPerGramFat);
  }

  /// Validate if stated calories match calculated calories from macros
  ///
  /// Uses tolerance to account for rounding differences.
  ///
  /// Parameters:
  /// - [carbs]: Grams of carbohydrates
  /// - [protein]: Grams of protein
  /// - [fat]: Grams of fat
  /// - [statedCalories]: The claimed calorie value
  ///
  /// Returns: true if calories are within tolerance
  static bool validateCalories({
    required double carbs,
    required double protein,
    required double fat,
    required double statedCalories,
  }) {
    final calculatedCalories = calculateCalories(
      carbs: carbs,
      protein: protein,
      fat: fat,
    );

    return (statedCalories - calculatedCalories).abs() <= calorieTolerance;
  }

  /// Calculate carbs from remaining calories
  ///
  /// Useful when user enters only calories and some macros.
  /// Assumes remaining calories come from carbs.
  ///
  /// Parameters:
  /// - [totalCalories]: Total calories
  /// - [protein]: Known protein in grams
  /// - [fat]: Known fat in grams
  ///
  /// Returns: Calculated carbs in grams (or 0 if invalid)
  static double calculateCarbsFromCalories({
    required double totalCalories,
    required double protein,
    required double fat,
  }) {
    final proteinCalories = protein * caloriesPerGramProtein;
    final fatCalories = fat * caloriesPerGramFat;
    final remainingCalories = totalCalories - proteinCalories - fatCalories;

    if (remainingCalories < 0) return 0.0;

    return remainingCalories / caloriesPerGramCarbs;
  }

  /// Calculate protein from remaining calories
  ///
  /// Useful when user enters only calories and some macros.
  /// Assumes remaining calories come from protein.
  ///
  /// Parameters:
  /// - [totalCalories]: Total calories
  /// - [carbs]: Known carbs in grams
  /// - [fat]: Known fat in grams
  ///
  /// Returns: Calculated protein in grams (or 0 if invalid)
  static double calculateProteinFromCalories({
    required double totalCalories,
    required double carbs,
    required double fat,
  }) {
    final carbsCalories = carbs * caloriesPerGramCarbs;
    final fatCalories = fat * caloriesPerGramFat;
    final remainingCalories = totalCalories - carbsCalories - fatCalories;

    if (remainingCalories < 0) return 0.0;

    return remainingCalories / caloriesPerGramProtein;
  }

  /// Calculate fat from remaining calories
  ///
  /// Useful when user enters only calories and some macros.
  /// Assumes remaining calories come from fat.
  ///
  /// Parameters:
  /// - [totalCalories]: Total calories
  /// - [carbs]: Known carbs in grams
  /// - [protein]: Known protein in grams
  ///
  /// Returns: Calculated fat in grams (or 0 if invalid)
  static double calculateFatFromCalories({
    required double totalCalories,
    required double carbs,
    required double protein,
  }) {
    final carbsCalories = carbs * caloriesPerGramCarbs;
    final proteinCalories = protein * caloriesPerGramProtein;
    final remainingCalories = totalCalories - carbsCalories - proteinCalories;

    if (remainingCalories < 0) return 0.0;

    return remainingCalories / caloriesPerGramFat;
  }

  /// Scale macros and calories by a multiplier
  ///
  /// Useful for meal portion calculations (e.g., 100g → 250g)
  ///
  /// Parameters:
  /// - [carbs]: Original carbs in grams
  /// - [protein]: Original protein in grams
  /// - [fat]: Original fat in grams
  /// - [calories]: Original calories
  /// - [multiplier]: Scaling factor (e.g., 2.5 for 250g from 100g base)
  ///
  /// Returns: Scaled MacroResult
  static MacroResult scaleNutrition({
    required double carbs,
    required double protein,
    required double fat,
    required double calories,
    required double multiplier,
  }) {
    return MacroResult(
      carbs: carbs * multiplier,
      protein: protein * multiplier,
      fat: fat * multiplier,
      calories: calories * multiplier,
    );
  }

  /// Format macro value for display (removes unnecessary decimals)
  ///
  /// Examples:
  /// - 15.0 → "15"
  /// - 15.5 → "15.5"
  /// - 15.123 → "15.1"
  static String formatMacro(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }

  /// Format calories for display (always as integer)
  ///
  /// Examples:
  /// - 276.8 → "277"
  /// - 210.2 → "210"
  static String formatCalories(double value) {
    return value.round().toString();
  }
}

/// Result class for macro calculations
class MacroResult {
  final double carbs;
  final double protein;
  final double fat;
  final double calories;

  const MacroResult({
    required this.carbs,
    required this.protein,
    required this.fat,
    required this.calories,
  });

  @override
  String toString() {
    return 'Carbs: ${MacroCalculator.formatMacro(carbs)}g, '
        'Protein: ${MacroCalculator.formatMacro(protein)}g, '
        'Fat: ${MacroCalculator.formatMacro(fat)}g, '
        'Calories: ${MacroCalculator.formatCalories(calories)}';
  }
}

class AppConstants {
  AppConstants._();

  // ==================== DATABASE ====================
  // databaseVersion is defined in EnvConfig (supports env override via DATABASE_VERSION)
  static const String databaseName = 'fitness_tracker.db';

  // ==================== EXERCISE LIMITS ====================
  static const int maxExercisesPerWorkout = 20;
  static const int maxSetsPerExercise = 10;
  static const int maxReps = 1000;
  static const double maxWeight = 1000.0; // kg
  static const int maxWeeklyGoal = 100;
  static const int maxExerciseNameLength = 50;

  // ==================== NUTRITION LIMITS ====================
  /// Maximum macronutrient value per 100g (in grams)
  static const double maxMacrosPer100g = 100.0;

  /// Maximum calories per 100g serving
  static const double maxCaloriesPer100g = 900.0; // Pure fat = 900 kcal/100g

  /// Maximum meal name length
  static const int maxMealNameLength = 50;

  /// Maximum grams for a single meal log entry
  static const int maxMealGrams = 2000; // 2kg max per meal

  /// Minimum grams for a valid meal log entry
  static const int minMealGrams = 1;

  /// Maximum daily macro intake (in grams) - for validation
  static const double maxDailyProtein = 500.0;
  static const double maxDailyCarbs = 1000.0;
  static const double maxDailyFats = 300.0;
  static const double maxDailyCalories = 10000.0;

  // ==================== NUTRITION DEFAULTS ====================
  /// Base serving size for meal nutritional values (100g standard)
  static const double baseServingSizeGrams = 100.0;

  /// Default meal serving size when creating new meals
  static const double defaultMealServingSize = 100.0;

  /// Default macro distribution ratios when only calories are provided
  /// These ratios represent percentage of total calories from each macro
  static const double defaultCarbsRatio = 0.4; // 40% of calories from carbs
  static const double defaultProteinRatio = 0.3; // 30% of calories from protein
  static const double defaultFatsRatio = 0.3; // 30% of calories from fats

  // ==================== GENERAL DEFAULTS ====================
  static const int defaultWeeklyGoal = 10;
  static const int defaultReps = 12;
  static const double defaultWeight = 20.0;

  // ==================== TIME ====================
  static const Duration sessionTimeout = Duration(hours: 24);
  static const Duration dataSyncInterval = Duration(hours: 6);
  static const int daysToKeepHistory = 365; // 1 year

  // ==================== UI ====================
  static const Duration animationDuration = Duration(milliseconds: 300);
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration splashDuration = Duration(seconds: 2);
  static const double maxBottomSheetHeight = 0.9; // 90% of screen height

  // ==================== PAGINATION ====================
  static const int itemsPerPage = 20;
  static const int historyItemsPerPage = 50;

  // ==================== CACHE ====================
  static const Duration cacheExpiration = Duration(days: 7);
  static const int maxCacheSize = 100; // MB

  // ==================== PERFORMANCE ====================
  static const int slowOperationThresholdMs = 500;
  static const int criticalOperationThresholdMs = 1000;

  // ==================== VALIDATION REGEX ====================
  static final RegExp exerciseNameRegex = RegExp(r'^[a-zA-Z0-9\s\-()]+$');
  static final RegExp mealNameRegex = RegExp(r'^[a-zA-Z0-9\s\-()]+$');
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // ==================== FILE PATHS ====================
  static const String assetsPath = 'assets/';
  static const String imagesPath = 'assets/images/';
  static const String iconsPath = 'assets/images/icons/';
  static const String dataPath = 'assets/data/';

  // ==================== NETWORK (for future use) ====================
  static const Duration networkTimeout = Duration(seconds: 30);
  static const int maxRetryAttempts = 3;
  static const Duration retryDelay = Duration(seconds: 2);
}

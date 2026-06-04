import 'package:flutter/foundation.dart';

/// Constants for muscle stimulus calculation and visualization system.
/// These are domain rules, not deployment/runtime configuration.
class MuscleStimulus {
  MuscleStimulus._();

  // ==================== MUSCLE GROUPS ====================
  /// Complete list of muscle groups for detailed tracking
  static const List<String> allMuscleGroups = [
    frontDelts,
    sideDelts,
    rearDelts,
    upperTraps,
    middleTraps,
    lowerTraps,
    upperChest,
    midChest,
    lowerChest,
    lats,
    biceps,
    triceps,
    forearms,
    abs,
    obliques,
    lovehandles,
    lowerBack,
    glutes,
    hipadductors,
    quads,
    hamstrings,
    calves,
  ];

  // Individual muscle group constants (kebab-case for database consistency
  // on existing groups, plus new explicit keys for the added regions)
  static const String frontDelts = 'front-delts';
  static const String sideDelts = 'side-delts';
  static const String rearDelts = 'rear-delts';
  static const String upperTraps = 'upper-traps';
  static const String middleTraps = 'middle-traps';
  static const String lowerTraps = 'lower-traps';
  static const String upperChest = 'upper-chest';
  static const String midChest = 'mid-chest';
  static const String lowerChest = 'lower-chest';
  static const String lats = 'lats';
  static const String biceps = 'biceps';
  static const String triceps = 'triceps';
  static const String forearms = 'forearms';
  static const String abs = 'abs';
  static const String obliques = 'obliques';
  static const String lovehandles = 'lovehandles';
  static const String lowerBack = 'lower-back';
  static const String glutes = 'glutes';
  static const String hipadductors = 'hipadductors';
  static const String quads = 'quads';
  static const String hamstrings = 'hamstrings';
  static const String calves = 'calves';

  // ==================== DISPLAY NAMES ====================
  /// User-friendly names for UI display
  static const Map<String, String> displayNames = {
    frontDelts: 'Front Delts',
    sideDelts: 'Side Delts',
    rearDelts: 'Rear Delts',
    upperTraps: 'Upper Traps',
    middleTraps: 'Middle Traps',
    lowerTraps: 'Lower Traps',
    upperChest: 'Upper Chest',
    midChest: 'Mid Chest',
    lowerChest: 'Lower Chest',
    lats: 'Lats',
    biceps: 'Biceps',
    triceps: 'Triceps',
    forearms: 'Forearms',
    abs: 'Abs',
    obliques: 'Obliques',
    lovehandles: 'Love Handles',
    lowerBack: 'Lower Back',
    glutes: 'Glutes',
    hipadductors: 'Hip Adductors',
    quads: 'Quads',
    hamstrings: 'Hamstrings',
    calves: 'Calves',
  };

  // ==================== RECOVERY RATES (k values) ====================
  /// Recovery decay rates for each muscle group (per hour).
  /// Higher k = faster recovery. Lower k = slower recovery.
  static const Map<String, double> recoveryRates = {
    // Shoulders
    frontDelts: 0.030,
    sideDelts: 0.030,
    rearDelts: 0.030,

    // Traps
    upperTraps: 0.028,
    middleTraps: 0.028,
    lowerTraps: 0.028,

    // Chest
    upperChest: 0.027,
    midChest: 0.027,
    lowerChest: 0.027,

    // Back
    lats: 0.024,
    lowerBack: 0.023,

    // Arms
    biceps: 0.032,
    triceps: 0.032,
    forearms: 0.035,

    // Core / waist
    abs: 0.020,
    obliques: 0.020,
    lovehandles: 0.020,

    // Hips / legs
    glutes: 0.022,
    hipadductors: 0.021,
    quads: 0.021,
    hamstrings: 0.022,
    calves: 0.033,
  };

  /// Default recovery rate for unknown muscles
  static const double defaultRecoveryRate = 0.025;

  // ==================== CALCULATION CONSTANTS ====================

  /// Formula: (intensity / maxIntensity) ^ intensityExponent
  static const double intensityExponent = 1.35;

  /// Weekly rolling load decay factor applied each day
  static const double weeklyDecayFactor = 0.6;

  /// Hard ceiling on how many days of accumulated stimulus can still register
  /// as fatigue. Even with the heaviest possible session, a muscle must be
  /// shown as fully recovered (gray) by this many days after the last set.
  ///
  /// With [weeklyDecayFactor] = 0.6 and a normalized [recoveredThreshold] of
  /// 0.5 the math already crosses the recovery cutoff well before this point
  /// (`30/25 * 0.6^6 ≈ 0.056`); this cap is a belt-and-suspenders guarantee
  /// in case decay/threshold constants are tuned later.
  static const int maxFatigueDays = 6;

  /// Recovery cutoff expressed on the **normalized** 0..1 scale
  /// (`rawLoad / threshold`). When the normalized load drops below this
  /// value the muscle is considered fully recovered and renders as
  /// untrained (gray) again.
  ///
  /// IMPORTANT: never compare this constant against a raw load value —
  /// the raw `rollingWeeklyLoad` is in stimulus units (~0–30+) while
  /// this threshold is a ratio. All comparisons must go through
  /// [NormalizedMuscleLoad.isRecovered] so the units cannot drift.
  static const double recoveredThreshold = 0.5;

  // ==================== INTENSITY LEVELS ====================

  static const int minIntensity = 0;
  static const int maxIntensity = 5;
  static const int defaultIntensity = 3;

  /// Intensity level descriptions (full version for dialogs)
  static const Map<int, String> intensityDescriptions = {
    0: 'No effort - Warm-up sets, technique practice, or mobility work. Minimal muscle activation.',
    1: 'Very Light - Easy sets with high reps remaining. Low muscle engagement, recovery work.',
    2: 'Light - Moderate effort with several reps in reserve. Building volume without strain.',
    3: 'Moderate - Working sets with 2-3 reps in reserve (RIR). Solid muscle activation.',
    4: 'Hard - Challenging sets with 1-2 RIR. High muscle activation, approaching failure.',
    5: 'Maximum - All-out effort, 0 RIR or actual failure. Maximum muscle stimulus.',
  };

  /// Intensity level short labels (for UI sliders)
  static const Map<int, String> intensityLabels = {
    0: 'Warm-up',
    1: 'Very Light',
    2: 'Light',
    3: 'Moderate',
    4: 'Hard',
    5: 'Max Effort',
  };

  // ==================== VISUAL INTENSITY THRESHOLDS ====================

  static const double dailyThreshold = 8.0;
  static const double weeklyThreshold = 25.0;

  // ==================== COLOR THRESHOLDS ====================

  static const double colorThresholdGreen = 0.20;
  static const double colorThresholdYellow = 0.45;
  static const double colorThresholdOrange = 0.70;
  static const double colorThresholdRed = 0.70;

  // ==================== VALIDATION & HELPER METHODS ====================

  static bool isValidMuscleGroup(String muscleGroup) {
    return allMuscleGroups.contains(muscleGroup.toLowerCase());
  }

  static String getDisplayName(String muscleGroup) {
    final String key = muscleGroup.toLowerCase();
    final String? mapped = displayNames[key];
    if (mapped != null) return mapped;

    // Fallback: title-case each word so unknown groups still render cleanly.
    return key
        .split(RegExp(r'[-\s]+'))
        .where((String w) => w.isNotEmpty)
        .map((String w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static double getRecoveryRate(String muscleGroup) {
    return recoveryRates[muscleGroup.toLowerCase()] ?? defaultRecoveryRate;
  }

  static String getIntensityDescription(int intensity) {
    final clampedIntensity = intensity.clamp(minIntensity, maxIntensity);
    return intensityDescriptions[clampedIntensity] ??
        intensityDescriptions[defaultIntensity]!;
  }

  static String getIntensityLabel(int intensity) {
    final clampedIntensity = intensity.clamp(minIntensity, maxIntensity);
    return intensityLabels[clampedIntensity] ??
        intensityLabels[defaultIntensity]!;
  }

  static bool isValidIntensity(int intensity) {
    return intensity >= minIntensity && intensity <= maxIntensity;
  }

  static int clampIntensity(int intensity) {
    return intensity.clamp(minIntensity, maxIntensity);
  }

  // ==================== DEBUG & LOGGING ====================

  static void printConfiguration() {
    if (!kDebugMode) return;

    debugPrint('========== Muscle Stimulus Configuration ==========');
    debugPrint('Total Muscle Groups: ${allMuscleGroups.length}');
    debugPrint('Intensity Exponent: $intensityExponent');
    debugPrint('Weekly Decay Factor: $weeklyDecayFactor');
    debugPrint('');
    debugPrint('Visual Thresholds:');
    debugPrint('  Daily: $dailyThreshold');
    debugPrint('  Weekly: $weeklyThreshold');
    debugPrint('');
    debugPrint('Color Thresholds:');
    debugPrint('  Green: 0.0 - $colorThresholdGreen');
    debugPrint('  Yellow: $colorThresholdGreen - $colorThresholdYellow');
    debugPrint('  Orange: $colorThresholdYellow - $colorThresholdOrange');
    debugPrint('  Red: $colorThresholdOrange - 1.0');
    debugPrint('==================================================');
  }
}

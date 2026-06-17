import 'package:fitness_tracker/core/constants/legacy_muscle_group_map.dart';
import 'package:flutter/foundation.dart';

/// Constants for muscle stimulus calculation and visualization system.
/// These are domain rules, not deployment/runtime configuration.
class MuscleStimulus {
  MuscleStimulus._();

  // ==================== CANONICAL MUSCLE GROUPS (v26) ====================
  /// The 18 canonical muscle-group keys — the single source of truth for
  /// `exercise_muscle_factors.muscle_group`, `muscle_stimulus.muscle_group`,
  /// `exercises.muscle_groups`, edit-dialog chips, and the body-map asset map.
  static const List<String> allMuscleGroups = <String>[
    shoulders,
    rearDelts,
    upperTraps,
    lowerTraps,
    chest,
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

  // ── Canonical constants ────────────────────────────────────────────────────
  static const String shoulders = 'shoulders';
  static const String rearDelts = 'rear-delts';
  static const String upperTraps = 'upper-traps';
  static const String lowerTraps = 'lower-traps';
  static const String chest = 'chest';
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

  // ── Granular seed-authoring vocabulary ──────────────────────────────────
  // Retained solely so `exercise_muscle_factors_data.dart` can author the seed
  // at biomechanical granularity (e.g. upper/mid/lower-chest). These keys never
  // reach storage or the runtime: `getAllFactors` folds them onto canonical
  // keys via `combineCanonicalFactors` at read time. Do not use elsewhere.
  static const String frontDelts = 'front-delts';
  static const String sideDelts = 'side-delts';
  static const String upperChest = 'upper-chest';
  static const String midChest = 'mid-chest';
  static const String lowerChest = 'lower-chest';
  static const String middleTraps = 'middle-traps';

  // ==================== DISPLAY NAMES ====================
  static const Map<String, String> displayNames = <String, String>{
    shoulders: 'Shoulders',
    rearDelts: 'Rear Delts',
    upperTraps: 'Upper Traps',
    lowerTraps: 'Lower Traps',
    chest: 'Chest',
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
  /// Recovery decay rates for each canonical muscle group (per hour).
  /// Merged sub-regions share the rate of their former parent group.
  static const Map<String, double> recoveryRates = <String, double>{
    // Shoulders
    shoulders: 0.030,
    rearDelts: 0.030,
    // Traps
    upperTraps: 0.028,
    lowerTraps: 0.028,
    // Chest
    chest: 0.027,
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

  // ==================== INTENSITY LEVELS ====================

  static const int minIntensity = 0;
  static const int maxIntensity = 5;
  static const int defaultIntensity = 3;

  /// Intensity level descriptions (full version for dialogs)
  static const Map<int, String> intensityDescriptions = <int, String>{
    0: 'No effort - Warm-up sets, technique practice, or mobility work. Minimal muscle activation.',
    1: 'Very Light - Easy sets with high reps remaining. Low muscle engagement, recovery work.',
    2: 'Light - Moderate effort with several reps in reserve. Building volume without strain.',
    3: 'Moderate - Working sets with 2-3 reps in reserve (RIR). Solid muscle activation.',
    4: 'Hard - Challenging sets with 1-2 RIR. High muscle activation, approaching failure.',
    5: 'Maximum - All-out effort, 0 RIR or actual failure. Maximum muscle stimulus.',
  };

  /// Intensity level short labels (for UI sliders)
  static const Map<int, String> intensityLabels = <int, String>{
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

  // ==================== FATIGUE MODEL (0–100) ====================
  /// Divisor that maps raw exercise stress to the 0–100 fatigue scale.
  static const double fatigueNormalizationConstant = 250.0;

  /// Recovery decay coefficients: fatigue *= e^(-(linear*t + quadratic*t^2)), t in days.
  static const double fatigueDecayLinearCoeff = 0.25;
  static const double fatigueDecayQuadraticCoeff = 0.06;

  /// Fatigue band lower bounds on the **normalized** 0..1 scale (fatigue/100):
  /// < mild → recovered (gray); [mild,moderate) → green; [moderate,high) → yellow;
  /// [high,severe) → orange; >= severe → red.
  static const double fatigueBandMild = 0.20;
  static const double fatigueBandModerate = 0.40;
  static const double fatigueBandHigh = 0.60;
  static const double fatigueBandSevere = 0.80;

  // ==================== VALIDATION & HELPER METHODS ====================

  /// Returns true for any canonical key or any legacy key that canonicalises
  /// to a canonical key. Accepts both the granular and simple vocabularies so
  /// existing stored data remains valid before the v26 migration runs.
  static bool isValidMuscleGroup(String muscleGroup) {
    return allMuscleGroups.contains(
      LegacyMuscleGroupMap.canonicalizeMuscleKey(muscleGroup),
    );
  }

  static String getDisplayName(String muscleGroup) {
    final String canonical = LegacyMuscleGroupMap.canonicalizeMuscleKey(
      muscleGroup,
    );
    final String? mapped = displayNames[canonical];
    if (mapped != null) return mapped;

    // Fallback: title-case each word so unknown groups still render cleanly.
    return canonical
        .split(RegExp(r'[-\s]+'))
        .where((String w) => w.isNotEmpty)
        .map((String w) => w[0].toUpperCase() + w.substring(1))
        .join(' ');
  }

  static double getRecoveryRate(String muscleGroup) {
    final String canonical = LegacyMuscleGroupMap.canonicalizeMuscleKey(
      muscleGroup,
    );
    return recoveryRates[canonical] ?? defaultRecoveryRate;
  }

  static String getIntensityDescription(int intensity) {
    final int clampedIntensity = intensity.clamp(minIntensity, maxIntensity);
    return intensityDescriptions[clampedIntensity] ??
        intensityDescriptions[defaultIntensity]!;
  }

  static String getIntensityLabel(int intensity) {
    final int clampedIntensity = intensity.clamp(minIntensity, maxIntensity);
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

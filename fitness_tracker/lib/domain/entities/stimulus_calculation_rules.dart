import 'dart:math';
import '../../core/constants/muscle_stimulus_constants.dart';

class StimulusCalculationRules {
  StimulusCalculationRules._(); // Private constructor

  static double calculateIntensityFactor(int intensity) {
    // Clamp intensity to valid range
    final clampedIntensity = MuscleStimulus.clampIntensity(intensity);

    // Handle zero intensity (warm-up sets)
    if (clampedIntensity == 0) return 0.0;

    // Calculate non-linear intensity factor
    final normalizedIntensity = clampedIntensity / MuscleStimulus.maxIntensity;
    final intensityFactor = pow(
      normalizedIntensity,
      MuscleStimulus.intensityExponent,
    );

    return intensityFactor.toDouble();
  }

  static double calculateSetStimulus({
    required int sets,
    required int intensity,
    required double exerciseFactor,
  }) {
    // Validate inputs
    assert(sets >= 0, 'Sets must be non-negative');
    assert(
      exerciseFactor >= 0.0 && exerciseFactor <= 1.0,
      'Exercise factor must be between 0.0 and 1.0',
    );

    // Calculate intensity factor
    final intensityFactor = calculateIntensityFactor(intensity);

    // Calculate stimulus
    final stimulus = sets * intensityFactor * exerciseFactor;

    return stimulus;
  }

  static double aggregateDailyStimulus(List<double> setStimuliForDay) {
    if (setStimuliForDay.isEmpty) return 0.0;

    return setStimuliForDay.reduce((sum, stimulus) => sum + stimulus);
  }

  static double calculateRollingWeeklyLoad({
    required double previousWeeklyLoad,
    required double dailyStimulus,
  }) {
    assert(
      previousWeeklyLoad >= 0.0,
      'Previous weekly load must be non-negative',
    );
    assert(dailyStimulus >= 0.0, 'Daily stimulus must be non-negative');

    final newWeeklyLoad =
        (previousWeeklyLoad * MuscleStimulus.weeklyDecayFactor) + dailyStimulus;

    return newWeeklyLoad;
  }

  static double applyDailyDecay(double currentWeeklyLoad) {
    assert(currentWeeklyLoad >= 0.0, 'Weekly load must be non-negative');

    return currentWeeklyLoad * MuscleStimulus.weeklyDecayFactor;
  }

  static double calculateRecoveryDecay({
    required double initialStimulus,
    required String muscleGroup,
    required double hoursElapsed,
  }) {
    assert(initialStimulus >= 0.0, 'Initial stimulus must be non-negative');
    assert(hoursElapsed >= 0.0, 'Hours elapsed must be non-negative');

    // Handle zero cases
    if (initialStimulus == 0.0 || hoursElapsed == 0.0) {
      return initialStimulus;
    }

    // Get muscle-specific recovery rate
    final k = MuscleStimulus.getRecoveryRate(muscleGroup);

    // Calculate remaining stimulus using exponential decay
    final remainingStimulus = initialStimulus * exp(-k * hoursElapsed);

    // Ensure non-negative result
    return remainingStimulus.clamp(0.0, initialStimulus);
  }

  static double calculateVisualIntensity({
    required double totalStimulus,
    required double threshold,
  }) {
    assert(totalStimulus >= 0.0, 'Total stimulus must be non-negative');
    assert(threshold > 0.0, 'Threshold must be positive');

    // Avoid division by zero
    if (threshold == 0.0) return 0.0;

    // Calculate and clamp intensity to 0-1 range
    final intensity = (totalStimulus / threshold).clamp(0.0, 1.0);

    return intensity;
  }

  static double aggregateMonthlyStimulus(List<double> dailyStimuliForMonth) {
    if (dailyStimuliForMonth.isEmpty) return 0.0;

    return dailyStimuliForMonth.reduce((sum, stimulus) => sum + stimulus);
  }

  static double findMaximumStimulus(List<double> allDailyStimuli) {
    if (allDailyStimuli.isEmpty) return 0.0;

    return allDailyStimuli.reduce(
      (max, stimulus) => stimulus > max ? stimulus : max,
    );
  }

  static bool validateStimulusInputs({
    required int sets,
    required int intensity,
    required double exerciseFactor,
  }) {
    return sets >= 0 &&
        MuscleStimulus.isValidIntensity(intensity) &&
        exerciseFactor >= 0.0 &&
        exerciseFactor <= 1.0;
  }

  /// Validate that intensity value is within acceptable range
  ///
  /// Returns: True if intensity is valid (0-5)
  static bool validateIntensity(int intensity) {
    return MuscleStimulus.isValidIntensity(intensity);
  }

  /// Validate that exercise factor is within acceptable range
  ///
  /// Returns: True if factor is valid (0.0-1.0)
  static bool validateExerciseFactor(double factor) {
    return factor >= 0.0 && factor <= 1.0;
  }

  // ==================== FATIGUE MODEL PRIMITIVES ====================

  /// 1 + ((clampedIntensity - 1) / 4)^2, intensity clamped to [1,5].
  /// Warm-up (logged intensity 0) is treated as 1 (lowest), matching the formula's domain.
  static double fatigueIntensityMultiplier(int intensity) {
    final c = intensity.clamp(1, 5);
    final x = (c - 1) / 4.0;
    return 1.0 + x * x;
  }

  /// Effective per-rep load: external weight plus a nominal bodyweight floor,
  /// so a set logged at `weight == 0` still carries load. Used by both fatigue
  /// and volume so the two stay consistent.
  static double effectiveLoad(double weight) =>
      weight + MuscleStimulus.bodyweightRepLoad;

  /// Fatigue contributed by one set to one muscle (before accumulation/decay).
  /// volumeLoad = effectiveLoad(weight)*reps;
  /// stress = volumeLoad * intensityMultiplier * muscleFactor;
  /// gain = stress / NORMALIZATION_CONSTANT.
  /// Bodyweight (weight==0) accumulates via the [effectiveLoad] floor.
  static double fatigueGain({
    required double weight,
    required int reps,
    required int intensity,
    required double muscleFactor,
  }) {
    final volumeLoad = effectiveLoad(weight) * reps;
    final stress =
        volumeLoad * fatigueIntensityMultiplier(intensity) * muscleFactor;
    return stress / MuscleStimulus.fatigueNormalizationConstant;
  }

  /// Delayed-recovery decay over [days] elapsed since the last set.
  /// fatigue * e^(-(0.25*d + 0.06*d^2)); [days] <= 0 returns [fatigue] unchanged.
  static double decayFatigue(double fatigue, int days) {
    if (days <= 0) return fatigue;
    final d = days.toDouble();
    return fatigue *
        exp(
          -(MuscleStimulus.fatigueDecayLinearCoeff * d +
              MuscleStimulus.fatigueDecayQuadraticCoeff * d * d),
        );
  }

  /// Accumulate a new set's gain onto a decayed running value, capped at 100.
  static double accumulateFatigue(double decayed, double gain) =>
      (decayed + gain).clamp(0.0, 100.0);
}

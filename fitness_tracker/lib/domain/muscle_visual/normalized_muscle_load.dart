import 'dart:math' show pow;

import '../../core/constants/muscle_stimulus_constants.dart';

/// A raw muscle-load value paired with the threshold that defines its
/// "fully loaded" point. Owns the two operations that the fatigue
/// calculation needs: **normalization** (raw / threshold) and
/// **passive decay** over time.
///
/// Why this exists — a prior bug compared [MuscleStimulus.recoveredThreshold]
/// (a *normalized* cutoff documented against `rollingWeeklyLoad /
/// weeklyThreshold`) directly against a *raw* decayed load. Because the
/// raw load is ~1–30 while the threshold is 0.5, muscles never dropped
/// below the cutoff and the fatigue map showed stale "light" stimulus
/// for days after a workout.
///
/// Routing every comparison through this value object makes the unit
/// contract explicit and un-bypassable.
///
/// Instances are immutable; [decayed] returns a new instance.
class NormalizedMuscleLoad {
  const NormalizedMuscleLoad({required this.raw, required this.threshold});

  /// Zero-load constant, useful as an identity in folds.
  static const NormalizedMuscleLoad zero = NormalizedMuscleLoad(
    raw: 0.0,
    threshold: 1.0,
  );

  /// Raw stimulus value in the same units as [threshold]
  /// (e.g. `rollingWeeklyLoad` for weekly calculations).
  final double raw;

  /// The threshold that defines a normalized value of 1.0
  /// (e.g. [MuscleStimulus.weeklyThreshold] = 25.0).
  final double threshold;

  /// [raw] divided by [threshold], clamped to non-negative.
  ///
  /// Returns 0.0 when [threshold] is non-positive — the caller must have
  /// misconfigured the value object, but the renderer never benefits
  /// from a NaN.
  double get normalized {
    if (threshold <= 0) return 0.0;
    final safeRaw = raw < 0 ? 0.0 : raw;
    return safeRaw / threshold;
  }

  /// True when [normalized] sits below [MuscleStimulus.recoveredThreshold].
  ///
  /// This is the single source of truth for "should the UI show this
  /// muscle as untrained?".  Do not inline the comparison elsewhere —
  /// keeping it here is what prevents the unit-mismatch bug from
  /// creeping back in.
  bool get isRecovered => normalized < MuscleStimulus.recoveredThreshold;

  /// Applies the per-day passive decay [MuscleStimulus.weeklyDecayFactor]
  /// [daysSince] times to [raw]. Non-positive [daysSince] is a no-op.
  ///
  /// Once [daysSince] reaches [MuscleStimulus.maxFatigueDays] the load is
  /// hard-zeroed regardless of how heavy the original session was. This
  /// matches the product invariant — *no muscle stays fatigued for more
  /// than [MuscleStimulus.maxFatigueDays] days* — and protects against
  /// future tuning of the decay/recovery constants drifting outside that
  /// envelope.
  NormalizedMuscleLoad decayed(int daysSince) {
    if (daysSince <= 0) return this;
    if (daysSince >= MuscleStimulus.maxFatigueDays) {
      return NormalizedMuscleLoad(raw: 0.0, threshold: threshold);
    }
    final decayedRaw =
        raw * pow(MuscleStimulus.weeklyDecayFactor, daysSince).toDouble();
    return NormalizedMuscleLoad(raw: decayedRaw, threshold: threshold);
  }
}

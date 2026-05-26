import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart';
import 'package:fitness_tracker/domain/muscle_visual/normalized_muscle_load.dart';
import 'package:flutter_test/flutter_test.dart';

/// These tests lock the fatigue-math contract that a prior bug broke:
///
/// * `raw / threshold` is the normalized scale the recovery cutoff lives on.
/// * Passive decay is per-day, multiplicative, using
///   [MuscleStimulus.weeklyDecayFactor].
/// * "Recovered" is defined on the normalized value, never on the raw one.
void main() {
  group('normalized', () {
    test('is raw divided by threshold', () {
      const load = NormalizedMuscleLoad(raw: 12.5, threshold: 25.0);
      expect(load.normalized, closeTo(0.5, 1e-9));
    });

    test('clamps negative raw values to zero', () {
      const load = NormalizedMuscleLoad(raw: -5.0, threshold: 10.0);
      expect(load.normalized, 0.0);
    });

    test('returns zero (not NaN/Infinity) for a non-positive threshold', () {
      const load = NormalizedMuscleLoad(raw: 5.0, threshold: 0.0);
      expect(load.normalized, 0.0);
    });
  });

  group('isRecovered', () {
    test('zero load at day zero is recovered', () {
      const load = NormalizedMuscleLoad(
        raw: 0.0,
        threshold: MuscleStimulus.weeklyThreshold,
      );
      expect(load.isRecovered, isTrue);
    });

    test('raw load equal to the weekly threshold is not recovered', () {
      const load = NormalizedMuscleLoad(
        raw: MuscleStimulus.weeklyThreshold,
        threshold: MuscleStimulus.weeklyThreshold,
      );
      expect(load.isRecovered, isFalse);
    });

    test(
      'a moderate stored load that decays for a week is classified as '
      'recovered — regression guard for the Lats-are-always-fatigued bug',
      () {
        // Use a load that clearly exceeds the recovery cutoff at day 0 so the
        // test only passes once decay + normalization are both applied.
        const original = NormalizedMuscleLoad(
          raw: 20.0,
          threshold: MuscleStimulus.weeklyThreshold,
        );
        expect(
          original.isRecovered,
          isFalse,
          reason: 'sanity: fresh load above threshold is not recovered',
        );

        final afterWeek = original.decayed(7);
        expect(
          afterWeek.isRecovered,
          isTrue,
          reason:
              'A one-week gap must decay a moderate load below the recovery '
              'cutoff; a raw-vs-normalized unit mismatch would leave it '
              '"fatigued" indefinitely.',
        );
      },
    );

    test('a very heavy load still visible one day later is not recovered', () {
      const load = NormalizedMuscleLoad(
        raw: 30.0,
        threshold: MuscleStimulus.weeklyThreshold,
      );
      // 30 * 0.6 = 18; 18 / 25 = 0.72 > 0.5 → still fatigued.
      expect(load.decayed(1).isRecovered, isFalse);
    });
  });

  group('decayed', () {
    test('zero or negative daysSince is a no-op', () {
      const load = NormalizedMuscleLoad(raw: 10.0, threshold: 25.0);
      expect(identical(load.decayed(0), load), isTrue);
      expect(identical(load.decayed(-3), load), isTrue);
    });

    test('applies weeklyDecayFactor per day multiplicatively', () {
      const load = NormalizedMuscleLoad(raw: 10.0, threshold: 25.0);
      final decayed = load.decayed(3);
      const expected =
          10.0 *
          MuscleStimulus.weeklyDecayFactor *
          MuscleStimulus.weeklyDecayFactor *
          MuscleStimulus.weeklyDecayFactor;
      expect(decayed.raw, closeTo(expected, 1e-9));
      // Threshold is preserved across decay.
      expect(decayed.threshold, load.threshold);
    });

    test('is pure — returns a new instance and does not mutate the source', () {
      const load = NormalizedMuscleLoad(raw: 10.0, threshold: 25.0);
      final decayed = load.decayed(5);
      expect(load.raw, 10.0);
      expect(identical(decayed, load), isFalse);
    });

    test(
      'hard-zeros raw at MuscleStimulus.maxFatigueDays regardless of load',
      () {
        const load = NormalizedMuscleLoad(
          raw: 1e9,
          threshold: MuscleStimulus.weeklyThreshold,
        );
        final capped = load.decayed(MuscleStimulus.maxFatigueDays);
        expect(capped.raw, 0.0);
        expect(capped.isRecovered, isTrue);
        expect(capped.threshold, MuscleStimulus.weeklyThreshold);
      },
    );

    test('stays zero past the fatigue-day cap', () {
      const load = NormalizedMuscleLoad(
        raw: 1e9,
        threshold: MuscleStimulus.weeklyThreshold,
      );
      final capped = load.decayed(MuscleStimulus.maxFatigueDays + 5);
      expect(capped.raw, 0.0);
      expect(capped.isRecovered, isTrue);
    });

    test('still applies normal decay one day before the cap', () {
      const load = NormalizedMuscleLoad(raw: 10.0, threshold: 25.0);
      final beforeCap = load.decayed(MuscleStimulus.maxFatigueDays - 1);
      expect(beforeCap.raw, greaterThan(0.0));
    });
  });
}

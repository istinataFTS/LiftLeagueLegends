import 'dart:math';

import 'package:fitness_tracker/domain/entities/stimulus_calculation_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StimulusCalculationRules.fatigueIntensityMultiplier', () {
    test('intensity 0 clamps to 1 → multiplier 1.0', () {
      expect(StimulusCalculationRules.fatigueIntensityMultiplier(0), 1.0);
    });

    test('intensity 1 → multiplier 1.0', () {
      expect(StimulusCalculationRules.fatigueIntensityMultiplier(1), 1.0);
    });

    test('intensity 3 → multiplier 1.25', () {
      expect(
        StimulusCalculationRules.fatigueIntensityMultiplier(3),
        closeTo(1.25, 1e-9),
      );
    });

    test('intensity 5 → multiplier 2.0', () {
      expect(
        StimulusCalculationRules.fatigueIntensityMultiplier(5),
        closeTo(2.0, 1e-9),
      );
    });

    test('intensity 6 clamps to 5 → multiplier 2.0', () {
      expect(
        StimulusCalculationRules.fatigueIntensityMultiplier(6),
        closeTo(2.0, 1e-9),
      );
    });

    test('intensity -1 clamps to 1 → multiplier 1.0', () {
      expect(StimulusCalculationRules.fatigueIntensityMultiplier(-1), 1.0);
    });
  });

  group('StimulusCalculationRules.effectiveLoad', () {
    test('adds the bodyweight per-rep floor (25 kg) to external weight', () {
      expect(StimulusCalculationRules.effectiveLoad(0.0), closeTo(25.0, 1e-9));
      expect(
        StimulusCalculationRules.effectiveLoad(100.0),
        closeTo(125.0, 1e-9),
      );
    });
  });

  group('StimulusCalculationRules.fatigueGain', () {
    test('computes correct gain for known inputs', () {
      // weight=100 → effectiveLoad=125, reps=10, intensity=3, factor=0.5
      // multiplier(3) = 1 + (2/4)^2 = 1.25
      // stress = (125*10) * 1.25 * 0.5 = 781.25
      // gain = 781.25 / 250 = 3.125
      expect(
        StimulusCalculationRules.fatigueGain(
          weight: 100.0,
          reps: 10,
          intensity: 3,
          muscleFactor: 0.5,
        ),
        closeTo(3.125, 1e-9),
      );
    });

    test('bodyweight (weight == 0) → gain > 0 via the per-rep floor', () {
      // effectiveLoad=25, reps=20, multiplier(4)=1+(3/4)^2=1.5625, factor=1.0
      // stress = (25*20) * 1.5625 * 1.0 = 781.25; gain = 3.125
      final gain = StimulusCalculationRules.fatigueGain(
        weight: 0.0,
        reps: 20,
        intensity: 4,
        muscleFactor: 1.0,
      );
      expect(gain, greaterThan(0.0));
      expect(gain, closeTo(3.125, 1e-9));
    });

    test('max intensity (5) produces expected gain', () {
      // effectiveLoad=125; stress=(125*5)*2.0*1.0=1250; gain=5.0
      expect(
        StimulusCalculationRules.fatigueGain(
          weight: 100.0,
          reps: 5,
          intensity: 5,
          muscleFactor: 1.0,
        ),
        closeTo(5.0, 1e-9),
      );
    });

    test('bodyweight gain scales monotonically with reps', () {
      double bw(int reps) => StimulusCalculationRules.fatigueGain(
        weight: 0.0,
        reps: reps,
        intensity: 3,
        muscleFactor: 1.0,
      );
      expect(bw(20), greaterThan(bw(10)));
      expect(bw(10), greaterThan(bw(5)));
    });

    test('bodyweight gain scales monotonically with intensity', () {
      double bw(int intensity) => StimulusCalculationRules.fatigueGain(
        weight: 0.0,
        reps: 10,
        intensity: intensity,
        muscleFactor: 1.0,
      );
      expect(bw(5), greaterThan(bw(3)));
      expect(bw(3), greaterThan(bw(1)));
    });

    test('bodyweight gain scales monotonically with muscle factor', () {
      double bw(double factor) => StimulusCalculationRules.fatigueGain(
        weight: 0.0,
        reps: 10,
        intensity: 3,
        muscleFactor: factor,
      );
      expect(bw(1.0), greaterThan(bw(0.5)));
      expect(bw(0.5), greaterThan(bw(0.1)));
    });

    test('weighted-set gain shifts by exactly the effectiveLoad ratio '
        '(repLoad / weight) — the chosen 25 kg floor is intentional', () {
      // For a representative weighted set, the new gain equals the old
      // (weight-only) gain scaled by effectiveLoad/weight = 125/100 = 1.25.
      const double weight = 100.0;
      const int reps = 8;
      const int intensity = 5; // multiplier 2.0
      const double factor = 1.0;
      final newGain = StimulusCalculationRules.fatigueGain(
        weight: weight,
        reps: reps,
        intensity: intensity,
        muscleFactor: factor,
      );
      // Old formula used weight*reps directly (no floor).
      final oldGain =
          (weight * reps) *
          StimulusCalculationRules.fatigueIntensityMultiplier(intensity) *
          factor /
          250.0;
      expect(newGain, closeTo(8.0, 1e-9));
      expect(newGain, closeTo(oldGain * 1.25, 1e-9));
    });
  });

  group('StimulusCalculationRules.decayFatigue', () {
    test('t=0 → fatigue unchanged', () {
      expect(StimulusCalculationRules.decayFatigue(80.0, 0), 80.0);
    });

    test('t<0 → fatigue unchanged', () {
      expect(StimulusCalculationRules.decayFatigue(50.0, -3), 50.0);
    });

    test('t=1 → fatigue * e^(-0.31)', () {
      const f = 100.0;
      final expected = f * exp(-(0.25 * 1 + 0.06 * 1));
      expect(
        StimulusCalculationRules.decayFatigue(f, 1),
        closeTo(expected, 1e-9),
      );
    });

    test('t=6 → fatigue * ≈0.0257', () {
      const f = 100.0;
      final expected = f * exp(-(0.25 * 6 + 0.06 * 36));
      expect(
        StimulusCalculationRules.decayFatigue(f, 6),
        closeTo(expected, 1e-6),
      );
      expect(expected, closeTo(f * 0.0257, 0.05));
    });
  });

  group('StimulusCalculationRules.accumulateFatigue', () {
    test('sums decayed and gain normally', () {
      expect(StimulusCalculationRules.accumulateFatigue(30.0, 10.0), 40.0);
    });

    test('caps at 100', () {
      expect(StimulusCalculationRules.accumulateFatigue(95.0, 20.0), 100.0);
    });

    test('does not go negative', () {
      expect(StimulusCalculationRules.accumulateFatigue(0.0, 0.0), 0.0);
    });
  });
}

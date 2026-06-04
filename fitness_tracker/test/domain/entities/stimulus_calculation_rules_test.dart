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

  group('StimulusCalculationRules.fatigueGain', () {
    test('computes correct gain for known inputs', () {
      // weight=100, reps=10, intensity=3, factor=0.5
      // multiplier(3) = 1 + (2/4)^2 = 1.25
      // stress = 1000 * 1.25 * 0.5 = 625
      // gain = 625 / 250 = 2.5
      expect(
        StimulusCalculationRules.fatigueGain(
          weight: 100.0,
          reps: 10,
          intensity: 3,
          muscleFactor: 0.5,
        ),
        closeTo(2.5, 1e-9),
      );
    });

    test('bodyweight (weight == 0) → gain 0', () {
      expect(
        StimulusCalculationRules.fatigueGain(
          weight: 0.0,
          reps: 20,
          intensity: 4,
          muscleFactor: 1.0,
        ),
        0.0,
      );
    });

    test('max intensity (5) produces expected gain', () {
      // multiplier(5)=2.0; stress=100*5*2.0*1.0=1000; gain=4.0
      expect(
        StimulusCalculationRules.fatigueGain(
          weight: 100.0,
          reps: 5,
          intensity: 5,
          muscleFactor: 1.0,
        ),
        closeTo(4.0, 1e-9),
      );
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

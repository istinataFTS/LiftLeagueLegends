import 'package:fitness_tracker/core/constants/muscle_factor_combine.dart';
import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('combineCanonicalFactors', () {
    test('collapses granular keys onto canonical keys with MAX', () {
      final result = combineCanonicalFactors(const <MapEntry<String, double>>[
        MapEntry('mid-chest', 1.0),
        MapEntry('upper-chest', 0.4),
        MapEntry('lower-chest', 0.4),
        MapEntry('front-delts', 0.4),
        MapEntry('triceps', 0.3),
      ]);

      expect(result, <String, double>{
        'chest': 1.0,
        'shoulders': 0.4,
        'triceps': 0.3,
      });
    });

    test('MAX preserves the prime mover, not an average', () {
      final result = combineCanonicalFactors(const <MapEntry<String, double>>[
        MapEntry('upper-chest', 0.2),
        MapEntry('mid-chest', 1.0),
      ]);

      expect(result['chest'], 1.0);
    });

    test('GATE-1 simple keys: traps→lower-traps, neck→upper-traps', () {
      final result = combineCanonicalFactors(const <MapEntry<String, double>>[
        MapEntry('traps', 0.5),
        MapEntry('neck', 0.6),
      ]);

      expect(result, <String, double>{'lower-traps': 0.5, 'upper-traps': 0.6});
    });

    test('canonical keys pass through unchanged (idempotent)', () {
      final result = combineCanonicalFactors(const <MapEntry<String, double>>[
        MapEntry('chest', 0.8),
        MapEntry('shoulders', 0.5),
      ]);

      expect(result, <String, double>{'chest': 0.8, 'shoulders': 0.5});
    });

    test('every output key is a valid canonical muscle group', () {
      final result = combineCanonicalFactors(const <MapEntry<String, double>>[
        MapEntry('mid-chest', 1.0),
        MapEntry('side-delts', 0.7),
        MapEntry('middle-traps', 0.4),
        MapEntry('hamstring', 0.5),
      ]);

      for (final key in result.keys) {
        expect(
          MuscleStimulus.allMuscleGroups.contains(key),
          isTrue,
          reason: '"$key" must be a canonical key',
        );
      }
    });

    test('empty input yields empty map', () {
      expect(
        combineCanonicalFactors(const <MapEntry<String, double>>[]),
        isEmpty,
      );
    });
  });
}

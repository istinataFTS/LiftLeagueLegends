import 'package:fitness_tracker/core/constants/legacy_muscle_group_map.dart';
import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LegacyMuscleGroupMap', () {
    group('legacyToCanonical — granular keys', () {
      test('front-delts → shoulders', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['front-delts'],
          'shoulders',
        );
      });
      test('side-delts → shoulders', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['side-delts'],
          'shoulders',
        );
      });
      test('rear-delts → rear-delts', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['rear-delts'],
          'rear-delts',
        );
      });
      test('upper-traps → upper-traps', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['upper-traps'],
          'upper-traps',
        );
      });
      test('middle-traps → lower-traps', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['middle-traps'],
          'lower-traps',
        );
      });
      test('lower-traps → lower-traps', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['lower-traps'],
          'lower-traps',
        );
      });
      test('upper-chest → chest', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['upper-chest'], 'chest');
      });
      test('mid-chest → chest', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['mid-chest'], 'chest');
      });
      test('lower-chest → chest', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['lower-chest'], 'chest');
      });
      test('lats → lats', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['lats'], 'lats');
      });
      test('biceps → biceps', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['biceps'], 'biceps');
      });
      test('triceps → triceps', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['triceps'], 'triceps');
      });
      test('forearms → forearms', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['forearms'], 'forearms');
      });
      test('abs → abs', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['abs'], 'abs');
      });
      test('obliques → obliques', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['obliques'], 'obliques');
      });
      test('lovehandles → lovehandles', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['lovehandles'],
          'lovehandles',
        );
      });
      test('lower-back → lower-back', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['lower-back'],
          'lower-back',
        );
      });
      test('glutes → glutes', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['glutes'], 'glutes');
      });
      test('hipadductors → hipadductors', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['hipadductors'],
          'hipadductors',
        );
      });
      test('quads → quads', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['quads'], 'quads');
      });
      test('hamstrings → hamstrings', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['hamstrings'],
          'hamstrings',
        );
      });
      test('calves → calves', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['calves'], 'calves');
      });
    });

    group('legacyToCanonical — simple keys (GATE-1)', () {
      test('shoulder → shoulders', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['shoulder'], 'shoulders');
      });
      test('traps → lower-traps (larger merged region)', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['traps'], 'lower-traps');
      });
      test('neck → upper-traps (rendered under upper-traps PNG)', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['neck'], 'upper-traps');
      });
      test('chest → chest', () {
        expect(LegacyMuscleGroupMap.legacyToCanonical['chest'], 'chest');
      });
      test('lower back (with space) → lower-back', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['lower back'],
          'lower-back',
        );
      });
      test('hamstring (no s) → hamstrings', () {
        expect(
          LegacyMuscleGroupMap.legacyToCanonical['hamstring'],
          'hamstrings',
        );
      });
    });

    group('canonicalizeMuscleKey', () {
      test('every canonical key is idempotent', () {
        for (final String key in MuscleStimulus.allMuscleGroups) {
          expect(
            LegacyMuscleGroupMap.canonicalizeMuscleKey(key),
            key,
            reason: 'canonical key "$key" must map to itself',
          );
        }
      });

      test('every value in legacyToCanonical is a canonical key', () {
        for (final MapEntry<String, String> entry
            in LegacyMuscleGroupMap.legacyToCanonical.entries) {
          expect(
            MuscleStimulus.allMuscleGroups,
            contains(entry.value),
            reason:
                '"${entry.key}" maps to "${entry.value}" which is not canonical',
          );
        }
      });

      test('every canonical key has a display name', () {
        for (final String key in MuscleStimulus.allMuscleGroups) {
          expect(
            MuscleStimulus.displayNames,
            contains(key),
            reason: 'canonical key "$key" is missing a display name',
          );
        }
      });

      test('every canonical key has a recovery rate', () {
        for (final String key in MuscleStimulus.allMuscleGroups) {
          expect(
            MuscleStimulus.recoveryRates,
            contains(key),
            reason: 'canonical key "$key" is missing a recovery rate',
          );
        }
      });

      test('strips leading and trailing whitespace', () {
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('  chest  '),
          'chest',
        );
      });

      test('normalises to lowercase before lookup', () {
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('Front-Delts'),
          'shoulders',
        );
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('MID-CHEST'),
          'chest',
        );
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('HAMSTRING'),
          'hamstrings',
        );
      });

      test('unknown key returned unchanged', () {
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('unknown-muscle'),
          'unknown-muscle',
        );
      });

      test('legacy simple "lower back" with space canonicalises correctly', () {
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('lower back'),
          'lower-back',
        );
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('Lower Back'),
          'lower-back',
        );
      });

      test('granular keys canonicalise end-to-end', () {
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('front-delts'),
          'shoulders',
        );
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('side-delts'),
          'shoulders',
        );
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('middle-traps'),
          'lower-traps',
        );
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('upper-chest'),
          'chest',
        );
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('mid-chest'),
          'chest',
        );
        expect(
          LegacyMuscleGroupMap.canonicalizeMuscleKey('lower-chest'),
          'chest',
        );
      });

      test(
        'MuscleStimulus.isValidMuscleGroup accepts all legacy granular keys',
        () {
          const List<String> granular = <String>[
            'front-delts',
            'side-delts',
            'rear-delts',
            'upper-traps',
            'middle-traps',
            'lower-traps',
            'upper-chest',
            'mid-chest',
            'lower-chest',
            'lats',
            'biceps',
            'triceps',
            'forearms',
            'abs',
            'obliques',
            'lovehandles',
            'lower-back',
            'glutes',
            'hipadductors',
            'quads',
            'hamstrings',
            'calves',
          ];
          for (final String key in granular) {
            expect(
              MuscleStimulus.isValidMuscleGroup(key),
              isTrue,
              reason: 'granular key "$key" should be accepted',
            );
          }
        },
      );

      test(
        'MuscleStimulus.isValidMuscleGroup accepts all legacy simple keys',
        () {
          const List<String> simple = <String>[
            'shoulder',
            'traps',
            'neck',
            'chest',
            'lats',
            'biceps',
            'triceps',
            'forearms',
            'abs',
            'obliques',
            'lower back',
            'glutes',
            'hamstring',
            'quads',
            'calves',
          ];
          for (final String key in simple) {
            expect(
              MuscleStimulus.isValidMuscleGroup(key),
              isTrue,
              reason: 'simple key "$key" should be accepted',
            );
          }
        },
      );

      test('MuscleStimulus.isValidMuscleGroup accepts all canonical keys', () {
        for (final String key in MuscleStimulus.allMuscleGroups) {
          expect(
            MuscleStimulus.isValidMuscleGroup(key),
            isTrue,
            reason: 'canonical key "$key" should be accepted',
          );
        }
      });
    });
  });
}

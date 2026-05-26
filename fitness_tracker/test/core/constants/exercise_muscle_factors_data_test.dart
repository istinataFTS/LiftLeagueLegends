import 'package:fitness_tracker/core/constants/exercise_muscle_factors_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regression: the factor seed map is keyed on names like "Sit-ups" and
  // "Push-ups", but exercises landing in the local DB from Supabase pulls or
  // older app versions may be spelled "Sit Ups" / "Push Ups" / "pushups".
  // The previous exact-string lookup made those rows miss their factors and
  // triggered the "couldn't map it to any muscle group" banner. Lookups
  // must be tolerant of spelling drift.
  group('ExerciseMuscleFactorsData name-normalized lookup', () {
    test('canonical hyphenated name still resolves', () {
      final factors = ExerciseMuscleFactorsData.getFactorsForExercise(
        'Sit-ups',
      );
      expect(factors, isNotNull);
      expect(factors, isNotEmpty);
      expect(ExerciseMuscleFactorsData.hasFactors('Sit-ups'), isTrue);
    });

    test('space-separated variant resolves to same factors', () {
      final hyphen = ExerciseMuscleFactorsData.getFactorsForExercise(
        'Sit-ups',
      )!;
      final spaced = ExerciseMuscleFactorsData.getFactorsForExercise('Sit Ups');
      expect(spaced, isNotNull);
      expect(spaced!.length, hyphen.length);
      expect(ExerciseMuscleFactorsData.hasFactors('Sit Ups'), isTrue);
    });

    test('lowercased and concatenated variants resolve too', () {
      expect(ExerciseMuscleFactorsData.hasFactors('sit ups'), isTrue);
      expect(ExerciseMuscleFactorsData.hasFactors('SITUPS'), isTrue);
      expect(ExerciseMuscleFactorsData.hasFactors('Push-ups'), isTrue);
      expect(ExerciseMuscleFactorsData.hasFactors('push ups'), isTrue);
      expect(ExerciseMuscleFactorsData.hasFactors('PushUps'), isTrue);
    });

    test('genuinely unknown exercises still miss', () {
      expect(
        ExerciseMuscleFactorsData.getFactorsForExercise('TestExercise'),
        isNull,
      );
      expect(ExerciseMuscleFactorsData.hasFactors('Vrat na leglo'), isFalse);
    });
  });
}

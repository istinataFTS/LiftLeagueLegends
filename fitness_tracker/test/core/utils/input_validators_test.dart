import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/utils/input_validators.dart';

void main() {
  group('InputValidators', () {
    group('validateExerciseName', () {
      test('returns error for null', () {
        expect(
          InputValidators.validateExerciseName(null),
          'Exercise name is required',
        );
      });

      test('returns error for empty string', () {
        expect(
          InputValidators.validateExerciseName(''),
          'Exercise name is required',
        );
      });

      test('returns error for whitespace-only string', () {
        expect(
          InputValidators.validateExerciseName('   '),
          'Exercise name is required',
        );
      });

      test('returns error for single character after trim', () {
        expect(
          InputValidators.validateExerciseName('A'),
          'Name must be at least 2 characters',
        );
      });

      test('returns error for name exceeding 50 characters', () {
        final longName = 'A' * 51;
        expect(
          InputValidators.validateExerciseName(longName),
          'Name must be less than 50 characters',
        );
      });

      test('returns error for name containing @', () {
        expect(
          InputValidators.validateExerciseName('Bench@Press'),
          'Name contains invalid characters',
        );
      });

      test('returns error for name containing #', () {
        expect(
          InputValidators.validateExerciseName('Bench#Press'),
          'Name contains invalid characters',
        );
      });

      test('returns null for valid name with hyphen', () {
        expect(InputValidators.validateExerciseName('Skull-Crusher'), isNull);
      });

      test('returns null for valid name with parentheses', () {
        expect(InputValidators.validateExerciseName('Curl (Hammer)'), isNull);
      });

      test('returns null for minimal 2-character name', () {
        expect(InputValidators.validateExerciseName('Ab'), isNull);
      });

      test('returns null for exactly 50-character name', () {
        final maxName = 'A' * 50;
        expect(InputValidators.validateExerciseName(maxName), isNull);
      });
    });

    group('validateReps', () {
      test('returns error for null', () {
        expect(InputValidators.validateReps(null), 'Reps is required');
      });

      test('returns error for empty string', () {
        expect(InputValidators.validateReps(''), 'Reps is required');
      });

      test('returns error for non-numeric input', () {
        expect(InputValidators.validateReps('abc'), 'Enter a valid number');
      });

      test('returns error for zero', () {
        expect(InputValidators.validateReps('0'), 'Reps must be at least 1');
      });

      test('returns error for 1001', () {
        expect(
          InputValidators.validateReps('1001'),
          'Reps must be less than 1000',
        );
      });

      test('returns null for lower boundary of 1', () {
        expect(InputValidators.validateReps('1'), isNull);
      });

      test('returns null for upper boundary of 1000', () {
        expect(InputValidators.validateReps('1000'), isNull);
      });

      test('returns null for mid-range value', () {
        expect(InputValidators.validateReps('12'), isNull);
      });
    });

    group('validateWeight', () {
      test('returns error for null', () {
        expect(InputValidators.validateWeight(null), 'Weight is required');
      });

      test('returns error for empty string', () {
        expect(InputValidators.validateWeight(''), 'Weight is required');
      });

      test('returns error for non-numeric input', () {
        expect(InputValidators.validateWeight('abc'), 'Enter a valid number');
      });

      test('returns error for zero', () {
        expect(
          InputValidators.validateWeight('0'),
          'Weight must be greater than 0',
        );
      });

      test('returns error for negative value', () {
        expect(
          InputValidators.validateWeight('-5'),
          'Weight must be greater than 0',
        );
      });

      test('returns error for value above 1000', () {
        expect(
          InputValidators.validateWeight('1001'),
          'Weight must be less than 1000kg',
        );
      });

      test('returns error for 3 decimal places', () {
        expect(
          InputValidators.validateWeight('10.123'),
          'Maximum 2 decimal places',
        );
      });

      test('returns null for valid integer weight', () {
        expect(InputValidators.validateWeight('100'), isNull);
      });

      test('returns null for valid decimal weight with 1 decimal place', () {
        expect(InputValidators.validateWeight('72.5'), isNull);
      });

      test('returns null for valid decimal weight with 2 decimal places', () {
        expect(InputValidators.validateWeight('72.25'), isNull);
      });

      test('returns null for upper boundary of 1000', () {
        expect(InputValidators.validateWeight('1000'), isNull);
      });
    });

    group('validateWeeklyGoal', () {
      test('returns error for null', () {
        expect(InputValidators.validateWeeklyGoal(null), 'Goal is required');
      });

      test('returns error for zero', () {
        expect(
          InputValidators.validateWeeklyGoal(0),
          'Goal must be at least 1',
        );
      });

      test('returns error for 101', () {
        expect(
          InputValidators.validateWeeklyGoal(101),
          'Goal must be less than 100',
        );
      });

      test('returns null for lower boundary of 1', () {
        expect(InputValidators.validateWeeklyGoal(1), isNull);
      });

      test('returns null for upper boundary of 100', () {
        expect(InputValidators.validateWeeklyGoal(100), isNull);
      });

      test('returns null for mid-range value', () {
        expect(InputValidators.validateWeeklyGoal(5), isNull);
      });
    });

    group('validateMuscleGroups', () {
      test('returns error for null', () {
        expect(
          InputValidators.validateMuscleGroups(null),
          'Select at least one muscle group',
        );
      });

      test('returns error for empty list', () {
        expect(
          InputValidators.validateMuscleGroups([]),
          'Select at least one muscle group',
        );
      });

      test('returns error for more than 10 groups', () {
        final groups = List.generate(11, (i) => 'muscle_$i');
        expect(
          InputValidators.validateMuscleGroups(groups),
          'Maximum 10 muscle groups',
        );
      });

      test('returns null for single group', () {
        expect(InputValidators.validateMuscleGroups(['chest']), isNull);
      });

      test('returns null for exactly 10 groups', () {
        final groups = List.generate(10, (i) => 'muscle_$i');
        expect(InputValidators.validateMuscleGroups(groups), isNull);
      });
    });

    group('sanitizeInput', () {
      test('trims leading and trailing whitespace', () {
        expect(InputValidators.sanitizeInput('  hello  '), 'hello');
      });

      test('collapses multiple spaces into one', () {
        expect(InputValidators.sanitizeInput('hello   world'), 'hello world');
      });

      test('strips less-than sign', () {
        expect(InputValidators.sanitizeInput('a<b'), 'ab');
      });

      test('strips greater-than sign', () {
        expect(InputValidators.sanitizeInput('a>b'), 'ab');
      });

      test('strips double-quote', () {
        expect(InputValidators.sanitizeInput('say "hello"'), 'say hello');
      });

      test('strips semicolon', () {
        expect(InputValidators.sanitizeInput('drop;table'), 'droptable');
      });

      test('strips backtick', () {
        expect(InputValidators.sanitizeInput('code`snippet'), 'codesnippet');
      });

      test('preserves valid alphanumeric content', () {
        expect(
          InputValidators.sanitizeInput('Bench Press 100'),
          'Bench Press 100',
        );
      });
    });

    group('formatWeight', () {
      test('formats whole number without decimal', () {
        expect(InputValidators.formatWeight(100.0), '100');
      });

      test('formats fractional weight with 2 decimal places', () {
        expect(InputValidators.formatWeight(72.5), '72.50');
      });

      test('formats zero as whole number', () {
        expect(InputValidators.formatWeight(0.0), '0');
      });
    });

    group('isValidWorkoutDate', () {
      test('returns true for today', () {
        final today = DateTime.now();
        expect(InputValidators.isValidWorkoutDate(today), isTrue);
      });

      test('returns false for tomorrow', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(InputValidators.isValidWorkoutDate(tomorrow), isFalse);
      });

      test('returns true for a past date', () {
        final pastDate = DateTime.now().subtract(const Duration(days: 30));
        expect(InputValidators.isValidWorkoutDate(pastDate), isTrue);
      });
    });

    group('validateWorkoutDate', () {
      test('returns error for null', () {
        expect(InputValidators.validateWorkoutDate(null), 'Date is required');
      });

      test('returns error for tomorrow', () {
        final tomorrow = DateTime.now().add(const Duration(days: 1));
        expect(
          InputValidators.validateWorkoutDate(tomorrow),
          'Cannot log workouts for future dates',
        );
      });

      test('returns error for date 366 days ago', () {
        final tooOld = DateTime.now().subtract(const Duration(days: 366));
        expect(
          InputValidators.validateWorkoutDate(tooOld),
          'Date is too far in the past',
        );
      });

      test('returns null for today', () {
        final today = DateTime.now();
        expect(InputValidators.validateWorkoutDate(today), isNull);
      });

      test('returns null for date 364 days ago', () {
        final recent = DateTime.now().subtract(const Duration(days: 364));
        expect(InputValidators.validateWorkoutDate(recent), isNull);
      });
    });
  });
}

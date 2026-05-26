import 'package:fitness_tracker/features/voice/data/parser/intent_parser.dart';
import 'package:fitness_tracker/features/voice/data/parser/parsed.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // IntentParser.normalise
  // ---------------------------------------------------------------------------

  group('IntentParser.normalise', () {
    test('lowercases text', () {
      expect(IntentParser.normalise('LOG BENCH'), 'log bench');
    });

    test('trims leading/trailing whitespace', () {
      expect(IntentParser.normalise('  log bench  '), 'log bench');
    });

    test('collapses multiple internal spaces', () {
      expect(IntentParser.normalise('log   bench   press'), 'log bench press');
    });

    test('collapses tabs and newlines', () {
      expect(IntentParser.normalise('log\tbench\npress'), 'log bench press');
    });

    test('returns empty string for whitespace-only input', () {
      expect(IntentParser.normalise('   '), '');
    });

    test('returns empty string for empty input', () {
      expect(IntentParser.normalise(''), '');
    });
  });

  // ---------------------------------------------------------------------------
  // Fallthrough behaviour (no matchers)
  // ---------------------------------------------------------------------------

  group('IntentParser.parse — fallthrough', () {
    late IntentParser parser;

    setUp(() => parser = const IntentParser([]));

    test('empty string → ParsedUnrecognized', () {
      expect(parser.parse(''), isA<ParsedUnrecognized>());
    });

    test('whitespace-only → ParsedUnrecognized', () {
      expect(parser.parse('   '), isA<ParsedUnrecognized>());
    });

    test('unmatched text → ParsedUnrecognized', () {
      expect(parser.parse('what is the weather'), isA<ParsedUnrecognized>());
    });

    test('fitness command with no matchers → ParsedUnrecognized', () {
      expect(
        parser.parse('log bench press 80 kg 10 reps'),
        isA<ParsedUnrecognized>(),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Matcher dispatch
  // ---------------------------------------------------------------------------

  group('IntentParser.parse — matcher dispatch', () {
    test('single matcher returning non-null → its result is returned', () {
      final intent = ParsedLogWorkoutSet(
        exerciseName: 'bench press',
        reps: 10,
        weight: 80,
      );
      final parser = IntentParser([(norm) => intent]);

      expect(parser.parse('log bench press'), same(intent));
    });

    test('single matcher returning null → ParsedUnrecognized', () {
      final parser = IntentParser([(norm) => null]);
      expect(parser.parse('log bench press'), isA<ParsedUnrecognized>());
    });

    test(
      'first matcher null, second matcher matches → second result returned',
      () {
        final intent = ParsedDeleteWorkoutSet();
        final parser = IntentParser([(norm) => null, (norm) => intent]);

        expect(parser.parse('delete my last set'), same(intent));
      },
    );

    test(
      'first matcher matches → first result returned, second never called',
      () {
        var secondCalled = false;
        final intent = ParsedDeleteWorkoutSet();
        final parser = IntentParser([
          (norm) => intent,
          (norm) {
            secondCalled = true;
            return null;
          },
        ]);

        parser.parse('delete my last set');
        expect(secondCalled, isFalse);
      },
    );

    test('input is normalised before being passed to matchers', () {
      String? captured;
      final parser = IntentParser([
        (norm) {
          captured = norm;
          return null;
        },
      ]);

      parser.parse('  LOG   BENCH PRESS  ');
      expect(captured, 'log bench press');
    });
  });

  // ---------------------------------------------------------------------------
  // ParsedIntent subtypes constructible
  // ---------------------------------------------------------------------------

  group('ParsedIntent subtypes', () {
    test('ParsedLogWorkoutSet holds fields', () {
      const intent = ParsedLogWorkoutSet(
        exerciseName: 'squat',
        reps: 5,
        weight: 100,
        weightUnit: 'kg',
      );
      expect(intent.exerciseName, 'squat');
      expect(intent.reps, 5);
      expect(intent.weight, 100);
      expect(intent.weightUnit, 'kg');
    });

    test('ParsedLogWorkoutSet weightUnit is nullable', () {
      const intent = ParsedLogWorkoutSet(
        exerciseName: 'squat',
        reps: 5,
        weight: 100,
      );
      expect(intent.weightUnit, isNull);
    });

    test('ParsedEditWorkoutSet all fields nullable', () {
      const intent = ParsedEditWorkoutSet();
      expect(intent.reps, isNull);
      expect(intent.weight, isNull);
      expect(intent.weightUnit, isNull);
    });

    test('ParsedLogNutrition holds fields', () {
      const intent = ParsedLogNutrition(
        mealName: 'oats',
        calories: 300,
        proteinGrams: 10,
        carbsGrams: 50,
        fatGrams: 5,
      );
      expect(intent.mealName, 'oats');
      expect(intent.calories, 300);
    });

    test('ParsedUnrecognized is a ParsedIntent', () {
      expect(const ParsedUnrecognized(), isA<ParsedIntent>());
    });

    test('sealed subtypes cover all categories', () {
      // Verify the switch is exhaustive by pattern-matching each type.
      final intents = <ParsedIntent>[
        const ParsedLogWorkoutSet(exerciseName: 'a', reps: 1, weight: 1),
        const ParsedEditWorkoutSet(),
        const ParsedDeleteWorkoutSet(),
        const ParsedLogNutrition(mealName: 'oats'),
        const ParsedEditNutrition(calories: 1),
        const ParsedDeleteNutrition(),
        const ParsedQueryWeeklyVolume(),
        const ParsedQueryDailyMacros(),
        const ParsedQueryRecentSets(),
        const ParsedUnrecognized(),
      ];

      for (final intent in intents) {
        final label = switch (intent) {
          ParsedLogWorkoutSet() => 'logSet',
          ParsedEditWorkoutSet() => 'editSet',
          ParsedDeleteWorkoutSet() => 'deleteSet',
          ParsedLogNutrition() => 'logNutrition',
          ParsedEditNutrition() => 'editNutrition',
          ParsedDeleteNutrition() => 'deleteNutrition',
          ParsedQueryWeeklyVolume() => 'weeklyVolume',
          ParsedQueryDailyMacros() => 'dailyMacros',
          ParsedQueryRecentSets() => 'recentSets',
          ParsedUnrecognized() => 'unrecognized',
        };
        expect(label, isNotEmpty, reason: '$intent should have a label');
      }
    });
  });
}

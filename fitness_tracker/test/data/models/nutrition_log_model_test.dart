import 'package:fitness_tracker/data/models/nutrition_log_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime loggedAt = DateTime(2026, 3, 22, 13, 30);

  NutritionLogModel buildMealLog({
    String id = 'log-1',
    String? mealId = 'meal-1',
    double? gramsConsumed = 150,
    double proteinGrams = 30,
    double carbsGrams = 40,
    double fatGrams = 10,
    double calories = 370,
  }) {
    return NutritionLogModel(
      id: id,
      mealId: mealId,
      mealName: 'Chicken Bowl',
      gramsConsumed: gramsConsumed,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      calories: calories,
      loggedAt: loggedAt,
      createdAt: loggedAt,
      updatedAt: loggedAt,
    );
  }

  NutritionLogModel buildDirectMacroLog({
    String id = 'log-2',
    double proteinGrams = 25,
    double carbsGrams = 15,
    double fatGrams = 5,
    double calories = 205,
  }) {
    return NutritionLogModel(
      id: id,
      mealId: null,
      mealName: 'Manual Entry',
      gramsConsumed: null,
      proteinGrams: proteinGrams,
      carbsGrams: carbsGrams,
      fatGrams: fatGrams,
      calories: calories,
      loggedAt: loggedAt,
      createdAt: loggedAt,
      updatedAt: loggedAt,
    );
  }

  group('NutritionLogModel', () {
    test('validate passes for a valid meal log', () {
      final NutritionLogModel log = buildMealLog();

      expect(log.validate, returnsNormally);
      expect(log.isMealLog, isTrue);
      expect(log.isValidMealLog, isTrue);
    });

    test('validate throws for an invalid meal log without grams', () {
      final NutritionLogModel log = buildMealLog(gramsConsumed: null);

      expect(
        log.validate,
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            'Invalid meal log: Must have mealId and grams > 0',
          ),
        ),
      );
    });

    test('validate throws for an invalid meal log with non-positive grams', () {
      final NutritionLogModel log = buildMealLog(gramsConsumed: 0);

      expect(
        log.validate,
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            'Invalid meal log: Must have mealId and grams > 0',
          ),
        ),
      );
    });

    test('validate passes for a valid direct macro log', () {
      final NutritionLogModel log = buildDirectMacroLog();

      expect(log.validate, returnsNormally);
      expect(log.isDirectMacroLog, isTrue);
      expect(log.isValidDirectMacroLog, isTrue);
    });

    test(
      'validate throws for an invalid direct macro log with all macros zero',
      () {
        final NutritionLogModel log = buildDirectMacroLog(
          proteinGrams: 0,
          carbsGrams: 0,
          fatGrams: 0,
          calories: 0,
        );

        expect(
          log.validate,
          throwsA(
            isA<ArgumentError>().having(
              (ArgumentError error) => error.message,
              'message',
              'Invalid direct macro log: Must have at least one macro > 0',
            ),
          ),
        );
      },
    );

    test('fromEntity preserves log fields', () {
      final NutritionLogModel original = buildMealLog(
        id: 'log-7',
        mealId: 'meal-7',
        gramsConsumed: 180,
        proteinGrams: 35,
        carbsGrams: 45,
        fatGrams: 12,
        calories: 428,
      );

      final NutritionLogModel mapped = NutritionLogModel.fromEntity(original);

      expect(mapped.id, original.id);
      expect(mapped.mealId, original.mealId);
      expect(mapped.mealName, original.mealName);
      expect(mapped.gramsConsumed, original.gramsConsumed);
      expect(mapped.loggedAt, original.loggedAt);
      expect(mapped.calories, original.calories);
    });

    test('toMap stores the logged date using loggedAt', () {
      final NutritionLogModel log = buildMealLog();

      final Map<String, dynamic> result = log.toMap();

      expect(result['date'], loggedAt.toIso8601String());
      expect(result['meal_name'], 'Chicken Bowl');
      expect(result['grams'], 150);
    });
  });
}

import 'package:fitness_tracker/data/models/meal_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime createdAt = DateTime(2026, 3, 22, 9, 0);

  MealModel buildMealModel({
    String id = 'meal-1',
    String name = 'Chicken Bowl',
    double servingSizeGrams = 100,
    double carbsPer100g = 30,
    double proteinPer100g = 20,
    double fatPer100g = 10,
    double caloriesPer100g = 290,
  }) {
    return MealModel(
      id: id,
      name: name,
      servingSizeGrams: servingSizeGrams,
      carbsPer100g: carbsPer100g,
      proteinPer100g: proteinPer100g,
      fatPer100g: fatPer100g,
      caloriesPer100g: caloriesPer100g,
      createdAt: createdAt,
      updatedAt: createdAt,
    );
  }

  group('MealModel', () {
    test('validateMacros passes for a valid meal', () {
      final MealModel meal = buildMealModel();

      expect(meal.validateMacros, returnsNormally);
    });

    test('validateMacros throws when name is empty', () {
      final MealModel meal = buildMealModel(name: '   ');

      expect(
        meal.validateMacros,
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            'Meal name cannot be empty',
          ),
        ),
      );
    });

    test('validateMacros throws when serving size is not positive', () {
      final MealModel meal = buildMealModel(servingSizeGrams: 0);

      expect(
        meal.validateMacros,
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            'Serving size must be greater than 0',
          ),
        ),
      );
    });

    test('validateMacros throws when macros are negative', () {
      final MealModel meal = buildMealModel(proteinPer100g: -1);

      expect(
        meal.validateMacros,
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            'Macros cannot be negative',
          ),
        ),
      );
    });

    test('validateMacros throws when calories are negative', () {
      final MealModel meal = buildMealModel(caloriesPer100g: -10);

      expect(
        meal.validateMacros,
        throwsA(
          isA<ArgumentError>().having(
            (ArgumentError error) => error.message,
            'message',
            'Calories cannot be negative',
          ),
        ),
      );
    });

    test(
      'hasValidCalories uses model tolerance around calculated calories',
      () {
        final MealModel validMeal = buildMealModel(
          carbsPer100g: 30,
          proteinPer100g: 20,
          fatPer100g: 10,
          caloriesPer100g: 294,
        );
        final MealModel invalidMeal = buildMealModel(
          carbsPer100g: 30,
          proteinPer100g: 20,
          fatPer100g: 10,
          caloriesPer100g: 301,
        );

        expect(validMeal.calculatedCalories, 290);
        expect(validMeal.hasValidCalories, isTrue);
        expect(invalidMeal.hasValidCalories, isFalse);
      },
    );

    test('withCalculatedMacros derives calories when calories are omitted', () {
      final MealModel meal = MealModel.withCalculatedMacros(
        id: 'meal-1',
        name: 'Oats',
        carbsPer100g: 60,
        proteinPer100g: 10,
        fatPer100g: 5,
        createdAt: createdAt,
      );

      expect(meal.caloriesPer100g, 325);
      expect(meal.carbsPer100g, 60);
      expect(meal.proteinPer100g, 10);
      expect(meal.fatPer100g, 5);
    });

    test('copyWith updates selected fields and preserves the rest', () {
      final MealModel meal = buildMealModel();

      final MealModel updated = meal.copyWith(
        name: 'Updated Bowl',
        servingSizeGrams: 150,
      );

      expect(updated.id, meal.id);
      expect(updated.name, 'Updated Bowl');
      expect(updated.servingSizeGrams, 150);
      expect(updated.proteinPer100g, meal.proteinPer100g);
      expect(updated.createdAt, meal.createdAt);
    });
  });
}

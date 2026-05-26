import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/features/library/application/library_meal_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime createdAt = DateTime(2026, 1, 1);

  Meal buildMeal({required String id, required String name}) {
    return Meal(
      id: id,
      name: name,
      servingSizeGrams: 100,
      proteinPer100g: 20,
      carbsPer100g: 30,
      fatPer100g: 10,
      caloriesPer100g: 290,
      createdAt: createdAt,
    );
  }

  final List<Meal> meals = <Meal>[
    buildMeal(id: '1', name: 'Chicken Bowl'),
    buildMeal(id: '2', name: 'Oats'),
    buildMeal(id: '3', name: 'Greek Yogurt'),
  ];

  group('LibraryMealFilters', () {
    test('returns all meals when query is blank', () {
      final List<Meal> result = LibraryMealFilters.apply(
        meals: meals,
        query: '   ',
      );

      expect(result, hasLength(3));
      expect(result.map((Meal item) => item.name), <String>[
        'Chicken Bowl',
        'Oats',
        'Greek Yogurt',
      ]);
    });

    test('filters meals by name using case-insensitive matching', () {
      final List<Meal> result = LibraryMealFilters.apply(
        meals: meals,
        query: 'chicken',
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Chicken Bowl');
    });

    test('trims whitespace from query before filtering', () {
      final List<Meal> result = LibraryMealFilters.apply(
        meals: meals,
        query: '  yogurt  ',
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Greek Yogurt');
    });

    test('returns empty list when no meals match the query', () {
      final List<Meal> result = LibraryMealFilters.apply(
        meals: meals,
        query: 'salmon',
      );

      expect(result, isEmpty);
    });
  });
}

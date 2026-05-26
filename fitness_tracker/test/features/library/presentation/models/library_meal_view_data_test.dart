import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/features/library/presentation/models/library_meal_view_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime createdAt = DateTime(2026, 1, 1);

  Meal buildMeal({
    required String id,
    required String name,
    required double servingSizeGrams,
    required double proteinPer100g,
    required double carbsPer100g,
    required double fatPer100g,
    required double caloriesPer100g,
  }) {
    return Meal(
      id: id,
      name: name,
      servingSizeGrams: servingSizeGrams,
      proteinPer100g: proteinPer100g,
      carbsPer100g: carbsPer100g,
      fatPer100g: fatPer100g,
      caloriesPer100g: caloriesPer100g,
      createdAt: createdAt,
    );
  }

  group('LibraryMealViewDataMapper', () {
    test('maps meal items, counts, and active search state', () {
      final Meal chickenBowl = buildMeal(
        id: '1',
        name: 'Chicken Bowl',
        servingSizeGrams: 150,
        proteinPer100g: 20,
        carbsPer100g: 10,
        fatPer100g: 8,
        caloriesPer100g: 196,
      );
      final Meal oats = buildMeal(
        id: '2',
        name: 'Oats',
        servingSizeGrams: 100,
        proteinPer100g: 12,
        carbsPer100g: 60,
        fatPer100g: 7,
        caloriesPer100g: 347,
      );

      final LibraryMealPageViewData viewData = LibraryMealViewDataMapper.map(
        allMeals: <Meal>[chickenBowl, oats],
        filteredMeals: <Meal>[chickenBowl],
        searchQuery: 'chicken',
      );

      expect(viewData.resultCountLabel, '1 of 2 meals');
      expect(viewData.hasMeals, isTrue);
      expect(viewData.hasResults, isTrue);
      expect(viewData.hasActiveSearch, isTrue);
      expect(viewData.searchQuery, 'chicken');
      expect(viewData.items, hasLength(1));

      final LibraryMealItemViewData item = viewData.items.single;
      expect(item.id, '1');
      expect(item.title, 'Chicken Bowl');
      expect(item.subtitle, '150 g serving • 294 kcal');
      expect(item.macroSummary, '30P • 15C • 12F');
      expect(item.meal, chickenBowl);
    });

    test('maps empty meal state without active search', () {
      final LibraryMealPageViewData viewData = LibraryMealViewDataMapper.map(
        allMeals: const <Meal>[],
        filteredMeals: const <Meal>[],
        searchQuery: '   ',
      );

      expect(viewData.items, isEmpty);
      expect(viewData.resultCountLabel, '0 of 0 meals');
      expect(viewData.hasMeals, isFalse);
      expect(viewData.hasResults, isFalse);
      expect(viewData.hasActiveSearch, isFalse);
      expect(viewData.searchQuery, '   ');
    });
  });
}

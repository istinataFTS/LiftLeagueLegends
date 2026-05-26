import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/features/library/application/library_exercise_filters.dart';
import 'package:fitness_tracker/features/library/application/library_meal_filters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime createdAt = DateTime(2026, 1, 1);

  Exercise buildExercise({
    required String id,
    required String name,
    required List<String> muscleGroups,
  }) {
    return Exercise(
      id: id,
      name: name,
      muscleGroups: muscleGroups,
      createdAt: createdAt,
    );
  }

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

  group('LibraryExerciseFilters.apply', () {
    final List<Exercise> exercises = <Exercise>[
      buildExercise(
        id: '1',
        name: 'Bench Press',
        muscleGroups: const <String>['chest', 'triceps'],
      ),
      buildExercise(
        id: '2',
        name: 'Pull Up',
        muscleGroups: const <String>['back', 'biceps'],
      ),
      buildExercise(
        id: '3',
        name: 'Leg Press',
        muscleGroups: const <String>['quads'],
      ),
    ];

    test('returns all exercises when no filters are active', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: '',
        selectedMuscle: null,
      );

      expect(result, hasLength(3));
    });

    test('filters by search query against exercise name', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: 'bench',
        selectedMuscle: null,
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Bench Press');
    });

    test('filters by search query against muscle display name', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: 'back',
        selectedMuscle: null,
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Pull Up');
    });

    test('filters by selected muscle', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: '',
        selectedMuscle: 'quads',
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Leg Press');
    });

    test('combines search and muscle filtering', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: 'press',
        selectedMuscle: 'chest',
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Bench Press');
    });
  });

  group('LibraryMealFilters.apply', () {
    final List<Meal> meals = <Meal>[
      buildMeal(id: 'm1', name: 'Chicken Bowl'),
      buildMeal(id: 'm2', name: 'Oats'),
      buildMeal(id: 'm3', name: 'Greek Yogurt'),
    ];

    test('returns all meals when query is empty', () {
      final List<Meal> result = LibraryMealFilters.apply(
        meals: meals,
        query: '',
      );

      expect(result, hasLength(3));
    });

    test('filters meals by case-insensitive search query', () {
      final List<Meal> result = LibraryMealFilters.apply(
        meals: meals,
        query: 'chicken',
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Chicken Bowl');
    });

    test('returns empty list when no meals match query', () {
      final List<Meal> result = LibraryMealFilters.apply(
        meals: meals,
        query: 'salmon',
      );

      expect(result, isEmpty);
    });
  });
}

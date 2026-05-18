import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/default_meals_data.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/utils/deterministic_catalog_id.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/repositories/meal_repository.dart';
import 'package:fitness_tracker/domain/usecases/meals/seed_meals.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryMealRepository implements MealRepository {
  final Map<String, Meal> store = <String, Meal>{};

  @override
  Future<Either<Failure, List<Meal>>> getAllMeals({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async => Right(store.values.toList());

  @override
  Future<Either<Failure, void>> addMeal(Meal meal) async {
    store[meal.id] = meal;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllMeals() async {
    store.clear();
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  group('DefaultMealsData', () {
    test('every default has Atwater-consistent calories', () {
      for (final m in DefaultMealsData.getDefaultMeals()) {
        final meal = m.toEntity('id', DateTime(2026), ownerUserId: '');
        expect(
          meal.hasValidCalories,
          isTrue,
          reason: '"${m.name}" calories must match 4/4/9 macros',
        );
      }
    });

    test('names are unique', () {
      final names = DefaultMealsData.getDefaultMeals()
          .map((m) => m.name)
          .toList();
      expect(names.toSet().length, names.length);
    });

    test('deterministic ids are unique across the catalog', () {
      final ids = DefaultMealsData.getDefaultMeals()
          .map((m) => DeterministicCatalogId.fromName(m.name))
          .toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('SeedMeals', () {
    test('seeds defaults with deterministic ids, owner-stamped', () async {
      final repo = _InMemoryMealRepository();
      final result = await SeedMeals(repo)(ownerUserId: 'user-1');

      expect(result.isRight(), isTrue);
      final defaults = DefaultMealsData.getDefaultMeals();
      expect(repo.store.length, defaults.length);
      for (final d in defaults) {
        final id = DeterministicCatalogId.fromName(d.name);
        expect(repo.store[id]?.ownerUserId, 'user-1');
      }
    });

    test('is a no-op when the account already has meals', () async {
      final repo = _InMemoryMealRepository();
      await repo.addMeal(
        Meal(
          id: 'x',
          name: 'Existing',
          servingSizeGrams: 100,
          carbsPer100g: 1,
          proteinPer100g: 1,
          fatPer100g: 1,
          caloriesPer100g: 17,
          createdAt: DateTime(2026),
        ),
      );

      final result = await SeedMeals(repo)(ownerUserId: 'user-1');

      expect(result, const Right<Failure, int>(0));
      expect(repo.store.length, 1);
    });
  });
}

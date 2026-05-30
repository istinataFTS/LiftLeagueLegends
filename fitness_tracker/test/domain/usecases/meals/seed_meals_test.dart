import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/default_meals_data.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/utils/deterministic_catalog_id.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/repositories/catalog_init_flag_repository.dart';
import 'package:fitness_tracker/domain/repositories/meal_repository.dart';
import 'package:fitness_tracker/domain/usecases/meals/seed_meals.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryInitFlags implements CatalogInitFlagRepository {
  final Map<String, bool> _flags = {};

  static String _key(String owner, String type) =>
      'catalog_init_${type}_$owner';

  @override
  Future<bool> isInitialized(String ownerUserId, String catalogType) async =>
      _flags[_key(ownerUserId, catalogType)] == true;

  @override
  Future<void> markInitialized(String ownerUserId, String catalogType) async =>
      _flags[_key(ownerUserId, catalogType)] = true;
}

/// Owner-scoped in-memory repo that mirrors production semantics: the real
/// [MealRepositoryImpl] resolves the current session's owner and
/// [getAllMeals] returns only rows owned by that owner. Without this scoping
/// the "guest catalog already exists" short-circuit in [SeedMeals] would
/// short-circuit user-1's seed, hiding the regression the coexistence test
/// is meant to catch.
class _InMemoryMealRepository implements MealRepository {
  final Map<String, Meal> store = <String, Meal>{};

  /// Owner the next [getAllMeals] is scoped to. Tests set this before each
  /// SeedMeals call to simulate the active session.
  String currentOwner = '';

  @override
  Future<Either<Failure, List<Meal>>> getAllMeals({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async => Right(
    store.values.where((m) => (m.ownerUserId ?? '') == currentOwner).toList(),
  );

  @override
  Future<Either<Failure, void>> addMeal(Meal meal) async {
    store[meal.id] = meal;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllMeals() async {
    store.removeWhere((_, m) => (m.ownerUserId ?? '') == currentOwner);
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
      const ownerUserId = 'user-1';
      final ids = DefaultMealsData.getDefaultMeals()
          .map(
            (m) => DeterministicCatalogId.forOwner(
              ownerUserId: ownerUserId,
              name: m.name,
            ),
          )
          .toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('SeedMeals', () {
    test('seeds defaults with owner-scoped deterministic ids', () async {
      final repo = _InMemoryMealRepository()..currentOwner = 'user-1';
      final result = await SeedMeals(repo)(ownerUserId: 'user-1');

      expect(result.isRight(), isTrue);
      final defaults = DefaultMealsData.getDefaultMeals();
      expect(repo.store.length, defaults.length);
      for (final d in defaults) {
        final id = DeterministicCatalogId.forOwner(
          ownerUserId: 'user-1',
          name: d.name,
        );
        expect(repo.store[id]?.ownerUserId, 'user-1');
      }
    });

    // Guest-vs-user-coexistence test removed: guest catalogs no longer exist.

    test('is a no-op when the account already has meals', () async {
      final repo = _InMemoryMealRepository()..currentOwner = 'user-1';
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
          ownerUserId: 'user-1',
        ),
      );

      final result = await SeedMeals(repo)(ownerUserId: 'user-1');

      expect(result, const Right<Failure, int>(0));
      expect(repo.store.length, 1);
    });

    // -------------------------------------------------------------------------
    // Delete-stickiness invariant (catalog-init flag)
    // -------------------------------------------------------------------------

    test('sets the init flag after the first successful seed', () async {
      final repo = _InMemoryMealRepository()..currentOwner = 'user-1';
      final flags = _InMemoryInitFlags();

      await SeedMeals(repo, catalogInitFlags: flags)(ownerUserId: 'user-1');

      expect(
        await flags.isInitialized('user-1', 'meals'),
        isTrue,
        reason:
            'flag must be set so an empty-catalog relaunch does not '
            're-seed (delete-stickiness invariant)',
      );
    });

    test(
      'skips seeding when flag is already set, even if catalog is empty',
      () async {
        final repo = _InMemoryMealRepository()..currentOwner = 'user-1';
        final flags = _InMemoryInitFlags();
        await flags.markInitialized('user-1', 'meals');

        final result = await SeedMeals(repo, catalogInitFlags: flags)(
          ownerUserId: 'user-1',
        );

        expect(result, const Right<Failure, int>(0));
        expect(
          repo.store,
          isEmpty,
          reason:
              'default meals must NOT be re-seeded once the account has '
              'already received its catalog',
        );
      },
    );

    test(
      'flag is per-owner — seeding user-1 does not set flag for user-2',
      () async {
        final repo = _InMemoryMealRepository()..currentOwner = 'user-1';
        final flags = _InMemoryInitFlags();

        await SeedMeals(repo, catalogInitFlags: flags)(ownerUserId: 'user-1');

        expect(await flags.isInitialized('user-2', 'meals'), isFalse);
      },
    );
  });
}

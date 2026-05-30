import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/default_exercises_data.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/utils/deterministic_catalog_id.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/repositories/catalog_init_flag_repository.dart';
import 'package:fitness_tracker/domain/repositories/exercise_repository.dart';
import 'package:fitness_tracker/domain/usecases/exercises/seed_exercises.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [CatalogInitFlagRepository] for testing the delete-stickiness
/// invariant without a real SQLite database.
class _InMemoryInitFlags implements CatalogInitFlagRepository {
  final Map<String, bool> _flags = {};

  static String _key(String owner, String type) =>
      'catalog_init_${type}_$owner';

  @override
  Future<bool> isInitialized(String ownerUserId, String catalogType) async {
    return _flags[_key(ownerUserId, catalogType)] == true;
  }

  @override
  Future<void> markInitialized(String ownerUserId, String catalogType) async {
    _flags[_key(ownerUserId, catalogType)] = true;
  }
}

/// Owner-scoped in-memory repository that mirrors production semantics:
/// real [ExerciseRepositoryImpl] resolves the current session's owner and
/// [getAllExercises] returns only rows owned by that owner. Tests set
/// [currentOwner] before each SeedExercises call to simulate the session.
class _InMemoryExerciseRepository implements ExerciseRepository {
  final Map<String, Exercise> store = <String, Exercise>{};

  String currentOwner = '';

  @override
  Future<Either<Failure, List<Exercise>>> getAllExercises({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async => Right(
    store.values.where((e) => (e.ownerUserId ?? '') == currentOwner).toList(),
  );

  @override
  Future<Either<Failure, void>> addExercise(Exercise exercise) async {
    store[exercise.id] = exercise;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllExercises() async {
    store.removeWhere((_, e) => (e.ownerUserId ?? '') == currentOwner);
    return const Right(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

void main() {
  test('seeds default exercises with owner-scoped deterministic ids', () async {
    final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
    final seed = SeedExercises(repo);

    final result = await seed(ownerUserId: 'user-1');

    expect(result.isRight(), isTrue);
    final defaults = DefaultExercisesData.getDefaultExercises();
    expect(repo.store.length, defaults.length);

    for (final d in defaults) {
      final expectedId = DeterministicCatalogId.forOwner(
        ownerUserId: 'user-1',
        name: d.name,
      );
      expect(
        repo.store.containsKey(expectedId),
        isTrue,
        reason: '"${d.name}" should be stored under its owner-scoped id',
      );
      expect(repo.store[expectedId]!.ownerUserId, 'user-1');
    }
  });

  // Guest-vs-user-coexistence test removed: guest catalogs no longer exist.

  // ---------------------------------------------------------------------------
  // Delete-stickiness invariant (catalog-init flag)
  // ---------------------------------------------------------------------------

  group('delete-stickiness (catalog-init flag)', () {
    test('sets the init flag after the first successful seed', () async {
      final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
      final flags = _InMemoryInitFlags();
      final seed = SeedExercises(repo, catalogInitFlags: flags);

      await seed(ownerUserId: 'user-1');

      expect(
        await flags.isInitialized('user-1', 'exercises'),
        isTrue,
        reason:
            'flag must be set so a subsequent empty-catalog launch '
            'does not re-seed',
      );
    });

    test(
      'skips seeding when flag is already set, even if catalog is empty',
      () async {
        final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
        final flags = _InMemoryInitFlags();
        await flags.markInitialized('user-1', 'exercises');

        final seed = SeedExercises(repo, catalogInitFlags: flags);
        final result = await seed(ownerUserId: 'user-1');

        expect(result, const Right<Failure, int>(0));
        expect(
          repo.store,
          isEmpty,
          reason:
              'default exercises must NOT be re-seeded when the account '
              'has already received its catalog (delete-stickiness invariant)',
        );
      },
    );

    test('does not set the flag for a different owner', () async {
      final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
      final flags = _InMemoryInitFlags();
      final seed = SeedExercises(repo, catalogInitFlags: flags);

      await seed(ownerUserId: 'user-1');

      expect(await flags.isInitialized('user-2', 'exercises'), isFalse);
    });

    test('does not set the flag when no exercises were inserted '
        '(e.g. all seeds failed)', () async {
      // Repository that always fails on addExercise.
      final failRepo = _FailingExerciseRepository();
      final flags = _InMemoryInitFlags();
      final seed = SeedExercises(failRepo, catalogInitFlags: flags);

      await seed(ownerUserId: 'user-1');

      expect(
        await flags.isInitialized('user-1', 'exercises'),
        isFalse,
        reason: 'flag must only be set on a successful first seed',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Self-heal pass
  // ---------------------------------------------------------------------------

  group('self-heal', () {
    test(
      'seeds only the missing defaults and sets flag when catalog is partial',
      () async {
        // Pre-populate with all defaults except the first two (simulates the
        // post-v22-migration state where "Bench Press" and "Bulgarian Split
        // Squat" never made it into the user-owned catalog).
        final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
        final defaults = DefaultExercisesData.getDefaultExercises();
        final toSkip = {defaults[0].name, defaults[1].name};
        final now = DateTime(2026);
        for (final d in defaults.skip(2)) {
          await repo.addExercise(
            d.toEntity(
              DeterministicCatalogId.forOwner(
                ownerUserId: 'user-1',
                name: d.name,
              ),
              now,
              ownerUserId: 'user-1',
            ),
          );
        }

        final flags = _InMemoryInitFlags();
        final seed = SeedExercises(repo, catalogInitFlags: flags);
        final result = await seed(ownerUserId: 'user-1');

        expect(result, const Right<Failure, int>(2));
        expect(repo.store.length, defaults.length);
        for (final name in toSkip) {
          expect(
            repo.store.values.any((e) => e.name == name),
            isTrue,
            reason: '"$name" must have been self-healed',
          );
        }
        expect(await flags.isInitialized('user-1', 'exercises'), isTrue);
      },
    );

    test(
      'marks flag and returns 0 when all defaults already present by name',
      () async {
        // All defaults present, flag absent — self-heal finds nothing missing,
        // sets the flag so delete-stickiness kicks in going forward.
        final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
        final now = DateTime(2026);
        for (final d in DefaultExercisesData.getDefaultExercises()) {
          await repo.addExercise(
            d.toEntity(
              DeterministicCatalogId.forOwner(
                ownerUserId: 'user-1',
                name: d.name,
              ),
              now,
              ownerUserId: 'user-1',
            ),
          );
        }

        final flags = _InMemoryInitFlags();
        final seed = SeedExercises(repo, catalogInitFlags: flags);
        final result = await seed(ownerUserId: 'user-1');

        expect(result, const Right<Failure, int>(0));
        expect(
          repo.store.length,
          DefaultExercisesData.getDefaultExercises().length,
        );
        expect(await flags.isInitialized('user-1', 'exercises'), isTrue);
      },
    );

    test(
      'delete-stickiness: flag set with partial catalog skips re-seeding',
      () async {
        // Flag already set — user deliberately deleted a default exercise.
        // Must not re-seed even though the catalog is incomplete.
        final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
        final defaults = DefaultExercisesData.getDefaultExercises();
        final now = DateTime(2026);
        for (final d in defaults.skip(1)) {
          await repo.addExercise(
            d.toEntity(
              DeterministicCatalogId.forOwner(
                ownerUserId: 'user-1',
                name: d.name,
              ),
              now,
              ownerUserId: 'user-1',
            ),
          );
        }
        final flags = _InMemoryInitFlags();
        await flags.markInitialized('user-1', 'exercises');

        final seed = SeedExercises(repo, catalogInitFlags: flags);
        final result = await seed(ownerUserId: 'user-1');

        expect(result, const Right<Failure, int>(0));
        expect(
          repo.store.length,
          defaults.length - 1,
          reason: 'no new rows may be added when the flag is already set',
        );
      },
    );

    test(
      'does not insert duplicate when default name exists under a legacy id',
      () async {
        // Simulates the real-device scenario: "Bench Press" was pulled from
        // Supabase under its legacy name-only id (not the new forOwner id).
        // The self-heal must detect the name match and not create a duplicate.
        final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
        final defaults = DefaultExercisesData.getDefaultExercises();
        final legacyTarget = defaults[0]; // 'Bench Press'
        final now = DateTime(2026);

        // Insert all defaults except legacyTarget under their correct ids.
        for (final d in defaults.skip(1)) {
          await repo.addExercise(
            d.toEntity(
              DeterministicCatalogId.forOwner(
                ownerUserId: 'user-1',
                name: d.name,
              ),
              now,
              ownerUserId: 'user-1',
            ),
          );
        }
        // Insert legacyTarget under a different (legacy) id.
        await repo.addExercise(
          legacyTarget.toEntity(
            'legacy-id-bench-press',
            now,
            ownerUserId: 'user-1',
          ),
        );

        final flags = _InMemoryInitFlags();
        final seed = SeedExercises(repo, catalogInitFlags: flags);
        final result = await seed(ownerUserId: 'user-1');

        // All names present → self-heal inserts 0, flag is set.
        expect(result, const Right<Failure, int>(0));
        expect(
          repo.store.length,
          defaults.length,
          reason: 'no duplicate must be added for "${legacyTarget.name}"',
        );
        expect(await flags.isInitialized('user-1', 'exercises'), isTrue);
      },
    );
  });

  test('reseeding is idempotent — ids are stable, no duplicates', () async {
    final repo = _InMemoryExerciseRepository()..currentOwner = 'user-1';
    final seed = SeedExercises(repo);

    await seed(ownerUserId: 'user-1');
    final idsAfterFirst = repo.store.keys.toSet();

    // Force a second seed pass over the already-populated store: re-add the
    // same defaults with the owner-scoped deterministic id. Stable ids mean
    // re-adding overwrites in place — the key set is unchanged.
    for (final d in DefaultExercisesData.getDefaultExercises()) {
      await repo.addExercise(
        d.toEntity(
          DeterministicCatalogId.forOwner(ownerUserId: 'user-1', name: d.name),
          DateTime.now(),
          ownerUserId: 'user-1',
        ),
      );
    }

    expect(repo.store.keys.toSet(), idsAfterFirst);
  });
}

/// Exercise repository whose [addExercise] always fails — used to assert the
/// init flag is NOT set when seeding produces no rows.
class _FailingExerciseRepository implements ExerciseRepository {
  @override
  Future<Either<Failure, List<Exercise>>> getAllExercises({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async => const Right([]);

  @override
  Future<Either<Failure, void>> addExercise(Exercise exercise) async =>
      const Left(DatabaseFailure('insert failed'));

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

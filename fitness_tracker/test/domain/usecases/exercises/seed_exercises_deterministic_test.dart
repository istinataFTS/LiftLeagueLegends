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

  test(
    'guest-seeded catalog coexists with a post-sign-in user catalog '
    '(no primary-key collision on adoption)',
    () async {
      // Regression for empty-Library-after-sign-in: with a name-only id
      // the guest seed at boot reserved every id and the post-sign-in
      // provision step aborted, leaving the new user with no exercises.
      final repo = _InMemoryExerciseRepository();

      repo.currentOwner = '';
      final guestResult = await SeedExercises(repo)(ownerUserId: '');
      expect(guestResult.isRight(), isTrue);
      final guestCount = repo.store.length;

      repo.currentOwner = 'user-1';
      final userResult = await SeedExercises(repo)(ownerUserId: 'user-1');
      expect(userResult.isRight(), isTrue);

      final defaults = DefaultExercisesData.getDefaultExercises();
      expect(repo.store.length, guestCount + defaults.length);
      for (final d in defaults) {
        final guestId = DeterministicCatalogId.forOwner(
          ownerUserId: '',
          name: d.name,
        );
        final userId = DeterministicCatalogId.forOwner(
          ownerUserId: 'user-1',
          name: d.name,
        );
        expect(repo.store[guestId]?.ownerUserId, '');
        expect(repo.store[userId]?.ownerUserId, 'user-1');
      }
    },
  );

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
          DeterministicCatalogId.forOwner(
            ownerUserId: 'user-1',
            name: d.name,
          ),
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

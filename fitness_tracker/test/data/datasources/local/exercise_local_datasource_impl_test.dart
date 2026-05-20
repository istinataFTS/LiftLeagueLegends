import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/session/current_user_id_resolver.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:fitness_tracker/data/datasources/local/exercise_local_datasource.dart';
import 'package:fitness_tracker/data/models/exercise_model.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockCurrentUserIdResolver extends Mock implements CurrentUserIdResolver {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MockDatabaseHelper databaseHelper;
  late MockCurrentUserIdResolver mockResolver;
  late ExerciseLocalDataSourceImpl dataSource;

  const String currentUserId = 'user-1';
  const String otherUserId = 'user-2';

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  // Per-user catalog model: every row is owned. Default to the current
  // (authenticated) user so a row is visible under the default session
  // unless a test explicitly overrides the owner for an isolation scenario.
  ExerciseModel buildExercise({
    required String id,
    String? ownerUserId = currentUserId,
    required String name,
    List<String> muscleGroups = const <String>['chest', 'triceps'],
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return ExerciseModel(
      id: id,
      ownerUserId: ownerUserId,
      name: name,
      muscleGroups: muscleGroups,
      createdAt: baseDate,
      updatedAt: updatedAt ?? baseDate,
      syncMetadata: syncMetadata,
    );
  }

  Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.exercises} (
        ${DatabaseTables.exerciseId} TEXT PRIMARY KEY,
        ${DatabaseTables.ownerUserId} TEXT,
        ${DatabaseTables.exerciseName} TEXT NOT NULL,
        ${DatabaseTables.exerciseMuscleGroups} TEXT NOT NULL,
        ${DatabaseTables.exerciseCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.exerciseUpdatedAt} TEXT NOT NULL,
        ${DatabaseTables.exerciseServerId} TEXT,
        ${DatabaseTables.exerciseSyncStatus} TEXT NOT NULL DEFAULT 'localOnly',
        ${DatabaseTables.exerciseLastSyncedAt} TEXT,
        ${DatabaseTables.exerciseLastSyncError} TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE ${DatabaseTables.exerciseMuscleFactors} (
        ${DatabaseTables.factorId} TEXT PRIMARY KEY,
        ${DatabaseTables.factorExerciseId} TEXT NOT NULL,
        ${DatabaseTables.factorMuscleGroup} TEXT NOT NULL,
        ${DatabaseTables.factorValue} REAL NOT NULL,
        ${DatabaseTables.factorCreatedAt} TEXT NOT NULL,
        FOREIGN KEY (${DatabaseTables.factorExerciseId})
          REFERENCES ${DatabaseTables.exercises}(${DatabaseTables.exerciseId})
          ON DELETE CASCADE
      )
    ''');
    // Per-owner uniqueness — mirrors the production idx_exercises_name_owner.
    await db.execute('''
      CREATE UNIQUE INDEX idx_exercises_name_owner
      ON ${DatabaseTables.exercises}(
        ${DatabaseTables.exerciseName},
        COALESCE(${DatabaseTables.ownerUserId}, '')
      )
    ''');
    await db.execute('PRAGMA foreign_keys = ON');
  }

  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    database = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, _) async => createSchema(db),
      ),
    );

    databaseHelper = MockDatabaseHelper();
    when(() => databaseHelper.database).thenAnswer((_) async => database);

    mockResolver = MockCurrentUserIdResolver();
    when(() => mockResolver.resolve()).thenAnswer((_) async => currentUserId);

    dataSource = ExerciseLocalDataSourceImpl(
      databaseHelper: databaseHelper,
      currentUserIdResolver: mockResolver,
    );
  });

  tearDown(() async {
    await database.close();
  });

  // ---------------------------------------------------------------------------
  // pendingDelete filtering (existing behaviour, unchanged)
  // ---------------------------------------------------------------------------

  group('ExerciseLocalDataSourceImpl reads', () {
    test('getAllExercises hides pendingDelete rows', () async {
      await dataSource.insertExercise(
        buildExercise(id: 'exercise-1', name: 'Bench Press'),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-2',
          name: 'Cable Fly',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final exercises = await dataSource.getAllExercises();

      expect(exercises.map((exercise) => exercise.id).toList(), <String>[
        'exercise-1',
      ]);
    });

    test('getExerciseById returns null for pendingDelete row', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final exercise = await dataSource.getExerciseById('exercise-1');

      expect(exercise, isNull);
    });

    test('getExerciseByName returns null for pendingDelete row', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final exercise = await dataSource.getExerciseByName('Bench Press');

      expect(exercise, isNull);
    });

    test('getExercisesForMuscle hides pendingDelete rows', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          name: 'Bench Press',
          muscleGroups: const <String>['chest', 'triceps'],
        ),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-2',
          name: 'Chest Press Machine',
          muscleGroups: const <String>['chest'],
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final exercises = await dataSource.getExercisesForMuscle('chest');

      expect(exercises.map((exercise) => exercise.id).toList(), <String>[
        'exercise-1',
      ]);
    });
  });

  // ---------------------------------------------------------------------------
  // User isolation
  // ---------------------------------------------------------------------------

  group('ExerciseLocalDataSourceImpl user isolation', () {
    test('getAllExercises excludes legacy NULL-owner rows for an authed user '
        '(strict per-owner; no shared bucket)', () async {
      await dataSource.insertExercise(
        buildExercise(id: 'mine', ownerUserId: currentUserId, name: 'Squat'),
      );
      // A leftover NULL-owner row (pre-v20). It belongs to no account and
      // must not surface for an authenticated user.
      await dataSource.insertExercise(
        buildExercise(id: 'legacy-null', ownerUserId: null, name: 'Deadlift'),
      );

      final exercises = await dataSource.getAllExercises();

      expect(exercises.map((e) => e.id).toList(), <String>['mine']);
    });

    test(
      'getAllExercises returns only current-user rows, not other accounts',
      () async {
        await dataSource.insertExercise(
          buildExercise(
            id: 'mine',
            ownerUserId: currentUserId,
            name: 'My Exercise',
          ),
        );
        await dataSource.insertExercise(
          buildExercise(
            id: 'theirs',
            ownerUserId: otherUserId,
            name: 'Their Exercise',
          ),
        );
        // Guest-owned ('') row — a different account, must stay hidden.
        await dataSource.insertExercise(
          buildExercise(
            id: 'guest-owned',
            ownerUserId: '',
            name: 'Guest Exercise',
          ),
        );

        final exercises = await dataSource.getAllExercises();
        final ids = exercises.map((e) => e.id).toSet();

        expect(ids, <String>{'mine'});
        expect(ids, isNot(contains('theirs')));
        expect(ids, isNot(contains('guest-owned')));
      },
    );

    test(
      "getAllExercises returns only guest-owned ('') rows for a guest session",
      () async {
        when(() => mockResolver.resolve()).thenAnswer((_) async => '');

        await dataSource.insertExercise(
          buildExercise(id: 'guest-ex', ownerUserId: '', name: 'Squat'),
        );
        await dataSource.insertExercise(
          buildExercise(
            id: 'user-owned',
            ownerUserId: currentUserId,
            name: 'My Custom',
          ),
        );

        final exercises = await dataSource.getAllExercises();
        final ids = exercises.map((e) => e.id).toSet();

        expect(ids, <String>{'guest-ex'});
        expect(ids, isNot(contains('user-owned')));
      },
    );

    test('getExerciseById respects owner filter', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'theirs',
          ownerUserId: otherUserId,
          name: 'Their Exercise',
        ),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'mine',
          ownerUserId: currentUserId,
          name: 'My Exercise',
        ),
      );

      expect(await dataSource.getExerciseById('mine'), isNotNull);
      expect(await dataSource.getExerciseById('theirs'), isNull);
    });

    test('getExerciseByName respects owner filter', () async {
      await dataSource.insertExercise(
        buildExercise(id: 'theirs', ownerUserId: otherUserId, name: 'Deadlift'),
      );

      expect(await dataSource.getExerciseByName('Deadlift'), isNull);
    });

    test('getExercisesForMuscle respects owner filter', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'mine',
          ownerUserId: currentUserId,
          name: 'Romanian DL',
          muscleGroups: const <String>['hamstrings'],
        ),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'theirs',
          ownerUserId: otherUserId,
          name: 'Nordic Curl',
          muscleGroups: const <String>['hamstrings'],
        ),
      );

      final exercises = await dataSource.getExercisesForMuscle('hamstrings');
      final ids = exercises.map((e) => e.id).toSet();

      expect(ids, contains('mine'));
      expect(ids, isNot(contains('theirs')));
    });
  });

  // ---------------------------------------------------------------------------
  // clearUserOwnedExercises
  // ---------------------------------------------------------------------------

  group('ExerciseLocalDataSourceImpl clearUserOwnedExercises', () {
    test('deletes only rows owned by the given userId', () async {
      await dataSource.insertExercise(
        buildExercise(id: 'seeded', ownerUserId: null, name: 'Squat'),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'mine',
          ownerUserId: currentUserId,
          name: 'My Exercise',
        ),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'theirs',
          ownerUserId: otherUserId,
          name: 'Their Exercise',
        ),
      );

      await dataSource.clearUserOwnedExercises(currentUserId);

      final rawRows = await database.query(DatabaseTables.exercises);
      final ids = rawRows.map((r) => r[DatabaseTables.exerciseId]).toSet();

      // user-1's exercise is gone; seeded and other-user rows survive
      expect(ids, containsAll(<String>['seeded', 'theirs']));
      expect(ids, isNot(contains('mine')));
    });

    test('is a no-op when the user owns no exercises', () async {
      await dataSource.insertExercise(
        buildExercise(id: 'seeded', ownerUserId: null, name: 'Squat'),
      );

      await dataSource.clearUserOwnedExercises(currentUserId);

      final rawRows = await database.query(DatabaseTables.exercises);
      expect(rawRows, hasLength(1));
    });

    test('never deletes seeded exercises (ownerUserId IS NULL)', () async {
      await dataSource.insertExercise(
        buildExercise(id: 'seeded-1', ownerUserId: null, name: 'Squat'),
      );
      await dataSource.insertExercise(
        buildExercise(id: 'seeded-2', ownerUserId: null, name: 'Bench Press'),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'mine',
          ownerUserId: currentUserId,
          name: 'My Custom',
        ),
      );

      await dataSource.clearUserOwnedExercises(currentUserId);

      final rawRows = await database.query(DatabaseTables.exercises);
      final ids = rawRows.map((r) => r[DatabaseTables.exerciseId]).toSet();

      expect(ids, containsAll(<String>['seeded-1', 'seeded-2']));
      expect(ids, isNot(contains('mine')));
    });

    test('sign-out isolation: cleared catalog is invisible to a later guest or '
        "other user, and the guest '' catalog survives", () async {
      // user-1's adopted catalog + a guest-bucket row + another user.
      await dataSource.insertExercise(
        buildExercise(id: 'a-ex', ownerUserId: currentUserId, name: 'A Custom'),
      );
      await dataSource.insertExercise(
        buildExercise(id: 'guest-cat', ownerUserId: '', name: 'Squat'),
      );
      await dataSource.insertExercise(
        buildExercise(id: 'b-ex', ownerUserId: otherUserId, name: 'B Custom'),
      );

      // Sign-out cleanup for user-1.
      await dataSource.clearUserOwnedExercises(currentUserId);

      // Physically: only user-1's row is gone; guest + other-user survive.
      final rawIds = (await database.query(
        DatabaseTables.exercises,
      )).map((r) => r[DatabaseTables.exerciseId]).toSet();
      expect(rawIds, <Object?>{'guest-cat', 'b-ex'});

      // A subsequent guest session sees only its own '' catalog —
      // never user-1's cleared data or user-2's rows.
      when(() => mockResolver.resolve()).thenAnswer((_) async => '');
      final asGuest = await dataSource.getAllExercises();
      expect(asGuest.map((e) => e.id).toList(), <String>['guest-cat']);

      // A different signed-in user sees only their own rows.
      when(() => mockResolver.resolve()).thenAnswer((_) async => otherUserId);
      final asOther = await dataSource.getAllExercises();
      expect(asOther.map((e) => e.id).toList(), <String>['b-ex']);
    });
  });

  // ---------------------------------------------------------------------------
  // Merge (existing behaviour, unchanged)
  // ---------------------------------------------------------------------------

  group('ExerciseLocalDataSourceImpl mergeRemoteExercises', () {
    test('preserves pending local update over newer remote row', () async {
      final localPendingExercise = buildExercise(
        id: 'exercise-1',
        name: 'Bench Press Local',
        updatedAt: baseDate.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpdate,
        ),
      );

      final remoteExercise = buildExercise(
        id: 'exercise-1',
        name: 'Bench Press Remote',
        updatedAt: baseDate.add(const Duration(hours: 2)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      await dataSource.insertExercise(localPendingExercise);

      await dataSource.mergeRemoteExercises(<ExerciseModel>[remoteExercise]);

      final exercises = await dataSource.getAllExercises();
      expect(exercises, hasLength(1));
      expect(exercises.first.name, 'Bench Press Local');
      expect(exercises.first.syncMetadata.status, SyncStatus.pendingUpdate);
    });

    test(
      'adds remote-only rows while preserving local pending upload',
      () async {
        final localPendingExercise = buildExercise(
          id: 'exercise-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        );

        final remoteExercise = buildExercise(
          id: 'exercise-2',
          name: 'Squat',
          muscleGroups: const <String>['quads', 'glutes'],
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        await dataSource.insertExercise(localPendingExercise);

        await dataSource.mergeRemoteExercises(<ExerciseModel>[remoteExercise]);

        final exercises = await dataSource.getAllExercises();
        expect(exercises.map((exercise) => exercise.id).toSet(), <String>{
          'exercise-1',
          'exercise-2',
        });
        expect(
          exercises
              .firstWhere((exercise) => exercise.id == 'exercise-1')
              .syncMetadata
              .status,
          SyncStatus.pendingUpload,
        );
      },
    );

    test(
      'keeps pendingDelete row hidden even if remote still has it',
      () async {
        final localPendingDelete = buildExercise(
          id: 'exercise-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        );

        final remoteExercise = buildExercise(
          id: 'exercise-1',
          name: 'Bench Press Remote',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        await dataSource.insertExercise(localPendingDelete);

        await dataSource.mergeRemoteExercises(<ExerciseModel>[remoteExercise]);

        final visibleExercises = await dataSource.getAllExercises();
        expect(visibleExercises, isEmpty);

        final rawRows = await database.query(DatabaseTables.exercises);
        expect(rawRows, hasLength(1));
        expect(
          rawRows.first[DatabaseTables.exerciseSyncStatus],
          SyncStatus.pendingDelete.name,
        );
      },
    );
  });

  // ---------------------------------------------------------------------------
  // State transitions (existing behaviour, unchanged)
  // ---------------------------------------------------------------------------

  group('ExerciseLocalDataSourceImpl state transitions', () {
    test('markAsPendingDelete updates sync status and error', () async {
      await dataSource.insertExercise(
        buildExercise(id: 'exercise-1', name: 'Bench Press'),
      );

      await dataSource.markAsPendingDelete(
        'exercise-1',
        errorMessage: 'delete queued',
      );

      final rawRows = await database.query(
        DatabaseTables.exercises,
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: <Object?>['exercise-1'],
      );

      expect(
        rawRows.single[DatabaseTables.exerciseSyncStatus],
        SyncStatus.pendingDelete.name,
      );
      expect(
        rawRows.single[DatabaseTables.exerciseLastSyncError],
        'delete queued',
      );
    });

    test(
      'upsertExercise inserts when missing and updates when present',
      () async {
        final inserted = buildExercise(id: 'exercise-1', name: 'Bench Press');

        await dataSource.upsertExercise(inserted);

        final updated = buildExercise(
          id: 'exercise-1',
          name: 'Bench Press Updated',
          updatedAt: baseDate.add(const Duration(hours: 2)),
        );

        await dataSource.upsertExercise(updated);

        final exercise = await dataSource.getExerciseById('exercise-1');
        expect(exercise, isNotNull);
        expect(exercise!.name, 'Bench Press Updated');
      },
    );

    test('upsertExercise does not revive a pendingDelete row', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      await dataSource.upsertExercise(
        buildExercise(
          id: 'exercise-1',
          name: 'Bench Press Remote',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      final visibleExercise = await dataSource.getExerciseById('exercise-1');
      expect(visibleExercise, isNull);

      final rawRows = await database.query(
        DatabaseTables.exercises,
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: <Object?>['exercise-1'],
      );
      expect(rawRows, hasLength(1));
      expect(
        rawRows.single[DatabaseTables.exerciseSyncStatus],
        SyncStatus.pendingDelete.name,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // prepareForInitialCloudMigration
  // ---------------------------------------------------------------------------

  group(
    'ExerciseLocalDataSourceImpl prepareForInitialCloudMigration auth guard',
    () {
      test(
        'throws MissingUserContextException when called in guest mode',
        () async {
          when(() => mockResolver.resolve()).thenAnswer((_) async => '');

          await expectLater(
            dataSource.prepareForInitialCloudMigration(userId: 'user-1'),
            throwsA(isA<MissingUserContextException>()),
          );
        },
      );
    },
  );

  group('ExerciseLocalDataSourceImpl prepareForInitialCloudMigration', () {
    Future<Map<String, Object?>> rawExercise(String id) async {
      final rows = await database.query(
        DatabaseTables.exercises,
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: <Object?>[id],
      );
      expect(rows, hasLength(1));
      return rows.single;
    }

    test("leaves guest-sentinel ('') localOnly exercise untouched", () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          ownerUserId: '',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.localOnly),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawExercise('exercise-1');
      expect(row[DatabaseTables.ownerUserId], '');
      expect(row[DatabaseTables.exerciseSyncStatus], SyncStatus.localOnly.name);
    });

    test('leaves legacy NULL-owner localOnly exercise untouched', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          ownerUserId: null,
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.localOnly),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawExercise('exercise-1');
      expect(row[DatabaseTables.ownerUserId], isNull);
      expect(row[DatabaseTables.exerciseSyncStatus], SyncStatus.localOnly.name);
    });

    test('leaves guest syncError exercise untouched', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          ownerUserId: '',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.syncError,
            lastSyncError: 'prior error',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawExercise('exercise-1');
      expect(row[DatabaseTables.ownerUserId], '');
      expect(row[DatabaseTables.exerciseSyncStatus], SyncStatus.syncError.name);
      expect(row[DatabaseTables.exerciseLastSyncError], 'prior error');
    });

    test('leaves guest pendingUpload exercise untouched', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          ownerUserId: '',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
            lastSyncError: 'prior error',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawExercise('exercise-1');
      expect(row[DatabaseTables.ownerUserId], '');
      expect(
        row[DatabaseTables.exerciseSyncStatus],
        SyncStatus.pendingUpload.name,
      );
      expect(row[DatabaseTables.exerciseLastSyncError], 'prior error');
    });

    test('leaves guest pendingUpdate exercise untouched', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          ownerUserId: '',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
            lastSyncError: 'prior error',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawExercise('exercise-1');
      expect(row[DatabaseTables.ownerUserId], '');
      expect(
        row[DatabaseTables.exerciseSyncStatus],
        SyncStatus.pendingUpdate.name,
      );
      expect(row[DatabaseTables.exerciseLastSyncError], 'prior error');
    });

    // User-owned exercises — queued for upload

    test('queues user-owned localOnly exercise for upload', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          ownerUserId: 'user-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.localOnly,
            lastSyncError: 'offline',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final exercise = await dataSource.getExerciseById('exercise-1');
      expect(exercise, isNotNull);
      expect(exercise!.ownerUserId, 'user-1');
      expect(exercise.syncMetadata.status, SyncStatus.pendingUpload);
      expect(exercise.syncMetadata.lastSyncError, isNull);
    });

    test('recovers user-owned syncError exercise into pendingUpload', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          ownerUserId: 'user-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.syncError,
            lastSyncError: 'offline',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final exercise = await dataSource.getExerciseById('exercise-1');
      expect(exercise, isNotNull);
      expect(exercise!.ownerUserId, 'user-1');
      expect(exercise.syncMetadata.status, SyncStatus.pendingUpload);
      expect(exercise.syncMetadata.lastSyncError, isNull);
    });

    test('leaves user-owned synced exercise unchanged', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'exercise-1',
          ownerUserId: 'user-1',
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.synced,
            serverId: 'server-1',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final exercise = await dataSource.getExerciseById('exercise-1');
      expect(exercise, isNotNull);
      expect(exercise!.syncMetadata.status, SyncStatus.synced);
      expect(exercise.syncMetadata.serverId, 'server-1');
    });
  });

  group('factor preservation during sync', () {
    // Regression: `mergeRemoteExercises` previously did
    // `DELETE FROM exercises` + `INSERT OR REPLACE`, which cascaded via
    // `ON DELETE CASCADE` on `exercise_muscle_factors.exerciseId` and
    // wiped every muscle factor on every sync. The user then saw
    // "Set logged, but we couldn't map it to any muscle group" because
    // stimulus calculation ran before the heal hook reseeded factors.
    Future<void> seedFactor(String exerciseId, String muscle) async {
      await database.insert(DatabaseTables.exerciseMuscleFactors, {
        DatabaseTables.factorId: 'factor-$exerciseId-$muscle',
        DatabaseTables.factorExerciseId: exerciseId,
        DatabaseTables.factorMuscleGroup: muscle,
        DatabaseTables.factorValue: 1.0,
        DatabaseTables.factorCreatedAt: baseDate.toIso8601String(),
      });
    }

    Future<int> factorCountFor(String exerciseId) async {
      final rows = await database.query(
        DatabaseTables.exerciseMuscleFactors,
        where: '${DatabaseTables.factorExerciseId} = ?',
        whereArgs: <Object?>[exerciseId],
      );
      return rows.length;
    }

    test(
      'mergeRemoteExercises preserves factors for unchanged exercises',
      () async {
        await database.insert(
          DatabaseTables.exercises,
          buildExercise(
            id: 'exercise-1',
            name: 'Cable Crossover',
            syncMetadata: const EntitySyncMetadata(
              status: SyncStatus.synced,
              serverId: 'server-1',
            ),
          ).toMap(),
        );
        await seedFactor('exercise-1', 'mid_chest');
        await seedFactor('exercise-1', 'front_delts');

        await dataSource.mergeRemoteExercises(<ExerciseModel>[
          buildExercise(
            id: 'exercise-1',
            name: 'Cable Crossover',
            updatedAt: baseDate.add(const Duration(minutes: 1)),
            syncMetadata: const EntitySyncMetadata(
              status: SyncStatus.synced,
              serverId: 'server-1',
            ),
          ),
        ]);

        expect(await factorCountFor('exercise-1'), 2);
      },
    );

    test(
      'insertExercise throws on duplicate id instead of cascading factors',
      () async {
        await database.insert(
          DatabaseTables.exercises,
          buildExercise(id: 'exercise-1', name: 'Original').toMap(),
        );
        await seedFactor('exercise-1', 'mid_chest');

        await expectLater(
          dataSource.insertExercise(
            buildExercise(id: 'exercise-1', name: 'Duplicate'),
          ),
          throwsA(isA<Object>()),
        );

        expect(await factorCountFor('exercise-1'), 1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Multi-owner name coexistence (regression for v18 schema migration)
  // ---------------------------------------------------------------------------
  // Before v18 the schema had UNIQUE(name) globally, so a sign-in sync that
  // pulled user-owned exercises whose names collided with system-seeded ones
  // would throw "UNIQUE constraint failed: exercises.name" and block the user.
  // After v18 the constraint is UNIQUE(name, COALESCE(owner_user_id, '')):
  // the system row (owner = NULL → '') and the user row live in separate
  // uniqueness buckets and can coexist.

  group('ExerciseLocalDataSourceImpl multi-owner name coexistence', () {
    test(
      "guest ('') and user-owned exercise with the same name coexist in "
      'storage; only the current-user row is visible (strict per-owner)',
      () async {
        // Guest-bucket row (legacy seeded catalog collapsed to '' by v20).
        await dataSource.insertExercise(
          buildExercise(
            id: 'guest-barbell-row',
            ownerUserId: '',
            name: 'Barbell Row',
          ),
        );

        // Remote pull brings the same exercise owned by the current user.
        await dataSource.mergeRemoteExercises(<ExerciseModel>[
          buildExercise(
            id: 'usr-barbell-row',
            ownerUserId: currentUserId,
            name: 'Barbell Row',
            syncMetadata: const EntitySyncMetadata(
              status: SyncStatus.synced,
              serverId: 'server-barbell',
            ),
          ),
        ]);

        // Both rows coexist in storage — distinct (name, owner) buckets.
        final rawRows = await database.query(DatabaseTables.exercises);
        expect(rawRows, hasLength(2));

        // But only the current user's row is visible — no shared bucket.
        final visible = await dataSource.getAllExercises();
        expect(visible.map((e) => e.id).toSet(), {'usr-barbell-row'});
      },
    );

    test('insertExercise rejects a duplicate (name, owner) pair '
        'while allowing same name for a different owner', () async {
      await dataSource.insertExercise(
        buildExercise(id: 'sys-squat', ownerUserId: null, name: 'Squat'),
      );

      // Different owner — must succeed.
      await expectLater(
        dataSource.insertExercise(
          buildExercise(
            id: 'usr-squat',
            ownerUserId: currentUserId,
            name: 'Squat',
          ),
        ),
        completes,
      );

      // Same owner as the first insert (null) — must fail.
      await expectLater(
        dataSource.insertExercise(
          buildExercise(id: 'sys-squat-dup', ownerUserId: null, name: 'Squat'),
        ),
        throwsA(isA<Object>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // getPendingSyncExercises — owner-scoped (Model-A Issue 2)
  // ---------------------------------------------------------------------------

  group('ExerciseLocalDataSourceImpl getPendingSyncExercises owner scope', () {
    test('returns current-user pending rows', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'mine-upload',
          ownerUserId: currentUserId,
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'mine-update',
          ownerUserId: currentUserId,
          name: 'Squat',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
          ),
        ),
      );

      final result = await dataSource.getPendingSyncExercises();
      expect(result.map((e) => e.id).toSet(), <String>{
        'mine-upload',
        'mine-update',
      });
    });

    test('excludes another account\'s pending rows', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'mine',
          ownerUserId: currentUserId,
          name: 'Bench Press',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'theirs',
          ownerUserId: otherUserId,
          name: 'Squat',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );

      final result = await dataSource.getPendingSyncExercises();
      expect(result.map((e) => e.id).toList(), <String>['mine']);
    });

    test('excludes localOnly and synced rows', () async {
      await dataSource.insertExercise(
        buildExercise(
          id: 'local-only',
          ownerUserId: currentUserId,
          name: 'Deadlift',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.localOnly),
        ),
      );
      await dataSource.insertExercise(
        buildExercise(
          id: 'synced',
          ownerUserId: currentUserId,
          name: 'Row',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      final result = await dataSource.getPendingSyncExercises();
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Incoming-list deduplication (regression for _deduplicateByNameAndOwner)
  // ---------------------------------------------------------------------------
  // If the remote sends two rows with the same (name, owner) in one batch —
  // possible during edge-case remote bugs — the datasource should keep only
  // the most-recently-updated entry and not trip the UNIQUE index.

  group('ExerciseLocalDataSourceImpl incoming duplicate deduplication', () {
    test('replaceAllExercises with duplicate (name, owner) in the incoming list '
        'keeps only the most-recently-updated row', () async {
      final older = buildExercise(
        id: 'e-old',
        ownerUserId: currentUserId,
        name: 'Squat',
        updatedAt: baseDate,
      );
      final newer = buildExercise(
        id: 'e-new',
        ownerUserId: currentUserId,
        name: 'Squat',
        updatedAt: baseDate.add(const Duration(hours: 1)),
      );

      // Both share (name='Squat', owner=currentUserId) — only 'e-new' survives.
      await dataSource.replaceAllExercises(<ExerciseModel>[older, newer]);

      final rawRows = await database.query(DatabaseTables.exercises);
      expect(rawRows, hasLength(1));
      expect(rawRows.first[DatabaseTables.exerciseId], 'e-new');
    });

    test(
      'replaceAllExercises with different (name, owner) pairs inserts all rows',
      () async {
        await dataSource.replaceAllExercises(<ExerciseModel>[
          buildExercise(id: 'e1', ownerUserId: currentUserId, name: 'Squat'),
          buildExercise(id: 'e2', ownerUserId: null, name: 'Squat'),
          buildExercise(id: 'e3', ownerUserId: currentUserId, name: 'Deadlift'),
        ]);

        final rawRows = await database.query(DatabaseTables.exercises);
        expect(rawRows, hasLength(3));
      },
    );
  });
}

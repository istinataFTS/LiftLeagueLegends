import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/session/current_user_id_resolver.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:fitness_tracker/data/datasources/local/workout_set_local_datasource_impl.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class MockDatabaseHelper extends Mock implements DatabaseHelper {}

class MockCurrentUserIdResolver extends Mock implements CurrentUserIdResolver {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database database;
  late MockDatabaseHelper databaseHelper;
  late MockCurrentUserIdResolver mockCurrentUserIdResolver;
  late WorkoutSetLocalDataSourceImpl dataSource;

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  WorkoutSet buildSet({
    required String id,
    required String exerciseId,
    required DateTime date,
    double weight = 80,
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return WorkoutSet(
      id: id,
      ownerUserId: 'user-1',
      exerciseId: exerciseId,
      reps: 10,
      weight: weight,
      intensity: 8,
      date: date,
      createdAt: date,
      updatedAt: updatedAt ?? date,
      syncMetadata: syncMetadata,
    );
  }

  Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.workoutSets} (
        ${DatabaseTables.setId} TEXT PRIMARY KEY,
        ${DatabaseTables.ownerUserId} TEXT,
        ${DatabaseTables.setExerciseId} TEXT NOT NULL,
        ${DatabaseTables.setReps} INTEGER NOT NULL,
        ${DatabaseTables.setWeight} REAL NOT NULL,
        ${DatabaseTables.setIntensity} INTEGER NOT NULL DEFAULT 10,
        ${DatabaseTables.setDate} TEXT NOT NULL,
        ${DatabaseTables.setCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.setUpdatedAt} TEXT NOT NULL,
        ${DatabaseTables.setServerId} TEXT,
        ${DatabaseTables.setSyncStatus} TEXT NOT NULL DEFAULT 'localOnly',
        ${DatabaseTables.setLastSyncedAt} TEXT,
        ${DatabaseTables.setLastSyncError} TEXT
      )
    ''');
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

    mockCurrentUserIdResolver = MockCurrentUserIdResolver();
    when(
      () => mockCurrentUserIdResolver.resolve(),
    ).thenAnswer((_) async => 'user-1');

    dataSource = WorkoutSetLocalDataSourceImpl(
      databaseHelper: databaseHelper,
      currentUserIdResolver: mockCurrentUserIdResolver,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('WorkoutSetLocalDataSourceImpl reads', () {
    test('getAllSets hides pendingDelete rows', () async {
      await dataSource.addSet(
        buildSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      );
      await dataSource.addSet(
        buildSet(
          id: 'set-2',
          exerciseId: 'bench',
          date: baseDate.add(const Duration(hours: 1)),
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final sets = await dataSource.getAllSets();

      expect(sets.map((set) => set.id).toList(), <String>['set-1']);
    });

    test('getSetById returns null for pendingDelete row', () async {
      await dataSource.addSet(
        buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final set = await dataSource.getSetById('set-1');

      expect(set, isNull);
    });

    test('getSetsByExerciseId hides pendingDelete rows', () async {
      await dataSource.addSet(
        buildSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      );
      await dataSource.addSet(
        buildSet(
          id: 'set-2',
          exerciseId: 'bench',
          date: baseDate.add(const Duration(hours: 1)),
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final sets = await dataSource.getSetsByExerciseId('bench');

      expect(sets.map((set) => set.id).toList(), <String>['set-1']);
    });

    test('getSetsByDateRange hides pendingDelete rows', () async {
      await dataSource.addSet(
        buildSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      );
      await dataSource.addSet(
        buildSet(
          id: 'set-2',
          exerciseId: 'squat',
          date: baseDate.add(const Duration(hours: 2)),
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final sets = await dataSource.getSetsByDateRange(
        baseDate.subtract(const Duration(hours: 1)),
        baseDate.add(const Duration(hours: 3)),
      );

      expect(sets.map((set) => set.id).toList(), <String>['set-1']);
    });
  });

  group('WorkoutSetLocalDataSourceImpl mergeRemoteSets', () {
    test('preserves pending local update over newer remote row', () async {
      final localPendingSet = buildSet(
        id: 'set-1',
        exerciseId: 'bench',
        date: baseDate,
        weight: 90,
        updatedAt: baseDate.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpdate,
        ),
      );

      final remoteSet = buildSet(
        id: 'set-1',
        exerciseId: 'bench',
        date: baseDate,
        weight: 110,
        updatedAt: baseDate.add(const Duration(hours: 2)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      await dataSource.addSet(localPendingSet);

      await dataSource.mergeRemoteSets(<WorkoutSet>[remoteSet]);

      final sets = await dataSource.getAllSets();
      expect(sets, hasLength(1));
      expect(sets.first.weight, 90);
      expect(sets.first.syncMetadata.status, SyncStatus.pendingUpdate);
    });

    test(
      'adds remote-only rows while preserving local pending upload',
      () async {
        final localPendingSet = buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        );

        final remoteSet = buildSet(
          id: 'set-2',
          exerciseId: 'squat',
          date: baseDate.add(const Duration(days: 1)),
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        await dataSource.addSet(localPendingSet);

        await dataSource.mergeRemoteSets(<WorkoutSet>[remoteSet]);

        final sets = await dataSource.getAllSets();
        expect(sets.map((set) => set.id).toSet(), <String>{'set-1', 'set-2'});
        expect(
          sets.firstWhere((set) => set.id == 'set-1').syncMetadata.status,
          SyncStatus.pendingUpload,
        );
      },
    );

    test(
      'keeps pendingDelete row hidden even if remote still has it',
      () async {
        final localPendingDelete = buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        );

        final remoteSet = buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          weight: 120,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        await dataSource.addSet(localPendingDelete);

        await dataSource.mergeRemoteSets(<WorkoutSet>[remoteSet]);

        final visibleSets = await dataSource.getAllSets();
        expect(visibleSets, isEmpty);

        final rawRows = await database.query(DatabaseTables.workoutSets);
        expect(rawRows, hasLength(1));
        expect(
          rawRows.first[DatabaseTables.setSyncStatus],
          SyncStatus.pendingDelete.name,
        );
      },
    );
  });

  group('WorkoutSetLocalDataSourceImpl state transitions', () {
    test('markAsPendingDelete updates sync status and error', () async {
      await dataSource.addSet(
        buildSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      );

      await dataSource.markAsPendingDelete(
        'set-1',
        errorMessage: 'delete queued',
      );

      final rawRows = await database.query(
        DatabaseTables.workoutSets,
        where: '${DatabaseTables.setId} = ?',
        whereArgs: <Object?>['set-1'],
      );

      expect(
        rawRows.single[DatabaseTables.setSyncStatus],
        SyncStatus.pendingDelete.name,
      );
      expect(rawRows.single[DatabaseTables.setLastSyncError], 'delete queued');
    });

    test('upsertSet inserts when missing and updates when present', () async {
      final inserted = buildSet(
        id: 'set-1',
        exerciseId: 'bench',
        date: baseDate,
      );

      await dataSource.upsertSet(inserted);

      final updated = buildSet(
        id: 'set-1',
        exerciseId: 'bench',
        date: baseDate,
        weight: 95,
        updatedAt: baseDate.add(const Duration(hours: 2)),
      );

      await dataSource.upsertSet(updated);

      final set = await dataSource.getSetById('set-1');
      expect(set, isNotNull);
      expect(set!.weight, 95);
    });

    test('upsertSet does not revive a pendingDelete row', () async {
      await dataSource.addSet(
        buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      await dataSource.upsertSet(
        buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          weight: 120,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      final visibleSet = await dataSource.getSetById('set-1');
      expect(visibleSet, isNull);

      final rawRows = await database.query(
        DatabaseTables.workoutSets,
        where: '${DatabaseTables.setId} = ?',
        whereArgs: <Object?>['set-1'],
      );
      expect(rawRows, hasLength(1));
      expect(
        rawRows.single[DatabaseTables.setSyncStatus],
        SyncStatus.pendingDelete.name,
      );
    });
  });

  group('WorkoutSetLocalDataSourceImpl user isolation', () {
    test('getAllSets only returns sets owned by the current user', () async {
      await dataSource.addSet(
        buildSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      );
      await dataSource.addSet(
        buildSet(
          id: 'set-2',
          exerciseId: 'squat',
          date: baseDate,
        ).copyWith(ownerUserId: 'user-2'),
      );

      final sets = await dataSource.getAllSets();

      expect(sets.map((s) => s.id).toList(), <String>['set-1']);
    });

    test('getSetsByExerciseId excludes other users sets', () async {
      await dataSource.addSet(
        buildSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      );
      await dataSource.addSet(
        buildSet(
          id: 'set-2',
          exerciseId: 'bench',
          date: baseDate,
        ).copyWith(ownerUserId: 'user-2'),
      );

      final sets = await dataSource.getSetsByExerciseId('bench');

      expect(sets.map((s) => s.id).toList(), <String>['set-1']);
    });

    test('getSetsByDateRange excludes other users sets', () async {
      await dataSource.addSet(
        buildSet(id: 'set-1', exerciseId: 'bench', date: baseDate),
      );
      await dataSource.addSet(
        buildSet(
          id: 'set-2',
          exerciseId: 'squat',
          date: baseDate,
        ).copyWith(ownerUserId: 'user-2'),
      );

      final sets = await dataSource.getSetsByDateRange(
        baseDate.subtract(const Duration(hours: 1)),
        baseDate.add(const Duration(hours: 1)),
      );

      expect(sets.map((s) => s.id).toList(), <String>['set-1']);
    });
  });

  // ---------------------------------------------------------------------------
  // getPendingSyncSets — owner-scoped (Model-A Issue 2)
  // ---------------------------------------------------------------------------

  group('WorkoutSetLocalDataSourceImpl getPendingSyncSets owner scope', () {
    test('returns current-user pending rows', () async {
      await dataSource.addSet(
        buildSet(
          id: 'mine-upload',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );
      await dataSource.addSet(
        buildSet(
          id: 'mine-update',
          exerciseId: 'squat',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
          ),
        ),
      );

      final result = await dataSource.getPendingSyncSets();
      expect(result.map((s) => s.id).toSet(), <String>{
        'mine-upload',
        'mine-update',
      });
    });

    test("excludes another account's pending rows", () async {
      await dataSource.addSet(
        buildSet(
          id: 'mine',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );
      await dataSource.addSet(
        buildSet(
          id: 'theirs',
          exerciseId: 'squat',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ).copyWith(ownerUserId: 'user-2'),
      );

      final result = await dataSource.getPendingSyncSets();
      expect(result.map((s) => s.id).toList(), <String>['mine']);
    });

    test('returns empty for a guest session', () async {
      when(
        () => mockCurrentUserIdResolver.resolve(),
      ).thenAnswer((_) async => kGuestUserId);
      await dataSource.addSet(
        buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );

      final result = await dataSource.getPendingSyncSets();
      expect(result, isEmpty);
    });

    test('excludes localOnly and synced rows', () async {
      await dataSource.addSet(
        buildSet(
          id: 'local-only',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.localOnly),
        ),
      );
      await dataSource.addSet(
        buildSet(
          id: 'synced',
          exerciseId: 'squat',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      final result = await dataSource.getPendingSyncSets();
      expect(result, isEmpty);
    });
  });

  group('WorkoutSetLocalDataSourceImpl prepareForInitialCloudMigration', () {
    Future<Map<String, Object?>> rawSet(String id) async {
      final rows = await database.query(
        DatabaseTables.workoutSets,
        where: '${DatabaseTables.setId} = ?',
        whereArgs: <Object?>[id],
      );
      expect(rows, hasLength(1));
      return rows.single;
    }

    test('leaves guest localOnly rows untouched', () async {
      await dataSource.addSet(
        buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.localOnly,
            lastSyncError: 'offline',
          ),
        ).copyWith(clearOwnerUserId: true),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawSet('set-1');
      expect(row[DatabaseTables.ownerUserId], isNull);
      expect(row[DatabaseTables.setSyncStatus], SyncStatus.localOnly.name);
      expect(row[DatabaseTables.setLastSyncError], 'offline');
    });

    test('leaves guest syncError rows untouched', () async {
      await dataSource.addSet(
        buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.syncError,
            lastSyncError: 'offline',
          ),
        ).copyWith(clearOwnerUserId: true),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawSet('set-1');
      expect(row[DatabaseTables.ownerUserId], isNull);
      expect(row[DatabaseTables.setSyncStatus], SyncStatus.syncError.name);
      expect(row[DatabaseTables.setLastSyncError], 'offline');
    });

    test('leaves guest and different-user rows untouched', () async {
      await dataSource.addSet(
        buildSet(
          id: 'set-1',
          exerciseId: 'bench',
          date: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ).copyWith(clearOwnerUserId: true),
      );
      await dataSource.addSet(
        buildSet(
          id: 'set-2',
          exerciseId: 'squat',
          date: baseDate,
        ).copyWith(ownerUserId: 'another-user'),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final rows = await database.query(DatabaseTables.workoutSets);
      final guestRow = rows.firstWhere(
        (row) => row[DatabaseTables.setId] == 'set-1',
      );
      final otherUser = rows.firstWhere(
        (row) => row[DatabaseTables.setId] == 'set-2',
      );

      expect(
        guestRow[DatabaseTables.setSyncStatus],
        SyncStatus.pendingDelete.name,
      );
      expect(guestRow[DatabaseTables.ownerUserId], isNull);
      expect(otherUser[DatabaseTables.ownerUserId], 'another-user');
      expect(
        otherUser[DatabaseTables.setSyncStatus],
        SyncStatus.localOnly.name,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // clearSetsForOwner — owner-scoped destructive clear (Phase 2 / Bug 2 fix)
  // ---------------------------------------------------------------------------

  group('WorkoutSetLocalDataSourceImpl clearSetsForOwner', () {
    test(
      'deletes only the target owner\'s rows — guest and bystander survive',
      () async {
        await dataSource.addSet(
          buildSet(
            id: 'guest-set',
            exerciseId: 'squat',
            date: baseDate,
          ).copyWith(ownerUserId: kGuestUserId),
        );
        // 'user-1' is the default owner in buildSet.
        await dataSource.addSet(
          buildSet(id: 'user-a-set', exerciseId: 'bench', date: baseDate),
        );
        await dataSource.addSet(
          buildSet(
            id: 'user-b-set',
            exerciseId: 'deadlift',
            date: baseDate,
          ).copyWith(ownerUserId: 'user-2'),
        );

        await dataSource.clearSetsForOwner('user-1');

        final remaining = await database.query(DatabaseTables.workoutSets);
        final ids = remaining
            .map((r) => r[DatabaseTables.setId] as String)
            .toSet();

        expect(ids, equals(<String>{'guest-set', 'user-b-set'}));
        expect(ids, isNot(contains('user-a-set')));
      },
    );

    test(
      'clears the guest bucket (\'\') without touching authenticated owners',
      () async {
        await dataSource.addSet(
          buildSet(
            id: 'guest-set',
            exerciseId: 'squat',
            date: baseDate,
          ).copyWith(ownerUserId: kGuestUserId),
        );
        await dataSource.addSet(
          buildSet(id: 'user-set', exerciseId: 'bench', date: baseDate),
        );

        await dataSource.clearSetsForOwner(kGuestUserId);

        final remaining = await database.query(DatabaseTables.workoutSets);
        final ids = remaining
            .map((r) => r[DatabaseTables.setId] as String)
            .toSet();

        expect(ids, equals(<String>{'user-set'}));
        expect(ids, isNot(contains('guest-set')));
      },
    );

    test('is a no-op when the target owner has no rows', () async {
      await dataSource.addSet(
        buildSet(id: 'user-set', exerciseId: 'bench', date: baseDate),
      );

      await dataSource.clearSetsForOwner('nonexistent-user');

      final remaining = await database.query(DatabaseTables.workoutSets);
      expect(remaining, hasLength(1));
    });
  });
}

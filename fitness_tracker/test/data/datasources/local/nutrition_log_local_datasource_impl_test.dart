import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/session/current_user_id_resolver.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:fitness_tracker/data/datasources/local/nutrition_log_local_datasource_impl.dart';
import 'package:fitness_tracker/data/models/nutrition_log_model.dart';
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
  late MockCurrentUserIdResolver mockCurrentUserIdResolver;
  late NutritionLogLocalDataSourceImpl dataSource;

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  NutritionLogModel buildLog({
    required String id,
    required DateTime loggedAt,
    String? ownerUserId = 'user-1',
    String? mealId = 'meal-1',
    String mealName = 'Chicken Bowl',
    double? gramsConsumed = 100,
    double protein = 25,
    double carbs = 30,
    double fat = 10,
    double calories = 310,
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return NutritionLogModel(
      id: id,
      ownerUserId: ownerUserId,
      mealId: mealId,
      mealName: mealName,
      gramsConsumed: gramsConsumed,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fat,
      calories: calories,
      loggedAt: loggedAt,
      createdAt: loggedAt,
      updatedAt: updatedAt ?? loggedAt,
      syncMetadata: syncMetadata,
    );
  }

  Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.nutritionLogs} (
        ${DatabaseTables.nutritionLogId} TEXT PRIMARY KEY,
        owner_user_id TEXT,
        ${DatabaseTables.nutritionLogMealId} TEXT,
        ${DatabaseTables.nutritionLogMealName} TEXT NOT NULL DEFAULT '',
        ${DatabaseTables.nutritionLogGrams} REAL,
        ${DatabaseTables.nutritionLogCarbs} REAL NOT NULL,
        ${DatabaseTables.nutritionLogProtein} REAL NOT NULL,
        ${DatabaseTables.nutritionLogFat} REAL NOT NULL,
        ${DatabaseTables.nutritionLogCalories} REAL NOT NULL,
        ${DatabaseTables.nutritionLogDate} TEXT NOT NULL,
        ${DatabaseTables.nutritionLogCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.nutritionLogUpdatedAt} TEXT NOT NULL,
        ${DatabaseTables.nutritionLogServerId} TEXT,
        ${DatabaseTables.nutritionLogSyncStatus} TEXT NOT NULL DEFAULT 'localOnly',
        ${DatabaseTables.nutritionLogLastSyncedAt} TEXT,
        ${DatabaseTables.nutritionLogLastSyncError} TEXT
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

    dataSource = NutritionLogLocalDataSourceImpl(
      databaseHelper: databaseHelper,
      currentUserIdResolver: mockCurrentUserIdResolver,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('NutritionLogLocalDataSourceImpl reads', () {
    test('getAllLogs hides pendingDelete rows', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );
      await dataSource.insertLog(
        buildLog(
          id: 'log-2',
          loggedAt: baseDate.add(const Duration(hours: 1)),
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final logs = await dataSource.getAllLogs();

      expect(logs.map((l) => l.id).toList(), <String>['log-1']);
    });

    test('getLogById returns null for pendingDelete row', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final log = await dataSource.getLogById('log-1');

      expect(log, isNull);
    });

    test('getLogsByDate excludes pendingDelete rows', () async {
      await dataSource.insertLog(buildLog(id: 'log-1', loggedAt: baseDate));
      await dataSource.insertLog(
        buildLog(
          id: 'log-2',
          loggedAt: baseDate.add(const Duration(hours: 1)),
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final logs = await dataSource.getLogsByDate(baseDate);

      expect(logs.map((l) => l.id).toList(), <String>['log-1']);
    });

    test('getMealLogs excludes pendingDelete rows', () async {
      await dataSource.insertLog(
        buildLog(id: 'log-1', loggedAt: baseDate, mealId: 'meal-1'),
      );
      await dataSource.insertLog(
        buildLog(
          id: 'log-2',
          loggedAt: baseDate.add(const Duration(hours: 1)),
          mealId: 'meal-2',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final logs = await dataSource.getMealLogs();

      expect(logs.map((l) => l.id).toList(), <String>['log-1']);
    });

    test('getDailyMacros excludes pendingDelete rows', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          protein: 25,
          carbs: 30,
          fat: 10,
          calories: 310,
        ),
      );
      await dataSource.insertLog(
        buildLog(
          id: 'log-2',
          loggedAt: baseDate.add(const Duration(hours: 1)),
          protein: 50,
          carbs: 60,
          fat: 20,
          calories: 620,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final macros = await dataSource.getDailyMacros(baseDate);

      expect(macros['totalProtein'], 25);
      expect(macros['totalCarbs'], 30);
      expect(macros['totalFat'], 10);
      expect(macros['totalCalories'], 310);
      expect(macros['logsCount'], 1);
    });
  });

  group('NutritionLogLocalDataSourceImpl mergeRemoteLogs', () {
    test('preserves pending local update over remote row', () async {
      final localPendingLog = buildLog(
        id: 'log-1',
        loggedAt: baseDate,
        calories: 330,
        updatedAt: baseDate.add(const Duration(minutes: 30)),
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpdate,
        ),
      );

      final remoteLog = buildLog(
        id: 'log-1',
        loggedAt: baseDate,
        calories: 500,
        updatedAt: baseDate.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      await dataSource.insertLog(localPendingLog);

      await dataSource.mergeRemoteLogs(<NutritionLogModel>[remoteLog]);

      final logs = await dataSource.getAllLogs();
      expect(logs, hasLength(1));
      expect(logs.first.calories, 330);
      expect(logs.first.syncMetadata.status, SyncStatus.pendingUpdate);
    });

    test('adds remote-only rows while keeping local pending upload', () async {
      final localPendingLog = buildLog(
        id: 'log-1',
        loggedAt: baseDate,
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpload,
        ),
      );

      final remoteLog = buildLog(
        id: 'log-2',
        loggedAt: baseDate.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      await dataSource.insertLog(localPendingLog);

      await dataSource.mergeRemoteLogs(<NutritionLogModel>[remoteLog]);

      final logs = await dataSource.getAllLogs();
      expect(logs.map((l) => l.id).toSet(), <String>{'log-1', 'log-2'});
      expect(
        logs.firstWhere((l) => l.id == 'log-1').syncMetadata.status,
        SyncStatus.pendingUpload,
      );
    });

    test(
      'keeps pendingDelete row hidden even if remote still has it',
      () async {
        final localPendingDelete = buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        );

        final remoteLog = buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        await dataSource.insertLog(localPendingDelete);

        await dataSource.mergeRemoteLogs(<NutritionLogModel>[remoteLog]);

        final visibleLogs = await dataSource.getAllLogs();
        expect(visibleLogs, isEmpty);

        final rawRows = await database.query(DatabaseTables.nutritionLogs);
        expect(rawRows, hasLength(1));
        expect(
          rawRows.first[DatabaseTables.nutritionLogSyncStatus],
          SyncStatus.pendingDelete.name,
        );
      },
    );
  });

  group('NutritionLogLocalDataSourceImpl state transitions', () {
    test('markAsPendingDelete updates sync status and error', () async {
      await dataSource.insertLog(buildLog(id: 'log-1', loggedAt: baseDate));

      await dataSource.markAsPendingDelete(
        'log-1',
        errorMessage: 'delete queued',
      );

      final rawRows = await database.query(
        DatabaseTables.nutritionLogs,
        where: '${DatabaseTables.nutritionLogId} = ?',
        whereArgs: <Object?>['log-1'],
      );

      expect(
        rawRows.single[DatabaseTables.nutritionLogSyncStatus],
        SyncStatus.pendingDelete.name,
      );
      expect(
        rawRows.single[DatabaseTables.nutritionLogLastSyncError],
        'delete queued',
      );
    });

    test('upsertLog inserts when missing and updates when present', () async {
      final inserted = buildLog(id: 'log-1', loggedAt: baseDate, calories: 310);

      await dataSource.upsertLog(inserted);

      final updated = buildLog(
        id: 'log-1',
        loggedAt: baseDate,
        calories: 420,
        updatedAt: baseDate.add(const Duration(hours: 1)),
      );

      await dataSource.upsertLog(updated);

      final log = await dataSource.getLogById('log-1');
      expect(log, isNotNull);
      expect(log!.calories, 420);
    });

    test('upsertLog does not revive a pendingDelete row', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      await dataSource.upsertLog(
        buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          calories: 450,
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      final visibleLog = await dataSource.getLogById('log-1');
      expect(visibleLog, isNull);

      final rawRows = await database.query(
        DatabaseTables.nutritionLogs,
        where: '${DatabaseTables.nutritionLogId} = ?',
        whereArgs: <Object?>['log-1'],
      );
      expect(rawRows, hasLength(1));
      expect(
        rawRows.single[DatabaseTables.nutritionLogSyncStatus],
        SyncStatus.pendingDelete.name,
      );
    });
  });

  group('NutritionLogLocalDataSourceImpl user isolation', () {
    test('getAllLogs only returns logs owned by the current user', () async {
      await dataSource.insertLog(
        buildLog(id: 'log-1', loggedAt: baseDate, ownerUserId: 'user-1'),
      );
      await dataSource.insertLog(
        buildLog(id: 'log-2', loggedAt: baseDate, ownerUserId: 'user-2'),
      );

      final logs = await dataSource.getAllLogs();

      expect(logs.map((l) => l.id).toList(), <String>['log-1']);
    });

    test('getLogsByDate only returns current user logs', () async {
      await dataSource.insertLog(
        buildLog(id: 'log-1', loggedAt: baseDate, ownerUserId: 'user-1'),
      );
      await dataSource.insertLog(
        buildLog(id: 'log-2', loggedAt: baseDate, ownerUserId: 'user-2'),
      );

      final logs = await dataSource.getLogsByDate(baseDate);

      expect(logs.map((l) => l.id).toList(), <String>['log-1']);
    });

    test('getDailyMacros only sums current user logs', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          ownerUserId: 'user-1',
          calories: 500,
          protein: 40,
          carbs: 50,
          fat: 15,
        ),
      );
      await dataSource.insertLog(
        buildLog(
          id: 'log-2',
          loggedAt: baseDate,
          ownerUserId: 'user-2',
          calories: 999,
          protein: 99,
          carbs: 99,
          fat: 99,
        ),
      );

      final macros = await dataSource.getDailyMacros(baseDate);

      expect(macros['totalCalories'], 500.0);
      expect(macros['totalProtein'], 40.0);
    });
  });

  // ---------------------------------------------------------------------------
  // getPendingSyncLogs — owner-scoped (Model-A Issue 2)
  // ---------------------------------------------------------------------------

  group('NutritionLogLocalDataSourceImpl getPendingSyncLogs owner scope', () {
    test('returns current-user pending rows', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'mine-upload',
          loggedAt: baseDate,
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );
      await dataSource.insertLog(
        buildLog(
          id: 'mine-update',
          loggedAt: baseDate,
          ownerUserId: 'user-1',
          mealName: 'Salad',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
          ),
        ),
      );

      final result = await dataSource.getPendingSyncLogs();
      expect(result.map((l) => l.id).toSet(), <String>{
        'mine-upload',
        'mine-update',
      });
    });

    test("excludes another account's pending rows", () async {
      await dataSource.insertLog(
        buildLog(
          id: 'mine',
          loggedAt: baseDate,
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );
      await dataSource.insertLog(
        buildLog(
          id: 'theirs',
          loggedAt: baseDate,
          ownerUserId: 'user-2',
          mealName: 'Their log',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );

      final result = await dataSource.getPendingSyncLogs();
      expect(result.map((l) => l.id).toList(), <String>['mine']);
    });

    // "returns empty for a guest session" removed: guest sessions no longer
    // exist; the resolver throws.

    test('excludes localOnly and synced rows', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'local-only',
          loggedAt: baseDate,
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.localOnly),
        ),
      );
      await dataSource.insertLog(
        buildLog(
          id: 'synced',
          loggedAt: baseDate,
          ownerUserId: 'user-1',
          mealName: 'Synced meal',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      final result = await dataSource.getPendingSyncLogs();
      expect(result, isEmpty);
    });
  });

  group(
    'NutritionLogLocalDataSourceImpl prepareForInitialCloudMigration auth guard',
    () {
      test(
        'throws MissingUserContextException when called in guest mode',
        () async {
          when(() => mockCurrentUserIdResolver.resolve()).thenAnswer(
            (_) async => throw const MissingUserContextException(
              operation: 'session lookup',
            ),
          );

          await expectLater(
            dataSource.prepareForInitialCloudMigration(userId: 'user-1'),
            throwsA(isA<MissingUserContextException>()),
          );
        },
      );
    },
  );

  group('NutritionLogLocalDataSourceImpl prepareForInitialCloudMigration', () {
    Future<Map<String, Object?>> rawLog(String id) async {
      final rows = await database.query(
        DatabaseTables.nutritionLogs,
        where: '${DatabaseTables.nutritionLogId} = ?',
        whereArgs: <Object?>[id],
      );
      expect(rows, hasLength(1));
      return rows.single;
    }

    test('leaves guest localOnly log untouched', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          ownerUserId: null,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.localOnly,
            lastSyncError: 'offline',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawLog('log-1');
      expect(row[DatabaseTables.ownerUserId], isNull);
      expect(
        row[DatabaseTables.nutritionLogSyncStatus],
        SyncStatus.localOnly.name,
      );
      expect(row[DatabaseTables.nutritionLogLastSyncError], 'offline');
    });

    test('leaves guest syncError log untouched', () async {
      await dataSource.insertLog(
        buildLog(
          id: 'log-1',
          loggedAt: baseDate,
          ownerUserId: null,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.syncError,
            lastSyncError: 'offline',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawLog('log-1');
      expect(row[DatabaseTables.ownerUserId], isNull);
      expect(
        row[DatabaseTables.nutritionLogSyncStatus],
        SyncStatus.syncError.name,
      );
      expect(row[DatabaseTables.nutritionLogLastSyncError], 'offline');
    });
  });

  // ---------------------------------------------------------------------------
  // clearLogsForOwner — owner-scoped destructive clear (Phase 2 / Bug 2 fix)
  // ---------------------------------------------------------------------------

  group('NutritionLogLocalDataSourceImpl clearLogsForOwner', () {
    test(
      'deletes only the target owner\'s logs — guest and bystander survive',
      () async {
        await dataSource.insertLog(
          buildLog(
            id: 'guest-log',
            loggedAt: baseDate,
            ownerUserId: '',
            mealId: null,
          ),
        );
        // 'user-1' is the default owner in buildLog.
        await dataSource.insertLog(
          buildLog(id: 'user-a-log', loggedAt: baseDate, mealId: null),
        );
        await dataSource.insertLog(
          buildLog(
            id: 'user-b-log',
            loggedAt: baseDate,
            ownerUserId: 'user-2',
            mealId: null,
          ),
        );

        await dataSource.clearLogsForOwner('user-1');

        final remaining = await database.query(DatabaseTables.nutritionLogs);
        final ids = remaining
            .map((r) => r[DatabaseTables.nutritionLogId] as String)
            .toSet();

        expect(ids, equals(<String>{'guest-log', 'user-b-log'}));
        expect(ids, isNot(contains('user-a-log')));
      },
    );

    test(
      'clears the guest bucket (\'\') without touching authenticated owners',
      () async {
        await dataSource.insertLog(
          buildLog(
            id: 'guest-log',
            loggedAt: baseDate,
            ownerUserId: '',
            mealId: null,
          ),
        );
        await dataSource.insertLog(
          buildLog(id: 'user-log', loggedAt: baseDate, mealId: null),
        );

        await dataSource.clearLogsForOwner('');

        final remaining = await database.query(DatabaseTables.nutritionLogs);
        final ids = remaining
            .map((r) => r[DatabaseTables.nutritionLogId] as String)
            .toSet();

        expect(ids, equals(<String>{'user-log'}));
        expect(ids, isNot(contains('guest-log')));
      },
    );

    test('is a no-op when the target owner has no logs', () async {
      await dataSource.insertLog(
        buildLog(id: 'log-1', loggedAt: baseDate, mealId: null),
      );

      await dataSource.clearLogsForOwner('nonexistent-user');

      final remaining = await database.query(DatabaseTables.nutritionLogs);
      expect(remaining, hasLength(1));
    });
  });
}

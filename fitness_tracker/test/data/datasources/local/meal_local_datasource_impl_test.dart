import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/session/current_user_id_resolver.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:fitness_tracker/data/datasources/local/meal_local_datasource_impl.dart';
import 'package:fitness_tracker/data/models/meal_model.dart';
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
  late MealLocalDataSourceImpl dataSource;

  final DateTime baseDate = DateTime(2026, 3, 22, 10, 0);

  MealModel buildMeal({
    required String id,
    required String name,
    String? ownerUserId = 'user-1',
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    return MealModel(
      id: id,
      ownerUserId: ownerUserId,
      name: name,
      servingSizeGrams: 100,
      carbsPer100g: 30,
      proteinPer100g: 20,
      fatPer100g: 10,
      caloriesPer100g: 290,
      createdAt: baseDate,
      updatedAt: updatedAt ?? baseDate,
      syncMetadata: syncMetadata,
    );
  }

  Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.meals} (
        ${DatabaseTables.mealId} TEXT PRIMARY KEY,
        ${DatabaseTables.ownerUserId} TEXT,
        ${DatabaseTables.mealName} TEXT NOT NULL,
        ${DatabaseTables.mealServingSize} REAL NOT NULL DEFAULT 100.0,
        ${DatabaseTables.mealCarbsPer100g} REAL NOT NULL,
        ${DatabaseTables.mealProteinPer100g} REAL NOT NULL,
        ${DatabaseTables.mealFatPer100g} REAL NOT NULL,
        ${DatabaseTables.mealCaloriesPer100g} REAL NOT NULL,
        ${DatabaseTables.mealCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.mealUpdatedAt} TEXT NOT NULL,
        ${DatabaseTables.mealServerId} TEXT,
        ${DatabaseTables.mealSyncStatus} TEXT NOT NULL DEFAULT 'localOnly',
        ${DatabaseTables.mealLastSyncedAt} TEXT,
        ${DatabaseTables.mealLastSyncError} TEXT
      )
    ''');

    // Per-owner uniqueness — mirrors the production idx_meals_name_owner.
    await db.execute('''
      CREATE UNIQUE INDEX idx_meals_name_owner
      ON ${DatabaseTables.meals}(
        ${DatabaseTables.mealName},
        COALESCE(${DatabaseTables.ownerUserId}, '')
      )
    ''');

    // nutrition_logs is needed to verify that _replaceStoredMeals does not
    // cascade-delete food diary entries when meals are updated in place.
    await db.execute('''
      CREATE TABLE ${DatabaseTables.nutritionLogs} (
        ${DatabaseTables.nutritionLogId} TEXT PRIMARY KEY,
        ${DatabaseTables.ownerUserId} TEXT,
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
        ${DatabaseTables.nutritionLogSyncStatus} TEXT NOT NULL DEFAULT 'localOnly',
        FOREIGN KEY (${DatabaseTables.nutritionLogMealId})
          REFERENCES ${DatabaseTables.meals}(${DatabaseTables.mealId})
          ON DELETE CASCADE
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
    when(() => mockResolver.resolve()).thenAnswer((_) async => 'user-1');

    dataSource = MealLocalDataSourceImpl(
      databaseHelper: databaseHelper,
      currentUserIdResolver: mockResolver,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('MealLocalDataSourceImpl reads', () {
    test('getAllMeals hides pendingDelete rows', () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-1',
          name: 'Visible Meal',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-2',
          name: 'Deleted Meal',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final meals = await dataSource.getAllMeals();

      expect(meals.map((m) => m.id).toList(), <String>['meal-1']);
    });

    test('getMealById returns null for pendingDelete row', () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-1',
          name: 'Deleted Meal',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final meal = await dataSource.getMealById('meal-1');

      expect(meal, isNull);
    });

    test('getMealByName returns null for pendingDelete row', () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-1',
          name: 'Deleted Meal',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final meal = await dataSource.getMealByName('Deleted Meal');

      expect(meal, isNull);
    });

    test('getMealsCount excludes pendingDelete rows', () async {
      await dataSource.insertMeal(
        buildMeal(id: 'meal-1', name: 'Visible Meal'),
      );
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-2',
          name: 'Deleted Meal',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      final count = await dataSource.getMealsCount();

      expect(count, 1);
    });
  });

  group('MealLocalDataSourceImpl mergeRemoteMeals', () {
    test('preserves pending local update over newer remote row', () async {
      final localPendingMeal = buildMeal(
        id: 'meal-1',
        name: 'Local Edited Meal',
        updatedAt: baseDate.add(const Duration(hours: 1)),
        syncMetadata: const EntitySyncMetadata(
          status: SyncStatus.pendingUpdate,
        ),
      );

      final remoteMeal = buildMeal(
        id: 'meal-1',
        name: 'Remote Meal',
        updatedAt: baseDate.add(const Duration(hours: 2)),
        syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
      );

      await dataSource.insertMeal(localPendingMeal);

      await dataSource.mergeRemoteMeals(<MealModel>[remoteMeal]);

      final meals = await dataSource.getAllMeals();
      expect(meals, hasLength(1));
      expect(meals.first.name, 'Local Edited Meal');
      expect(meals.first.syncMetadata.status, SyncStatus.pendingUpdate);
    });

    test(
      'adds remote-only rows while preserving local pending changes',
      () async {
        final localPendingMeal = buildMeal(
          id: 'meal-1',
          name: 'Local Pending Meal',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        );

        final remoteMeal = buildMeal(
          id: 'meal-2',
          name: 'Remote Meal',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        await dataSource.insertMeal(localPendingMeal);

        await dataSource.mergeRemoteMeals(<MealModel>[remoteMeal]);

        final meals = await dataSource.getAllMeals();
        expect(meals.map((m) => m.id).toSet(), <String>{'meal-1', 'meal-2'});
        expect(
          meals.firstWhere((m) => m.id == 'meal-1').syncMetadata.status,
          SyncStatus.pendingUpload,
        );
      },
    );

    test(
      'keeps pendingDelete row hidden even if remote still contains entity',
      () async {
        final localPendingDelete = buildMeal(
          id: 'meal-1',
          name: 'Deleted Locally',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        );

        final remoteMeal = buildMeal(
          id: 'meal-1',
          name: 'Remote Still Exists',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        );

        await dataSource.insertMeal(localPendingDelete);

        await dataSource.mergeRemoteMeals(<MealModel>[remoteMeal]);

        final meals = await dataSource.getAllMeals();
        expect(meals, isEmpty);

        final rawRows = await database.query(DatabaseTables.meals);
        expect(rawRows, hasLength(1));
        expect(
          rawRows.first[DatabaseTables.mealSyncStatus],
          SyncStatus.pendingDelete.name,
        );
      },
    );
  });

  group('MealLocalDataSourceImpl state transitions', () {
    test('markAsPendingDelete updates sync status and error', () async {
      await dataSource.insertMeal(buildMeal(id: 'meal-1', name: 'Meal'));

      await dataSource.markAsPendingDelete(
        'meal-1',
        errorMessage: 'delete queued',
      );

      final rawRows = await database.query(
        DatabaseTables.meals,
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: <Object?>['meal-1'],
      );

      expect(
        rawRows.single[DatabaseTables.mealSyncStatus],
        SyncStatus.pendingDelete.name,
      );
      expect(rawRows.single[DatabaseTables.mealLastSyncError], 'delete queued');
    });

    test('upsertMeal inserts when missing and updates when present', () async {
      final inserted = buildMeal(id: 'meal-1', name: 'Original Meal');

      await dataSource.upsertMeal(inserted);

      final updated = buildMeal(
        id: 'meal-1',
        name: 'Updated Meal',
        updatedAt: baseDate.add(const Duration(hours: 2)),
      );

      await dataSource.upsertMeal(updated);

      final meal = await dataSource.getMealById('meal-1');
      expect(meal, isNotNull);
      expect(meal!.name, 'Updated Meal');
    });

    test('upsertMeal does not revive a pendingDelete row', () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-1',
          name: 'Deleted Meal',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingDelete,
          ),
        ),
      );

      await dataSource.upsertMeal(
        buildMeal(
          id: 'meal-1',
          name: 'Remote Meal',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      final visibleMeal = await dataSource.getMealById('meal-1');
      expect(visibleMeal, isNull);

      final rawRows = await database.query(
        DatabaseTables.meals,
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: <Object?>['meal-1'],
      );
      expect(rawRows, hasLength(1));
      expect(
        rawRows.single[DatabaseTables.mealSyncStatus],
        SyncStatus.pendingDelete.name,
      );
    });
  });

  group('MealLocalDataSourceImpl user isolation', () {
    test('getAllMeals only returns meals owned by the current user', () async {
      await dataSource.insertMeal(
        buildMeal(id: 'meal-1', name: 'My Meal', ownerUserId: 'user-1'),
      );
      await dataSource.insertMeal(
        buildMeal(id: 'meal-2', name: 'Other User Meal', ownerUserId: 'user-2'),
      );

      final meals = await dataSource.getAllMeals();

      expect(meals.map((m) => m.id).toList(), <String>['meal-1']);
    });

    test('getMealById returns null for a meal owned by another user', () async {
      await dataSource.insertMeal(
        buildMeal(id: 'meal-1', name: 'Other Meal', ownerUserId: 'user-2'),
      );

      final meal = await dataSource.getMealById('meal-1');

      expect(meal, isNull);
    });

    test('searchMealsByName excludes other users meals', () async {
      await dataSource.insertMeal(
        buildMeal(id: 'meal-1', name: 'Chicken Bowl', ownerUserId: 'user-1'),
      );
      await dataSource.insertMeal(
        buildMeal(id: 'meal-2', name: 'Chicken Rice', ownerUserId: 'user-2'),
      );

      final results = await dataSource.searchMealsByName('Chicken');

      expect(results.map((m) => m.id).toList(), <String>['meal-1']);
    });

    test('getMealsCount excludes other users meals', () async {
      await dataSource.insertMeal(
        buildMeal(id: 'meal-1', name: 'My Meal', ownerUserId: 'user-1'),
      );
      await dataSource.insertMeal(
        buildMeal(id: 'meal-2', name: 'Other Meal', ownerUserId: 'user-2'),
      );

      final count = await dataSource.getMealsCount();

      expect(count, 1);
    });
  });

  group(
    'MealLocalDataSourceImpl prepareForInitialCloudMigration auth guard',
    () {
      test(
        'throws MissingUserContextException when called in guest mode',
        () async {
          when(() => mockResolver.resolve()).thenThrow(
            const MissingUserContextException(operation: 'session lookup'),
          );

          await expectLater(
            dataSource.prepareForInitialCloudMigration(userId: 'user-1'),
            throwsA(isA<MissingUserContextException>()),
          );
        },
      );
    },
  );

  group('MealLocalDataSourceImpl prepareForInitialCloudMigration', () {
    Future<Map<String, Object?>> rawMeal(String id) async {
      final rows = await database.query(
        DatabaseTables.meals,
        where: '${DatabaseTables.mealId} = ?',
        whereArgs: <Object?>[id],
      );
      expect(rows, hasLength(1));
      return rows.single;
    }

    test('leaves guest localOnly meal untouched', () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-1',
          name: 'Guest Meal',
          ownerUserId: null,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.localOnly,
            lastSyncError: 'offline',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawMeal('meal-1');
      expect(row[DatabaseTables.ownerUserId], isNull);
      expect(row[DatabaseTables.mealSyncStatus], SyncStatus.localOnly.name);
      expect(row[DatabaseTables.mealLastSyncError], 'offline');
    });

    test('leaves guest syncError meal untouched', () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-1',
          name: 'Guest Meal',
          ownerUserId: null,
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.syncError,
            lastSyncError: 'offline',
          ),
        ),
      );

      await dataSource.prepareForInitialCloudMigration(userId: 'user-1');

      final row = await rawMeal('meal-1');
      expect(row[DatabaseTables.ownerUserId], isNull);
      expect(row[DatabaseTables.mealSyncStatus], SyncStatus.syncError.name);
      expect(row[DatabaseTables.mealLastSyncError], 'offline');
    });
  });

  // ---------------------------------------------------------------------------
  // clearMealsForOwner — owner-scoped destructive clear (Phase 2 / Bug 2 fix)
  // ---------------------------------------------------------------------------

  group('MealLocalDataSourceImpl clearMealsForOwner', () {
    test(
      'deletes only the target owner\'s meals — guest and bystander survive',
      () async {
        await dataSource.insertMeal(
          buildMeal(id: 'guest-meal', name: 'Guest Oats', ownerUserId: ''),
        );
        // 'user-1' is the default owner in buildMeal.
        await dataSource.insertMeal(
          buildMeal(id: 'user-a-meal', name: 'User A Chicken'),
        );
        await dataSource.insertMeal(
          buildMeal(
            id: 'user-b-meal',
            name: 'User B Rice',
            ownerUserId: 'user-2',
          ),
        );

        await dataSource.clearMealsForOwner('user-1');

        final remaining = await database.query(DatabaseTables.meals);
        final ids = remaining
            .map((r) => r[DatabaseTables.mealId] as String)
            .toSet();

        expect(ids, equals(<String>{'guest-meal', 'user-b-meal'}));
        expect(ids, isNot(contains('user-a-meal')));
      },
    );

    test(
      'clears the guest bucket (\'\') without touching authenticated owners',
      () async {
        await dataSource.insertMeal(
          buildMeal(id: 'guest-meal', name: 'Guest Oats', ownerUserId: ''),
        );
        await dataSource.insertMeal(
          buildMeal(id: 'user-meal', name: 'User Chicken'),
        );

        await dataSource.clearMealsForOwner('');

        final remaining = await database.query(DatabaseTables.meals);
        final ids = remaining
            .map((r) => r[DatabaseTables.mealId] as String)
            .toSet();

        expect(ids, equals(<String>{'user-meal'}));
        expect(ids, isNot(contains('guest-meal')));
      },
    );

    test('is a no-op when the target owner has no meals', () async {
      await dataSource.insertMeal(buildMeal(id: 'meal-1', name: 'Oats'));

      await dataSource.clearMealsForOwner('nonexistent-user');

      final remaining = await database.query(DatabaseTables.meals);
      expect(remaining, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  // Multi-owner name coexistence (regression for v18 schema migration)
  // ---------------------------------------------------------------------------
  // Before v18 the schema had UNIQUE(name) globally on meals. If two different
  // users each had a meal called "Chicken Rice", a remote sync for the second
  // user would throw UNIQUE constraint failed. After v18 the constraint is
  // UNIQUE(name, COALESCE(owner_user_id, '')) — each user's meals are an
  // independent uniqueness scope.

  group('MealLocalDataSourceImpl multi-owner name coexistence', () {
    test('two users can each have a meal with the same name — '
        'mergeRemoteMeals stores both rows without UNIQUE violation', () async {
      // User-1's meal is already stored locally.
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-u1',
          name: 'Chicken Rice',
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      // Remote pull brings user-2's meal with the same name (different ID,
      // different owner — should not conflict).
      await dataSource.mergeRemoteMeals(<MealModel>[
        buildMeal(
          id: 'meal-u2',
          name: 'Chicken Rice',
          ownerUserId: 'user-2',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      ]);

      final rawRows = await database.query(DatabaseTables.meals);
      expect(rawRows, hasLength(2));
      expect(rawRows.map((r) => r[DatabaseTables.mealId]).toSet(), {
        'meal-u1',
        'meal-u2',
      });
    });
  });

  // ---------------------------------------------------------------------------
  // nutrition_logs preservation (regression for _replaceStoredMeals rewrite)
  // ---------------------------------------------------------------------------
  // The previous _replaceStoredMeals did DELETE FROM meals + INSERT, which
  // cascade-deleted every nutrition_log via the ON DELETE CASCADE FK on
  // nutrition_logs.meal_id — silently wiping the user's food diary on every
  // remote sync. The rewrite uses UPDATE-in-place so nutrition_logs survive.

  group('MealLocalDataSourceImpl nutrition_logs preservation', () {
    test('mergeRemoteMeals does not cascade-delete nutrition_logs '
        'for a meal that is updated in place', () async {
      // Seed a meal and a nutrition log referencing it.
      await dataSource.insertMeal(
        buildMeal(
          id: 'meal-1',
          name: 'Oats',
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.synced,
            serverId: 'server-meal-1',
          ),
        ),
      );
      await database.insert(DatabaseTables.nutritionLogs, {
        DatabaseTables.nutritionLogId: 'log-1',
        DatabaseTables.ownerUserId: 'user-1',
        DatabaseTables.nutritionLogMealId: 'meal-1',
        DatabaseTables.nutritionLogMealName: 'Oats',
        DatabaseTables.nutritionLogCarbs: 30.0,
        DatabaseTables.nutritionLogProtein: 5.0,
        DatabaseTables.nutritionLogFat: 3.0,
        DatabaseTables.nutritionLogCalories: 167.0,
        DatabaseTables.nutritionLogDate: '2026-01-01',
        DatabaseTables.nutritionLogCreatedAt: '2026-01-01T09:00:00.000',
        DatabaseTables.nutritionLogUpdatedAt: '2026-01-01T09:00:00.000',
        DatabaseTables.nutritionLogSyncStatus: 'localOnly',
      });

      // Remote sync brings back the same meal with an updated name.
      await dataSource.mergeRemoteMeals(<MealModel>[
        buildMeal(
          id: 'meal-1',
          name: 'Rolled Oats',
          ownerUserId: 'user-1',
          updatedAt: baseDate.add(const Duration(hours: 1)),
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.synced,
            serverId: 'server-meal-1',
          ),
        ),
      ]);

      // The nutrition log must still exist — it was not cascade-deleted.
      final logs = await database.query(
        DatabaseTables.nutritionLogs,
        where: '${DatabaseTables.nutritionLogMealId} = ?',
        whereArgs: <Object?>['meal-1'],
      );
      expect(logs, hasLength(1));
      expect(logs.first[DatabaseTables.nutritionLogId], 'log-1');
    });
  });

  // ---------------------------------------------------------------------------
  // getPendingSyncMeals — owner-scoped (Model-A Issue 2)
  // ---------------------------------------------------------------------------

  group('MealLocalDataSourceImpl getPendingSyncMeals owner scope', () {
    test('returns current-user pending rows', () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'mine-upload',
          name: 'Chicken Bowl',
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );
      await dataSource.insertMeal(
        buildMeal(
          id: 'mine-update',
          name: 'Oats',
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpdate,
          ),
        ),
      );

      final result = await dataSource.getPendingSyncMeals();
      expect(result.map((m) => m.id).toSet(), <String>{
        'mine-upload',
        'mine-update',
      });
    });

    test("excludes another account's pending rows", () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'mine',
          name: 'Chicken Bowl',
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );
      await dataSource.insertMeal(
        buildMeal(
          id: 'theirs',
          name: 'Rice',
          ownerUserId: 'user-2',
          syncMetadata: const EntitySyncMetadata(
            status: SyncStatus.pendingUpload,
          ),
        ),
      );

      final result = await dataSource.getPendingSyncMeals();
      expect(result.map((m) => m.id).toList(), <String>['mine']);
    });

    test('excludes localOnly and synced rows', () async {
      await dataSource.insertMeal(
        buildMeal(
          id: 'local-only',
          name: 'Yogurt',
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.localOnly),
        ),
      );
      await dataSource.insertMeal(
        buildMeal(
          id: 'synced',
          name: 'Toast',
          ownerUserId: 'user-1',
          syncMetadata: const EntitySyncMetadata(status: SyncStatus.synced),
        ),
      );

      final result = await dataSource.getPendingSyncMeals();
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Incoming-list deduplication (regression for _deduplicateByNameAndOwner)
  // ---------------------------------------------------------------------------

  group('MealLocalDataSourceImpl incoming duplicate deduplication', () {
    test('replaceAllMeals with duplicate (name, owner) in the incoming list '
        'keeps only the most-recently-updated row', () async {
      final older = buildMeal(
        id: 'm-old',
        name: 'Oats',
        ownerUserId: 'user-1',
        updatedAt: baseDate,
      );
      final newer = buildMeal(
        id: 'm-new',
        name: 'Oats',
        ownerUserId: 'user-1',
        updatedAt: baseDate.add(const Duration(hours: 1)),
      );

      await dataSource.replaceAllMeals(<MealModel>[older, newer]);

      final rawRows = await database.query(DatabaseTables.meals);
      expect(rawRows, hasLength(1));
      expect(rawRows.first[DatabaseTables.mealId], 'm-new');
    });
  });
}

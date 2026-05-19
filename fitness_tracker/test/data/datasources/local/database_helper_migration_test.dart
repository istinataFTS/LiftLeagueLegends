// Regression suite for schema migrations v18, v19 and v20.
//
// Three things are verified:
//   1. Fresh-install path (`DatabaseHelper.createSchema`): the per-owner
//      expression index `UNIQUE(name, COALESCE(owner_user_id, ''))` correctly
//      allows a system exercise/meal (owner = NULL) and a user exercise/meal
//      to share the same name, while still rejecting same-owner duplicates.
//      The targets table must NOT be present in a fresh v19 install.
//
//   2. Upgrade path (v17 → v18 DDL): the DDL steps that production runs inside
//      `_migrateExercisesForMultiOwnerUniqueness` and
//      `_migrateMealsForMultiOwnerUniqueness` are replicated here in raw SQL
//      so the migration can be exercised without accessing private methods.
//      After the DDL runs, the per-owner uniqueness contract is enforced and
//      all pre-migration rows are preserved intact.
//
//   3. Upgrade path (v18 → v19 DDL): the targets table is dropped so existing
//      devices no longer carry a schema artefact for the removed feature.
import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  // -------------------------------------------------------------------------
  // Row-builder helpers — provide only the columns required by the schema.
  // -------------------------------------------------------------------------

  Map<String, Object?> exerciseRow({
    required String id,
    required String name,
    String? owner,
    String updatedAt = '2026-01-01T10:00:00.000',
  }) => {
    DatabaseTables.exerciseId: id,
    DatabaseTables.ownerUserId: owner,
    DatabaseTables.exerciseName: name,
    DatabaseTables.exerciseMuscleGroups: '["chest"]',
    DatabaseTables.exerciseCreatedAt: '2026-01-01T09:00:00.000',
    DatabaseTables.exerciseUpdatedAt: updatedAt,
    DatabaseTables.exerciseSyncStatus: 'localOnly',
  };

  Map<String, Object?> mealRow({
    required String id,
    required String name,
    String? owner,
  }) => {
    DatabaseTables.mealId: id,
    DatabaseTables.ownerUserId: owner,
    DatabaseTables.mealName: name,
    DatabaseTables.mealServingSize: 100.0,
    DatabaseTables.mealCarbsPer100g: 30.0,
    DatabaseTables.mealProteinPer100g: 20.0,
    DatabaseTables.mealFatPer100g: 10.0,
    DatabaseTables.mealCaloriesPer100g: 290.0,
    DatabaseTables.mealCreatedAt: '2026-01-01T09:00:00.000',
    DatabaseTables.mealUpdatedAt: '2026-01-01T10:00:00.000',
    DatabaseTables.mealSyncStatus: 'localOnly',
  };

  // -------------------------------------------------------------------------
  // v17-schema helpers (old global UNIQUE(name) on each table)
  // -------------------------------------------------------------------------

  Future<void> createV17ExerciseSchema(Database db) => db.execute('''
    CREATE TABLE ${DatabaseTables.exercises} (
      ${DatabaseTables.exerciseId} TEXT PRIMARY KEY,
      ${DatabaseTables.ownerUserId} TEXT,
      ${DatabaseTables.exerciseName} TEXT NOT NULL UNIQUE,
      ${DatabaseTables.exerciseMuscleGroups} TEXT NOT NULL,
      ${DatabaseTables.exerciseCreatedAt} TEXT NOT NULL,
      ${DatabaseTables.exerciseUpdatedAt} TEXT NOT NULL,
      ${DatabaseTables.exerciseServerId} TEXT,
      ${DatabaseTables.exerciseSyncStatus} TEXT NOT NULL DEFAULT 'localOnly',
      ${DatabaseTables.exerciseLastSyncedAt} TEXT,
      ${DatabaseTables.exerciseLastSyncError} TEXT
    )
  ''');

  Future<void> createV17MealSchema(Database db) => db.execute('''
    CREATE TABLE ${DatabaseTables.meals} (
      ${DatabaseTables.mealId} TEXT PRIMARY KEY,
      ${DatabaseTables.ownerUserId} TEXT,
      ${DatabaseTables.mealName} TEXT NOT NULL UNIQUE,
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

  // -------------------------------------------------------------------------
  // v18 migration DDL helpers
  //
  // These replicate the SQL inside the private migration methods so the
  // upgrade path can be exercised end-to-end without touching private APIs.
  // -------------------------------------------------------------------------

  Future<void> applyExerciseMigrationV18(Database db) async {
    await db.execute('''
      CREATE TABLE exercises_v18 (
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
    await db.execute(
      'INSERT INTO exercises_v18 SELECT * FROM ${DatabaseTables.exercises}',
    );
    await db.execute('DROP TABLE ${DatabaseTables.exercises}');
    await db.execute(
      'ALTER TABLE exercises_v18 RENAME TO ${DatabaseTables.exercises}',
    );
    await db.execute('''
      CREATE UNIQUE INDEX idx_exercises_name_owner
      ON ${DatabaseTables.exercises}(
        ${DatabaseTables.exerciseName},
        COALESCE(${DatabaseTables.ownerUserId}, '')
      )
    ''');
  }

  Future<void> applyMealMigrationV18(Database db) async {
    await db.execute('''
      CREATE TABLE meals_v18 (
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
    await db.execute(
      'INSERT INTO meals_v18 SELECT * FROM ${DatabaseTables.meals}',
    );
    await db.execute('DROP TABLE ${DatabaseTables.meals}');
    await db.execute('ALTER TABLE meals_v18 RENAME TO ${DatabaseTables.meals}');
    await db.execute('''
      CREATE UNIQUE INDEX idx_meals_name_owner
      ON ${DatabaseTables.meals}(
        ${DatabaseTables.mealName},
        COALESCE(${DatabaseTables.ownerUserId}, '')
      )
    ''');
  }

  // =========================================================================
  // 1. Fresh-install schema (DatabaseHelper.createSchema)
  // =========================================================================

  group('DatabaseHelper.createSchema — per-owner uniqueness (fresh v19 install)', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async => DatabaseHelper.createSchema(db),
        ),
      );
    });

    tearDown(() async => db.close());

    // --- exercises ---

    test(
      'exercises: system (owner=null) and user-owned exercise with the same '
      'name coexist — different owner buckets, no UNIQUE violation',
      () async {
        await db.insert(
          DatabaseTables.exercises,
          exerciseRow(id: 'sys', name: 'Barbell Row', owner: null),
        );
        // Must not throw: null → '' vs 'user-1' are different COALESCE buckets.
        await db.insert(
          DatabaseTables.exercises,
          exerciseRow(id: 'usr', name: 'Barbell Row', owner: 'user-1'),
        );

        final rows = await db.query(DatabaseTables.exercises);
        expect(rows, hasLength(2));
        expect(rows.map((r) => r[DatabaseTables.exerciseId]).toSet(), {
          'sys',
          'usr',
        });
      },
    );

    test(
      'exercises: two user exercises with the same name and owner violate UNIQUE',
      () async {
        await db.insert(
          DatabaseTables.exercises,
          exerciseRow(id: 'e1', name: 'Squat', owner: 'user-1'),
        );

        await expectLater(
          db.insert(
            DatabaseTables.exercises,
            exerciseRow(id: 'e2', name: 'Squat', owner: 'user-1'),
          ),
          throwsException,
        );
      },
    );

    test(
      'exercises: two system exercises (owner=null) with the same name violate UNIQUE',
      () async {
        await db.insert(
          DatabaseTables.exercises,
          exerciseRow(id: 'e1', name: 'Squat', owner: null),
        );

        await expectLater(
          db.insert(
            DatabaseTables.exercises,
            exerciseRow(id: 'e2', name: 'Squat', owner: null),
          ),
          throwsException,
        );
      },
    );

    // --- meals ---

    test(
      'meals: system (owner=null) and user-owned meal with the same name coexist',
      () async {
        await db.insert(
          DatabaseTables.meals,
          mealRow(id: 'sys', name: 'Oats', owner: null),
        );
        await db.insert(
          DatabaseTables.meals,
          mealRow(id: 'usr', name: 'Oats', owner: 'user-1'),
        );

        final rows = await db.query(DatabaseTables.meals);
        expect(rows, hasLength(2));
        expect(rows.map((r) => r[DatabaseTables.mealId]).toSet(), {
          'sys',
          'usr',
        });
      },
    );

    test(
      'meals: two user meals with the same name and owner violate UNIQUE',
      () async {
        await db.insert(
          DatabaseTables.meals,
          mealRow(id: 'm1', name: 'Oats', owner: 'user-1'),
        );

        await expectLater(
          db.insert(
            DatabaseTables.meals,
            mealRow(id: 'm2', name: 'Oats', owner: 'user-1'),
          ),
          throwsException,
        );
      },
    );

    test('targets table is absent from fresh v19 schema', () async {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='targets'",
      );
      expect(tables, isEmpty);
    });
  });

  // =========================================================================
  // 2. v17 → v18 upgrade path
  // =========================================================================

  group('v17 to v18 migration DDL', () {
    late Database db;

    setUp(() async {
      // Open a raw in-memory DB with no schema — each test builds what it needs.
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    });

    tearDown(() async => db.close());

    // --- exercises ---

    group('exercises', () {
      test(
        'pre-migration rows are preserved with original IDs and field values',
        () async {
          await createV17ExerciseSchema(db);
          await db.insert(
            DatabaseTables.exercises,
            exerciseRow(id: 'seeded-1', name: 'Barbell Row', owner: null),
          );

          await applyExerciseMigrationV18(db);

          final rows = await db.query(DatabaseTables.exercises);
          expect(rows, hasLength(1));
          expect(rows.first[DatabaseTables.exerciseId], 'seeded-1');
          expect(rows.first[DatabaseTables.exerciseName], 'Barbell Row');
          expect(rows.first[DatabaseTables.ownerUserId], isNull);
        },
      );

      test(
        'after migration a user exercise with the same name as a system '
        'exercise can be inserted — previously blocked by UNIQUE(name)',
        () async {
          await createV17ExerciseSchema(db);
          await db.insert(
            DatabaseTables.exercises,
            exerciseRow(id: 'sys', name: 'Barbell Row', owner: null),
          );

          await applyExerciseMigrationV18(db);

          // This insert would have thrown UNIQUE constraint failed on v17.
          await db.insert(
            DatabaseTables.exercises,
            exerciseRow(id: 'usr', name: 'Barbell Row', owner: 'user-1'),
          );

          final rows = await db.query(DatabaseTables.exercises);
          expect(rows.map((r) => r[DatabaseTables.exerciseId]).toSet(), {
            'sys',
            'usr',
          });
        },
      );

      test(
        'after migration same-name same-owner exercises still violate UNIQUE',
        () async {
          await createV17ExerciseSchema(db);
          await db.insert(
            DatabaseTables.exercises,
            exerciseRow(id: 'e1', name: 'Squat', owner: 'user-1'),
          );

          await applyExerciseMigrationV18(db);

          await expectLater(
            db.insert(
              DatabaseTables.exercises,
              exerciseRow(id: 'e2', name: 'Squat', owner: 'user-1'),
            ),
            throwsException,
          );
        },
      );
    });

    // --- meals ---

    group('meals', () {
      test(
        'pre-migration rows are preserved with original IDs and field values',
        () async {
          await createV17MealSchema(db);
          await db.insert(
            DatabaseTables.meals,
            mealRow(id: 'seeded-1', name: 'Oats', owner: null),
          );

          await applyMealMigrationV18(db);

          final rows = await db.query(DatabaseTables.meals);
          expect(rows, hasLength(1));
          expect(rows.first[DatabaseTables.mealId], 'seeded-1');
          expect(rows.first[DatabaseTables.mealName], 'Oats');
          expect(rows.first[DatabaseTables.ownerUserId], isNull);
        },
      );

      test('after migration a user meal with the same name as a system meal '
          'can be inserted — previously blocked by UNIQUE(name)', () async {
        await createV17MealSchema(db);
        await db.insert(
          DatabaseTables.meals,
          mealRow(id: 'sys', name: 'Oats', owner: null),
        );

        await applyMealMigrationV18(db);

        await db.insert(
          DatabaseTables.meals,
          mealRow(id: 'usr', name: 'Oats', owner: 'user-1'),
        );

        final rows = await db.query(DatabaseTables.meals);
        expect(rows.map((r) => r[DatabaseTables.mealId]).toSet(), {
          'sys',
          'usr',
        });
      });

      test(
        'after migration same-name same-owner meals still violate UNIQUE',
        () async {
          await createV17MealSchema(db);
          await db.insert(
            DatabaseTables.meals,
            mealRow(id: 'm1', name: 'Oats', owner: 'user-1'),
          );

          await applyMealMigrationV18(db);

          await expectLater(
            db.insert(
              DatabaseTables.meals,
              mealRow(id: 'm2', name: 'Oats', owner: 'user-1'),
            ),
            throwsException,
          );
        },
      );
    });
  });

  // =========================================================================
  // 3. v18 → v19 upgrade path — targets table dropped
  // =========================================================================

  group('v18 to v19 migration DDL — targets table removed', () {
    late Database db;

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    });

    tearDown(() async => db.close());

    Future<void> createV18TargetsTable(Database db) => db.execute('''
      CREATE TABLE targets (
        id TEXT PRIMARY KEY,
        owner_user_id TEXT,
        type TEXT NOT NULL,
        category_key TEXT NOT NULL,
        target_value REAL NOT NULL,
        unit TEXT NOT NULL,
        period TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        server_id TEXT,
        sync_status TEXT NOT NULL DEFAULT 'localOnly',
        last_synced_at TEXT,
        last_sync_error TEXT,
        UNIQUE(type, category_key, period)
      )
    ''');

    test('targets table is dropped when it exists on a v18 device', () async {
      await createV18TargetsTable(db);
      await db.insert('targets', {
        'id': 'target-1',
        'owner_user_id': null,
        'type': 'macro',
        'category_key': 'protein',
        'target_value': 180.0,
        'unit': 'grams',
        'period': 'daily',
        'created_at': '2026-01-01T09:00:00.000',
        'updated_at': '2026-01-01T09:00:00.000',
        'sync_status': 'localOnly',
      });

      // Verify the table exists before migration.
      var tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='targets'",
      );
      expect(tables, hasLength(1));

      // Apply v19 migration.
      await db.execute('DROP TABLE IF EXISTS targets');

      // Verify the table no longer exists.
      tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='targets'",
      );
      expect(tables, isEmpty);
    });

    test(
      'DROP TABLE IF EXISTS is a no-op when targets table is absent',
      () async {
        // Don't create the targets table — simulates a device that somehow
        // skipped older versions.
        await expectLater(
          db.execute('DROP TABLE IF EXISTS targets'),
          completes,
        );

        final tables = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='targets'",
        );
        expect(tables, isEmpty);
      },
    );
  });

  // =========================================================================
  // 4. v19 → v20 upgrade path — NULL catalog owners collapse to guest ''
  //
  // Mirrors production `_collapseNullCatalogOwnersToGuestBucket`: a pure
  // in-place UPDATE, no deletes, no child repointing. Asserts NULL→'',
  // cross-bucket rows preserved, child rows untouched, and idempotency.
  // =========================================================================

  group(
    'v19 to v20 migration DDL — NULL owners collapse to guest sentinel',
    () {
      late Database db;

      // Exact SQL run by `_collapseNullCatalogOwnersToGuestBucket`.
      Future<List<int>> runV20Collapse(Database database) async {
        final exercises = await database.update(
          DatabaseTables.exercises,
          <String, Object?>{DatabaseTables.ownerUserId: ''},
          where: '${DatabaseTables.ownerUserId} IS NULL',
        );
        final meals = await database.update(
          DatabaseTables.meals,
          <String, Object?>{DatabaseTables.ownerUserId: ''},
          where: '${DatabaseTables.ownerUserId} IS NULL',
        );
        return <int>[exercises, meals];
      }

      setUp(() async {
        db = await databaseFactoryFfi.openDatabase(
          inMemoryDatabasePath,
          options: OpenDatabaseOptions(
            version: 1,
            onCreate: (db, _) async => DatabaseHelper.createSchema(db),
          ),
        );

        // Legacy seeded (NULL owner) + cross-bucket user copy (same name).
        await db.insert(
          DatabaseTables.exercises,
          exerciseRow(id: 'sys-ex', name: 'Bench Press', owner: null),
        );
        await db.insert(
          DatabaseTables.exercises,
          exerciseRow(id: 'usr-ex', name: 'Bench Press', owner: 'user-1'),
        );
        // Already on the guest sentinel — must stay untouched.
        await db.insert(
          DatabaseTables.exercises,
          exerciseRow(id: 'guest-ex', name: 'Plank', owner: ''),
        );

        await db.insert(
          DatabaseTables.meals,
          mealRow(id: 'sys-meal', name: 'Oats', owner: null),
        );
        await db.insert(
          DatabaseTables.meals,
          mealRow(id: 'usr-meal', name: 'Oats', owner: 'user-1'),
        );

        // Child rows pointing at the NULL-owner catalog entries.
        await db.insert(DatabaseTables.workoutSets, <String, Object?>{
          DatabaseTables.setId: 'set-1',
          DatabaseTables.setExerciseId: 'sys-ex',
          DatabaseTables.setReps: 10,
          DatabaseTables.setWeight: 50.0,
          DatabaseTables.setDate: '2026-01-02T10:00:00.000',
          DatabaseTables.setCreatedAt: '2026-01-02T10:00:00.000',
          DatabaseTables.setUpdatedAt: '2026-01-02T10:00:00.000',
        });
        await db.insert(DatabaseTables.exerciseMuscleFactors, <String, Object?>{
          DatabaseTables.factorId: 'f-1',
          DatabaseTables.factorExerciseId: 'sys-ex',
          DatabaseTables.factorMuscleGroup: 'chest',
          DatabaseTables.factorValue: 1.0,
        });
        await db.insert(DatabaseTables.nutritionLogs, <String, Object?>{
          DatabaseTables.nutritionLogId: 'log-1',
          DatabaseTables.nutritionLogMealId: 'sys-meal',
          DatabaseTables.nutritionLogMealName: 'Oats',
          DatabaseTables.nutritionLogCarbs: 30.0,
          DatabaseTables.nutritionLogProtein: 20.0,
          DatabaseTables.nutritionLogFat: 10.0,
          DatabaseTables.nutritionLogCalories: 290.0,
          DatabaseTables.nutritionLogDate: '2026-01-02T10:00:00.000',
          DatabaseTables.nutritionLogCreatedAt: '2026-01-02T10:00:00.000',
          DatabaseTables.nutritionLogUpdatedAt: '2026-01-02T10:00:00.000',
        });
      });

      tearDown(() async => db.close());

      test(
        'NULL owners become the guest sentinel; other owners untouched',
        () async {
          final affected = await runV20Collapse(db);
          expect(affected, <int>[1, 1]); // one exercise, one meal updated

          Future<String?> ownerOf(String table, String idCol, String id) async {
            final rows = await db.query(
              table,
              columns: <String>[DatabaseTables.ownerUserId],
              where: '$idCol = ?',
              whereArgs: <Object?>[id],
            );
            return rows.single[DatabaseTables.ownerUserId] as String?;
          }

          expect(
            await ownerOf(
              DatabaseTables.exercises,
              DatabaseTables.exerciseId,
              'sys-ex',
            ),
            '',
          );
          expect(
            await ownerOf(
              DatabaseTables.exercises,
              DatabaseTables.exerciseId,
              'usr-ex',
            ),
            'user-1',
          );
          expect(
            await ownerOf(
              DatabaseTables.exercises,
              DatabaseTables.exerciseId,
              'guest-ex',
            ),
            '',
          );
          expect(
            await ownerOf(
              DatabaseTables.meals,
              DatabaseTables.mealId,
              'sys-meal',
            ),
            '',
          );
          expect(
            await ownerOf(
              DatabaseTables.meals,
              DatabaseTables.mealId,
              'usr-meal',
            ),
            'user-1',
          );
        },
      );

      test(
        'cross-bucket rows are preserved — no merge, no data loss',
        () async {
          await runV20Collapse(db);

          final exercises = await db.query(DatabaseTables.exercises);
          final meals = await db.query(DatabaseTables.meals);
          // sys-ex ('') and usr-ex ('user-1') both survive (distinct accounts).
          expect(exercises, hasLength(3));
          expect(meals, hasLength(2));
        },
      );

      test('child rows are untouched (no delete, no repoint)', () async {
        await runV20Collapse(db);

        final sets = await db.query(DatabaseTables.workoutSets);
        expect(sets, hasLength(1));
        expect(sets.single[DatabaseTables.setExerciseId], 'sys-ex');

        final factors = await db.query(DatabaseTables.exerciseMuscleFactors);
        expect(factors, hasLength(1));
        expect(factors.single[DatabaseTables.factorExerciseId], 'sys-ex');

        final logs = await db.query(DatabaseTables.nutritionLogs);
        expect(logs, hasLength(1));
        expect(logs.single[DatabaseTables.nutritionLogMealId], 'sys-meal');
      });

      test('idempotent — a second pass changes nothing', () async {
        await runV20Collapse(db);
        final secondPass = await runV20Collapse(db);
        expect(secondPass, <int>[0, 0]);

        final nullExercises = await db.query(
          DatabaseTables.exercises,
          where: '${DatabaseTables.ownerUserId} IS NULL',
        );
        final nullMeals = await db.query(
          DatabaseTables.meals,
          where: '${DatabaseTables.ownerUserId} IS NULL',
        );
        expect(nullExercises, isEmpty);
        expect(nullMeals, isEmpty);
      });
    },
  );
}

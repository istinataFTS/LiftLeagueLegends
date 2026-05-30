import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../../config/env_config.dart';
import '../../../core/constants/database_tables.dart';
import '../../../core/constants/default_exercises_data.dart';
import '../../../core/constants/default_meals_data.dart';
import '../../../core/constants/muscle_stimulus_constants.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/utils/deterministic_catalog_id.dart';

class UnsupportedDatabaseVersionException implements Exception {
  const UnsupportedDatabaseVersionException({
    required this.oldVersion,
    required this.newVersion,
    required this.minimumSupportedVersion,
  });

  final int oldVersion;
  final int newVersion;
  final int minimumSupportedVersion;

  @override
  String toString() {
    return 'UnsupportedDatabaseVersionException('
        'oldVersion: $oldVersion, '
        'newVersion: $newVersion, '
        'minimumSupportedVersion: $minimumSupportedVersion'
        ')';
  }
}

class DatabaseHelper {
  DatabaseHelper();

  static Database? _database;

  static const int _minimumSupportedUpgradeVersion = 2;

  Future<Database> get database async {
    if (kIsWeb) {
      throw UnsupportedError('Database is not supported on web platform');
    }

    if (_database != null) return _database!;

    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw UnsupportedError('Database is not supported on web platform');
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, EnvConfig.databaseName);

    return openDatabase(
      path,
      version: EnvConfig.databaseVersion,
      onCreate: (db, version) => createSchema(db),
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates the full application schema on [db].
  ///
  /// Exposed as a static entry point so integration tests can bootstrap an
  /// in-memory `sqflite_common_ffi` database with the identical schema the
  /// production app runs against — duplicating ~900 lines of DDL in tests
  /// would otherwise drift the test fixture from production on every
  /// schema change.
  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE ${DatabaseTables.workoutSets} (
        ${DatabaseTables.setId} TEXT PRIMARY KEY,
        ${DatabaseTables.ownerUserId} TEXT,
        ${DatabaseTables.setExerciseId} TEXT NOT NULL,
        ${DatabaseTables.setReps} INTEGER NOT NULL,
        ${DatabaseTables.setWeight} REAL NOT NULL,
        ${DatabaseTables.setIntensity} INTEGER NOT NULL DEFAULT ${MuscleStimulus.defaultIntensity},
        ${DatabaseTables.setDate} TEXT NOT NULL,
        ${DatabaseTables.setCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.setUpdatedAt} TEXT NOT NULL,
        ${DatabaseTables.setServerId} TEXT,
        ${DatabaseTables.setSyncStatus} TEXT NOT NULL DEFAULT 'localOnly',
        ${DatabaseTables.setLastSyncedAt} TEXT,
        ${DatabaseTables.setLastSyncError} TEXT
      )
    ''');

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
        ${DatabaseTables.nutritionLogServerId} TEXT,
        ${DatabaseTables.nutritionLogSyncStatus} TEXT NOT NULL DEFAULT 'localOnly',
        ${DatabaseTables.nutritionLogLastSyncedAt} TEXT,
        ${DatabaseTables.nutritionLogLastSyncError} TEXT,
        FOREIGN KEY (${DatabaseTables.nutritionLogMealId})
          REFERENCES ${DatabaseTables.meals}(${DatabaseTables.mealId})
          ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.exerciseMuscleFactors} (
        ${DatabaseTables.factorId} TEXT PRIMARY KEY,
        ${DatabaseTables.factorExerciseId} TEXT NOT NULL,
        ${DatabaseTables.factorMuscleGroup} TEXT NOT NULL,
        ${DatabaseTables.factorValue} REAL NOT NULL,
        FOREIGN KEY (${DatabaseTables.factorExerciseId})
          REFERENCES ${DatabaseTables.exercises}(${DatabaseTables.exerciseId})
          ON DELETE CASCADE,
        UNIQUE(${DatabaseTables.factorExerciseId}, ${DatabaseTables.factorMuscleGroup})
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.muscleStimulus} (
        ${DatabaseTables.stimulusId} TEXT PRIMARY KEY,
        ${DatabaseTables.ownerUserId} TEXT NOT NULL DEFAULT '',
        ${DatabaseTables.stimulusMuscleGroup} TEXT NOT NULL,
        ${DatabaseTables.stimulusDate} TEXT NOT NULL,
        ${DatabaseTables.stimulusDailyStimulus} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseTables.stimulusRollingWeeklyLoad} REAL NOT NULL DEFAULT 0.0,
        ${DatabaseTables.stimulusLastSetTimestamp} INTEGER,
        ${DatabaseTables.stimulusLastSetStimulus} REAL,
        ${DatabaseTables.stimulusCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.stimulusUpdatedAt} TEXT NOT NULL,
        UNIQUE(${DatabaseTables.ownerUserId}, ${DatabaseTables.stimulusMuscleGroup}, ${DatabaseTables.stimulusDate})
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.pendingSyncDeletes} (
        ${DatabaseTables.pendingDeleteId} TEXT PRIMARY KEY,
        ${DatabaseTables.pendingDeleteEntityType} TEXT NOT NULL,
        ${DatabaseTables.pendingDeleteLocalEntityId} TEXT NOT NULL,
        ${DatabaseTables.pendingDeleteServerEntityId} TEXT,
        ${DatabaseTables.pendingDeleteCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.pendingDeleteLastAttemptAt} TEXT,
        ${DatabaseTables.pendingDeleteErrorMessage} TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DatabaseTables.appMetadata} (
        ${DatabaseTables.metadataKey} TEXT PRIMARY KEY,
        ${DatabaseTables.metadataValue} TEXT,
        ${DatabaseTables.metadataUpdatedAt} TEXT NOT NULL
      )
    ''');

    await _createIndexes(db);
  }

  /// Triggers the full `_onUpgrade` cascade against [db] from [oldVersion] to
  /// [newVersion]. Exposed exclusively for the migration-replay test
  /// (`test/data/datasources/local/database_helper_migration_replay_test.dart`)
  /// — production paths reach `_onUpgrade` through `openDatabase(...)`'s
  /// `onUpgrade:` parameter and never call this method.
  @visibleForTesting
  static Future<void> runOnUpgradeForTesting(
    Database db,
    int oldVersion,
    int newVersion,
  ) => DatabaseHelper()._onUpgrade(db, oldVersion, newVersion);

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _ensureSupportedUpgradePath(oldVersion, newVersion);

    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.exercises} (
          ${DatabaseTables.exerciseId} TEXT PRIMARY KEY,
          ${DatabaseTables.exerciseName} TEXT NOT NULL UNIQUE,
          ${DatabaseTables.exerciseMuscleGroups} TEXT NOT NULL,
          ${DatabaseTables.exerciseCreatedAt} TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_exercises_name
        ON ${DatabaseTables.exercises}(${DatabaseTables.exerciseName})
      ''');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.meals} (
          ${DatabaseTables.mealId} TEXT PRIMARY KEY,
          ${DatabaseTables.mealName} TEXT NOT NULL UNIQUE,
          ${DatabaseTables.mealServingSize} REAL NOT NULL DEFAULT 100.0,
          ${DatabaseTables.mealCarbsPer100g} REAL NOT NULL,
          ${DatabaseTables.mealProteinPer100g} REAL NOT NULL,
          ${DatabaseTables.mealFatPer100g} REAL NOT NULL,
          ${DatabaseTables.mealCaloriesPer100g} REAL NOT NULL,
          ${DatabaseTables.mealCreatedAt} TEXT NOT NULL
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ${DatabaseTables.nutritionLogs} (
          ${DatabaseTables.nutritionLogId} TEXT PRIMARY KEY,
          ${DatabaseTables.nutritionLogMealId} TEXT,
          ${DatabaseTables.nutritionLogMealName} TEXT NOT NULL DEFAULT '',
          ${DatabaseTables.nutritionLogGrams} REAL,
          ${DatabaseTables.nutritionLogCarbs} REAL NOT NULL,
          ${DatabaseTables.nutritionLogProtein} REAL NOT NULL,
          ${DatabaseTables.nutritionLogFat} REAL NOT NULL,
          ${DatabaseTables.nutritionLogCalories} REAL NOT NULL,
          ${DatabaseTables.nutritionLogDate} TEXT NOT NULL,
          ${DatabaseTables.nutritionLogCreatedAt} TEXT NOT NULL,
          FOREIGN KEY (${DatabaseTables.nutritionLogMealId})
            REFERENCES ${DatabaseTables.meals}(${DatabaseTables.mealId})
            ON DELETE CASCADE
        )
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_meals_name
        ON ${DatabaseTables.meals}(${DatabaseTables.mealName})
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_nutrition_logs_meal_id
        ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogMealId})
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_nutrition_logs_date
        ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogDate})
      ''');

      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_nutrition_logs_created_at
        ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogCreatedAt})
      ''');
    }

    if (oldVersion < 5) {
      await db.execute('''
        ALTER TABLE ${DatabaseTables.workoutSets}
        ADD COLUMN ${DatabaseTables.setIntensity} INTEGER NOT NULL
        DEFAULT ${MuscleStimulus.defaultIntensity}
      ''');

      await db.execute('''
        CREATE TABLE ${DatabaseTables.exerciseMuscleFactors} (
          ${DatabaseTables.factorId} TEXT PRIMARY KEY,
          ${DatabaseTables.factorExerciseId} TEXT NOT NULL,
          ${DatabaseTables.factorMuscleGroup} TEXT NOT NULL,
          ${DatabaseTables.factorValue} REAL NOT NULL,
          FOREIGN KEY (${DatabaseTables.factorExerciseId})
            REFERENCES ${DatabaseTables.exercises}(${DatabaseTables.exerciseId})
            ON DELETE CASCADE,
          UNIQUE(${DatabaseTables.factorExerciseId}, ${DatabaseTables.factorMuscleGroup})
        )
      ''');

      await db.execute('''
        CREATE TABLE ${DatabaseTables.muscleStimulus} (
          ${DatabaseTables.stimulusId} TEXT PRIMARY KEY,
          ${DatabaseTables.stimulusMuscleGroup} TEXT NOT NULL,
          ${DatabaseTables.stimulusDate} TEXT NOT NULL,
          ${DatabaseTables.stimulusDailyStimulus} REAL NOT NULL DEFAULT 0.0,
          ${DatabaseTables.stimulusRollingWeeklyLoad} REAL NOT NULL DEFAULT 0.0,
          ${DatabaseTables.stimulusLastSetTimestamp} INTEGER,
          ${DatabaseTables.stimulusLastSetStimulus} REAL,
          ${DatabaseTables.stimulusCreatedAt} TEXT NOT NULL,
          ${DatabaseTables.stimulusUpdatedAt} TEXT NOT NULL,
          UNIQUE(${DatabaseTables.stimulusMuscleGroup}, ${DatabaseTables.stimulusDate})
        )
      ''');

      await db.execute('''
        CREATE INDEX idx_exercise_muscle_factors_exercise_id
        ON ${DatabaseTables.exerciseMuscleFactors}(${DatabaseTables.factorExerciseId})
      ''');

      await db.execute('''
        CREATE INDEX idx_exercise_muscle_factors_muscle_group
        ON ${DatabaseTables.exerciseMuscleFactors}(${DatabaseTables.factorMuscleGroup})
      ''');

      await db.execute('''
        CREATE INDEX idx_muscle_stimulus_muscle_group
        ON ${DatabaseTables.muscleStimulus}(${DatabaseTables.stimulusMuscleGroup})
      ''');

      await db.execute('''
        CREATE INDEX idx_muscle_stimulus_date
        ON ${DatabaseTables.muscleStimulus}(${DatabaseTables.stimulusDate})
      ''');

      await db.execute('''
        CREATE INDEX idx_muscle_stimulus_muscle_date
        ON ${DatabaseTables.muscleStimulus}(
          ${DatabaseTables.stimulusMuscleGroup},
          ${DatabaseTables.stimulusDate}
        )
      ''');
    }

    if (oldVersion < 6) {
      // The v4 CREATE TABLE for nutrition_logs already includes meal_name
      // (it was retrofitted to keep fresh installs out of the v6 ADD COLUMN
      // path). A chained v2 -> v6+ replay therefore hits "duplicate column
      // name" on this ALTER without the existence guard. The migration is
      // a no-op for fresh installs and existing v6+ users alike.
      await _addColumnIfMissing(
        db,
        tableName: DatabaseTables.nutritionLogs,
        columnName: DatabaseTables.nutritionLogMealName,
        columnSpec: "TEXT NOT NULL DEFAULT ''",
      );
    }

    if (oldVersion < 7) {
      // Same retrofit-vs-ALTER duplication as v6 above: the v4 meals CREATE
      // already declares serving_size_grams.
      await _addColumnIfMissing(
        db,
        tableName: DatabaseTables.meals,
        columnName: DatabaseTables.mealServingSize,
        columnSpec: 'REAL NOT NULL DEFAULT 100.0',
      );
    }

    if (oldVersion < 8) {
      await _migrateTargetsToTypedGoals(db);
    }

    if (oldVersion < 9) {
      await _migrateWorkoutSetsForRemoteReadiness(db);
    }

    if (oldVersion < 10) {
      await _createPendingSyncDeletesTable(db);
    }

    if (oldVersion < 11) {
      await _migrateTargetsForRemoteReadiness(db);
    }

    if (oldVersion < 12) {
      await _migrateExercisesForRemoteReadiness(db);
    }

    if (oldVersion < 13) {
      await _migrateMealsAndNutritionLogsForRemoteReadiness(db);
    }

    if (oldVersion < 14) {
      await _createAppMetadataTable(db);
    }

    if (oldVersion < 15) {
      await _migrateOwnershipColumns(db);
    }

    if (oldVersion < 16) {
      // Clear stale muscle factor and stimulus data so the seeder re-runs
      // with the corrected exercise name mappings from exercise_muscle_factors_data.dart.
      // muscle_stimulus will be rebuilt from workout history by AppDataSeeder after reseeding.
      await db.delete(DatabaseTables.exerciseMuscleFactors);
      await db.delete(DatabaseTables.muscleStimulus);
    }

    if (oldVersion < 17) {
      // Add owner_user_id to muscle_stimulus and update the unique constraint
      // from (muscle_group, date) to (owner_user_id, muscle_group, date).
      // SQLite does not support DROP CONSTRAINT, so the table must be recreated.
      await db.execute('''
        CREATE TABLE muscle_stimulus_v17 (
          ${DatabaseTables.stimulusId} TEXT PRIMARY KEY,
          ${DatabaseTables.ownerUserId} TEXT NOT NULL DEFAULT '',
          ${DatabaseTables.stimulusMuscleGroup} TEXT NOT NULL,
          ${DatabaseTables.stimulusDate} TEXT NOT NULL,
          ${DatabaseTables.stimulusDailyStimulus} REAL NOT NULL DEFAULT 0.0,
          ${DatabaseTables.stimulusRollingWeeklyLoad} REAL NOT NULL DEFAULT 0.0,
          ${DatabaseTables.stimulusLastSetTimestamp} INTEGER,
          ${DatabaseTables.stimulusLastSetStimulus} REAL,
          ${DatabaseTables.stimulusCreatedAt} TEXT NOT NULL,
          ${DatabaseTables.stimulusUpdatedAt} TEXT NOT NULL,
          UNIQUE(${DatabaseTables.ownerUserId}, ${DatabaseTables.stimulusMuscleGroup}, ${DatabaseTables.stimulusDate})
        )
      ''');

      // Copy existing rows; pre-auth records receive owner_user_id = ''
      // so they remain accessible to the guest/unauthenticated state.
      await db.execute('''
        INSERT INTO muscle_stimulus_v17 (
          ${DatabaseTables.stimulusId},
          ${DatabaseTables.ownerUserId},
          ${DatabaseTables.stimulusMuscleGroup},
          ${DatabaseTables.stimulusDate},
          ${DatabaseTables.stimulusDailyStimulus},
          ${DatabaseTables.stimulusRollingWeeklyLoad},
          ${DatabaseTables.stimulusLastSetTimestamp},
          ${DatabaseTables.stimulusLastSetStimulus},
          ${DatabaseTables.stimulusCreatedAt},
          ${DatabaseTables.stimulusUpdatedAt}
        )
        SELECT
          ${DatabaseTables.stimulusId},
          '',
          ${DatabaseTables.stimulusMuscleGroup},
          ${DatabaseTables.stimulusDate},
          ${DatabaseTables.stimulusDailyStimulus},
          ${DatabaseTables.stimulusRollingWeeklyLoad},
          ${DatabaseTables.stimulusLastSetTimestamp},
          ${DatabaseTables.stimulusLastSetStimulus},
          ${DatabaseTables.stimulusCreatedAt},
          ${DatabaseTables.stimulusUpdatedAt}
        FROM ${DatabaseTables.muscleStimulus}
      ''');

      await db.execute('DROP TABLE ${DatabaseTables.muscleStimulus}');
      await db.execute(
        'ALTER TABLE muscle_stimulus_v17 RENAME TO ${DatabaseTables.muscleStimulus}',
      );
    }

    if (oldVersion < 18) {
      // Replace the global UNIQUE(name) on exercises and meals with a
      // per-owner expression index UNIQUE(name, COALESCE(owner_user_id, '')).
      //
      // The old global constraint was wrong: a system-seeded exercise (owner
      // IS NULL) and a user-owned exercise can legitimately share the same
      // name. The global UNIQUE caused sign-in sync to fail with
      // "UNIQUE constraint failed: exercises.name" whenever the remote
      // returned user-owned exercises whose names collided with seeded ones.
      //
      // SQLite does not support DROP CONSTRAINT, so both tables are
      // recreated following the same pattern as migration v17.
      await _migrateExercisesForMultiOwnerUniqueness(db);
      await _migrateMealsForMultiOwnerUniqueness(db);
    }

    if (oldVersion < 19) {
      // The Targets feature has been removed from the app.
      // Drop the table so the schema stays in sync on existing devices.
      // IF NOT EXISTS is not valid for DROP TABLE in SQLite; use IF EXISTS (sqflite
      // wraps the standard syntax). Any installation that never created the
      // targets table (e.g., fresh installs between v18 and v19) will skip
      // silently via the try/ignore pattern handled by sqflite.
      try {
        await db.execute('DROP TABLE IF EXISTS targets');
      } catch (_) {
        // Table may not exist on installations that skipped older versions
        // via a non-standard upgrade path — safe to ignore.
      }
    }

    if (oldVersion < 20) {
      // Per-user catalog model: owner_user_id must never be NULL. Legacy
      // seeded exercises/meals were created with NULL owner; collapse them
      // to the guest sentinel '' (the same sentinel muscle_stimulus has used
      // since v17). Pure in-place UPDATE — no rows are deleted, so no child
      // FK repointing is needed.
      //
      // Why no dedupe pass: the v18 expression index
      // UNIQUE(name, COALESCE(owner_user_id, '')) already guarantees at most
      // one row per (name, owner-bucket), and COALESCE(NULL,'') == '' means
      // NULL→'' leaves every index key unchanged — it can neither create a
      // collision nor merge distinct accounts (NULL/'' vs a real uid stay
      // separate by design; that convergence is user-scoped and happens at
      // sign-in, not in this user-agnostic migration).
      await _collapseNullCatalogOwnersToGuestBucket(db);
    }

    if (oldVersion < 21) {
      // Deterministic default-catalog identity. Pre-existing installs have
      // default exercises/meals under random v4 ids; rewrite them to the
      // stable name-derived UUIDv5 and repoint children so existing workout
      // history and nutrition logs keep resolving (no "Unknown exercise",
      // no FK-orphaned logs) and the next sync is idempotent by id.
      await rewriteDefaultCatalogIdsToDeterministic(db);
    }

    if (oldVersion < 22) {
      // Destructive data cleanup tied to the removal of guest mode. The
      // empty-owner branch of `DeterministicCatalogId.forOwner` collapses
      // to the same name-only UUIDv5 that older Supabase rows still carry,
      // so a guest-seeded `exercises` row at id X collides with the
      // server-side row at id X on the very first initial-cloud-migration
      // pull, leaving `session.requires_initial_cloud_migration = true`
      // forever. Wiping every guest-owned row removes the collision
      // entirely; subsequent commits delete the code paths that could
      // ever recreate one. See KNOWN_ISSUES.md anchor
      // #guest-catalog-pk-collision-blocks-initial-sign-in.
      await purgeGuestOwnedRowsAndCatalogFlags(db);
    }

    await _createIndexes(db);
  }

  /// Rewrites every default exercise/meal row to its deterministic,
  /// name-derived id and repoints child references (db v21).
  ///
  /// Exposed as a static entry point — like [createSchema] — so the data
  /// migration can be exercised directly in tests without reaching into the
  /// private upgrade path.
  ///
  /// Properties:
  /// - **Idempotent**: a second run finds each default already at its
  ///   deterministic id and does nothing.
  /// - **Index-safe**: an id rewrite stays within the same
  ///   `(name, COALESCE(owner,''))` bucket, so `idx_*_name_owner` keys are
  ///   unchanged. The deterministic id is name-derived, so if a default name
  ///   exists under several owner buckets they necessarily collapse to one
  ///   row (the local PK is the id alone); the surviving row keeps its owner
  ///   and all children are repointed to it — no history is lost, only the
  ///   transient duplicate row.
  /// - **No orphans**: `workout_sets` / `exercise_muscle_factors` /
  ///   `nutrition_logs` are repointed before any stale catalog row is
  ///   deleted; factor repoints use `UPDATE OR IGNORE` + cleanup to respect
  ///   `UNIQUE(exercise_id, muscle_group)`.
  static Future<void> rewriteDefaultCatalogIdsToDeterministic(
    Database db,
  ) async {
    await _rewriteCatalogGroup(
      db,
      table: DatabaseTables.exercises,
      idColumn: DatabaseTables.exerciseId,
      nameColumn: DatabaseTables.exerciseName,
      updatedAtColumn: DatabaseTables.exerciseUpdatedAt,
      createdAtColumn: DatabaseTables.exerciseCreatedAt,
      defaultNames: DefaultExercisesData.getDefaultExercises()
          .map((e) => e.name)
          .toList(),
      childRepoints: const <_CatalogChildRepoint>[
        _CatalogChildRepoint(
          table: DatabaseTables.workoutSets,
          column: DatabaseTables.setExerciseId,
        ),
        _CatalogChildRepoint(
          table: DatabaseTables.exerciseMuscleFactors,
          column: DatabaseTables.factorExerciseId,
          dedupeOnConflict: true,
        ),
      ],
    );

    await _rewriteCatalogGroup(
      db,
      table: DatabaseTables.meals,
      idColumn: DatabaseTables.mealId,
      nameColumn: DatabaseTables.mealName,
      updatedAtColumn: DatabaseTables.mealUpdatedAt,
      createdAtColumn: DatabaseTables.mealCreatedAt,
      defaultNames: DefaultMealsData.getDefaultMeals()
          .map((m) => m.name)
          .toList(),
      childRepoints: const <_CatalogChildRepoint>[
        _CatalogChildRepoint(
          table: DatabaseTables.nutritionLogs,
          column: DatabaseTables.nutritionLogMealId,
        ),
      ],
    );
  }

  /// Collapses every local row whose name equals a default [defaultNames]
  /// entry onto a single row carrying the deterministic id, repointing the
  /// declared [childRepoints] first so no child is left dangling.
  static Future<void> _rewriteCatalogGroup(
    Database db, {
    required String table,
    required String idColumn,
    required String nameColumn,
    required String updatedAtColumn,
    required String createdAtColumn,
    required List<String> defaultNames,
    required List<_CatalogChildRepoint> childRepoints,
  }) async {
    var rewritten = 0;

    for (final name in defaultNames) {
      // Legacy name-only UUIDv5 derivation, preserved verbatim for the v21
      // historical upgrade path. New code must use
      // [DeterministicCatalogId.forOwner] with a non-empty authenticated
      // owner — see `KNOWN_ISSUES.md#guest-catalog-pk-collision-blocks-initial-sign-in`.
      final detId = const Uuid().v5(
        DeterministicCatalogId.namespace,
        DeterministicCatalogId.canonicalName(name),
      );

      // Copy out of the read-only QueryResultSet so the survivor sort below
      // can reorder in place.
      final rows = List<Map<String, Object?>>.from(
        await db.query(
          table,
          columns: [idColumn, updatedAtColumn, createdAtColumn],
          where: '$nameColumn = ?',
          whereArgs: [name],
        ),
      );
      if (rows.isEmpty) continue;

      // Survivor: an already-deterministic row if present (idempotent
      // re-run), otherwise the newest row (updated → created → id desc).
      final String survivorOldId;
      if (rows.any((r) => r[idColumn] == detId)) {
        survivorOldId = detId;
      } else {
        rows.sort((a, b) {
          String ts(Map<String, Object?> r) =>
              (r[updatedAtColumn] as String?) ??
              (r[createdAtColumn] as String?) ??
              '';
          final byTime = ts(b).compareTo(ts(a));
          if (byTime != 0) return byTime;
          return (b[idColumn] as String).compareTo(a[idColumn] as String);
        });
        survivorOldId = rows.first[idColumn] as String;
      }

      // Repoint children of every non-deterministic row onto the det id.
      for (final row in rows) {
        final oldId = row[idColumn] as String;
        if (oldId == detId) continue;

        for (final child in childRepoints) {
          if (child.dedupeOnConflict) {
            await db.rawUpdate(
              'UPDATE OR IGNORE ${child.table} '
              'SET ${child.column} = ? WHERE ${child.column} = ?',
              [detId, oldId],
            );
            // Rows that lost the race to a pre-existing (det id, key) pair
            // are now redundant duplicates — drop them so the delete of the
            // stale catalog row below does not cascade away anything live.
            await db.delete(
              child.table,
              where: '${child.column} = ?',
              whereArgs: [oldId],
            );
          } else {
            await db.update(
              child.table,
              <String, Object?>{child.column: detId},
              where: '${child.column} = ?',
              whereArgs: [oldId],
            );
          }
        }
      }

      // Drop every stale catalog row; children no longer reference them.
      for (final row in rows) {
        final oldId = row[idColumn] as String;
        if (oldId == survivorOldId) continue;
        await db.delete(table, where: '$idColumn = ?', whereArgs: [oldId]);
      }

      // Finally adopt the deterministic id on the survivor.
      if (survivorOldId != detId) {
        await db.update(
          table,
          <String, Object?>{idColumn: detId},
          where: '$idColumn = ?',
          whereArgs: [survivorOldId],
        );
        rewritten++;
      }
    }

    if (rewritten > 0) {
      AppLogger.info(
        'v21 migration: rewrote $rewritten default "$table" row(s) to '
        'deterministic ids',
        category: 'db_migration',
      );
    }
  }

  /// Rewrites `owner_user_id IS NULL` to the guest sentinel `''` for the
  /// exercise and meal catalogs (db v20).
  ///
  /// Safe to re-run: the predicate only matches genuine NULLs, so a second
  /// pass is a no-op.
  Future<void> _collapseNullCatalogOwnersToGuestBucket(Database db) async {
    final exercisesUpdated = await db.update(
      DatabaseTables.exercises,
      <String, Object?>{DatabaseTables.ownerUserId: ''},
      where: '${DatabaseTables.ownerUserId} IS NULL',
    );
    final mealsUpdated = await db.update(
      DatabaseTables.meals,
      <String, Object?>{DatabaseTables.ownerUserId: ''},
      where: '${DatabaseTables.ownerUserId} IS NULL',
    );

    AppLogger.info(
      'v20 migration: collapsed $exercisesUpdated exercise and '
      '$mealsUpdated meal row(s) from NULL owner to guest sentinel',
      category: 'db_migration',
    );
  }

  /// Destructively purges every row whose `owner_user_id` is the empty-string
  /// guest sentinel (or NULL) across all user-scoped tables and removes the
  /// guest-bucket catalog-init flags from `app_metadata` (db v22).
  ///
  /// Exposed as a static entry point — like [createSchema] and
  /// [rewriteDefaultCatalogIdsToDeterministic] — so the data migration can
  /// be exercised directly in tests without reaching into the private
  /// upgrade path.
  ///
  /// Scope:
  /// - `exercises`, `meals`, `workout_sets`, `nutrition_logs`,
  ///   `muscle_stimulus` — every row where `owner_user_id IS NULL` or
  ///   `owner_user_id = ''`.
  /// - `exercise_muscle_factors` — rows that reference a soon-to-be-deleted
  ///   guest exercise are explicitly purged first. The FK declares
  ///   `ON DELETE CASCADE`, but the exercises table was recreated by the
  ///   v18 migration (and `muscle_stimulus` by v17); doing the child delete
  ///   explicitly removes the dependency on the cascade surviving those
  ///   recreations on any given device.
  /// - `app_metadata` — the two empty-owner-suffix keys
  ///   `catalog_init_exercises_` and `catalog_init_meals_` (the guest
  ///   catalog-init flags). Authenticated-user flags
  ///   `catalog_init_<entity>_<uid>` are NOT touched.
  ///
  /// This migration deletes data permanently. It is safe because the only
  /// supported entry point to be a guest user is removed in subsequent
  /// commits, so the deleted rows would otherwise be inaccessible going
  /// forward. See the implementation plan and the KNOWN_ISSUES anchor
  /// `#guest-catalog-pk-collision-blocks-initial-sign-in` for the full
  /// rationale.
  static Future<void> purgeGuestOwnedRowsAndCatalogFlags(Database db) async {
    const guestPredicate =
        '${DatabaseTables.ownerUserId} IS NULL OR ${DatabaseTables.ownerUserId} = ?';

    final factorsDeleted = await db.rawDelete(
      'DELETE FROM ${DatabaseTables.exerciseMuscleFactors} '
      'WHERE ${DatabaseTables.factorExerciseId} IN ('
      '  SELECT ${DatabaseTables.exerciseId} '
      '  FROM ${DatabaseTables.exercises} '
      '  WHERE ${DatabaseTables.ownerUserId} IS NULL '
      "     OR ${DatabaseTables.ownerUserId} = ''"
      ')',
    );

    final exercisesDeleted = await db.delete(
      DatabaseTables.exercises,
      where: guestPredicate,
      whereArgs: const [''],
    );
    final mealsDeleted = await db.delete(
      DatabaseTables.meals,
      where: guestPredicate,
      whereArgs: const [''],
    );
    final setsDeleted = await db.delete(
      DatabaseTables.workoutSets,
      where: guestPredicate,
      whereArgs: const [''],
    );
    final logsDeleted = await db.delete(
      DatabaseTables.nutritionLogs,
      where: guestPredicate,
      whereArgs: const [''],
    );
    final stimulusDeleted = await db.delete(
      DatabaseTables.muscleStimulus,
      where: guestPredicate,
      whereArgs: const [''],
    );

    final flagsDeleted = await db.delete(
      DatabaseTables.appMetadata,
      where: '${DatabaseTables.metadataKey} IN (?, ?)',
      whereArgs: const ['catalog_init_exercises_', 'catalog_init_meals_'],
    );

    AppLogger.info(
      'v22 migration: purged guest-owned rows '
      '(exercises=$exercisesDeleted, meals=$mealsDeleted, '
      'workout_sets=$setsDeleted, nutrition_logs=$logsDeleted, '
      'muscle_stimulus=$stimulusDeleted, '
      'exercise_muscle_factors=$factorsDeleted) and guest catalog-init '
      'flags (count=$flagsDeleted)',
      category: 'db_migration',
    );
  }

  void _ensureSupportedUpgradePath(int oldVersion, int newVersion) {
    if (oldVersion >= _minimumSupportedUpgradeVersion) {
      return;
    }

    throw UnsupportedDatabaseVersionException(
      oldVersion: oldVersion,
      newVersion: newVersion,
      minimumSupportedVersion: _minimumSupportedUpgradeVersion,
    );
  }

  // ignore: unused_element — kept for upgrade path from db versions < 8.
  Future<void> _migrateTargetsToTypedGoals(Database db) async {
    await db.execute('ALTER TABLE targets RENAME TO targets_legacy');

    await db.execute('''
      CREATE TABLE targets (
        id TEXT PRIMARY KEY,
        ${DatabaseTables.ownerUserId} TEXT,
        type TEXT NOT NULL,
        category_key TEXT NOT NULL,
        target_value REAL NOT NULL,
        unit TEXT NOT NULL,
        period TEXT NOT NULL,
        created_at TEXT NOT NULL,
        UNIQUE(type, category_key, period)
      )
    ''');

    final legacyTargets = await db.query('targets_legacy');

    for (final legacyTarget in legacyTargets) {
      await db.insert('targets', <String, Object?>{
        'id': legacyTarget['id'] as String,
        DatabaseTables.ownerUserId: null,
        'type': 'muscle_sets',
        'category_key': legacyTarget['muscle_group'] as String,
        'target_value': (legacyTarget['weekly_goal'] as num).toDouble(),
        'unit': 'sets',
        'period': 'weekly',
        'created_at': legacyTarget['created_at'] as String,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    await db.execute('DROP TABLE targets_legacy');
  }

  Future<void> _migrateWorkoutSetsForRemoteReadiness(Database db) async {
    await db.execute('''
      ALTER TABLE ${DatabaseTables.workoutSets}
      ADD COLUMN ${DatabaseTables.setUpdatedAt} TEXT
    ''');

    await db.execute('''
      UPDATE ${DatabaseTables.workoutSets}
      SET ${DatabaseTables.setUpdatedAt} = ${DatabaseTables.setCreatedAt}
      WHERE ${DatabaseTables.setUpdatedAt} IS NULL
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.workoutSets}
      ADD COLUMN ${DatabaseTables.setServerId} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.workoutSets}
      ADD COLUMN ${DatabaseTables.setSyncStatus} TEXT NOT NULL DEFAULT 'localOnly'
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.workoutSets}
      ADD COLUMN ${DatabaseTables.setLastSyncedAt} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.workoutSets}
      ADD COLUMN ${DatabaseTables.setLastSyncError} TEXT
    ''');
  }

  Future<void> _createPendingSyncDeletesTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.pendingSyncDeletes} (
        ${DatabaseTables.pendingDeleteId} TEXT PRIMARY KEY,
        ${DatabaseTables.pendingDeleteEntityType} TEXT NOT NULL,
        ${DatabaseTables.pendingDeleteLocalEntityId} TEXT NOT NULL,
        ${DatabaseTables.pendingDeleteServerEntityId} TEXT,
        ${DatabaseTables.pendingDeleteCreatedAt} TEXT NOT NULL,
        ${DatabaseTables.pendingDeleteLastAttemptAt} TEXT,
        ${DatabaseTables.pendingDeleteErrorMessage} TEXT
      )
    ''');
  }

  // ignore: unused_element — kept for upgrade path from db versions < 11.
  Future<void> _migrateTargetsForRemoteReadiness(Database db) async {
    await db.execute('ALTER TABLE targets ADD COLUMN updated_at TEXT');
    await db.execute(
      'UPDATE targets SET updated_at = created_at WHERE updated_at IS NULL',
    );
    await db.execute('ALTER TABLE targets ADD COLUMN server_id TEXT');
    await db.execute(
      "ALTER TABLE targets ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'localOnly'",
    );
    await db.execute('ALTER TABLE targets ADD COLUMN last_synced_at TEXT');
    await db.execute('ALTER TABLE targets ADD COLUMN last_sync_error TEXT');
  }

  Future<void> _migrateExercisesForRemoteReadiness(Database db) async {
    await db.execute('''
      ALTER TABLE ${DatabaseTables.exercises}
      ADD COLUMN ${DatabaseTables.exerciseUpdatedAt} TEXT
    ''');

    await db.execute('''
      UPDATE ${DatabaseTables.exercises}
      SET ${DatabaseTables.exerciseUpdatedAt} = ${DatabaseTables.exerciseCreatedAt}
      WHERE ${DatabaseTables.exerciseUpdatedAt} IS NULL
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.exercises}
      ADD COLUMN ${DatabaseTables.exerciseServerId} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.exercises}
      ADD COLUMN ${DatabaseTables.exerciseSyncStatus} TEXT NOT NULL DEFAULT 'localOnly'
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.exercises}
      ADD COLUMN ${DatabaseTables.exerciseLastSyncedAt} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.exercises}
      ADD COLUMN ${DatabaseTables.exerciseLastSyncError} TEXT
    ''');
  }

  Future<void> _migrateMealsAndNutritionLogsForRemoteReadiness(
    Database db,
  ) async {
    await db.execute('''
      ALTER TABLE ${DatabaseTables.meals}
      ADD COLUMN ${DatabaseTables.mealUpdatedAt} TEXT
    ''');

    await db.execute('''
      UPDATE ${DatabaseTables.meals}
      SET ${DatabaseTables.mealUpdatedAt} = ${DatabaseTables.mealCreatedAt}
      WHERE ${DatabaseTables.mealUpdatedAt} IS NULL
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.meals}
      ADD COLUMN ${DatabaseTables.mealServerId} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.meals}
      ADD COLUMN ${DatabaseTables.mealSyncStatus} TEXT NOT NULL DEFAULT 'localOnly'
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.meals}
      ADD COLUMN ${DatabaseTables.mealLastSyncedAt} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.meals}
      ADD COLUMN ${DatabaseTables.mealLastSyncError} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.nutritionLogs}
      ADD COLUMN ${DatabaseTables.nutritionLogUpdatedAt} TEXT
    ''');

    await db.execute('''
      UPDATE ${DatabaseTables.nutritionLogs}
      SET ${DatabaseTables.nutritionLogUpdatedAt} = ${DatabaseTables.nutritionLogCreatedAt}
      WHERE ${DatabaseTables.nutritionLogUpdatedAt} IS NULL
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.nutritionLogs}
      ADD COLUMN ${DatabaseTables.nutritionLogServerId} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.nutritionLogs}
      ADD COLUMN ${DatabaseTables.nutritionLogSyncStatus} TEXT NOT NULL DEFAULT 'localOnly'
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.nutritionLogs}
      ADD COLUMN ${DatabaseTables.nutritionLogLastSyncedAt} TEXT
    ''');

    await db.execute('''
      ALTER TABLE ${DatabaseTables.nutritionLogs}
      ADD COLUMN ${DatabaseTables.nutritionLogLastSyncError} TEXT
    ''');
  }

  Future<void> _createAppMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DatabaseTables.appMetadata} (
        ${DatabaseTables.metadataKey} TEXT PRIMARY KEY,
        ${DatabaseTables.metadataValue} TEXT,
        ${DatabaseTables.metadataUpdatedAt} TEXT NOT NULL
      )
    ''');
  }

  Future<void> _migrateOwnershipColumns(Database db) async {
    // targets table still exists at this point in the upgrade path (v15);
    // owner_user_id is added here and the table itself is dropped in v19.
    await _addNullableTextColumnIfMissing(
      db,
      tableName: 'targets',
      columnName: DatabaseTables.ownerUserId,
    );
    await _addNullableTextColumnIfMissing(
      db,
      tableName: DatabaseTables.workoutSets,
      columnName: DatabaseTables.ownerUserId,
    );
    await _addNullableTextColumnIfMissing(
      db,
      tableName: DatabaseTables.exercises,
      columnName: DatabaseTables.ownerUserId,
    );
    await _addNullableTextColumnIfMissing(
      db,
      tableName: DatabaseTables.meals,
      columnName: DatabaseTables.ownerUserId,
    );
    await _addNullableTextColumnIfMissing(
      db,
      tableName: DatabaseTables.nutritionLogs,
      columnName: DatabaseTables.ownerUserId,
    );
  }

  Future<void> _addNullableTextColumnIfMissing(
    Database db, {
    required String tableName,
    required String columnName,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    final exists = columns.any((row) => row['name'] == columnName);

    if (exists) {
      return;
    }

    await db.execute('ALTER TABLE $tableName ADD COLUMN $columnName TEXT');
  }

  /// Adds [columnName] to [tableName] with [columnSpec] only when the column
  /// is not already present. Use this for any `ALTER TABLE ... ADD COLUMN`
  /// migration whose target column also appears in an earlier-version
  /// `CREATE TABLE` block (i.e. retrofitted into fresh installs) — without
  /// the guard, a chained replay from a pre-CREATE version through to a
  /// version that has both the CREATE and the ALTER will fail with
  /// `duplicate column name`.
  ///
  /// [columnSpec] is the full type+constraints string after `ADD COLUMN
  /// <name>` — e.g. `"TEXT NOT NULL DEFAULT ''"` or `"REAL NOT NULL DEFAULT
  /// 100.0"`. See KNOWN_ISSUES.md#migration-add-column-must-be-idempotent.
  Future<void> _addColumnIfMissing(
    Database db, {
    required String tableName,
    required String columnName,
    required String columnSpec,
  }) async {
    final columns = await db.rawQuery('PRAGMA table_info($tableName)');
    if (columns.any((row) => row['name'] == columnName)) return;
    await db.execute(
      'ALTER TABLE $tableName ADD COLUMN $columnName $columnSpec',
    );
  }

  /// Migrates [exercises] to use per-owner uniqueness.
  ///
  /// Before v18 the schema had `exerciseName TEXT NOT NULL UNIQUE` — a global
  /// uniqueness constraint that conflicted with multi-owner scenarios (e.g. a
  /// system-seeded "Barbell Row" and a user-owned "Barbell Row" cannot coexist).
  ///
  /// After v18 the constraint lives in the expression index
  /// `idx_exercises_name_owner` — `UNIQUE(name, COALESCE(owner_user_id, ''))`.
  /// That allows one system row (owner = NULL → '') and one row per user to
  /// share the same name. [_createIndexes] builds the index after migration.
  ///
  /// The table is fully recreated because SQLite has no `DROP CONSTRAINT`.
  /// A defensive dedup pass runs first in case pre-migration rows somehow
  /// violate the incoming constraint (the old global UNIQUE should prevent
  /// this in practice, but guard against corrupt / manually-edited databases).
  Future<void> _migrateExercisesForMultiOwnerUniqueness(Database db) async {
    final rows = await db.query(DatabaseTables.exercises);

    final keepIds = _keepNewestPerGroup(
      rows,
      groupKey: (row) =>
          '${row[DatabaseTables.exerciseName]}|'
          '${row[DatabaseTables.ownerUserId] ?? ''}',
      updatedAtKey: DatabaseTables.exerciseUpdatedAt,
      createdAtKey: DatabaseTables.exerciseCreatedAt,
      idKey: DatabaseTables.exerciseId,
    );

    final dropIds = rows
        .map((r) => r[DatabaseTables.exerciseId] as String)
        .where((id) => !keepIds.contains(id))
        .toList();

    if (dropIds.isNotEmpty) {
      AppLogger.warning(
        'v18 migration: dropping ${dropIds.length} duplicate exercise '
        'row(s) — ids: ${dropIds.join(', ')}',
        category: 'db_migration',
      );
      for (final id in dropIds) {
        await db.delete(
          DatabaseTables.exercises,
          where: '${DatabaseTables.exerciseId} = ?',
          whereArgs: [id],
        );
      }
    }

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
  }

  /// Migrates [meals] to use per-owner uniqueness.
  ///
  /// Identical rationale to [_migrateExercisesForMultiOwnerUniqueness].
  /// After migration, uniqueness is enforced by `idx_meals_name_owner`
  /// (`UNIQUE(name, COALESCE(owner_user_id, ''))`).
  Future<void> _migrateMealsForMultiOwnerUniqueness(Database db) async {
    final rows = await db.query(DatabaseTables.meals);

    final keepIds = _keepNewestPerGroup(
      rows,
      groupKey: (row) =>
          '${row[DatabaseTables.mealName]}|'
          '${row[DatabaseTables.ownerUserId] ?? ''}',
      updatedAtKey: DatabaseTables.mealUpdatedAt,
      createdAtKey: DatabaseTables.mealCreatedAt,
      idKey: DatabaseTables.mealId,
    );

    final dropIds = rows
        .map((r) => r[DatabaseTables.mealId] as String)
        .where((id) => !keepIds.contains(id))
        .toList();

    if (dropIds.isNotEmpty) {
      AppLogger.warning(
        'v18 migration: dropping ${dropIds.length} duplicate meal '
        'row(s) — ids: ${dropIds.join(', ')}',
        category: 'db_migration',
      );
      for (final id in dropIds) {
        await db.delete(
          DatabaseTables.meals,
          where: '${DatabaseTables.mealId} = ?',
          whereArgs: [id],
        );
      }
    }

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
  }

  /// Returns the set of IDs that should be retained when deduplicating
  /// [rows] by [groupKey].
  ///
  /// For each group the row with the lexicographically greatest
  /// [updatedAtKey] timestamp is kept. [createdAtKey] is the fallback when
  /// [updatedAtKey] is absent, and [idKey] (lexicographic max) is the final
  /// deterministic tie-breaker.
  static Set<String> _keepNewestPerGroup(
    List<Map<String, Object?>> rows, {
    required String Function(Map<String, Object?> row) groupKey,
    required String updatedAtKey,
    required String createdAtKey,
    required String idKey,
  }) {
    final best = <String, Map<String, Object?>>{};

    for (final row in rows) {
      final key = groupKey(row);
      final existing = best[key];
      if (existing == null ||
          _rowIsNewer(row, existing, updatedAtKey, createdAtKey, idKey)) {
        best[key] = row;
      }
    }

    return {for (final row in best.values) row[idKey] as String};
  }

  /// Returns `true` when [candidate] is strictly newer than [current].
  static bool _rowIsNewer(
    Map<String, Object?> candidate,
    Map<String, Object?> current,
    String updatedAtKey,
    String createdAtKey,
    String idKey,
  ) {
    final tA =
        (candidate[updatedAtKey] as String?) ??
        (candidate[createdAtKey] as String?) ??
        '';
    final tB =
        (current[updatedAtKey] as String?) ??
        (current[createdAtKey] as String?) ??
        '';
    final cmp = tA.compareTo(tB);
    if (cmp != 0) return cmp > 0;
    // Deterministic tie-breaker: lexicographically greater ID wins.
    final idA = candidate[idKey] as String? ?? '';
    final idB = current[idKey] as String? ?? '';
    return idA.compareTo(idB) > 0;
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_workout_sets_exercise_id
      ON ${DatabaseTables.workoutSets}(${DatabaseTables.setExerciseId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_workout_sets_date
      ON ${DatabaseTables.workoutSets}(${DatabaseTables.setDate})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_workout_sets_created_at
      ON ${DatabaseTables.workoutSets}(${DatabaseTables.setCreatedAt})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_workout_sets_updated_at
      ON ${DatabaseTables.workoutSets}(${DatabaseTables.setUpdatedAt})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_workout_sets_sync_status
      ON ${DatabaseTables.workoutSets}(${DatabaseTables.setSyncStatus})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_workout_sets_server_id
      ON ${DatabaseTables.workoutSets}(${DatabaseTables.setServerId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_workout_sets_owner_user_id
      ON ${DatabaseTables.workoutSets}(${DatabaseTables.ownerUserId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exercises_name
      ON ${DatabaseTables.exercises}(${DatabaseTables.exerciseName})
    ''');

    // Per-owner uniqueness: a system exercise and a user exercise may share
    // the same name. NULL owner_user_id (system) is normalised to '' so the
    // index treats all system rows as one owner group.
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_exercises_name_owner
      ON ${DatabaseTables.exercises}(
        ${DatabaseTables.exerciseName},
        COALESCE(${DatabaseTables.ownerUserId}, '')
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exercises_updated_at
      ON ${DatabaseTables.exercises}(${DatabaseTables.exerciseUpdatedAt})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exercises_sync_status
      ON ${DatabaseTables.exercises}(${DatabaseTables.exerciseSyncStatus})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exercises_server_id
      ON ${DatabaseTables.exercises}(${DatabaseTables.exerciseServerId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exercises_owner_user_id
      ON ${DatabaseTables.exercises}(${DatabaseTables.ownerUserId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meals_name
      ON ${DatabaseTables.meals}(${DatabaseTables.mealName})
    ''');

    // Per-owner uniqueness: same rationale as idx_exercises_name_owner.
    await db.execute('''
      CREATE UNIQUE INDEX IF NOT EXISTS idx_meals_name_owner
      ON ${DatabaseTables.meals}(
        ${DatabaseTables.mealName},
        COALESCE(${DatabaseTables.ownerUserId}, '')
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meals_updated_at
      ON ${DatabaseTables.meals}(${DatabaseTables.mealUpdatedAt})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meals_sync_status
      ON ${DatabaseTables.meals}(${DatabaseTables.mealSyncStatus})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meals_server_id
      ON ${DatabaseTables.meals}(${DatabaseTables.mealServerId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_meals_owner_user_id
      ON ${DatabaseTables.meals}(${DatabaseTables.ownerUserId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nutrition_logs_meal_id
      ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogMealId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nutrition_logs_date
      ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogDate})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nutrition_logs_created_at
      ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogCreatedAt})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nutrition_logs_updated_at
      ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogUpdatedAt})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nutrition_logs_sync_status
      ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogSyncStatus})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nutrition_logs_server_id
      ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.nutritionLogServerId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_nutrition_logs_owner_user_id
      ON ${DatabaseTables.nutritionLogs}(${DatabaseTables.ownerUserId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exercise_muscle_factors_exercise_id
      ON ${DatabaseTables.exerciseMuscleFactors}(${DatabaseTables.factorExerciseId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_exercise_muscle_factors_muscle_group
      ON ${DatabaseTables.exerciseMuscleFactors}(${DatabaseTables.factorMuscleGroup})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_muscle_stimulus_owner_user_id
      ON ${DatabaseTables.muscleStimulus}(${DatabaseTables.ownerUserId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_muscle_stimulus_muscle_group
      ON ${DatabaseTables.muscleStimulus}(${DatabaseTables.stimulusMuscleGroup})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_muscle_stimulus_date
      ON ${DatabaseTables.muscleStimulus}(${DatabaseTables.stimulusDate})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_muscle_stimulus_owner_muscle_date
      ON ${DatabaseTables.muscleStimulus}(
        ${DatabaseTables.ownerUserId},
        ${DatabaseTables.stimulusMuscleGroup},
        ${DatabaseTables.stimulusDate}
      )
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_sync_deletes_entity_type
      ON ${DatabaseTables.pendingSyncDeletes}(${DatabaseTables.pendingDeleteEntityType})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_sync_deletes_created_at
      ON ${DatabaseTables.pendingSyncDeletes}(${DatabaseTables.pendingDeleteCreatedAt})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pending_sync_deletes_local_entity_id
      ON ${DatabaseTables.pendingSyncDeletes}(${DatabaseTables.pendingDeleteLocalEntityId})
    ''');

    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_app_metadata_updated_at
      ON ${DatabaseTables.appMetadata}(${DatabaseTables.metadataUpdatedAt})
    ''');
  }

  Future<void> close() async {
    if (kIsWeb) return;

    final db = await database;
    await db.close();
    _database = null;
  }
}

/// A child table/column that references a catalog row's id and must be
/// repointed when that id is rewritten (db v21).
///
/// [dedupeOnConflict] is set for tables with a uniqueness constraint on the
/// reference (e.g. `exercise_muscle_factors UNIQUE(exercise_id,
/// muscle_group)`): the repoint uses `UPDATE OR IGNORE` and the losing rows
/// are deleted instead of aborting the migration.
class _CatalogChildRepoint {
  const _CatalogChildRepoint({
    required this.table,
    required this.column,
    this.dedupeOnConflict = false,
  });

  final String table;
  final String column;
  final bool dedupeOnConflict;
}

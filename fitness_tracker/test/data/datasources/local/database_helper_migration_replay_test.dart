// End-to-end migration replay: simulates an oldest-supported install (v2)
// upgrading straight to the current schema version in a single
// `_onUpgrade` cascade, then asserts no exceptions and that the canonical
// tables exist.
//
// Per-version tests (`database_helper_vN_migration_test.dart`) catch
// regressions in each individual branch. This replay test catches the
// orthogonal failure mode: *interaction* bugs between migrations — e.g.
// a v17 table-recreation that breaks an FK referenced by a v22 cleanup, a
// later migration that assumes a column the previous one renamed, etc.
//
// Starting at v2 because `DatabaseHelper._minimumSupportedUpgradeVersion`
// is 2 — anything below that is rejected with
// `UnsupportedDatabaseVersionException` by design.
import 'package:fitness_tracker/config/env_config.dart';
import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const int _minimumStartVersion = 2;

/// The minimal table set that an actual v2 database carried.
///
/// Derived by reading every `if (oldVersion < N)` branch in `_onUpgrade`:
/// the v3 branch CREATEs `exercises`, v4 CREATEs `meals` +
/// `nutrition_logs`, v5 CREATEs `exercise_muscle_factors` +
/// `muscle_stimulus`, etc. — so at v2 only `workout_sets` and `targets`
/// existed. `targets` is required because the v8 migration does
/// `ALTER TABLE targets RENAME TO targets_legacy`; that throws if the
/// table is absent at v8 boot.
Future<void> _createMinimalV2Schema(Database db) async {
  await db.execute('''
    CREATE TABLE ${DatabaseTables.workoutSets} (
      ${DatabaseTables.setId} TEXT PRIMARY KEY,
      ${DatabaseTables.setExerciseId} TEXT NOT NULL,
      ${DatabaseTables.setReps} INTEGER NOT NULL,
      ${DatabaseTables.setWeight} REAL NOT NULL,
      ${DatabaseTables.setDate} TEXT NOT NULL,
      ${DatabaseTables.setCreatedAt} TEXT NOT NULL
    )
  ''');

  await db.execute('''
    CREATE TABLE targets (
      id TEXT PRIMARY KEY,
      muscle_group TEXT NOT NULL,
      weekly_goal REAL NOT NULL,
      created_at TEXT NOT NULL
    )
  ''');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test(
    'replay: minimal v2 schema upgrades to the current version without errors',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: _minimumStartVersion,
          onCreate: (d, _) => _createMinimalV2Schema(d),
        ),
      );
      addTearDown(() async => db.close());

      // Run the entire migration cascade in one call.
      await DatabaseHelper.runOnUpgradeForTesting(
        db,
        _minimumStartVersion,
        EnvConfig.databaseVersion,
      );

      // Canonical tables that must exist after replay.
      final names = (await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      )).map((r) => r['name'] as String).toSet();

      expect(
        names,
        containsAll(<String>[
          DatabaseTables.workoutSets,
          DatabaseTables.exercises,
          DatabaseTables.meals,
          DatabaseTables.nutritionLogs,
          DatabaseTables.exerciseMuscleFactors,
          DatabaseTables.muscleStimulus,
          DatabaseTables.pendingSyncDeletes,
          DatabaseTables.appMetadata,
        ]),
        reason:
            'every table created across the v3–v22 migrations must '
            'survive the full replay',
      );

      // The targets table was dropped in v19 — make sure it's actually
      // gone, not lingering from the seed.
      expect(
        names,
        isNot(contains('targets')),
        reason: 'v19 migration drops the targets table',
      );
    },
  );

  test('replay: idempotent — re-running the cascade from current to current '
      'is a no-op', () async {
    // Boot directly at the current version via createSchema, then ask
    // the migration cascade to "upgrade" from current to current.
    // Should be entirely silent.
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: EnvConfig.databaseVersion,
        onCreate: (d, _) => DatabaseHelper.createSchema(d),
      ),
    );
    addTearDown(() async => db.close());

    // No branch with `oldVersion < EnvConfig.databaseVersion` should fire
    // because oldVersion already equals newVersion.
    await DatabaseHelper.runOnUpgradeForTesting(
      db,
      EnvConfig.databaseVersion,
      EnvConfig.databaseVersion,
    );

    // Sanity-check the schema is still intact.
    final names = (await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table'",
    )).map((r) => r['name'] as String).toSet();
    expect(names, contains(DatabaseTables.exercises));
    expect(names, contains(DatabaseTables.meals));
  });
}

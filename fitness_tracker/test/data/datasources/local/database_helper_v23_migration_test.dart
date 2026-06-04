// Regression suite for the db v23 schema migration.
//
// Verifies:
//   1. Fresh-install DDL includes the `daily_volume` column with DEFAULT 0.0.
//   2. Upgrading a v22 database adds the `daily_volume` column.
//   3. Existing v22 rows survive the upgrade with daily_volume == 0.0.
//   4. New rows can be inserted and read back with a non-zero daily_volume.
//
// Note: daily_volume rows are 0.0 immediately after the migration because
// RebuildMuscleStimulusFromWorkoutHistory repopulates the full history on the
// next launch/sync — no manual backfill is required.
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

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Opens an in-memory database at [fromVersion] using the real schema
  /// creator (so the pre-v23 DDL does NOT include `daily_volume`).
  Future<Database> _openAtVersion(int fromVersion) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: fromVersion,
        onCreate: (d, _) => DatabaseHelper.createSchema(d),
      ),
    );
    // createSchema always builds the current (v23+) DDL, so remove daily_volume
    // to simulate a genuine pre-v23 database for upgrade tests.
    if (fromVersion < 23) {
      await db.execute(
        'ALTER TABLE ${DatabaseTables.muscleStimulus} '
        'RENAME TO muscle_stimulus_backup',
      );
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
          UNIQUE(${DatabaseTables.ownerUserId},
                 ${DatabaseTables.stimulusMuscleGroup},
                 ${DatabaseTables.stimulusDate})
        )
      ''');
      await db.execute(
        'INSERT INTO ${DatabaseTables.muscleStimulus} '
        'SELECT id, owner_user_id, muscle_group, date, daily_stimulus, '
        'rolling_weekly_load, last_set_timestamp, last_set_stimulus, '
        'created_at, updated_at FROM muscle_stimulus_backup',
      );
      await db.execute('DROP TABLE muscle_stimulus_backup');
    }
    return db;
  }

  Future<void> insertV22Row(
    Database db, {
    required String id,
    required String owner,
    double dailyStimulus = 3.5,
  }) => db.insert(DatabaseTables.muscleStimulus, {
    DatabaseTables.stimulusId: id,
    DatabaseTables.ownerUserId: owner,
    DatabaseTables.stimulusMuscleGroup: 'mid-chest',
    DatabaseTables.stimulusDate: '2026-01-15',
    DatabaseTables.stimulusDailyStimulus: dailyStimulus,
    DatabaseTables.stimulusRollingWeeklyLoad: 7.0,
    DatabaseTables.stimulusCreatedAt: '2026-01-15T09:00:00.000Z',
    DatabaseTables.stimulusUpdatedAt: '2026-01-15T09:00:00.000Z',
  });

  // ---------------------------------------------------------------------------
  // Case 1: fresh install includes daily_volume
  // ---------------------------------------------------------------------------

  test(
    'fresh install: muscle_stimulus table has daily_volume column',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 23,
          onCreate: (d, _) => DatabaseHelper.createSchema(d),
        ),
      );

      final info = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(
        columns.contains(DatabaseTables.stimulusDailyVolume),
        isTrue,
        reason: 'fresh-install DDL must include daily_volume',
      );

      // Verify the column default
      final dflt = info.firstWhere(
        (r) => r['name'] == DatabaseTables.stimulusDailyVolume,
      );
      expect(
        dflt['dflt_value'],
        '0.0',
        reason: 'daily_volume default must be 0.0',
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 2: upgrade from v22 adds the column
  // ---------------------------------------------------------------------------

  test(
    'upgrade from v22: daily_volume column added to muscle_stimulus',
    () async {
      final db = await _openAtVersion(22);

      // Confirm the column is absent before the migration
      final infoBefore = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columnsBefore = infoBefore.map((r) => r['name'] as String).toSet();
      expect(
        columnsBefore.contains(DatabaseTables.stimulusDailyVolume),
        isFalse,
        reason: 'pre-migration schema must not have daily_volume',
      );

      // Run the v23 migration
      await DatabaseHelper.runOnUpgradeForTesting(db, 22, 23);

      final infoAfter = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columnsAfter = infoAfter.map((r) => r['name'] as String).toSet();
      expect(
        columnsAfter.contains(DatabaseTables.stimulusDailyVolume),
        isTrue,
        reason: 'post-migration schema must include daily_volume',
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 3: existing v22 rows survive with daily_volume == 0.0
  // ---------------------------------------------------------------------------

  test(
    'upgrade from v22: existing rows survive with daily_volume = 0.0',
    () async {
      final db = await _openAtVersion(22);
      await insertV22Row(db, id: 'stim-pre', owner: 'user-1');

      await DatabaseHelper.runOnUpgradeForTesting(db, 22, 23);

      final rows = await db.query(DatabaseTables.muscleStimulus);
      expect(rows.length, 1);
      expect(rows.first[DatabaseTables.stimulusId], 'stim-pre');
      expect(
        rows.first[DatabaseTables.stimulusDailyVolume],
        0.0,
        reason:
            'existing rows must default to daily_volume = 0.0 after v23 '
            'migration; RebuildMuscleStimulusFromWorkoutHistory repopulates '
            'history on the next launch so no backfill is needed',
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 4: new rows can carry a non-zero daily_volume
  // ---------------------------------------------------------------------------

  test(
    'post-v23: rows can be inserted and read back with non-zero daily_volume',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 23,
          onCreate: (d, _) => DatabaseHelper.createSchema(d),
        ),
      );

      await db.insert(DatabaseTables.muscleStimulus, {
        DatabaseTables.stimulusId: 'stim-v23',
        DatabaseTables.ownerUserId: 'user-1',
        DatabaseTables.stimulusMuscleGroup: 'quads',
        DatabaseTables.stimulusDate: '2026-06-04',
        DatabaseTables.stimulusDailyStimulus: 4.0,
        DatabaseTables.stimulusRollingWeeklyLoad: 8.0,
        DatabaseTables.stimulusDailyVolume: 4800.0,
        DatabaseTables.stimulusCreatedAt: '2026-06-04T10:00:00.000Z',
        DatabaseTables.stimulusUpdatedAt: '2026-06-04T10:00:00.000Z',
      });

      final rows = await db.query(DatabaseTables.muscleStimulus);
      expect(rows.length, 1);
      expect(rows.first[DatabaseTables.stimulusDailyVolume], 4800.0);

      await db.close();
    },
  );
}

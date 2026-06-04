// Regression suite for the db v24 schema migration.
//
// Verifies:
//   1. Fresh-install DDL includes the `fatigue_score` column with DEFAULT 0.0.
//   2. Upgrading a v23 database adds the `fatigue_score` column.
//   3. Existing v23 rows survive the upgrade with fatigue_score == 0.0.
//   4. New rows can be inserted and read back with a non-zero fatigue_score.
//
// Note: fatigue_score rows are 0.0 immediately after the migration because
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
  /// creator (so the pre-v24 DDL does NOT include `fatigue_score`).
  Future<Database> _openAtVersion(int fromVersion) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: fromVersion,
        onCreate: (d, _) => DatabaseHelper.createSchema(d),
      ),
    );
    // createSchema always builds the current (v24+) DDL, so remove fatigue_score
    // to simulate a genuine pre-v24 database for upgrade tests.
    if (fromVersion < 24) {
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
          ${DatabaseTables.stimulusDailyVolume} REAL NOT NULL DEFAULT 0.0,
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
        'daily_volume, created_at, updated_at FROM muscle_stimulus_backup',
      );
      await db.execute('DROP TABLE muscle_stimulus_backup');
    }
    return db;
  }

  Future<void> insertV23Row(
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
    DatabaseTables.stimulusDailyVolume: 576.0,
    DatabaseTables.stimulusCreatedAt: '2026-01-15T09:00:00.000Z',
    DatabaseTables.stimulusUpdatedAt: '2026-01-15T09:00:00.000Z',
  });

  // ---------------------------------------------------------------------------
  // Case 1: fresh install includes fatigue_score
  // ---------------------------------------------------------------------------

  test(
    'fresh install: muscle_stimulus table has fatigue_score column',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 24,
          onCreate: (d, _) => DatabaseHelper.createSchema(d),
        ),
      );

      final info = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(
        columns.contains(DatabaseTables.stimulusFatigueScore),
        isTrue,
        reason: 'fresh-install DDL must include fatigue_score',
      );

      final dflt = info.firstWhere(
        (r) => r['name'] == DatabaseTables.stimulusFatigueScore,
      );
      expect(
        dflt['dflt_value'],
        '0.0',
        reason: 'fatigue_score default must be 0.0',
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 2: upgrade from v23 adds the column
  // ---------------------------------------------------------------------------

  test(
    'upgrade from v23: fatigue_score column added to muscle_stimulus',
    () async {
      final db = await _openAtVersion(23);

      final infoBefore = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columnsBefore = infoBefore.map((r) => r['name'] as String).toSet();
      expect(
        columnsBefore.contains(DatabaseTables.stimulusFatigueScore),
        isFalse,
        reason: 'pre-migration schema must not have fatigue_score',
      );

      await DatabaseHelper.runOnUpgradeForTesting(db, 23, 24);

      final infoAfter = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columnsAfter = infoAfter.map((r) => r['name'] as String).toSet();
      expect(
        columnsAfter.contains(DatabaseTables.stimulusFatigueScore),
        isTrue,
        reason: 'post-migration schema must include fatigue_score',
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 3: existing v23 rows survive with fatigue_score == 0.0
  // ---------------------------------------------------------------------------

  test(
    'upgrade from v23: existing rows survive with fatigue_score = 0.0',
    () async {
      final db = await _openAtVersion(23);
      await insertV23Row(db, id: 'stim-pre', owner: 'user-1');

      await DatabaseHelper.runOnUpgradeForTesting(db, 23, 24);

      final rows = await db.query(DatabaseTables.muscleStimulus);
      expect(rows.length, 1);
      expect(rows.first[DatabaseTables.stimulusId], 'stim-pre');
      expect(
        rows.first[DatabaseTables.stimulusFatigueScore],
        0.0,
        reason:
            'existing rows must default to fatigue_score = 0.0 after v24 '
            'migration; RebuildMuscleStimulusFromWorkoutHistory repopulates '
            'history on the next launch so no backfill is needed',
      );
      // Pre-existing columns must be untouched.
      expect(rows.first[DatabaseTables.stimulusDailyVolume], 576.0);

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 4: new rows can carry a non-zero fatigue_score
  // ---------------------------------------------------------------------------

  test(
    'post-v24: rows can be inserted and read back with non-zero fatigue_score',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 24,
          onCreate: (d, _) => DatabaseHelper.createSchema(d),
        ),
      );

      await db.insert(DatabaseTables.muscleStimulus, {
        DatabaseTables.stimulusId: 'stim-v24',
        DatabaseTables.ownerUserId: 'user-1',
        DatabaseTables.stimulusMuscleGroup: 'quads',
        DatabaseTables.stimulusDate: '2026-06-04',
        DatabaseTables.stimulusDailyStimulus: 4.0,
        DatabaseTables.stimulusRollingWeeklyLoad: 8.0,
        DatabaseTables.stimulusDailyVolume: 4800.0,
        DatabaseTables.stimulusFatigueScore: 35.5,
        DatabaseTables.stimulusCreatedAt: '2026-06-04T10:00:00.000Z',
        DatabaseTables.stimulusUpdatedAt: '2026-06-04T10:00:00.000Z',
      });

      final rows = await db.query(DatabaseTables.muscleStimulus);
      expect(rows.length, 1);
      expect(rows.first[DatabaseTables.stimulusFatigueScore], 35.5);

      await db.close();
    },
  );
}

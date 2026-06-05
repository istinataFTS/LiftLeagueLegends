// Regression suite for the db v25 schema migration.
//
// Verifies:
//   1. Fresh-install DDL includes `fatigue_anchor_ts` (INTEGER, nullable).
//   2. Upgrading a v24 database adds the `fatigue_anchor_ts` column.
//   3. Existing v24 rows survive with fatigue_anchor_ts == NULL.
//   4. New rows can be inserted and read back with a non-null fatigue_anchor_ts.
//
// Note: fatigue_anchor_ts is NULL immediately after the migration because
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
  /// creator, then strips `fatigue_anchor_ts` to simulate a pre-v25 database.
  Future<Database> _openAtVersion(int fromVersion) async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: fromVersion,
        onCreate: (d, _) => DatabaseHelper.createSchema(d),
      ),
    );
    if (fromVersion < 25) {
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
          ${DatabaseTables.stimulusFatigueScore} REAL NOT NULL DEFAULT 0.0,
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
        'daily_volume, fatigue_score, created_at, updated_at '
        'FROM muscle_stimulus_backup',
      );
      await db.execute('DROP TABLE muscle_stimulus_backup');
    }
    return db;
  }

  Future<void> insertV24Row(
    Database db, {
    required String id,
    required String owner,
    double fatigueScore = 42.0,
  }) => db.insert(DatabaseTables.muscleStimulus, {
    DatabaseTables.stimulusId: id,
    DatabaseTables.ownerUserId: owner,
    DatabaseTables.stimulusMuscleGroup: 'mid-chest',
    DatabaseTables.stimulusDate: '2026-01-15',
    DatabaseTables.stimulusDailyStimulus: 3.5,
    DatabaseTables.stimulusRollingWeeklyLoad: 7.0,
    DatabaseTables.stimulusDailyVolume: 576.0,
    DatabaseTables.stimulusFatigueScore: fatigueScore,
    DatabaseTables.stimulusCreatedAt: '2026-01-15T09:00:00.000Z',
    DatabaseTables.stimulusUpdatedAt: '2026-01-15T09:00:00.000Z',
  });

  // ---------------------------------------------------------------------------
  // Case 1: fresh install includes fatigue_anchor_ts
  // ---------------------------------------------------------------------------

  test(
    'fresh install: muscle_stimulus table has fatigue_anchor_ts column (nullable INTEGER)',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 25,
          onCreate: (d, _) => DatabaseHelper.createSchema(d),
        ),
      );

      final info = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columns = info.map((r) => r['name'] as String).toSet();
      expect(
        columns.contains(DatabaseTables.stimulusFatigueAnchorTs),
        isTrue,
        reason: 'fresh-install DDL must include fatigue_anchor_ts',
      );

      final col = info.firstWhere(
        (r) => r['name'] == DatabaseTables.stimulusFatigueAnchorTs,
      );
      expect(col['type'], 'INTEGER', reason: 'column type must be INTEGER');
      expect(col['notnull'], 0, reason: 'column must be nullable (notnull=0)');

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 2: upgrade from v24 adds the column
  // ---------------------------------------------------------------------------

  test(
    'upgrade from v24: fatigue_anchor_ts column added to muscle_stimulus',
    () async {
      final db = await _openAtVersion(24);

      final infoBefore = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columnsBefore = infoBefore.map((r) => r['name'] as String).toSet();
      expect(
        columnsBefore.contains(DatabaseTables.stimulusFatigueAnchorTs),
        isFalse,
        reason: 'pre-migration schema must not have fatigue_anchor_ts',
      );

      await DatabaseHelper.runOnUpgradeForTesting(db, 24, 25);

      final infoAfter = await db.rawQuery(
        'PRAGMA table_info(${DatabaseTables.muscleStimulus})',
      );
      final columnsAfter = infoAfter.map((r) => r['name'] as String).toSet();
      expect(
        columnsAfter.contains(DatabaseTables.stimulusFatigueAnchorTs),
        isTrue,
        reason: 'post-migration schema must include fatigue_anchor_ts',
      );

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 3: existing v24 rows survive with fatigue_anchor_ts == NULL
  // ---------------------------------------------------------------------------

  test(
    'upgrade from v24: existing rows survive with fatigue_anchor_ts = NULL',
    () async {
      final db = await _openAtVersion(24);
      await insertV24Row(db, id: 'stim-pre', owner: 'user-1');

      await DatabaseHelper.runOnUpgradeForTesting(db, 24, 25);

      final rows = await db.query(DatabaseTables.muscleStimulus);
      expect(rows.length, 1);
      expect(rows.first[DatabaseTables.stimulusId], 'stim-pre');
      expect(
        rows.first[DatabaseTables.stimulusFatigueAnchorTs],
        isNull,
        reason:
            'existing rows must have fatigue_anchor_ts = NULL after v25 '
            'migration; RebuildMuscleStimulusFromWorkoutHistory repopulates '
            'on the next launch so no backfill is needed',
      );
      // Pre-existing columns must be untouched.
      expect(rows.first[DatabaseTables.stimulusFatigueScore], 42.0);
      expect(rows.first[DatabaseTables.stimulusDailyVolume], 576.0);

      await db.close();
    },
  );

  // ---------------------------------------------------------------------------
  // Case 4: new rows can carry a non-null fatigue_anchor_ts
  // ---------------------------------------------------------------------------

  test(
    'post-v25: rows can be inserted and read back with non-null fatigue_anchor_ts',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 25,
          onCreate: (d, _) => DatabaseHelper.createSchema(d),
        ),
      );

      final anchorMs = DateTime(2026, 6, 2).millisecondsSinceEpoch;

      await db.insert(DatabaseTables.muscleStimulus, {
        DatabaseTables.stimulusId: 'stim-v25',
        DatabaseTables.ownerUserId: 'user-1',
        DatabaseTables.stimulusMuscleGroup: 'mid-chest',
        DatabaseTables.stimulusDate: '2026-06-05',
        DatabaseTables.stimulusDailyStimulus: 4.0,
        DatabaseTables.stimulusRollingWeeklyLoad: 8.0,
        DatabaseTables.stimulusDailyVolume: 4800.0,
        DatabaseTables.stimulusFatigueScore: 60.0,
        DatabaseTables.stimulusFatigueAnchorTs: anchorMs,
        DatabaseTables.stimulusCreatedAt: '2026-06-05T10:00:00.000Z',
        DatabaseTables.stimulusUpdatedAt: '2026-06-05T10:00:00.000Z',
      });

      final rows = await db.query(DatabaseTables.muscleStimulus);
      expect(rows.length, 1);
      expect(rows.first[DatabaseTables.stimulusFatigueAnchorTs], anchorMs);
      expect(rows.first[DatabaseTables.stimulusFatigueScore], 60.0);

      await db.close();
    },
  );
}

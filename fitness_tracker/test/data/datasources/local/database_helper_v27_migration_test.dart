// Regression suite for the db v27 bodyweight-fatigue rebuild trigger.
//
// v27 is a logic-only migration: the bodyweight fatigue/volume formula changed
// (sets logged at weight == 0 now accumulate via a per-rep load floor). Derived
// fatigue is recomputed from workout history, so the upgrade only needs to flag
// a one-time rebuild for the next launch — reusing the same pending-flag +
// bootstrap mechanism introduced in v26.
//
// Verifies that upgrading to v27:
//   1. Sets the pending-stimulus-rebuild flag.
//   2. Leaves user data (exercises, factors) untouched.
//   3. Is idempotent — a second run leaves the flag set to 'true'.
import 'dart:convert';

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

  Future<Database> openV26() {
    return databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 26,
        onCreate: (d, _) => DatabaseHelper.createSchema(d),
      ),
    );
  }

  Future<Map<String, Object?>?> pendingFlag(Database db) async {
    final rows = await db.query(
      DatabaseTables.appMetadata,
      where: '${DatabaseTables.metadataKey} = ?',
      whereArgs: <Object?>[DatabaseTables.metadataPendingStimulusRebuild],
    );
    return rows.isEmpty ? null : rows.first;
  }

  test('sets the pending-stimulus-rebuild flag', () async {
    final db = await openV26();
    expect(await pendingFlag(db), isNull);

    await DatabaseHelper.runOnUpgradeForTesting(db, 26, 27);

    final flag = await pendingFlag(db);
    expect(flag, isNotNull);
    expect(flag![DatabaseTables.metadataValue], 'true');

    await db.close();
  });

  test('leaves existing exercise and factor data untouched', () async {
    final db = await openV26();
    await db.insert(DatabaseTables.exercises, <String, Object?>{
      DatabaseTables.exerciseId: 'squat',
      DatabaseTables.exerciseName: 'Squat',
      DatabaseTables.exerciseMuscleGroups: jsonEncode(<String>['quads']),
      DatabaseTables.exerciseCreatedAt: '2026-01-01T00:00:00.000Z',
      DatabaseTables.exerciseUpdatedAt: '2026-01-01T00:00:00.000Z',
    });
    await db.insert(DatabaseTables.exerciseMuscleFactors, <String, Object?>{
      DatabaseTables.factorId: 'f1',
      DatabaseTables.factorExerciseId: 'squat',
      DatabaseTables.factorMuscleGroup: 'quads',
      DatabaseTables.factorValue: 1.0,
    });

    await DatabaseHelper.runOnUpgradeForTesting(db, 26, 27);

    final exercises = await db.query(DatabaseTables.exercises);
    expect(exercises, hasLength(1));
    expect(exercises.first[DatabaseTables.exerciseMuscleGroups], '["quads"]');
    final factors = await db.query(DatabaseTables.exerciseMuscleFactors);
    expect(factors, hasLength(1));
    expect(factors.first[DatabaseTables.factorValue], 1.0);

    await db.close();
  });

  test('is idempotent — second run keeps the flag set to true', () async {
    final db = await openV26();

    await DatabaseHelper.flagPendingStimulusRebuildV27(db);
    await DatabaseHelper.flagPendingStimulusRebuildV27(db);

    final rows = await db.query(
      DatabaseTables.appMetadata,
      where: '${DatabaseTables.metadataKey} = ?',
      whereArgs: <Object?>[DatabaseTables.metadataPendingStimulusRebuild],
    );
    expect(rows, hasLength(1));
    expect(rows.first[DatabaseTables.metadataValue], 'true');

    await db.close();
  });
}

// Regression suite for the db v26 muscle-taxonomy migration.
//
// Verifies that upgrading a v25 database:
//   1. Collapses granular factor rows onto canonical keys with the MAX rule
//      and no UNIQUE(exercise_id, muscle_group) violation.
//   2. Canonicalises legacy *simple* keys (incl. GATE-1: traps→lower-traps,
//      neck→upper-traps) in both factors and the exercises.muscle_groups JSON.
//   3. De-duplicates the exercises.muscle_groups JSON list.
//   4. Empties muscle_stimulus (it is rebuilt from history on next launch).
//   5. Sets the pending-rebuild flag.
//   6. Is idempotent — a second run changes nothing logically.
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

  Future<Database> openV25() {
    return databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 25,
        onCreate: (d, _) => DatabaseHelper.createSchema(d),
      ),
    );
  }

  Future<void> insertExercise(
    Database db, {
    required String id,
    required String name,
    required List<String> muscleGroups,
  }) {
    return db.insert(DatabaseTables.exercises, <String, Object?>{
      DatabaseTables.exerciseId: id,
      DatabaseTables.exerciseName: name,
      DatabaseTables.exerciseMuscleGroups: jsonEncode(muscleGroups),
      DatabaseTables.exerciseCreatedAt: '2026-01-01T00:00:00.000Z',
      DatabaseTables.exerciseUpdatedAt: '2026-01-01T00:00:00.000Z',
    });
  }

  Future<void> insertFactor(
    Database db, {
    required String id,
    required String exerciseId,
    required String muscleGroup,
    required double factor,
  }) {
    return db.insert(DatabaseTables.exerciseMuscleFactors, <String, Object?>{
      DatabaseTables.factorId: id,
      DatabaseTables.factorExerciseId: exerciseId,
      DatabaseTables.factorMuscleGroup: muscleGroup,
      DatabaseTables.factorValue: factor,
    });
  }

  /// Returns the {canonicalKey: factor} map for an exercise's factor rows.
  Future<Map<String, double>> factorsFor(Database db, String exerciseId) async {
    final rows = await db.query(
      DatabaseTables.exerciseMuscleFactors,
      where: '${DatabaseTables.factorExerciseId} = ?',
      whereArgs: <Object?>[exerciseId],
    );
    return <String, double>{
      for (final r in rows)
        r[DatabaseTables.factorMuscleGroup] as String:
            (r[DatabaseTables.factorValue] as num).toDouble(),
    };
  }

  Future<List<String>> muscleGroupsFor(Database db, String exerciseId) async {
    final rows = await db.query(
      DatabaseTables.exercises,
      columns: <String>[DatabaseTables.exerciseMuscleGroups],
      where: '${DatabaseTables.exerciseId} = ?',
      whereArgs: <Object?>[exerciseId],
    );
    return (jsonDecode(
              rows.first[DatabaseTables.exerciseMuscleGroups] as String,
            )
            as List)
        .cast<String>();
  }

  test(
    'collapses granular factors onto canonical keys with MAX rule',
    () async {
      final db = await openV25();
      await insertExercise(
        db,
        id: 'bench',
        name: 'Bench Press',
        muscleGroups: <String>['mid-chest', 'upper-chest', 'front-delts'],
      );
      // Bench Press granular factors.
      await insertFactor(
        db,
        id: 'f1',
        exerciseId: 'bench',
        muscleGroup: 'mid-chest',
        factor: 1.0,
      );
      await insertFactor(
        db,
        id: 'f2',
        exerciseId: 'bench',
        muscleGroup: 'upper-chest',
        factor: 0.4,
      );
      await insertFactor(
        db,
        id: 'f3',
        exerciseId: 'bench',
        muscleGroup: 'lower-chest',
        factor: 0.4,
      );
      await insertFactor(
        db,
        id: 'f4',
        exerciseId: 'bench',
        muscleGroup: 'front-delts',
        factor: 0.4,
      );
      await insertFactor(
        db,
        id: 'f5',
        exerciseId: 'bench',
        muscleGroup: 'triceps',
        factor: 0.3,
      );

      await DatabaseHelper.runOnUpgradeForTesting(db, 25, 26);

      final factors = await factorsFor(db, 'bench');
      expect(factors, <String, double>{
        'chest': 1.0, // MAX(1.0, 0.4, 0.4)
        'shoulders': 0.4, // front-delts → shoulders
        'triceps': 0.3,
      });

      await db.close();
    },
  );

  test('canonicalises legacy simple keys incl. GATE-1 (traps, neck)', () async {
    final db = await openV25();
    await insertExercise(
      db,
      id: 'lejanka',
      name: 'Lejanka',
      muscleGroups: <String>['chest', 'traps', 'neck', 'hamstring'],
    );
    await insertFactor(
      db,
      id: 'g1',
      exerciseId: 'lejanka',
      muscleGroup: 'chest',
      factor: 1.0,
    );
    await insertFactor(
      db,
      id: 'g2',
      exerciseId: 'lejanka',
      muscleGroup: 'traps',
      factor: 0.5,
    );
    await insertFactor(
      db,
      id: 'g3',
      exerciseId: 'lejanka',
      muscleGroup: 'neck',
      factor: 0.6,
    );

    await DatabaseHelper.runOnUpgradeForTesting(db, 25, 26);

    final factors = await factorsFor(db, 'lejanka');
    expect(factors, <String, double>{
      'chest': 1.0,
      'lower-traps': 0.5, // GATE-1: traps → lower-traps
      'upper-traps': 0.6, // GATE-1: neck → upper-traps
    });

    final groups = await muscleGroupsFor(db, 'lejanka');
    expect(groups, <String>[
      'chest',
      'lower-traps',
      'upper-traps',
      'hamstrings',
    ]);

    await db.close();
  });

  test('de-duplicates the exercises.muscle_groups JSON list', () async {
    final db = await openV25();
    await insertExercise(
      db,
      id: 'multi',
      name: 'Multi',
      muscleGroups: <String>[
        'mid-chest',
        'upper-chest',
        'lower-chest',
        'triceps',
      ],
    );

    await DatabaseHelper.runOnUpgradeForTesting(db, 25, 26);

    // Three chest sub-regions collapse to a single 'chest', order preserved.
    expect(await muscleGroupsFor(db, 'multi'), <String>['chest', 'triceps']);

    await db.close();
  });

  test(
    'skips a row with malformed muscle_groups JSON without aborting',
    () async {
      final db = await openV25();
      // Malformed JSON in an existing row must not abort the whole upgrade.
      await db.insert(DatabaseTables.exercises, <String, Object?>{
        DatabaseTables.exerciseId: 'broken',
        DatabaseTables.exerciseName: 'Broken',
        DatabaseTables.exerciseMuscleGroups: '{not valid json',
        DatabaseTables.exerciseCreatedAt: '2026-01-01T00:00:00.000Z',
        DatabaseTables.exerciseUpdatedAt: '2026-01-01T00:00:00.000Z',
      });
      await insertExercise(
        db,
        id: 'ok',
        name: 'Ok',
        muscleGroups: <String>['mid-chest', 'upper-chest'],
      );

      await DatabaseHelper.runOnUpgradeForTesting(db, 25, 26);

      // The valid row is still canonicalised; the broken row is left untouched.
      expect(await muscleGroupsFor(db, 'ok'), <String>['chest']);
      final brokenRows = await db.query(
        DatabaseTables.exercises,
        columns: <String>[DatabaseTables.exerciseMuscleGroups],
        where: '${DatabaseTables.exerciseId} = ?',
        whereArgs: <Object?>['broken'],
      );
      expect(
        brokenRows.first[DatabaseTables.exerciseMuscleGroups],
        '{not valid json',
      );

      await db.close();
    },
  );

  test('empties muscle_stimulus and sets the pending-rebuild flag', () async {
    final db = await openV25();
    await db.insert(DatabaseTables.muscleStimulus, <String, Object?>{
      DatabaseTables.stimulusId: 's1',
      DatabaseTables.ownerUserId: 'user-1',
      DatabaseTables.stimulusMuscleGroup: 'mid-chest',
      DatabaseTables.stimulusDate: '2026-01-15',
      DatabaseTables.stimulusCreatedAt: '2026-01-15T09:00:00.000Z',
      DatabaseTables.stimulusUpdatedAt: '2026-01-15T09:00:00.000Z',
    });

    await DatabaseHelper.runOnUpgradeForTesting(db, 25, 26);

    expect(await db.query(DatabaseTables.muscleStimulus), isEmpty);

    final flag = await db.query(
      DatabaseTables.appMetadata,
      where: '${DatabaseTables.metadataKey} = ?',
      whereArgs: <Object?>[DatabaseTables.metadataPendingStimulusRebuild],
    );
    expect(flag, hasLength(1));
    expect(flag.first[DatabaseTables.metadataValue], 'true');

    await db.close();
  });

  test('is idempotent — second run produces the same factor tuples', () async {
    final db = await openV25();
    await insertExercise(
      db,
      id: 'bench',
      name: 'Bench Press',
      muscleGroups: <String>['mid-chest', 'front-delts'],
    );
    await insertFactor(
      db,
      id: 'f1',
      exerciseId: 'bench',
      muscleGroup: 'mid-chest',
      factor: 1.0,
    );
    await insertFactor(
      db,
      id: 'f2',
      exerciseId: 'bench',
      muscleGroup: 'upper-chest',
      factor: 0.4,
    );

    await DatabaseHelper.runOnUpgradeForTesting(db, 25, 26);
    final first = await factorsFor(db, 'bench');

    await DatabaseHelper.migrateMuscleTaxonomyToCanonicalV26(db);
    final second = await factorsFor(db, 'bench');

    expect(second, first);
    expect(second, <String, double>{'chest': 1.0});

    await db.close();
  });
}

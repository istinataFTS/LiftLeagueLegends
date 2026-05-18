// Regression suite for the db v21 data migration
// (`DatabaseHelper.rewriteDefaultCatalogIdsToDeterministic`).
//
// Verifies that pre-existing default exercise/meal rows (random v4 ids) are
// rewritten to their deterministic name-derived id, that all child
// references are repointed, and that the migration is idempotent,
// index-safe and orphan-free — including the cross-owner collapse and the
// `exercise_muscle_factors` UNIQUE(exercise_id, muscle_group) dedupe.
import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/utils/deterministic_catalog_id.dart';
import 'package:fitness_tracker/data/datasources/local/database_helper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database db;

  setUp(() async {
    db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (d, _) => DatabaseHelper.createSchema(d),
      ),
    );
  });

  tearDown(() async => db.close());

  Future<void> insertExercise(String id, String name, {String owner = ''}) =>
      db.insert(DatabaseTables.exercises, {
        DatabaseTables.exerciseId: id,
        DatabaseTables.ownerUserId: owner,
        DatabaseTables.exerciseName: name,
        DatabaseTables.exerciseMuscleGroups: '["chest"]',
        DatabaseTables.exerciseCreatedAt: '2026-01-01T09:00:00.000',
        DatabaseTables.exerciseUpdatedAt: '2026-01-01T10:00:00.000',
        DatabaseTables.exerciseSyncStatus: 'localOnly',
      });

  Future<void> insertSet(String id, String exerciseId) =>
      db.insert(DatabaseTables.workoutSets, {
        DatabaseTables.setId: id,
        DatabaseTables.setExerciseId: exerciseId,
        DatabaseTables.setReps: 10,
        DatabaseTables.setWeight: 50.0,
        DatabaseTables.setIntensity: 5,
        DatabaseTables.setDate: '2026-01-02',
        DatabaseTables.setCreatedAt: '2026-01-02T10:00:00.000',
        DatabaseTables.setUpdatedAt: '2026-01-02T10:00:00.000',
        DatabaseTables.setSyncStatus: 'localOnly',
      });

  Future<void> insertFactor(String exerciseId, String muscle) =>
      db.insert(DatabaseTables.exerciseMuscleFactors, {
        DatabaseTables.factorId: '$exerciseId-$muscle',
        DatabaseTables.factorExerciseId: exerciseId,
        DatabaseTables.factorMuscleGroup: muscle,
        DatabaseTables.factorValue: 1.0,
      });

  Future<void> insertMeal(String id, String name, {String owner = ''}) =>
      db.insert(DatabaseTables.meals, {
        DatabaseTables.mealId: id,
        DatabaseTables.ownerUserId: owner,
        DatabaseTables.mealName: name,
        DatabaseTables.mealServingSize: 100.0,
        DatabaseTables.mealCarbsPer100g: 0.0,
        DatabaseTables.mealProteinPer100g: 31.0,
        DatabaseTables.mealFatPer100g: 3.6,
        DatabaseTables.mealCaloriesPer100g: 156.4,
        DatabaseTables.mealCreatedAt: '2026-01-01T09:00:00.000',
        DatabaseTables.mealUpdatedAt: '2026-01-01T10:00:00.000',
        DatabaseTables.mealSyncStatus: 'localOnly',
      });

  Future<void> insertLog(String id, String mealId) =>
      db.insert(DatabaseTables.nutritionLogs, {
        DatabaseTables.nutritionLogId: id,
        DatabaseTables.nutritionLogMealId: mealId,
        DatabaseTables.nutritionLogMealName: 'Chicken Breast',
        DatabaseTables.nutritionLogCarbs: 0.0,
        DatabaseTables.nutritionLogProtein: 31.0,
        DatabaseTables.nutritionLogFat: 3.6,
        DatabaseTables.nutritionLogCalories: 156.4,
        DatabaseTables.nutritionLogDate: '2026-01-02',
        DatabaseTables.nutritionLogCreatedAt: '2026-01-02T10:00:00.000',
        DatabaseTables.nutritionLogUpdatedAt: '2026-01-02T10:00:00.000',
        DatabaseTables.nutritionLogSyncStatus: 'localOnly',
      });

  final benchId = DeterministicCatalogId.fromName('Bench Press');
  final chickenId = DeterministicCatalogId.fromName('Chicken Breast');

  test('rewrites default exercise id and repoints workout_sets', () async {
    await insertExercise('old-rand-1', 'Bench Press');
    await insertSet('set-1', 'old-rand-1');

    await DatabaseHelper.rewriteDefaultCatalogIdsToDeterministic(db);

    final ex = await db.query(DatabaseTables.exercises);
    expect(ex.single[DatabaseTables.exerciseId], benchId);

    final sets = await db.query(DatabaseTables.workoutSets);
    expect(sets.single[DatabaseTables.setExerciseId], benchId);
  });

  test('is idempotent — a second run is a no-op', () async {
    await insertExercise('old-rand-1', 'Bench Press');
    await insertSet('set-1', 'old-rand-1');

    await DatabaseHelper.rewriteDefaultCatalogIdsToDeterministic(db);
    await DatabaseHelper.rewriteDefaultCatalogIdsToDeterministic(db);

    final ex = await db.query(DatabaseTables.exercises);
    expect(ex.length, 1);
    expect(ex.single[DatabaseTables.exerciseId], benchId);
    final sets = await db.query(DatabaseTables.workoutSets);
    expect(sets.single[DatabaseTables.setExerciseId], benchId);
  });

  test('collapses the same default across owners onto one row', () async {
    await insertExercise('guest-bench', 'Bench Press', owner: '');
    await insertExercise('user-bench', 'Bench Press', owner: 'user-1');
    await insertSet('set-guest', 'guest-bench');
    await insertSet('set-user', 'user-bench');

    await DatabaseHelper.rewriteDefaultCatalogIdsToDeterministic(db);

    final ex = await db.query(DatabaseTables.exercises);
    expect(ex.length, 1);
    expect(ex.single[DatabaseTables.exerciseId], benchId);

    final sets = await db.query(DatabaseTables.workoutSets);
    expect(
      sets.map((s) => s[DatabaseTables.setExerciseId]).toSet(),
      {benchId},
      reason: 'both owners\' history must repoint to the surviving row',
    );
  });

  test('dedupes exercise_muscle_factors on UNIQUE conflict', () async {
    // Survivor already lives at the deterministic id with a chest factor;
    // a stale random-id row also has a chest factor.
    await insertExercise(benchId, 'Bench Press');
    await insertExercise('old-rand-1', 'Bench Press', owner: 'user-1');
    await insertFactor(benchId, 'chest');
    await insertFactor('old-rand-1', 'chest');
    await insertFactor('old-rand-1', 'triceps');

    await DatabaseHelper.rewriteDefaultCatalogIdsToDeterministic(db);

    final factors = await db.query(
      DatabaseTables.exerciseMuscleFactors,
      where: '${DatabaseTables.factorExerciseId} = ?',
      whereArgs: [benchId],
    );
    final muscles =
        factors.map((f) => f[DatabaseTables.factorMuscleGroup]).toList()
          ..sort();
    expect(muscles, ['chest', 'triceps']);

    // No orphaned factor rows pointing at the dropped id.
    final orphans = await db.query(
      DatabaseTables.exerciseMuscleFactors,
      where: '${DatabaseTables.factorExerciseId} = ?',
      whereArgs: ['old-rand-1'],
    );
    expect(orphans, isEmpty);
  });

  test('rewrites default meal id and repoints nutrition_logs', () async {
    await insertMeal('old-meal-1', 'Chicken Breast');
    await insertLog('log-1', 'old-meal-1');

    await DatabaseHelper.rewriteDefaultCatalogIdsToDeterministic(db);

    final meals = await db.query(DatabaseTables.meals);
    expect(meals.single[DatabaseTables.mealId], chickenId);

    final logs = await db.query(DatabaseTables.nutritionLogs);
    expect(logs.single[DatabaseTables.nutritionLogMealId], chickenId);
  });

  test('leaves user-created non-default rows untouched', () async {
    await insertExercise('custom-1', 'My Secret Lift', owner: 'user-1');

    await DatabaseHelper.rewriteDefaultCatalogIdsToDeterministic(db);

    final ex = await db.query(DatabaseTables.exercises);
    expect(ex.single[DatabaseTables.exerciseId], 'custom-1');
  });
}

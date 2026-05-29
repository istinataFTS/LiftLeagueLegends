// Regression suite for the db v22 data migration
// (`DatabaseHelper.purgeGuestOwnedRowsAndCatalogFlags`).
//
// Verifies that guest-owned rows are destructively purged from every
// user-scoped table, that the two guest-bucket `catalog_init_*` flags are
// removed from `app_metadata`, that authenticated-user data and flags are
// left alone, and that `exercise_muscle_factors` rows pointed at deleted
// guest exercises are removed alongside their parent (independent of the
// FK cascade, which the v17/v18 table recreations may have disturbed).
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

  Future<void> insertExercise(
    String id,
    String name, {
    required String owner,
  }) => db.insert(DatabaseTables.exercises, {
    DatabaseTables.exerciseId: id,
    DatabaseTables.ownerUserId: owner,
    DatabaseTables.exerciseName: name,
    DatabaseTables.exerciseMuscleGroups: '["chest"]',
    DatabaseTables.exerciseCreatedAt: '2026-01-01T09:00:00.000',
    DatabaseTables.exerciseUpdatedAt: '2026-01-01T10:00:00.000',
    DatabaseTables.exerciseSyncStatus: 'localOnly',
  });

  Future<void> insertMeal(String id, String name, {required String owner}) =>
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

  Future<void> insertSet(
    String id,
    String exerciseId, {
    required String owner,
  }) => db.insert(DatabaseTables.workoutSets, {
    DatabaseTables.setId: id,
    DatabaseTables.ownerUserId: owner,
    DatabaseTables.setExerciseId: exerciseId,
    DatabaseTables.setReps: 10,
    DatabaseTables.setWeight: 50.0,
    DatabaseTables.setIntensity: 5,
    DatabaseTables.setDate: '2026-01-02',
    DatabaseTables.setCreatedAt: '2026-01-02T10:00:00.000',
    DatabaseTables.setUpdatedAt: '2026-01-02T10:00:00.000',
    DatabaseTables.setSyncStatus: 'localOnly',
  });

  Future<void> insertLog(String id, String mealId, {required String owner}) =>
      db.insert(DatabaseTables.nutritionLogs, {
        DatabaseTables.nutritionLogId: id,
        DatabaseTables.ownerUserId: owner,
        DatabaseTables.nutritionLogMealId: mealId,
        DatabaseTables.nutritionLogMealName: 'Test Meal',
        DatabaseTables.nutritionLogCarbs: 0.0,
        DatabaseTables.nutritionLogProtein: 31.0,
        DatabaseTables.nutritionLogFat: 3.6,
        DatabaseTables.nutritionLogCalories: 156.4,
        DatabaseTables.nutritionLogDate: '2026-01-02',
        DatabaseTables.nutritionLogCreatedAt: '2026-01-02T10:00:00.000',
        DatabaseTables.nutritionLogUpdatedAt: '2026-01-02T10:00:00.000',
        DatabaseTables.nutritionLogSyncStatus: 'localOnly',
      });

  Future<void> insertStimulus(
    String id,
    String muscle, {
    required String owner,
  }) => db.insert(DatabaseTables.muscleStimulus, {
    DatabaseTables.stimulusId: id,
    DatabaseTables.ownerUserId: owner,
    DatabaseTables.stimulusMuscleGroup: muscle,
    DatabaseTables.stimulusDate: '2026-01-02',
    DatabaseTables.stimulusDailyStimulus: 1.0,
    DatabaseTables.stimulusRollingWeeklyLoad: 1.0,
    DatabaseTables.stimulusCreatedAt: '2026-01-02T10:00:00.000',
    DatabaseTables.stimulusUpdatedAt: '2026-01-02T10:00:00.000',
  });

  Future<void> insertFactor(String exerciseId, String muscle) =>
      db.insert(DatabaseTables.exerciseMuscleFactors, {
        DatabaseTables.factorId: '$exerciseId-$muscle',
        DatabaseTables.factorExerciseId: exerciseId,
        DatabaseTables.factorMuscleGroup: muscle,
        DatabaseTables.factorValue: 1.0,
      });

  Future<void> insertMetadata(String key, String value) =>
      db.insert(DatabaseTables.appMetadata, {
        DatabaseTables.metadataKey: key,
        DatabaseTables.metadataValue: value,
        DatabaseTables.metadataUpdatedAt: '2026-01-01T10:00:00.000',
      });

  test(
    'case A — fresh install: purge entry point is a clean no-op on an empty db',
    () async {
      await DatabaseHelper.purgeGuestOwnedRowsAndCatalogFlags(db);

      expect(await db.query(DatabaseTables.exercises), isEmpty);
      expect(await db.query(DatabaseTables.meals), isEmpty);
      expect(await db.query(DatabaseTables.workoutSets), isEmpty);
      expect(await db.query(DatabaseTables.nutritionLogs), isEmpty);
      expect(await db.query(DatabaseTables.muscleStimulus), isEmpty);
      expect(await db.query(DatabaseTables.exerciseMuscleFactors), isEmpty);
      expect(await db.query(DatabaseTables.appMetadata), isEmpty);
    },
  );

  test(
    'case B — upgrade from v21: guest rows destroyed, authenticated rows kept',
    () async {
      const uid = 'user-1';

      await insertExercise('guest-bench', 'Bench Press', owner: '');
      await insertExercise('guest-squat', 'Squat', owner: '');
      await insertExercise('user-bench', 'Bench Press', owner: uid);

      await insertMeal('guest-chicken', 'Chicken Breast', owner: '');
      await insertMeal('guest-rice', 'Rice', owner: '');
      await insertMeal('user-chicken', 'Chicken Breast', owner: uid);

      await insertSet('user-set-1', 'user-bench', owner: uid);
      await insertLog('user-log-1', 'user-chicken', owner: uid);
      await insertStimulus('user-stim-1', 'chest', owner: uid);

      await insertMetadata('catalog_init_exercises_', 'true');
      await insertMetadata('catalog_init_meals_', 'true');
      await insertMetadata('catalog_init_exercises_$uid', 'true');

      await DatabaseHelper.purgeGuestOwnedRowsAndCatalogFlags(db);

      final ex = await db.query(DatabaseTables.exercises);
      expect(ex.length, 1);
      expect(ex.single[DatabaseTables.exerciseId], 'user-bench');

      final meals = await db.query(DatabaseTables.meals);
      expect(meals.length, 1);
      expect(meals.single[DatabaseTables.mealId], 'user-chicken');

      final sets = await db.query(DatabaseTables.workoutSets);
      expect(sets.length, 1);
      expect(sets.single[DatabaseTables.setId], 'user-set-1');

      final logs = await db.query(DatabaseTables.nutritionLogs);
      expect(logs.length, 1);
      expect(logs.single[DatabaseTables.nutritionLogId], 'user-log-1');

      final stim = await db.query(DatabaseTables.muscleStimulus);
      expect(stim.length, 1);
      expect(stim.single[DatabaseTables.stimulusId], 'user-stim-1');

      final metaKeys = (await db.query(
        DatabaseTables.appMetadata,
      )).map((r) => r[DatabaseTables.metadataKey]).toSet();
      expect(
        metaKeys,
        {'catalog_init_exercises_$uid'},
        reason:
            'authenticated-user catalog-init flag must survive; only the '
            'empty-owner-suffix guest flags are wiped',
      );
    },
  );

  test('case C — no guest data present: migration is a no-op', () async {
    const uid = 'user-1';

    await insertExercise('user-bench', 'Bench Press', owner: uid);
    await insertMeal('user-chicken', 'Chicken Breast', owner: uid);
    await insertSet('user-set-1', 'user-bench', owner: uid);
    await insertLog('user-log-1', 'user-chicken', owner: uid);
    await insertMetadata('catalog_init_exercises_$uid', 'true');

    await DatabaseHelper.purgeGuestOwnedRowsAndCatalogFlags(db);

    expect((await db.query(DatabaseTables.exercises)).length, 1);
    expect((await db.query(DatabaseTables.meals)).length, 1);
    expect((await db.query(DatabaseTables.workoutSets)).length, 1);
    expect((await db.query(DatabaseTables.nutritionLogs)).length, 1);

    final metaKeys = (await db.query(
      DatabaseTables.appMetadata,
    )).map((r) => r[DatabaseTables.metadataKey]).toSet();
    expect(metaKeys, {'catalog_init_exercises_$uid'});
  });

  test(
    'case D — exercise_muscle_factors of guest exercises are removed too',
    () async {
      const uid = 'user-1';

      await insertExercise('guest-bench', 'Bench Press', owner: '');
      await insertFactor('guest-bench', 'chest');
      await insertFactor('guest-bench', 'triceps');

      await insertExercise('user-bench', 'Bench Press', owner: uid);
      await insertFactor('user-bench', 'chest');

      await DatabaseHelper.purgeGuestOwnedRowsAndCatalogFlags(db);

      final ex = await db.query(DatabaseTables.exercises);
      expect(ex.length, 1);
      expect(ex.single[DatabaseTables.exerciseId], 'user-bench');

      final factors = await db.query(DatabaseTables.exerciseMuscleFactors);
      expect(
        factors.length,
        1,
        reason:
            'guest-exercise factor rows must be purged regardless of '
            'whether the FK cascade survived the v17/v18 recreations',
      );
      expect(factors.single[DatabaseTables.factorExerciseId], 'user-bench');
    },
  );
}

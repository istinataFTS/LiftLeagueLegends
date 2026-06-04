import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:get_it/get_it.dart';
import 'package:uuid/uuid.dart';

import '../core/auth/auth_session_service.dart';
import '../core/config/app_sync_policy.dart';
import '../core/enums/data_source_preference.dart';
import '../core/enums/sync_trigger.dart';
import '../core/errors/failures.dart';
import '../core/session/session_sync_service.dart';
import '../core/sync/sync_orchestrator.dart';
import '../domain/entities/app_session.dart';
import '../domain/entities/app_settings.dart';
import '../domain/entities/app_user.dart';
import '../domain/entities/exercise.dart';
import '../domain/entities/initial_cloud_migration_state.dart';
import '../domain/entities/meal.dart';
import '../domain/entities/muscle_factor.dart';
import '../domain/entities/muscle_stimulus.dart';
import '../domain/entities/nutrition_log.dart';
import '../domain/entities/stimulus_calculation_rules.dart';
import '../domain/entities/workout_set.dart';
import '../domain/repositories/app_session_repository.dart';
import '../domain/repositories/app_settings_repository.dart';
import '../domain/repositories/exercise_repository.dart';
import '../domain/repositories/meal_repository.dart';
import '../domain/repositories/muscle_factor_repository.dart';
import '../domain/repositories/muscle_stimulus_repository.dart';
import '../domain/repositories/nutrition_log_repository.dart';
import '../domain/repositories/workout_set_repository.dart';

bool get isWebDemoMode => kIsWeb;

Future<void> registerWebDemoOverrides(GetIt sl) async {
  if (!kIsWeb) {
    return;
  }

  final store = WebDemoStore.seeded();

  await _replaceRegistration<AppSessionRepository>(
    sl,
    () => WebDemoAppSessionRepository(store),
  );
  await _replaceRegistration<AppSettingsRepository>(
    sl,
    () => WebDemoAppSettingsRepository(store),
  );
  await _replaceRegistration<WorkoutSetRepository>(
    sl,
    () => WebDemoWorkoutSetRepository(store),
  );
  await _replaceRegistration<ExerciseRepository>(
    sl,
    () => WebDemoExerciseRepository(store),
  );
  await _replaceRegistration<MealRepository>(
    sl,
    () => WebDemoMealRepository(store),
  );
  await _replaceRegistration<NutritionLogRepository>(
    sl,
    () => WebDemoNutritionLogRepository(store),
  );
  await _replaceRegistration<MuscleFactorRepository>(
    sl,
    () => WebDemoMuscleFactorRepository(store),
  );
  await _replaceRegistration<MuscleStimulusRepository>(
    sl,
    () => WebDemoMuscleStimulusRepository(store),
  );
  await _replaceRegistration<SessionSyncService>(
    sl,
    () => WebDemoSessionSyncService(store),
  );
  await _replaceRegistration<AuthSessionService>(
    sl,
    () => WebDemoAuthSessionService(store),
  );
  await _replaceRegistration<SyncOrchestrator>(
    sl,
    () => const WebDemoSyncOrchestrator(),
  );
}

Future<void> _replaceRegistration<T extends Object>(
  GetIt sl,
  T Function() factory,
) async {
  if (sl.isRegistered<T>()) {
    await sl.unregister<T>();
  }
  sl.registerLazySingleton<T>(factory);
}

class WebDemoStore {
  WebDemoStore({
    this.session,
    required this.settings,
    required this.workoutSets,
    required this.exercises,
    required this.meals,
    required this.nutritionLogs,
    required this.muscleFactors,
    required this.muscleStimulusRecords,
    this.migrationState,
  });

  AppSession? session;
  AppSettings settings;
  InitialCloudMigrationState? migrationState;

  List<WorkoutSet> workoutSets;
  List<Exercise> exercises;
  List<Meal> meals;
  List<NutritionLog> nutritionLogs;
  List<MuscleFactor> muscleFactors;
  List<MuscleStimulus> muscleStimulusRecords;

  factory WebDemoStore.seeded() {
    final now = DateTime.now();
    final today = _startOfDay(now);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));
    final threeDaysAgo = today.subtract(const Duration(days: 3));
    final eightDaysAgo = today.subtract(const Duration(days: 8));

    const benchId = 'exercise-bench-press';
    const rowId = 'exercise-barbell-row';
    const squatId = 'exercise-back-squat';
    const overheadPressId = 'exercise-overhead-press';
    const pullUpId = 'exercise-pull-up';

    final exercises = <Exercise>[
      Exercise(
        id: benchId,
        name: 'Bench Press',
        muscleGroups: const <String>['mid-chest', 'triceps', 'front-delts'],
        createdAt: threeDaysAgo,
      ),
      Exercise(
        id: rowId,
        name: 'Barbell Row',
        muscleGroups: const <String>['lats', 'middle-traps', 'biceps'],
        createdAt: threeDaysAgo,
      ),
      Exercise(
        id: squatId,
        name: 'Back Squat',
        muscleGroups: const <String>['quads', 'glutes', 'hamstrings'],
        createdAt: twoDaysAgo,
      ),
      Exercise(
        id: overheadPressId,
        name: 'Overhead Press',
        muscleGroups: const <String>['front-delts', 'side-delts', 'triceps'],
        createdAt: twoDaysAgo,
      ),
      Exercise(
        id: pullUpId,
        name: 'Pull Up',
        muscleGroups: const <String>['lats', 'biceps', 'rear-delts'],
        createdAt: yesterday,
      ),
    ];

    final workoutSets = <WorkoutSet>[
      WorkoutSet(
        id: 'set-1',
        exerciseId: benchId,
        reps: 8,
        weight: 80,
        intensity: 4,
        date: today.add(const Duration(hours: 9)),
        createdAt: today.add(const Duration(hours: 9)),
      ),
      WorkoutSet(
        id: 'set-2',
        exerciseId: benchId,
        reps: 6,
        weight: 85,
        intensity: 5,
        date: today.add(const Duration(hours: 9, minutes: 10)),
        createdAt: today.add(const Duration(hours: 9, minutes: 10)),
      ),
      WorkoutSet(
        id: 'set-3',
        exerciseId: rowId,
        reps: 10,
        weight: 70,
        intensity: 4,
        date: yesterday.add(const Duration(hours: 18)),
        createdAt: yesterday.add(const Duration(hours: 18)),
      ),
      WorkoutSet(
        id: 'set-4',
        exerciseId: squatId,
        reps: 5,
        weight: 110,
        intensity: 5,
        date: twoDaysAgo.add(const Duration(hours: 19)),
        createdAt: twoDaysAgo.add(const Duration(hours: 19)),
      ),
      WorkoutSet(
        id: 'set-5',
        exerciseId: overheadPressId,
        reps: 8,
        weight: 45,
        intensity: 3,
        date: threeDaysAgo.add(const Duration(hours: 17)),
        createdAt: threeDaysAgo.add(const Duration(hours: 17)),
      ),
      WorkoutSet(
        id: 'set-6',
        exerciseId: pullUpId,
        reps: 9,
        weight: 0,
        intensity: 4,
        date: eightDaysAgo.add(const Duration(hours: 16)),
        createdAt: eightDaysAgo.add(const Duration(hours: 16)),
      ),
    ];

    final meals = <Meal>[
      Meal(
        id: 'meal-1',
        name: 'Chicken Rice Bowl',
        servingSizeGrams: 350,
        carbsPer100g: 24,
        proteinPer100g: 12,
        fatPer100g: 5,
        caloriesPer100g: 185,
        createdAt: threeDaysAgo,
      ),
      Meal(
        id: 'meal-2',
        name: 'Greek Yogurt Bowl',
        servingSizeGrams: 220,
        carbsPer100g: 8,
        proteinPer100g: 11,
        fatPer100g: 2,
        caloriesPer100g: 90,
        createdAt: twoDaysAgo,
      ),
      Meal(
        id: 'meal-3',
        name: 'Oats and Banana',
        servingSizeGrams: 180,
        carbsPer100g: 27,
        proteinPer100g: 6,
        fatPer100g: 4,
        caloriesPer100g: 170,
        createdAt: yesterday,
      ),
    ];

    final nutritionLogs = <NutritionLog>[
      NutritionLog(
        id: 'log-1',
        mealId: 'meal-2',
        mealName: 'Greek Yogurt Bowl',
        gramsConsumed: 220,
        proteinGrams: 24.2,
        carbsGrams: 17.6,
        fatGrams: 4.4,
        calories: 198,
        loggedAt: today.add(const Duration(hours: 8)),
        createdAt: today.add(const Duration(hours: 8)),
      ),
      NutritionLog(
        id: 'log-2',
        mealId: 'meal-1',
        mealName: 'Chicken Rice Bowl',
        gramsConsumed: 350,
        proteinGrams: 42,
        carbsGrams: 84,
        fatGrams: 17.5,
        calories: 647.5,
        loggedAt: today.add(const Duration(hours: 13)),
        createdAt: today.add(const Duration(hours: 13)),
      ),
      NutritionLog(
        id: 'log-3',
        mealId: null,
        mealName: 'Protein Shake',
        gramsConsumed: null,
        proteinGrams: 30,
        carbsGrams: 6,
        fatGrams: 3,
        calories: 171,
        loggedAt: yesterday.add(const Duration(hours: 20)),
        createdAt: yesterday.add(const Duration(hours: 20)),
      ),
    ];

    final muscleFactors = <MuscleFactor>[
      const MuscleFactor(
        id: 'factor-1',
        exerciseId: benchId,
        muscleGroup: 'mid-chest',
        factor: 0.90,
      ),
      const MuscleFactor(
        id: 'factor-2',
        exerciseId: benchId,
        muscleGroup: 'triceps',
        factor: 0.55,
      ),
      const MuscleFactor(
        id: 'factor-3',
        exerciseId: benchId,
        muscleGroup: 'front-delts',
        factor: 0.35,
      ),
      const MuscleFactor(
        id: 'factor-4',
        exerciseId: rowId,
        muscleGroup: 'lats',
        factor: 0.85,
      ),
      const MuscleFactor(
        id: 'factor-5',
        exerciseId: rowId,
        muscleGroup: 'middle-traps',
        factor: 0.60,
      ),
      const MuscleFactor(
        id: 'factor-6',
        exerciseId: rowId,
        muscleGroup: 'biceps',
        factor: 0.45,
      ),
      const MuscleFactor(
        id: 'factor-7',
        exerciseId: squatId,
        muscleGroup: 'quads',
        factor: 0.90,
      ),
      const MuscleFactor(
        id: 'factor-8',
        exerciseId: squatId,
        muscleGroup: 'glutes',
        factor: 0.60,
      ),
      const MuscleFactor(
        id: 'factor-9',
        exerciseId: squatId,
        muscleGroup: 'hamstrings',
        factor: 0.35,
      ),
      const MuscleFactor(
        id: 'factor-10',
        exerciseId: overheadPressId,
        muscleGroup: 'front-delts',
        factor: 0.85,
      ),
      const MuscleFactor(
        id: 'factor-11',
        exerciseId: overheadPressId,
        muscleGroup: 'side-delts',
        factor: 0.55,
      ),
      const MuscleFactor(
        id: 'factor-12',
        exerciseId: overheadPressId,
        muscleGroup: 'triceps',
        factor: 0.45,
      ),
      const MuscleFactor(
        id: 'factor-13',
        exerciseId: pullUpId,
        muscleGroup: 'lats',
        factor: 0.85,
      ),
      const MuscleFactor(
        id: 'factor-14',
        exerciseId: pullUpId,
        muscleGroup: 'biceps',
        factor: 0.60,
      ),
      const MuscleFactor(
        id: 'factor-15',
        exerciseId: pullUpId,
        muscleGroup: 'rear-delts',
        factor: 0.25,
      ),
    ];

    final muscleStimulusRecords = _buildSeededMuscleStimulusRecords(
      workoutSets: workoutSets,
      muscleFactors: muscleFactors,
      now: now,
    );

    return WebDemoStore(
      settings: const AppSettings.defaults(),
      workoutSets: workoutSets,
      exercises: exercises,
      meals: meals,
      nutritionLogs: nutritionLogs,
      muscleFactors: muscleFactors,
      muscleStimulusRecords: muscleStimulusRecords,
    );
  }

  void claimUnownedDemoData(String userId) {
    workoutSets = workoutSets
        .map(
          (set) =>
              set.ownerUserId == null ? set.copyWith(ownerUserId: userId) : set,
        )
        .toList();
    exercises = exercises
        .map(
          (exercise) => exercise.ownerUserId == null
              ? exercise.copyWith(ownerUserId: userId)
              : exercise,
        )
        .toList();
    meals = meals
        .map(
          (meal) => meal.ownerUserId == null
              ? meal.copyWith(ownerUserId: userId)
              : meal,
        )
        .toList();
    nutritionLogs = nutritionLogs
        .map(
          (log) =>
              log.ownerUserId == null ? log.copyWith(ownerUserId: userId) : log,
        )
        .toList();
  }
}

class WebDemoAppSessionRepository implements AppSessionRepository {
  WebDemoAppSessionRepository(this._store);

  final WebDemoStore _store;

  @override
  AppSyncPolicy get syncPolicy => AppSyncPolicy.productionDefault;

  @override
  Future<Either<Failure, AppSession>> getCurrentSession() async {
    final session = _store.session;
    if (session == null) {
      return const Left(
        SessionLookupFailure(message: 'no authenticated demo session'),
      );
    }
    return Right(session);
  }

  @override
  Future<Either<Failure, void>> startAuthenticatedSession(
    AppUser user, {
    bool requiresInitialCloudMigration = true,
  }) async {
    _store.session = AppSession(
      user: user,
      requiresInitialCloudMigration: requiresInitialCloudMigration,
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> completeInitialCloudMigration() async {
    final existing = _store.session;
    if (existing != null) {
      _store.session = existing.copyWith(requiresInitialCloudMigration: false);
    }
    _store.migrationState = null;
    return const Right(null);
  }

  @override
  Future<Either<Failure, InitialCloudMigrationState?>>
  getInitialCloudMigrationState() async {
    return Right(_store.migrationState);
  }

  @override
  Future<Either<Failure, void>> saveInitialCloudMigrationState(
    InitialCloudMigrationState state,
  ) async {
    _store.migrationState = state;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearInitialCloudMigrationState() async {
    _store.migrationState = null;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> recordSuccessfulCloudSync(
    DateTime syncedAt,
  ) async {
    final existing = _store.session;
    if (existing != null) {
      _store.session = existing.copyWith(lastCloudSyncAt: syncedAt);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearSession() async {
    _store.session = null;
    _store.migrationState = null;
    return const Right(null);
  }
}

class WebDemoAppSettingsRepository implements AppSettingsRepository {
  WebDemoAppSettingsRepository(this._store);

  final WebDemoStore _store;
  final StreamController<AppSettings> _settingsController =
      StreamController<AppSettings>.broadcast();

  @override
  Future<Either<Failure, AppSettings>> getSettings() async {
    return Right(_store.settings);
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettings settings) async {
    _store.settings = settings;
    _settingsController.add(settings);
    return const Right(null);
  }

  @override
  Stream<AppSettings> watchSettings() {
    return Stream<AppSettings>.multi((listener) {
      listener.add(_store.settings);
      final sub = _settingsController.stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = () async {
        await sub.cancel();
      };
    });
  }
}

class WebDemoWorkoutSetRepository implements WorkoutSetRepository {
  WebDemoWorkoutSetRepository(this._store);

  final WebDemoStore _store;

  @override
  Future<Either<Failure, List<WorkoutSet>>> getAllSets({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return Right(_sortedWorkoutSets(_store.workoutSets));
  }

  @override
  Future<Either<Failure, WorkoutSet?>> getSetById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return Right(_firstWhereOrNull(_store.workoutSets, (set) => set.id == id));
  }

  @override
  Future<Either<Failure, List<WorkoutSet>>> getSetsByExerciseId(
    String exerciseId, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return Right(
      _sortedWorkoutSets(
        _store.workoutSets
            .where((set) => set.exerciseId == exerciseId)
            .toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, List<WorkoutSet>>> getSetsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
    int? limit,
  }) async {
    final start = _startOfDay(startDate);
    final end = _endOfDay(endDate);

    return Right(
      _sortedWorkoutSets(
        _store.workoutSets.where((set) {
          return !set.date.isBefore(start) && !set.date.isAfter(end);
        }).toList(),
      ),
    );
  }

  @override
  Future<Either<Failure, void>> addSet(WorkoutSet set) async {
    _store.workoutSets.removeWhere((item) => item.id == set.id);
    _store.workoutSets.add(set);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateSet(WorkoutSet set) async {
    final index = _store.workoutSets.indexWhere((item) => item.id == set.id);
    if (index < 0) {
      return const Left(ValidationFailure('Workout set not found'));
    }

    _store.workoutSets[index] = set;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteSet(String id) async {
    _store.workoutSets.removeWhere((set) => set.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllSets() async {
    _store.workoutSets.clear();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> syncPendingSets() async {
    return const Right(null);
  }
}

class WebDemoExerciseRepository implements ExerciseRepository {
  WebDemoExerciseRepository(this._store);

  final WebDemoStore _store;

  @override
  Future<Either<Failure, List<Exercise>>> getAllExercises({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final items = [..._store.exercises]
      ..sort((a, b) => a.name.compareTo(b.name));
    return Right(items);
  }

  @override
  Future<Either<Failure, Exercise?>> getExerciseById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return Right(
      _firstWhereOrNull(_store.exercises, (exercise) => exercise.id == id),
    );
  }

  @override
  Future<Either<Failure, Exercise?>> getExerciseByName(
    String name, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final normalizedName = _normalize(name);
    return Right(
      _firstWhereOrNull(
        _store.exercises,
        (exercise) => _normalize(exercise.name) == normalizedName,
      ),
    );
  }

  @override
  Future<Either<Failure, List<Exercise>>> getExercisesForMuscle(
    String muscleGroup, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final normalizedGroup = _normalize(muscleGroup);
    final items = _store.exercises.where((exercise) {
      return exercise.muscleGroups.map(_normalize).contains(normalizedGroup);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return Right(items);
  }

  @override
  Future<Either<Failure, void>> addExercise(Exercise exercise) async {
    final duplicate = _store.exercises.any(
      (item) => _normalize(item.name) == _normalize(exercise.name),
    );

    if (duplicate) {
      return const Left(ValidationFailure('Exercise name already exists'));
    }

    _store.exercises.add(exercise);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateExercise(Exercise exercise) async {
    final index = _store.exercises.indexWhere((item) => item.id == exercise.id);
    if (index < 0) {
      return const Left(ValidationFailure('Exercise not found'));
    }

    final duplicate = _store.exercises.any(
      (item) =>
          item.id != exercise.id &&
          _normalize(item.name) == _normalize(exercise.name),
    );

    if (duplicate) {
      return const Left(ValidationFailure('Exercise name already exists'));
    }

    _store.exercises[index] = exercise;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteExercise(String id) async {
    _store.exercises.removeWhere((exercise) => exercise.id == id);
    _store.muscleFactors.removeWhere((factor) => factor.exerciseId == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllExercises() async {
    _store.exercises.clear();
    _store.muscleFactors.clear();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearUserOwnedExercises(String userId) async {
    _store.exercises.removeWhere((exercise) => exercise.ownerUserId == userId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> syncPendingExercises() async {
    return const Right(null);
  }
}

class WebDemoMealRepository implements MealRepository {
  WebDemoMealRepository(this._store);

  final WebDemoStore _store;

  @override
  Future<Either<Failure, List<Meal>>> getAllMeals({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final items = [..._store.meals]..sort((a, b) => a.name.compareTo(b.name));
    return Right(items);
  }

  @override
  Future<Either<Failure, Meal?>> getMealById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return Right(_firstWhereOrNull(_store.meals, (meal) => meal.id == id));
  }

  @override
  Future<Either<Failure, Meal?>> getMealByName(
    String name, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final normalizedName = _normalize(name);
    return Right(
      _firstWhereOrNull(
        _store.meals,
        (meal) => _normalize(meal.name) == normalizedName,
      ),
    );
  }

  @override
  Future<Either<Failure, List<Meal>>> searchMealsByName(
    String query, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final normalizedQuery = _normalize(query);
    final items = _store.meals.where((meal) {
      return _normalize(meal.name).contains(normalizedQuery);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return Right(items);
  }

  @override
  Future<Either<Failure, List<Meal>>> getRecentMeals({
    int limit = 5,
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final items = [..._store.meals]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Right(items.take(limit).toList());
  }

  @override
  Future<Either<Failure, List<Meal>>> getFrequentMeals({
    int limit = 10,
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final counts = <String, int>{};
    for (final log in _store.nutritionLogs) {
      final mealId = log.mealId;
      if (mealId == null) {
        continue;
      }
      counts[mealId] = (counts[mealId] ?? 0) + 1;
    }

    final items = [..._store.meals]
      ..sort((a, b) {
        final diff = (counts[b.id] ?? 0) - (counts[a.id] ?? 0);
        if (diff != 0) {
          return diff;
        }
        return a.name.compareTo(b.name);
      });

    return Right(items.take(limit).toList());
  }

  @override
  Future<Either<Failure, void>> addMeal(Meal meal) async {
    final duplicate = _store.meals.any(
      (item) => _normalize(item.name) == _normalize(meal.name),
    );

    if (duplicate) {
      return const Left(ValidationFailure('Meal name already exists'));
    }

    _store.meals.add(meal);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateMeal(Meal meal) async {
    final index = _store.meals.indexWhere((item) => item.id == meal.id);
    if (index < 0) {
      return const Left(ValidationFailure('Meal not found'));
    }

    final duplicate = _store.meals.any(
      (item) =>
          item.id != meal.id && _normalize(item.name) == _normalize(meal.name),
    );

    if (duplicate) {
      return const Left(ValidationFailure('Meal name already exists'));
    }

    _store.meals[index] = meal;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteMeal(String id) async {
    _store.meals.removeWhere((meal) => meal.id == id);
    _store.nutritionLogs.removeWhere((log) => log.mealId == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllMeals() async {
    _store.meals.clear();
    _store.nutritionLogs.removeWhere((log) => log.mealId != null);
    return const Right(null);
  }

  @override
  Future<Either<Failure, int>> getMealsCount() async {
    return Right(_store.meals.length);
  }

  @override
  Future<Either<Failure, void>> syncPendingMeals() async {
    return const Right(null);
  }
}

class WebDemoNutritionLogRepository implements NutritionLogRepository {
  WebDemoNutritionLogRepository(this._store);

  final WebDemoStore _store;

  @override
  Future<Either<Failure, List<NutritionLog>>> getAllLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return Right(_sortedNutritionLogs(_store.nutritionLogs));
  }

  @override
  Future<Either<Failure, NutritionLog?>> getLogById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return Right(
      _firstWhereOrNull(_store.nutritionLogs, (log) => log.id == id),
    );
  }

  @override
  Future<Either<Failure, List<NutritionLog>>> getLogsByDate(
    DateTime date, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return getLogsForDate(date, sourcePreference: sourcePreference);
  }

  @override
  Future<Either<Failure, List<NutritionLog>>> getLogsForDate(
    DateTime date, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final targetDate = _startOfDay(date);
    final items = _store.nutritionLogs.where((log) {
      return _startOfDay(log.loggedAt) == targetDate;
    }).toList();

    return Right(_sortedNutritionLogs(items));
  }

  @override
  Future<Either<Failure, List<NutritionLog>>> getLogsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final start = _startOfDay(startDate);
    final end = _endOfDay(endDate);

    final items = _store.nutritionLogs.where((log) {
      return !log.loggedAt.isBefore(start) && !log.loggedAt.isAfter(end);
    }).toList();

    return Right(_sortedNutritionLogs(items));
  }

  @override
  Future<Either<Failure, List<NutritionLog>>> getLogsByMealId(
    String mealId, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final items = _store.nutritionLogs
        .where((log) => log.mealId == mealId)
        .toList();
    return Right(_sortedNutritionLogs(items));
  }

  @override
  Future<Either<Failure, List<NutritionLog>>> getTodayLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    return getLogsForDate(DateTime.now(), sourcePreference: sourcePreference);
  }

  @override
  Future<Either<Failure, List<NutritionLog>>> getWeeklyLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final today = _startOfDay(DateTime.now());
    final start = today.subtract(const Duration(days: 6));
    return getLogsByDateRange(start, today, sourcePreference: sourcePreference);
  }

  @override
  Future<Either<Failure, List<NutritionLog>>> getMealLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final items = _store.nutritionLogs
        .where((log) => log.mealId != null)
        .toList();
    return Right(_sortedNutritionLogs(items));
  }

  @override
  Future<Either<Failure, List<NutritionLog>>> getDirectMacroLogs({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final items = _store.nutritionLogs
        .where((log) => log.mealId == null)
        .toList();
    return Right(_sortedNutritionLogs(items));
  }

  @override
  Future<Either<Failure, void>> addLog(NutritionLog log) async {
    _store.nutritionLogs.removeWhere((item) => item.id == log.id);
    _store.nutritionLogs.add(log);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateLog(NutritionLog log) async {
    final index = _store.nutritionLogs.indexWhere((item) => item.id == log.id);
    if (index < 0) {
      return const Left(ValidationFailure('Nutrition log not found'));
    }

    _store.nutritionLogs[index] = log;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteLog(String id) async {
    _store.nutritionLogs.removeWhere((log) => log.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteLogsByDate(DateTime date) async {
    final targetDate = _startOfDay(date);
    _store.nutritionLogs.removeWhere(
      (log) => _startOfDay(log.loggedAt) == targetDate,
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteLogsByMealId(String mealId) async {
    _store.nutritionLogs.removeWhere((log) => log.mealId == mealId);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllLogs() async {
    _store.nutritionLogs.clear();
    return const Right(null);
  }

  @override
  Future<Either<Failure, int>> getLogsCount() async {
    return Right(_store.nutritionLogs.length);
  }

  @override
  Future<Either<Failure, DailyMacros>> getDailyMacros(
    DateTime date, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async {
    final items = _store.nutritionLogs.where((log) {
      return _startOfDay(log.loggedAt) == _startOfDay(date);
    }).toList();

    double totalCarbs = 0;
    double totalProtein = 0;
    double totalFat = 0;
    double totalCalories = 0;

    for (final log in items) {
      totalCarbs += log.carbsGrams;
      totalProtein += log.proteinGrams;
      totalFat += log.fatGrams;
      totalCalories += log.calories;
    }

    return Right(
      DailyMacros(
        totalCarbs: totalCarbs,
        totalProtein: totalProtein,
        totalFat: totalFat,
        totalCalories: totalCalories,
        date: _startOfDay(date),
        logsCount: items.length,
      ),
    );
  }

  @override
  Future<Either<Failure, void>> syncPendingLogs() async {
    return const Right(null);
  }
}

class WebDemoMuscleFactorRepository implements MuscleFactorRepository {
  WebDemoMuscleFactorRepository(this._store);

  final WebDemoStore _store;

  @override
  Future<Either<Failure, MuscleFactor?>> getFactorById(String id) async {
    return Right(
      _firstWhereOrNull(_store.muscleFactors, (factor) => factor.id == id),
    );
  }

  @override
  Future<Either<Failure, List<MuscleFactor>>> getAllFactors() async {
    return Right([..._store.muscleFactors]);
  }

  @override
  Future<Either<Failure, List<MuscleFactor>>> getFactorsForExercise(
    String exerciseId,
  ) async {
    return Right(
      _store.muscleFactors
          .where((factor) => factor.exerciseId == exerciseId)
          .toList(),
    );
  }

  @override
  Future<Either<Failure, List<MuscleFactor>>> getFactorsByMuscleGroup(
    String muscleGroup,
  ) async {
    return Right(
      _store.muscleFactors
          .where((factor) => factor.muscleGroup == muscleGroup)
          .toList(),
    );
  }

  @override
  Future<Either<Failure, void>> addMuscleFactor(MuscleFactor factor) async {
    _store.muscleFactors.removeWhere((item) => item.id == factor.id);
    _store.muscleFactors.add(factor);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> addMuscleFactorsBatch(
    List<MuscleFactor> factors,
  ) async {
    for (final factor in factors) {
      _store.muscleFactors.removeWhere((item) => item.id == factor.id);
      _store.muscleFactors.add(factor);
    }
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateMuscleFactor(MuscleFactor factor) async {
    final index = _store.muscleFactors.indexWhere(
      (item) => item.id == factor.id,
    );
    if (index < 0) {
      return const Left(ValidationFailure('Muscle factor not found'));
    }

    _store.muscleFactors[index] = factor;
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteMuscleFactor(String id) async {
    _store.muscleFactors.removeWhere((factor) => factor.id == id);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> deleteMuscleFactorsByExerciseId(
    String exerciseId,
  ) async {
    _store.muscleFactors.removeWhere(
      (factor) => factor.exerciseId == exerciseId,
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllFactors() async {
    _store.muscleFactors.clear();
    return const Right(null);
  }
}

class WebDemoMuscleStimulusRepository implements MuscleStimulusRepository {
  WebDemoMuscleStimulusRepository(this._store);

  final WebDemoStore _store;

  @override
  Future<Either<Failure, MuscleStimulus?>> getStimulusByMuscleAndDate({
    required String muscleGroup,
    required DateTime date,
  }) async {
    final normalizedDate = _startOfDay(date);
    return Right(
      _firstWhereOrNull(
        _store.muscleStimulusRecords,
        (item) =>
            item.muscleGroup == muscleGroup &&
            _startOfDay(item.date) == normalizedDate,
      ),
    );
  }

  @override
  Future<Either<Failure, List<MuscleStimulus>>> getStimulusByDateRange({
    required String muscleGroup,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final start = _startOfDay(startDate);
    final end = _endOfDay(endDate);

    final items = _store.muscleStimulusRecords.where((item) {
      return item.muscleGroup == muscleGroup &&
          !item.date.isBefore(start) &&
          !item.date.isAfter(end);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    return Right(items);
  }

  @override
  Future<Either<Failure, MuscleStimulus?>> getTodayStimulus(
    String muscleGroup,
  ) async {
    return getStimulusByMuscleAndDate(
      muscleGroup: muscleGroup,
      date: DateTime.now(),
    );
  }

  @override
  Future<Either<Failure, List<MuscleStimulus>>> getAllStimulusForDate(
    DateTime date,
  ) async {
    final normalizedDate = _startOfDay(date);
    final items = _store.muscleStimulusRecords.where((item) {
      return _startOfDay(item.date) == normalizedDate;
    }).toList()..sort((a, b) => a.muscleGroup.compareTo(b.muscleGroup));

    return Right(items);
  }

  @override
  Future<Either<Failure, void>> upsertStimulus(MuscleStimulus stimulus) async {
    final existingIndex = _store.muscleStimulusRecords.indexWhere(
      (item) =>
          item.id == stimulus.id ||
          (item.muscleGroup == stimulus.muscleGroup &&
              _startOfDay(item.date) == _startOfDay(stimulus.date)),
    );

    if (existingIndex >= 0) {
      _store.muscleStimulusRecords[existingIndex] = stimulus;
    } else {
      _store.muscleStimulusRecords.add(stimulus);
    }

    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> updateStimulusValues({
    required String id,
    required double dailyStimulus,
    required double rollingWeeklyLoad,
    int? lastSetTimestamp,
    double? lastSetStimulus,
  }) async {
    final index = _store.muscleStimulusRecords.indexWhere(
      (item) => item.id == id,
    );
    if (index < 0) {
      return const Left(ValidationFailure('Muscle stimulus record not found'));
    }

    final current = _store.muscleStimulusRecords[index];
    _store.muscleStimulusRecords[index] = current.copyWith(
      dailyStimulus: dailyStimulus,
      rollingWeeklyLoad: rollingWeeklyLoad,
      lastSetTimestamp: lastSetTimestamp,
      lastSetStimulus: lastSetStimulus,
      updatedAt: DateTime.now(),
    );

    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> applyDailyDecayToAll() async {
    final today = _startOfDay(DateTime.now());
    final latestByMuscle = <String, MuscleStimulus>{};

    for (final record in _store.muscleStimulusRecords) {
      final existing = latestByMuscle[record.muscleGroup];
      if (existing == null || record.date.isAfter(existing.date)) {
        latestByMuscle[record.muscleGroup] = record;
      }
    }

    for (final entry in latestByMuscle.entries) {
      final existingToday = _store.muscleStimulusRecords.any(
        (record) =>
            record.muscleGroup == entry.key &&
            _startOfDay(record.date) == today,
      );

      if (existingToday) {
        continue;
      }

      final previous = entry.value;
      if (!_startOfDay(previous.date).isBefore(today)) {
        continue;
      }

      _store.muscleStimulusRecords.add(
        MuscleStimulus(
          id: const Uuid().v4(),
          ownerUserId: previous.ownerUserId,
          muscleGroup: previous.muscleGroup,
          date: today,
          dailyStimulus: 0,
          rollingWeeklyLoad: previous.rollingWeeklyLoad * 0.6,
          lastSetTimestamp: previous.lastSetTimestamp,
          lastSetStimulus: previous.lastSetStimulus,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
    }

    return const Right(null);
  }

  @override
  Future<Either<Failure, double>> getMaxStimulusForMuscle(
    String muscleGroup,
  ) async {
    final values = _store.muscleStimulusRecords
        .where((record) => record.muscleGroup == muscleGroup)
        .map((record) => record.dailyStimulus)
        .toList();

    if (values.isEmpty) {
      return const Right(0);
    }

    values.sort();
    return Right(values.last);
  }

  @override
  Future<Either<Failure, double>> getTotalVolumeForMuscle(
    String muscleGroup, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final total = _store.muscleStimulusRecords
        .where((r) => r.muscleGroup == muscleGroup)
        .where((r) {
          if (startDate != null &&
              r.date.isBefore(
                DateTime(startDate.year, startDate.month, startDate.day),
              )) {
            return false;
          }
          if (endDate != null &&
              r.date.isAfter(
                DateTime(
                  endDate.year,
                  endDate.month,
                  endDate.day,
                  23,
                  59,
                  59,
                  999,
                  999,
                ),
              )) {
            return false;
          }
          return true;
        })
        .fold<double>(0.0, (sum, r) => sum + r.dailyVolume);
    return Right(total);
  }

  @override
  Future<Either<Failure, void>> deleteOlderThan(DateTime date) async {
    final cutoff = _startOfDay(date);
    _store.muscleStimulusRecords.removeWhere(
      (record) => record.date.isBefore(cutoff),
    );
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearAllStimulus() async {
    _store.muscleStimulusRecords.clear();
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearStimulusForUser(String userId) async {
    // Demo mode is single-user; clear all stimulus records on user sign-out.
    _store.muscleStimulusRecords.clear();
    return const Right(null);
  }
}

class WebDemoSessionSyncService implements SessionSyncService {
  WebDemoSessionSyncService(this._store);

  final WebDemoStore _store;

  // App-lifetime singleton: the controller is created once and never closed,
  // matching AppSettingsRepositoryImpl's broadcast controller.
  final StreamController<void> _onSessionEstablishedController =
      StreamController<void>.broadcast();

  @override
  Stream<void> get onSessionEstablished =>
      _onSessionEstablishedController.stream;

  @override
  Future<SessionSyncActionResult> establishAuthenticatedSession(
    AppUser user,
  ) async {
    _store.claimUnownedDemoData(user.id);
    _store.session = AppSession(
      user: user,
      requiresInitialCloudMigration: false,
      lastCloudSyncAt: DateTime.now(),
    );
    _store.migrationState = null;

    _onSessionEstablishedController.add(null);

    return const SessionSyncActionResult(
      status: SessionSyncActionStatus.completed,
      message: 'Chrome demo session started successfully.',
    );
  }

  @override
  Future<SessionSyncActionResult> runManualRefresh() async {
    final existing = _store.session;
    if (existing != null) {
      _store.session = existing.copyWith(lastCloudSyncAt: DateTime.now());
    }

    return const SessionSyncActionResult(
      status: SessionSyncActionStatus.completed,
      message: 'Chrome demo data refreshed locally.',
    );
  }

  @override
  Future<SessionSyncActionResult> signOut() async {
    _store.session = null;
    _store.migrationState = null;

    return const SessionSyncActionResult(
      status: SessionSyncActionStatus.completed,
      message: 'Signed out of Chrome demo session.',
    );
  }
}

class WebDemoAuthSessionService implements AuthSessionService {
  WebDemoAuthSessionService(this._store);

  final WebDemoStore _store;

  @override
  Future<AuthSessionActionResult> signInWithEmail({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim();
    final normalizedPassword = password.trim();

    if (normalizedEmail.isEmpty || normalizedPassword.isEmpty) {
      return const AuthSessionActionResult(
        status: AuthSessionActionStatus.failed,
        message: 'Email and password are required.',
      );
    }

    final localPart = normalizedEmail.split('@').first.trim();
    final user = AppUser(
      id: 'demo-${localPart.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '-').toLowerCase()}',
      email: normalizedEmail,
      displayName: localPart.isEmpty ? 'Demo User' : localPart,
    );

    _store.claimUnownedDemoData(user.id);
    _store.session = AppSession(
      user: user,
      requiresInitialCloudMigration: false,
      lastCloudSyncAt: DateTime.now(),
    );
    _store.migrationState = null;

    return const AuthSessionActionResult(
      status: AuthSessionActionStatus.completed,
      message: 'Signed in using Chrome demo mode.',
    );
  }

  @override
  Future<AuthSessionActionResult> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    // Demo mode: sign-up behaves the same as sign-in — no real account created.
    return signInWithEmail(email: email, password: password);
  }

  @override
  Future<AuthSessionActionResult> verifyEmailOtp({
    required String email,
    required String token,
  }) async {
    throw UnsupportedError('OTP verification is not available in demo mode.');
  }

  @override
  Future<SessionSyncActionResult> signOut() async {
    _store.session = null;
    _store.migrationState = null;

    return const SessionSyncActionResult(
      status: SessionSyncActionStatus.completed,
      message: 'Signed out of Chrome demo mode.',
    );
  }
}

class WebDemoSyncOrchestrator implements SyncOrchestrator {
  const WebDemoSyncOrchestrator();

  @override
  Stream<SyncRunResult> get onSyncCompleted =>
      const Stream<SyncRunResult>.empty();

  @override
  Future<SyncRunResult> run(SyncTrigger trigger) async {
    return SyncRunResult(
      status: SyncRunStatus.completed,
      trigger: trigger,
      message: 'Chrome demo mode uses local in-memory data only.',
    );
  }
}

DateTime _startOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

DateTime _endOfDay(DateTime value) {
  return DateTime(value.year, value.month, value.day, 23, 59, 59, 999);
}

String _normalize(String value) {
  return value.trim().toLowerCase();
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T value) predicate) {
  for (final item in items) {
    if (predicate(item)) {
      return item;
    }
  }
  return null;
}

List<WorkoutSet> _sortedWorkoutSets(List<WorkoutSet> items) {
  final result = [...items];
  result.sort((a, b) {
    final dateCompare = b.date.compareTo(a.date);
    if (dateCompare != 0) {
      return dateCompare;
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return result;
}

List<NutritionLog> _sortedNutritionLogs(List<NutritionLog> items) {
  final result = [...items];
  result.sort((a, b) {
    final loggedCompare = b.loggedAt.compareTo(a.loggedAt);
    if (loggedCompare != 0) {
      return loggedCompare;
    }
    return b.createdAt.compareTo(a.createdAt);
  });
  return result;
}

List<MuscleStimulus> _buildSeededMuscleStimulusRecords({
  required List<WorkoutSet> workoutSets,
  required List<MuscleFactor> muscleFactors,
  required DateTime now,
}) {
  if (workoutSets.isEmpty) {
    return <MuscleStimulus>[];
  }

  final sortedSets = [...workoutSets]
    ..sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.createdAt.compareTo(b.createdAt);
    });

  final factorsByExercise = <String, List<MuscleFactor>>{};
  for (final factor in muscleFactors) {
    factorsByExercise.putIfAbsent(factor.exerciseId, () => <MuscleFactor>[]);
    factorsByExercise[factor.exerciseId]!.add(factor);
  }

  final dailyStimulusByDate = <DateTime, Map<String, double>>{};
  final lastSetByDate = <DateTime, Map<String, _SeededStimulusMeta>>{};

  for (final workoutSet in sortedSets) {
    final day = _startOfDay(workoutSet.date);
    final dayStimulus = dailyStimulusByDate.putIfAbsent(
      day,
      () => <String, double>{},
    );
    final dayLastSet = lastSetByDate.putIfAbsent(
      day,
      () => <String, _SeededStimulusMeta>{},
    );

    for (final factor
        in factorsByExercise[workoutSet.exerciseId] ?? const <MuscleFactor>[]) {
      final setStimulus = StimulusCalculationRules.calculateSetStimulus(
        sets: 1,
        intensity: workoutSet.intensity,
        exerciseFactor: factor.factor,
      );

      dayStimulus[factor.muscleGroup] =
          (dayStimulus[factor.muscleGroup] ?? 0.0) + setStimulus;

      final existingMeta = dayLastSet[factor.muscleGroup];
      if (existingMeta == null ||
          workoutSet.date.millisecondsSinceEpoch >= existingMeta.timestamp) {
        dayLastSet[factor.muscleGroup] = _SeededStimulusMeta(
          timestamp: workoutSet.date.millisecondsSinceEpoch,
          stimulus: setStimulus,
        );
      }
    }
  }

  final earliestDay = _startOfDay(sortedSets.first.date);
  final latestWorkoutDay = _startOfDay(sortedSets.last.date);
  final today = _startOfDay(now);
  final finalDay = latestWorkoutDay.isAfter(today) ? latestWorkoutDay : today;

  final records = <MuscleStimulus>[];
  final previousRollingLoad = <String, double>{};
  final latestSetMeta = <String, _SeededStimulusMeta>{};
  var recordId = 0;

  for (
    DateTime day = earliestDay;
    !day.isAfter(finalDay);
    day = day.add(const Duration(days: 1))
  ) {
    final dayStimulus = dailyStimulusByDate[day] ?? const <String, double>{};
    final dayLastSet =
        lastSetByDate[day] ?? const <String, _SeededStimulusMeta>{};

    final musclesForDay = <String>{
      ...previousRollingLoad.keys,
      ...dayStimulus.keys,
      ...dayLastSet.keys,
    };

    for (final muscleGroup in musclesForDay) {
      final stimulus = dayStimulus[muscleGroup] ?? 0.0;
      final rollingWeeklyLoad =
          StimulusCalculationRules.calculateRollingWeeklyLoad(
            previousWeeklyLoad: previousRollingLoad[muscleGroup] ?? 0.0,
            dailyStimulus: stimulus,
          );

      final latestForDay = dayLastSet[muscleGroup];
      if (latestForDay != null) {
        latestSetMeta[muscleGroup] = latestForDay;
      }

      final carriedMeta = latestSetMeta[muscleGroup];
      recordId += 1;

      records.add(
        MuscleStimulus(
          id: 'stimulus-$recordId',
          ownerUserId: '',
          muscleGroup: muscleGroup,
          date: day,
          dailyStimulus: stimulus,
          rollingWeeklyLoad: rollingWeeklyLoad,
          lastSetTimestamp: carriedMeta?.timestamp,
          lastSetStimulus: carriedMeta?.stimulus,
          createdAt: day,
          updatedAt: day,
        ),
      );

      previousRollingLoad[muscleGroup] = rollingWeeklyLoad;
    }
  }

  return records;
}

class _SeededStimulusMeta {
  const _SeededStimulusMeta({required this.timestamp, required this.stimulus});

  final int timestamp;
  final double stimulus;
}

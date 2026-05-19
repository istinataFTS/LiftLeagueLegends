import 'dart:async';

import 'package:get_it/get_it.dart';

import '../core/auth/auth_session_service.dart';
import '../core/auth/auth_session_service_impl.dart';
import '../core/session/session_sync_service.dart';
import '../core/session/session_sync_service_impl.dart';
import '../core/sync/hooks/account_catalog_provision_hook.dart';
import '../core/sync/hooks/muscle_factor_heal_hook.dart';
import '../core/sync/hooks/muscle_stimulus_rebuild_hook.dart';
import '../core/sync/initial_cloud_migration_coordinator.dart';
import '../core/sync/initial_cloud_migration_coordinator_impl.dart';
import '../core/sync/initial_cloud_migration_step.dart';
import '../core/sync/post_sync_hook.dart';
import '../core/sync/sync_feature.dart';
import '../core/sync/sync_orchestrator.dart';
import '../core/sync/sync_orchestrator_impl.dart';
import '../domain/usecases/exercises/seed_exercises.dart';
import '../domain/usecases/meals/seed_meals.dart';
import '../domain/usecases/muscle_factors/seed_exercise_factors.dart';
import '../domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import '../data/datasources/local/database_helper.dart';
import '../data/sync/exercise_sync_coordinator.dart';
import '../data/sync/meal_sync_coordinator.dart';
import '../data/sync/nutrition_log_sync_coordinator.dart';
import '../data/sync/workout_set_sync_coordinator.dart';
import '../domain/repositories/user_profile_repository.dart';
import '../features/home/application/home_bloc.dart';
import '../features/home/application/usecases/load_home_dashboard_data.dart';
import 'modules/register_core_module.dart';
import 'modules/register_exercises_module.dart';
import 'modules/register_history_module.dart';
import 'modules/register_meals_nutrition_module.dart';
import 'modules/register_muscle_load_module.dart';
import 'modules/register_muscle_stimulus_module.dart';
import 'modules/register_profile_module.dart';
import 'modules/register_settings_module.dart';
import 'modules/register_social_module.dart';
import 'modules/register_voice_module.dart';
import 'modules/register_workout_module.dart';

final sl = GetIt.instance;

typedef ServiceOverrideRegistrar = FutureOr<void> Function(GetIt sl);

Future<void> init({
  bool openDatabase = false,
  ServiceOverrideRegistrar? registerOverrides,
}) async {
  await sl.reset(dispose: true);

  registerCoreModule(sl);
  registerSettingsModule(sl);
  registerProfileModule(sl);
  registerSocialModule(sl);
  registerVoiceModule(sl);
  registerWorkoutModule(sl);
  registerExercisesModule(sl);
  registerMealsNutritionModule(sl);
  registerMuscleStimulusModule(sl);
  registerMuscleLoadModule(sl);
  registerHistoryModule(sl);
  _registerAppComposition(sl);

  if (registerOverrides != null) {
    await registerOverrides(sl);
  }

  if (openDatabase) {
    await sl<DatabaseHelper>().database;
  }
}

Future<void> resetDependencies() {
  return sl.reset(dispose: true);
}

void _registerAppComposition(GetIt sl) {
  // Migration and sync order must respect FK dependencies in the remote schema:
  //   exercises → meals → workout_sets → nutrition_logs
  // Every migration step follows the same prepare → pull → push shape,
  // mirroring the regular feature sync (which already pulls before pushing):
  //   1. prepare: reassign any guest-owned rows to this authenticated user.
  //   2. pull:    download the cloud rows for this user first and reconcile
  //               by (name, owner) via the local insert path, so a server
  //               row that already exists is adopted locally instead of
  //               being blind-inserted again.
  //   3. push:    upload only the genuinely local-only / changed rows.
  // Pulling before pushing prevents the duplicate-key collision that a
  // blind insert-by-id would otherwise hit on the server's
  // UNIQUE(user_id, name), and still guarantees post-sync hooks (factor
  // heal, stimulus rebuild) see cloud-only data on a new device.
  sl.registerLazySingleton<List<InitialCloudMigrationStep>>(
    () => <InitialCloudMigrationStep>[
      InitialCloudMigrationStep(
        key: 'exercises',
        run: (userId) async {
          final coordinator = sl<ExerciseSyncCoordinator>();
          await coordinator.prepareForInitialCloudMigration(userId);
          await coordinator.pullRemoteChanges(userId: userId, since: null);
          await coordinator.syncPendingChanges();
        },
      ),
      InitialCloudMigrationStep(
        key: 'meals',
        run: (userId) async {
          final coordinator = sl<MealSyncCoordinator>();
          await coordinator.prepareForInitialCloudMigration(userId);
          await coordinator.pullRemoteChanges(userId: userId, since: null);
          await coordinator.syncPendingChanges();
        },
      ),
      InitialCloudMigrationStep(
        key: 'workout_sets',
        run: (userId) async {
          final coordinator = sl<WorkoutSetSyncCoordinator>();
          await coordinator.prepareForInitialCloudMigration(userId);
          await coordinator.pullRemoteChanges(userId: userId, since: null);
          await coordinator.syncPendingChanges();
        },
      ),
      InitialCloudMigrationStep(
        key: 'nutrition_logs',
        run: (userId) async {
          final coordinator = sl<NutritionLogSyncCoordinator>();
          await coordinator.prepareForInitialCloudMigration(userId);
          await coordinator.pullRemoteChanges(userId: userId, since: null);
          await coordinator.syncPendingChanges();
        },
      ),
    ],
  );

  sl.registerLazySingleton<InitialCloudMigrationCoordinator>(
    () => InitialCloudMigrationCoordinatorImpl(
      appSessionRepository: sl(),
      steps: sl(),
    ),
  );

  sl.registerLazySingleton<List<SyncFeature>>(
    () => <SyncFeature>[
      SyncFeature(
        name: 'exercises',
        syncPendingChanges: sl<ExerciseSyncCoordinator>().syncPendingChanges,
        pullRemoteChanges: (userId, since) => sl<ExerciseSyncCoordinator>()
            .pullRemoteChanges(userId: userId, since: since),
      ),
      SyncFeature(
        name: 'meals',
        syncPendingChanges: sl<MealSyncCoordinator>().syncPendingChanges,
        pullRemoteChanges: (userId, since) => sl<MealSyncCoordinator>()
            .pullRemoteChanges(userId: userId, since: since),
      ),
      SyncFeature(
        name: 'workout_sets',
        syncPendingChanges: sl<WorkoutSetSyncCoordinator>().syncPendingChanges,
        pullRemoteChanges: (userId, since) => sl<WorkoutSetSyncCoordinator>()
            .pullRemoteChanges(userId: userId, since: since),
      ),
      SyncFeature(
        name: 'nutrition_logs',
        syncPendingChanges:
            sl<NutritionLogSyncCoordinator>().syncPendingChanges,
        pullRemoteChanges: (userId, since) => sl<NutritionLogSyncCoordinator>()
            .pullRemoteChanges(userId: userId, since: since),
      ),
    ],
  );

  // Hook order matters and is strictly: catalog provision → factor heal →
  // stimulus rebuild. Provisioning must run first so the account owns its
  // exercises before factors (keyed by exercise id) are healed, which in
  // turn must precede the stimulus rebuild that reads those factors.
  sl.registerLazySingleton<List<PostSyncHook>>(
    () => <PostSyncHook>[
      AccountCatalogProvisionHook(
        seedExercises: sl<SeedExercises>(),
        seedMeals: sl<SeedMeals>(),
      ),
      MuscleFactorHealHook(seedExerciseFactors: sl<SeedExerciseFactors>()),
      MuscleStimulusRebuildHook(
        rebuild: sl<RebuildMuscleStimulusFromWorkoutHistory>(),
      ),
    ],
  );

  sl.registerLazySingleton<SyncOrchestrator>(
    () => SyncOrchestratorImpl(
      appSessionRepository: sl(),
      syncPolicy: sl(),
      remoteSyncAvailability: sl(),
      initialCloudMigrationCoordinator: sl(),
      features: sl(),
      postSyncHooks: sl<List<PostSyncHook>>(),
    ),
  );

  sl.registerLazySingleton<SessionSyncService>(
    () => SessionSyncServiceImpl(
      appSessionRepository: sl(),
      authRemoteDataSource: sl(),
      syncOrchestrator: sl(),
      rebuildMuscleStimulus: sl(),
      exerciseLocalDataSource: sl(),
      mealLocalDataSource: sl(),
      muscleStimulusLocalDataSource: sl(),
      nutritionLogLocalDataSource: sl(),
      workoutSetLocalDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<AuthSessionService>(
    () => AuthSessionServiceImpl(
      authRemoteDataSource: sl(),
      sessionSyncService: sl(),
      userProfileRepository: sl<UserProfileRepository>(),
    ),
  );

  sl.registerLazySingleton(
    () => LoadHomeDashboardData(
      getLogsForDate: sl(),
      getDailyMacros: sl(),
      muscleLoadResolver: sl(),
      appSessionRepository: sl(),
      clock: sl(),
    ),
  );

  sl.registerFactory(() => HomeBloc(loadHomeDashboardData: sl()));
}

import 'package:get_it/get_it.dart';

import '../../core/sync/remote_sync_runtime_policy.dart';
import '../../data/datasources/local/pending_sync_delete_local_datasource.dart';
import '../../data/datasources/local/pending_sync_delete_local_datasource_impl.dart';
import '../../data/datasources/local/workout_set_local_datasource.dart';
import '../../data/datasources/local/workout_set_local_datasource_impl.dart';
import '../../data/datasources/remote/noop_workout_set_remote_datasource.dart';
import '../../data/datasources/remote/supabase_workout_set_remote_datasource.dart';
import '../../data/datasources/remote/workout_set_remote_datasource.dart';
import '../../data/repositories/workout_set_repository_impl.dart';
import '../../data/sync/workout_set_sync_coordinator.dart';
import '../../data/sync/workout_set_sync_coordinator_impl.dart';
import '../../domain/repositories/workout_set_repository.dart';
import '../../domain/usecases/workout_sets/add_workout_set.dart';
import '../../domain/usecases/workout_sets/delete_workout_set.dart';
import '../../domain/usecases/workout_sets/get_all_workout_sets.dart';
import '../../domain/usecases/workout_sets/get_sets_by_date_range.dart';
import '../../domain/usecases/workout_sets/get_weekly_sets.dart';
import '../../domain/usecases/workout_sets/update_workout_set.dart';
import '../../features/log/log.dart';

void registerWorkoutModule(GetIt sl) {
  sl.registerLazySingleton(
    () => WorkoutBloc(
      addWorkoutSet: sl(),
      getWeeklySets: sl(),
      calculateMuscleStimulus: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => AddWorkoutSet(
      sl(),
      appSessionRepository: sl(),
      rebuildMuscleStimulusFromWorkoutHistory: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => GetAllWorkoutSets(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => GetWeeklySets(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => GetSetsByDateRange(
      workoutSetRepository: sl(),
      exerciseRepository: sl(),
      sourcePreferenceResolver: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => DeleteWorkoutSet(
      sl(),
      appSessionRepository: sl(),
      rebuildMuscleStimulusFromWorkoutHistory: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => UpdateWorkoutSet(
      sl(),
      appSessionRepository: sl(),
      rebuildMuscleStimulusFromWorkoutHistory: sl(),
    ),
  );

  sl.registerLazySingleton<WorkoutSetRepository>(
    () => WorkoutSetRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      syncCoordinator: sl(),
    ),
  );

  sl.registerLazySingleton<WorkoutSetSyncCoordinator>(
    () => WorkoutSetSyncCoordinatorImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      pendingSyncDeleteLocalDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<WorkoutSetLocalDataSource>(
    () => WorkoutSetLocalDataSourceImpl(
      databaseHelper: sl(),
      currentUserIdResolver: sl(),
    ),
  );

  sl.registerLazySingleton<PendingSyncDeleteLocalDataSource>(
    () => PendingSyncDeleteLocalDataSourceImpl(databaseHelper: sl()),
  );

  sl.registerLazySingleton<WorkoutSetRemoteDataSource>(
    () => sl<RemoteSyncRuntimePolicy>().isRemoteSyncConfigured
        ? SupabaseWorkoutSetRemoteDataSource(clientProvider: sl())
        : const NoopWorkoutSetRemoteDataSource(),
  );
}

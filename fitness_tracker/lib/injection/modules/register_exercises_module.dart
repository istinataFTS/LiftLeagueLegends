import 'package:get_it/get_it.dart';

import '../../core/sync/remote_sync_runtime_policy.dart';
import '../../data/datasources/local/exercise_local_datasource.dart';
import '../../data/datasources/remote/exercise_remote_datasource.dart';
import '../../data/datasources/remote/noop_exercise_remote_datasource.dart';
import '../../data/datasources/remote/supabase_exercise_remote_datasource.dart';
import '../../data/repositories/exercise_repository_impl.dart';
import '../../data/sync/exercise_sync_coordinator.dart';
import '../../data/sync/exercise_sync_coordinator_impl.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/usecases/exercises/add_exercise.dart';
import '../../domain/usecases/exercises/delete_exercise.dart';
import '../../domain/usecases/exercises/ensure_default_exercises.dart';
import '../../domain/usecases/exercises/get_all_exercises.dart';
import '../../domain/usecases/exercises/get_exercise_by_id.dart';
import '../../domain/usecases/exercises/get_exercises_for_muscle.dart';
import '../../domain/usecases/exercises/seed_exercises.dart';
import '../../domain/usecases/exercises/update_exercise.dart';
import '../../domain/usecases/muscle_factors/get_muscle_factors_for_exercise.dart';
import '../../domain/usecases/muscle_factors/sync_exercise_muscle_factors.dart';
import '../../domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import '../../features/library/application/exercise_bloc.dart';

void registerExercisesModule(GetIt sl) {
  sl.registerFactory(
    () => ExerciseBloc(
      getAllExercises: sl(),
      getExerciseById: sl(),
      getExercisesForMuscle: sl(),
      addExercise: sl(),
      updateExercise: sl(),
      deleteExercise: sl(),
      ensureDefaultExercises: sl(),
      getMuscleFactorsForExercise: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => GetAllExercises(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => GetExerciseById(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => GetExercisesForMuscle(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => AddExercise(
      sl(),
      appSessionRepository: sl(),
      syncExerciseMuscleFactors: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => UpdateExercise(
      sl(),
      appSessionRepository: sl(),
      syncExerciseMuscleFactors: sl(),
      rebuildMuscleStimulusFromWorkoutHistory: sl(),
    ),
  );
  sl.registerLazySingleton(
    () => DeleteExercise(
      sl(),
      appSessionRepository: sl(),
      muscleFactorRepository: sl(),
      rebuildMuscleStimulusFromWorkoutHistory: sl(),
    ),
  );
  sl.registerLazySingleton(() => SeedExercises(sl(), catalogInitFlags: sl()));
  sl.registerLazySingleton(
    () => EnsureDefaultExercises(
      appSessionRepository: sl(),
      seedExercises: sl(),
      seedExerciseFactors: sl(),
      rebuildMuscleStimulusFromWorkoutHistory: sl(),
    ),
  );
  sl.registerLazySingleton(() => SyncExerciseMuscleFactors(sl()));
  sl.registerLazySingleton(() => GetMuscleFactorsForExercise(sl()));

  sl.registerLazySingleton<ExerciseRepository>(
    () => ExerciseRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      syncCoordinator: sl(),
    ),
  );

  sl.registerLazySingleton<ExerciseSyncCoordinator>(
    () => ExerciseSyncCoordinatorImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      pendingSyncDeleteLocalDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<ExerciseLocalDataSource>(
    () => ExerciseLocalDataSourceImpl(
      databaseHelper: sl(),
      appSessionRepository: sl(),
    ),
  );

  sl.registerLazySingleton<ExerciseRemoteDataSource>(
    () => sl<RemoteSyncRuntimePolicy>().isRemoteSyncConfigured
        ? SupabaseExerciseRemoteDataSource(clientProvider: sl())
        : const NoopExerciseRemoteDataSource(),
  );
}

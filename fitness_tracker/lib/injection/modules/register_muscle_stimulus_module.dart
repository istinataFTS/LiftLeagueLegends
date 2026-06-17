import 'package:get_it/get_it.dart';

import '../../data/datasources/local/muscle_factor_local_datasource.dart';
import '../../data/datasources/local/muscle_stimulus_local_datasource.dart';
import '../../data/repositories/muscle_factor_repository_impl.dart';
import '../../data/repositories/muscle_stimulus_repository_impl.dart';
import '../../data/repositories/stimulus_rebuild_flag_repository_impl.dart';
import '../../domain/repositories/muscle_factor_repository.dart';
import '../../domain/repositories/muscle_stimulus_repository.dart';
import '../../domain/repositories/stimulus_rebuild_flag_repository.dart';
import '../../domain/usecases/muscle_factors/seed_exercise_factors.dart';
import '../../domain/usecases/muscle_stimulus/apply_daily_decay.dart';
import '../../domain/usecases/muscle_stimulus/calculate_muscle_stimulus.dart';
import '../../domain/usecases/muscle_stimulus/get_muscle_visual_data.dart';
import '../../domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import '../../domain/usecases/muscle_stimulus/record_workout_set.dart';
import '../../domain/usecases/muscle_stimulus/run_pending_stimulus_rebuild.dart';
import '../../features/home/application/muscle_visual_bloc.dart';

void registerMuscleStimulusModule(GetIt sl) {
  sl.registerFactory(
    () => MuscleVisualBloc(
      getMuscleVisualData: sl(),
      appSessionRepository: sl(),
      clock: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => SeedExerciseFactors(
      muscleFactorRepository: sl(),
      exerciseRepository: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => CalculateMuscleStimulus(muscleFactorRepository: sl()),
  );

  sl.registerLazySingleton(
    () => RecordWorkoutSet(
      muscleFactorRepository: sl(),
      muscleStimulusRepository: sl(),
      calculateMuscleStimulus: sl(),
      clock: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => RebuildMuscleStimulusFromWorkoutHistory(
      workoutSetRepository: sl(),
      muscleStimulusRepository: sl(),
      calculateMuscleStimulus: sl(),
      clock: sl(),
    ),
  );

  sl.registerLazySingleton<StimulusRebuildFlagRepository>(
    () => StimulusRebuildFlagRepositoryImpl(sl()),
  );

  sl.registerLazySingleton(
    () => RunPendingStimulusRebuild(
      flagRepository: sl(),
      appSessionRepository: sl(),
      rebuild: sl(),
    ),
  );

  sl.registerLazySingleton(() => GetMuscleVisualData(sl(), clock: sl()));
  sl.registerLazySingleton(() => ApplyDailyDecay(sl(), clock: sl()));

  sl.registerLazySingleton<MuscleFactorRepository>(
    () => MuscleFactorRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton<MuscleStimulusRepository>(
    () => MuscleStimulusRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton<MuscleFactorLocalDataSource>(
    () => MuscleFactorLocalDataSource(databaseHelper: sl()),
  );

  sl.registerLazySingleton<MuscleStimulusLocalDataSource>(
    () => MuscleStimulusLocalDataSourceImpl(
      databaseHelper: sl(),
      currentUserIdResolver: sl(),
    ),
  );
}

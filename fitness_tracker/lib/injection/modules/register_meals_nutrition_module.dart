import 'package:get_it/get_it.dart';

import '../../core/sync/remote_sync_runtime_policy.dart';
import '../../data/datasources/local/meal_local_datasource.dart';
import '../../data/datasources/local/meal_local_datasource_impl.dart';
import '../../data/datasources/local/nutrition_log_local_datasource.dart';
import '../../data/datasources/local/nutrition_log_local_datasource_impl.dart';
import '../../data/datasources/remote/meal_remote_datasource.dart';
import '../../data/datasources/remote/noop_meal_remote_datasource.dart';
import '../../data/datasources/remote/noop_nutrition_log_remote_datasource.dart';
import '../../data/datasources/remote/nutrition_log_remote_datasource.dart';
import '../../data/datasources/remote/supabase_meal_remote_datasource.dart';
import '../../data/datasources/remote/supabase_nutrition_log_remote_datasource.dart';
import '../../data/repositories/meal_repository_impl.dart';
import '../../data/repositories/nutrition_log_repository_impl.dart';
import '../../data/sync/meal_sync_coordinator.dart';
import '../../data/sync/meal_sync_coordinator_impl.dart';
import '../../data/sync/nutrition_log_sync_coordinator.dart';
import '../../data/sync/nutrition_log_sync_coordinator_impl.dart';
import '../../domain/repositories/meal_repository.dart';
import '../../domain/repositories/nutrition_log_repository.dart';
import '../../domain/usecases/meals/add_meal.dart';
import '../../domain/usecases/meals/delete_meal.dart';
import '../../domain/usecases/meals/ensure_default_meals.dart';
import '../../domain/usecases/meals/get_all_meals.dart';
import '../../domain/usecases/meals/get_meal_by_id.dart';
import '../../domain/usecases/meals/get_meal_by_name.dart';
import '../../domain/usecases/meals/seed_meals.dart';
import '../../domain/usecases/meals/update_meal.dart';
import '../../domain/usecases/nutrition_logs/add_nutrition_log.dart';
import '../../domain/usecases/nutrition_logs/delete_nutrition_log.dart';
import '../../domain/usecases/nutrition_logs/get_daily_macros.dart';
import '../../domain/usecases/nutrition_logs/get_logs_by_date_range.dart';
import '../../domain/usecases/nutrition_logs/get_logs_for_date.dart';
import '../../domain/usecases/nutrition_logs/update_nutrition_log.dart';
import '../../features/library/application/meal_bloc.dart';
import '../../features/log/application/nutrition_log_bloc.dart';

void registerMealsNutritionModule(GetIt sl) {
  sl.registerFactory(
    () => MealBloc(
      getAllMeals: sl(),
      getMealById: sl(),
      getMealByName: sl(),
      addMeal: sl(),
      updateMeal: sl(),
      deleteMeal: sl(),
      ensureDefaultMeals: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => NutritionLogBloc(
      getLogsForDate: sl(),
      addNutritionLog: sl(),
      updateNutritionLog: sl(),
      deleteNutritionLog: sl(),
      getDailyMacros: sl(),
    ),
  );

  sl.registerLazySingleton(
    () => GetAllMeals(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => GetMealById(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => GetMealByName(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(() => AddMeal(sl(), appSessionRepository: sl()));
  sl.registerLazySingleton(() => UpdateMeal(sl(), appSessionRepository: sl()));
  sl.registerLazySingleton(() => DeleteMeal(sl()));
  sl.registerLazySingleton(() => SeedMeals(sl(), catalogInitFlags: sl()));
  sl.registerLazySingleton(
    () => EnsureDefaultMeals(appSessionRepository: sl(), seedMeals: sl()),
  );

  sl.registerLazySingleton(
    () => GetLogsForDate(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => GetLogsByDateRange(sl(), sourcePreferenceResolver: sl()),
  );
  sl.registerLazySingleton(
    () => AddNutritionLog(sl(), appSessionRepository: sl()),
  );
  sl.registerLazySingleton(
    () => UpdateNutritionLog(sl(), appSessionRepository: sl()),
  );
  sl.registerLazySingleton(() => DeleteNutritionLog(sl()));
  sl.registerLazySingleton(
    () => GetDailyMacros(sl(), sourcePreferenceResolver: sl()),
  );

  sl.registerLazySingleton<MealRepository>(
    () => MealRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      syncCoordinator: sl(),
    ),
  );

  sl.registerLazySingleton<MealSyncCoordinator>(
    () => MealSyncCoordinatorImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      pendingSyncDeleteLocalDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<NutritionLogRepository>(
    () => NutritionLogRepositoryImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      syncCoordinator: sl(),
    ),
  );

  sl.registerLazySingleton<NutritionLogSyncCoordinator>(
    () => NutritionLogSyncCoordinatorImpl(
      localDataSource: sl(),
      remoteDataSource: sl(),
      pendingSyncDeleteLocalDataSource: sl(),
    ),
  );

  sl.registerLazySingleton<MealLocalDataSource>(
    () => MealLocalDataSourceImpl(
      databaseHelper: sl(),
      currentUserIdResolver: sl(),
    ),
  );

  sl.registerLazySingleton<NutritionLogLocalDataSource>(
    () => NutritionLogLocalDataSourceImpl(
      databaseHelper: sl(),
      currentUserIdResolver: sl(),
    ),
  );

  sl.registerLazySingleton<MealRemoteDataSource>(
    () => sl<RemoteSyncRuntimePolicy>().isRemoteSyncConfigured
        ? SupabaseMealRemoteDataSource(clientProvider: sl())
        : const NoopMealRemoteDataSource(),
  );

  sl.registerLazySingleton<NutritionLogRemoteDataSource>(
    () => sl<RemoteSyncRuntimePolicy>().isRemoteSyncConfigured
        ? SupabaseNutritionLogRemoteDataSource(clientProvider: sl())
        : const NoopNutritionLogRemoteDataSource(),
  );
}

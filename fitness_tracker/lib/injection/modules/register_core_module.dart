import 'package:get_it/get_it.dart';

import '../../config/env_config.dart';
import '../../core/config/app_sync_policy.dart';
import '../../core/network/default_network_status_service.dart';
import '../../core/network/network_status_service.dart';
import '../../core/time/clock.dart';
import '../../core/time/system_clock.dart';
import '../../core/ui/keypad_visibility_controller.dart';
import '../../core/sync/remote_sync_availability.dart';
import '../../core/sync/remote_sync_runtime_policy.dart';
import '../../data/datasources/local/app_metadata_local_datasource.dart';
import '../../data/datasources/local/database_helper.dart';
import '../../data/datasources/remote/auth_remote_datasource.dart';
import '../../data/datasources/remote/noop_auth_remote_datasource.dart';
import '../../data/datasources/remote/supabase_auth_remote_datasource.dart';
import '../../data/datasources/remote/supabase_client_provider.dart';
import '../../data/repositories/app_session_repository_impl.dart';
import '../../data/repositories/app_settings_repository_impl.dart';
import '../../data/repositories/catalog_init_flag_repository_impl.dart';
import '../../domain/repositories/app_session_repository.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../domain/repositories/catalog_init_flag_repository.dart';
import '../../core/session/current_user_id_resolver.dart';
import '../../domain/services/authenticated_data_source_preference_resolver.dart';

void registerCoreModule(GetIt sl) {
  sl.registerLazySingleton<Clock>(() => const SystemClock());

  sl.registerLazySingleton<KeypadVisibilityController>(
    KeypadVisibilityController.new,
  );

  sl.registerLazySingleton<DatabaseHelper>(DatabaseHelper.new);

  sl.registerLazySingleton<AppMetadataLocalDataSource>(
    () => AppMetadataLocalDataSourceImpl(databaseHelper: sl()),
  );

  sl.registerLazySingleton<CatalogInitFlagRepository>(
    () => CatalogInitFlagRepositoryImpl(sl()),
  );

  sl.registerLazySingleton(
    () => const RemoteSyncRuntimePolicy(
      isSupabaseEnabled: EnvConfig.enableSupabase,
      supabaseUrl: EnvConfig.supabaseUrl,
      supabaseAnonKey: EnvConfig.supabaseAnonKey,
    ),
  );

  sl.registerLazySingleton<SupabaseClientProvider>(
    () => SupabaseClientProvider(
      isConfigured: sl<RemoteSyncRuntimePolicy>().isRemoteSyncConfigured,
    ),
  );

  sl.registerLazySingleton<AuthRemoteDataSource>(
    () => sl<RemoteSyncRuntimePolicy>().isRemoteSyncConfigured
        ? SupabaseAuthRemoteDataSource(clientProvider: sl())
        : const NoopAuthRemoteDataSource(),
  );

  sl.registerLazySingleton<AppSyncPolicy>(
    () => AppSyncPolicy.productionDefault,
  );

  sl.registerLazySingleton<NetworkStatusService>(
    DefaultNetworkStatusService.new,
  );

  sl.registerLazySingleton(
    () =>
        RemoteSyncAvailability(runtimePolicy: sl(), networkStatusService: sl()),
  );

  sl.registerLazySingleton<AppSessionRepository>(
    () => AppSessionRepositoryImpl(
      localDataSource: sl(),
      authRemoteDataSource: sl(),
      syncPolicy: sl(),
    ),
  );

  sl.registerLazySingleton<AppSettingsRepository>(
    () => AppSettingsRepositoryImpl(localDataSource: sl()),
  );

  sl.registerLazySingleton(
    () => AuthenticatedDataSourcePreferenceResolver(appSessionRepository: sl()),
  );

  sl.registerLazySingleton(
    () => CurrentUserIdResolver(appSessionRepository: sl()),
  );
}

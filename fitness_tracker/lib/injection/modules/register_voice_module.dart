import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:get_it/get_it.dart';

import '../../core/network/network_status_service.dart';
import '../../core/platform/wakelock_service.dart';
import '../../core/sync/remote_sync_runtime_policy.dart';
import '../../core/time/clock.dart';
import '../../data/datasources/remote/noop_voice_remote_datasource.dart';
import '../../data/datasources/remote/supabase_voice_remote_datasource.dart';
import '../../data/datasources/remote/voice_remote_datasource.dart';
import '../../data/repositories/voice_repository_impl.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../../domain/repositories/meal_repository.dart';
import '../../domain/repositories/voice_repository.dart';
import '../../domain/services/voice_credential_service.dart';
import '../../domain/services/voice_stt_service.dart';
import '../../domain/services/voice_tts_service.dart';
import '../../domain/services/voice_wake_word_service.dart';
import '../../domain/usecases/exercises/get_all_exercises.dart';
import '../../domain/usecases/nutrition_logs/get_daily_macros.dart';
import '../../domain/usecases/nutrition_logs/get_logs_for_date.dart';
import '../../domain/usecases/voice/delete_voice_history.dart';
import '../../domain/usecases/voice/get_voice_budget.dart';
import '../../domain/usecases/voice/send_voice_message.dart';
import '../../domain/usecases/workout_sets/get_sets_by_date_range.dart';
import '../../domain/usecases/workout_sets/get_weekly_sets.dart';
import '../../features/settings/application/app_settings_cubit.dart';
import '../../features/voice/application/voice_bloc.dart';
import '../../features/voice/application/voice_settings_cubit.dart';
import '../../features/voice/data/coordinator/offline_voice_coordinator.dart';
import '../../features/voice/data/lookup/exercise_lookup.dart';
import '../../features/voice/data/lookup/meal_lookup.dart';
import '../../features/voice/data/lookup/recent_entity_lookup.dart';
import '../../features/voice/data/parser/intent_parser.dart';
import '../../features/voice/data/parser/matchers/nutrition_matchers.dart';
import '../../features/voice/data/parser/matchers/query_matchers.dart';
import '../../features/voice/data/parser/matchers/workout_set_matchers.dart';
import '../../features/voice/data/services/flutter_tts_voice_tts_service.dart';
import '../../features/voice/data/services/porcupine_voice_wake_word_service.dart';
import '../../features/voice/data/services/secure_storage_voice_credential_service.dart';
import '../../features/voice/data/services/speech_to_text_voice_stt_service.dart';

/// Wires up the voice feature.
///
/// Ordering note: `registerCoreModule` must run before this module
/// (it owns `AppSettingsCubit`, `AppSettingsRepository`, and
/// `NetworkStatusService`). The injection bootstrap enforces this order.
void registerVoiceModule(GetIt sl) {
  // ── Secure storage (shared with VoiceCredentialService) ────────────────
  // Only register if not already present (e.g. if another module added it).
  if (!sl.isRegistered<FlutterSecureStorage>()) {
    sl.registerLazySingleton<FlutterSecureStorage>(
      () => const FlutterSecureStorage(),
    );
  }

  // ── Voice credential service ───────────────────────────────────────────
  // Registered with a dispose hook so the change-notification stream is
  // closed when the container is reset (e.g. between integration tests).
  sl.registerLazySingleton<VoiceCredentialService>(
    () => SecureStorageVoiceCredentialService(sl<FlutterSecureStorage>()),
    dispose: (s) => s.dispose(),
  );

  // ── Device services (STT + TTS) ────────────────────────────────────────
  // Lazy singletons: the underlying plugins hold native resources
  // (microphone session, TTS engine) and must not be torn down /
  // re-created per overlay instance.
  sl.registerLazySingleton<VoiceSttService>(SpeechToTextVoiceSttService.new);
  sl.registerLazySingleton<VoiceTtsService>(FlutterTtsVoiceTtsService.new);

  // ── Wake-word engine ───────────────────────────────────────────────────
  // Lazy singleton: Porcupine holds the microphone and must not be
  // torn down/re-created per overlay instance. VoiceFab manages lifecycle
  // (start on resume, stop on background).
  sl.registerLazySingleton<VoiceWakeWordService>(
    () => PorcupineVoiceWakeWordService(credentialService: sl()),
  );

  // ── Wakelock service ───────────────────────────────────────────────────
  sl.registerLazySingleton<WakelockService>(
    () => const DefaultWakelockService(),
  );

  // ── Repository + datasource ────────────────────────────────────────────
  sl.registerLazySingleton<VoiceRepository>(
    () => VoiceRepositoryImpl(remoteDataSource: sl()),
  );

  sl.registerLazySingleton<VoiceRemoteDataSource>(
    () => sl<RemoteSyncRuntimePolicy>().isRemoteSyncConfigured
        ? SupabaseVoiceRemoteDataSource(clientProvider: sl())
        : const NoopVoiceRemoteDataSource(),
  );

  // ── Use cases ──────────────────────────────────────────────────────────
  sl.registerLazySingleton(() => GetVoiceBudget(sl()));
  sl.registerLazySingleton(() => DeleteVoiceHistory(sl()));
  sl.registerLazySingleton(() => SendVoiceMessage(sl()));

  // ── C-6: Lookup helpers (singletons — cache persists across sessions) ──
  sl.registerLazySingleton<ExerciseLookup>(
    () => ExerciseLookup(sl<GetAllExercises>()),
  );
  sl.registerLazySingleton<MealLookup>(() => MealLookup(sl<MealRepository>()));
  sl.registerLazySingleton<RecentEntityLookup>(
    () => RecentEntityLookup(
      getSetsByDateRange: sl<GetSetsByDateRange>(),
      getLogsForDate: sl<GetLogsForDate>(),
      clock: sl<Clock>(),
    ),
  );

  // ── C-6: Offline coordinator (factory — one per VoiceBloc instance) ────
  sl.registerFactory<OfflineVoiceCoordinator>(
    () => OfflineVoiceCoordinator(
      parser: const IntentParser([
        matchDeleteWorkoutSet,
        matchEditWorkoutSet,
        matchLogWorkoutSet,
        matchDeleteNutrition,
        matchEditNutrition,
        matchLogNutrition,
        matchQueryWeeklyVolume,
        matchQueryDailyMacros,
        matchQueryRecentSets,
      ]),
      exerciseLookup: sl<ExerciseLookup>(),
      mealLookup: sl<MealLookup>(),
      recentEntityLookup: sl<RecentEntityLookup>(),
    ),
  );

  // ── Cubits / blocs ─────────────────────────────────────────────────────
  // VoiceSettingsCubit: factory — subscribes to
  // AppSettingsRepository.watchSettings() so writes from anywhere (the
  // main settings page, the voice settings page) propagate through the
  // single repository-level broadcast channel. No cross-feature
  // application-layer import on AppSettingsCubit.
  sl.registerFactory(
    () => VoiceSettingsCubit(
      repository: sl<AppSettingsRepository>(),
      deleteVoiceHistory: sl<DeleteVoiceHistory>(),
    ),
  );

  // VoiceBloc: factory — per voice overlay instance.
  // `currentVoiceSettings` is a callback so the bloc reads the latest values
  // from the singleton AppSettingsCubit at every chat turn (no stale snapshot).
  // Mutation dispatch is handled by VoiceCommandRouter in the widget tree —
  // VoiceBloc holds no BLoC references.
  sl.registerFactory(
    () => VoiceBloc(
      sendVoiceMessage: sl(),
      getVoiceBudget: sl(),
      deleteVoiceHistory: sl(),
      sttService: sl(),
      ttsService: sl(),
      appSettingsRepository: sl(),
      currentVoiceSettings: () =>
          sl<AppSettingsCubit>().state.settings.voiceSettings,
      networkStatusService: sl<NetworkStatusService>(),
      wakeWordService: sl<VoiceWakeWordService>(),
      wakelockService: sl<WakelockService>(),
      getSetsByDateRange: sl<GetSetsByDateRange>(),
      getDailyMacros: sl<GetDailyMacros>(),
      getWeeklySets: sl<GetWeeklySets>(),
      getLogsForDate: sl<GetLogsForDate>(),
      exerciseLookup: sl<ExerciseLookup>(),
      offlineCoordinator: sl<OfflineVoiceCoordinator>(),
    ),
  );
}

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
import '../../domain/services/voice_earcon_service.dart';
import '../../domain/services/voice_media_button_service.dart';
import '../../domain/services/voice_permission_service.dart';
import '../../domain/services/voice_pre_roll_store.dart';
import '../../domain/services/voice_stt_service.dart';
import '../../domain/services/voice_tts_service.dart';
import '../../domain/services/voice_wake_word_service.dart';
import '../../domain/usecases/exercises/get_all_exercises.dart';
import '../../domain/usecases/nutrition_logs/get_daily_macros.dart';
import '../../domain/usecases/nutrition_logs/get_logs_by_date_range.dart';
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
import '../../features/voice/data/services/in_memory_voice_pre_roll_store.dart';
import '../../features/voice/data/services/just_audio_voice_earcon_service.dart';
import '../../features/voice/data/services/network_aware_voice_stt_service.dart';
import '../../features/voice/data/services/permission_handler_voice_permission_service.dart';
import '../../features/voice/data/services/sherpa_onnx_voice_wake_word_service.dart';
import '../../features/voice/data/services/speech_to_text_voice_stt_service.dart';
import '../../features/voice/data/services/voice_media_button_factory.dart'
    if (dart.library.io) '../../features/voice/data/services/voice_media_button_factory_io.dart';
import '../../features/voice/data/services/whisper_voice_stt_service.dart';

/// Wires up the voice feature.
///
/// Ordering note: `registerCoreModule` must run before this module
/// (it owns `AppSettingsCubit`, `AppSettingsRepository`, and
/// `NetworkStatusService`). The injection bootstrap enforces this order.
void registerVoiceModule(GetIt sl) {
  // ── Microphone permission service ──────────────────────────────────────
  sl.registerLazySingleton<VoicePermissionService>(
    () => const PermissionHandlerVoicePermissionService(),
  );

  // ── Device services (STT + TTS) ────────────────────────────────────────
  // Lazy singletons: the underlying plugins hold native resources
  // (microphone session, TTS engine) and must not be torn down /
  // re-created per overlay instance.
  //
  // STT routing: the composite NetworkAwareVoiceSttService delegates each
  // listen() call to Whisper when online (better gym-jargon recognition,
  // billed server-side) and falls back to the on-device speech_to_text
  // plugin when offline. Both backends are warmed up at initialise time.
  sl.registerLazySingleton<VoiceSttService>(
    () => NetworkAwareVoiceSttService(
      remoteService: WhisperVoiceSttService(
        remoteDataSource: sl<VoiceRemoteDataSource>(),
        preRollStore: sl<VoicePreRollStore>(),
      ),
      onDeviceService: SpeechToTextVoiceSttService(),
      networkStatusService: sl<NetworkStatusService>(),
    ),
  );
  sl.registerLazySingleton<VoiceTtsService>(FlutterTtsVoiceTtsService.new);

  // ── Earcon player (non-speech cues; owns a just_audio AudioPlayer) ──────
  sl.registerLazySingleton<VoiceEarconService>(JustAudioVoiceEarconService.new);

  // ── Pre-roll store (wake→STT first-words capture) ──────────────────────
  // Single-slot hand-off buffer shared between the wake-word engine (producer)
  // and the Whisper STT path (consumer). Must be a singleton so both sides see
  // the same instance. Registered before the wake-word engine, which depends
  // on it.
  sl.registerLazySingleton<VoicePreRollStore>(
    () => InMemoryVoicePreRollStore(clock: sl<Clock>()),
  );

  // ── Wake-word engine ───────────────────────────────────────────────────
  // Lazy singleton: holds the microphone and must not be torn down /
  // re-created per overlay instance. VoiceFab manages lifecycle
  // (start on resume, stop on background).
  sl.registerLazySingleton<VoiceWakeWordService>(
    () => SherpaOnnxVoiceWakeWordService(
      preRollStore: sl<VoicePreRollStore>(),
      clock: sl<Clock>(),
    ),
  );

  // ── Media-button (headphone tap-to-wake) service ───────────────────────
  // Platform selection is handled by the conditional-import factory:
  // Android → PlatformChannelVoiceMediaButtonService (native MediaSession);
  // all other platforms → NoopVoiceMediaButtonService (stream never emits).
  // Lifecycle mirrors the wake-word engine — started/stopped in VoiceFab
  // (Plan 3 commit 2).
  sl.registerLazySingleton<VoiceMediaButtonService>(
    createVoiceMediaButtonService,
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
      earconService: sl<VoiceEarconService>(),
      wakeWordService: sl<VoiceWakeWordService>(),
      wakelockService: sl<WakelockService>(),
      getSetsByDateRange: sl<GetSetsByDateRange>(),
      getDailyMacros: sl<GetDailyMacros>(),
      getWeeklySets: sl<GetWeeklySets>(),
      getLogsForDate: sl<GetLogsForDate>(),
      getLogsByDateRange: sl<GetLogsByDateRange>(),
      exerciseLookup: sl<ExerciseLookup>(),
      offlineCoordinator: sl<OfflineVoiceCoordinator>(),
    ),
  );
}

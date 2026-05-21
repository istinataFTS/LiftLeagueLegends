import 'package:get_it/get_it.dart';

import '../../domain/repositories/app_settings_repository.dart';
import '../../features/settings/application/app_settings_cubit.dart';

/// Registers [AppSettingsCubit] as a lazy singleton so every injection point
/// (Settings page, VoiceSettingsCubit) shares the same instance and state.
void registerSettingsModule(GetIt sl) {
  // convention-checker:allow=bloc-factory-registration reason=shared cross-page state for Settings and VoiceSettings pages
  sl.registerLazySingleton<AppSettingsCubit>(
    () => AppSettingsCubit(repository: sl<AppSettingsRepository>()),
  );
}

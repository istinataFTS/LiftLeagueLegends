import 'package:get_it/get_it.dart';

import '../../domain/repositories/app_settings_repository.dart';
import '../../features/settings/application/app_settings_cubit.dart';

/// Registers [AppSettingsCubit] as a lazy singleton so every injection point
/// shares the same instance and state. Settings values (weight unit, week
/// start day, expansion state) are read from multiple pages and must not
/// diverge between them.
void registerSettingsModule(GetIt sl) {
  // convention-checker:allow=bloc-factory-registration reason=app-wide settings state read by multiple pages; a factory would let instances diverge
  sl.registerLazySingleton<AppSettingsCubit>(
    () => AppSettingsCubit(repository: sl<AppSettingsRepository>()),
  );
}

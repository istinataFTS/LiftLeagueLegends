import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/app_settings.dart';

abstract class AppSettingsRepository {
  Future<Either<Failure, AppSettings>> getSettings();

  Future<Either<Failure, void>> saveSettings(AppSettings settings);

  /// Broadcast stream of the most recently observed [AppSettings].
  ///
  /// Semantics (behavior-subject-like):
  /// - Each new listener immediately receives the last cached value, if
  ///   any. The cache is populated by both [getSettings] (on success) and
  ///   [saveSettings] (on success). If neither has been called, the
  ///   stream emits nothing until one of them runs.
  /// - Every successful [saveSettings] call emits the saved [AppSettings]
  ///   to all current listeners.
  /// - [saveSettings] failures do NOT emit. The cache is unchanged and
  ///   the previous value remains the latest observable.
  /// - Multiple concurrent listeners are supported. The stream is
  ///   broadcast — calling [Stream.listen] does not throw on a second
  ///   subscriber.
  ///
  /// This stream is the single propagation channel for cross-cubit
  /// observability: cubits that mirror a slice of [AppSettings] (e.g.
  /// `VoiceSettingsCubit`) listen here instead of depending on another
  /// cubit, eliminating cross-feature application-layer imports.
  Stream<AppSettings> watchSettings();
}

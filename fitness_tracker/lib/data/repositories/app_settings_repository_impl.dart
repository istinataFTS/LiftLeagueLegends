import 'dart:async';

import 'package:dartz/dartz.dart';

import '../../core/constants/voice_constants.dart';
import '../../core/errors/failures.dart';
import '../../core/errors/repository_guard.dart';
import '../../domain/entities/app_settings.dart';
import '../../domain/entities/voice_settings.dart';
import '../../domain/repositories/app_settings_repository.dart';
import '../datasources/local/app_metadata_local_datasource.dart';

class AppSettingsRepositoryImpl implements AppSettingsRepository {
  static const String _notificationsEnabledKey =
      'settings.notifications_enabled';
  static const String _weekStartDayKey = 'settings.week_start_day';
  static const String _weightUnitKey = 'settings.weight_unit';
  static const String _uiExpansionStateKey = 'settings.ui_expansion_state';

  // Voice settings — one metadata key per field. Missing keys fall back
  // to the corresponding VoiceSettings default.
  static const String _voiceWakeWordPresetKey =
      'settings.voice.wake_word_preset';
  static const String _voiceSessionLoggingKey =
      'settings.voice.session_logging';
  static const String _voiceWorkoutModeAutoKey =
      'settings.voice.workout_mode_auto';
  static const String _voiceTtsVolumeKey = 'settings.voice.tts_volume';
  static const String _voiceTtsSpeechRateKey = 'settings.voice.tts_speech_rate';
  static const String _voiceWakeWordArmedKey = 'settings.voice.wake_word_armed';

  final AppMetadataLocalDataSource localDataSource;

  AppSettingsRepositoryImpl({required this.localDataSource});

  /// Most recently observed [AppSettings]. Populated on successful
  /// [getSettings] reads and successful [saveSettings] writes. Replayed
  /// to each new [watchSettings] subscriber.
  AppSettings? _lastCached;

  /// Broadcasts post-save updates to all [watchSettings] listeners.
  /// Created lazily so callers that never subscribe pay nothing.
  StreamController<AppSettings>? _controller;

  StreamController<AppSettings> _ensureController() {
    return _controller ??= StreamController<AppSettings>.broadcast();
  }

  @override
  Future<Either<Failure, AppSettings>> getSettings() {
    return RepositoryGuard.run(() async {
      final notificationsEnabled = await localDataSource.readBool(
        _notificationsEnabledKey,
      );
      final weekStartDayRaw = await localDataSource.readString(
        _weekStartDayKey,
      );
      final weightUnitRaw = await localDataSource.readString(_weightUnitKey);
      final uiExpansionRaw = await localDataSource.readJsonObject(
        _uiExpansionStateKey,
      );

      final voiceSettings = await _readVoiceSettings();

      final settings = AppSettings(
        notificationsEnabled: notificationsEnabled ?? true,
        weekStartDay: _parseWeekStartDay(weekStartDayRaw),
        weightUnit: _parseWeightUnit(weightUnitRaw),
        uiExpansionState: _parseUiExpansionState(uiExpansionRaw),
        voiceSettings: voiceSettings,
      );

      _lastCached = settings;
      return settings;
    });
  }

  @override
  Future<Either<Failure, void>> saveSettings(AppSettings settings) {
    return RepositoryGuard.run(() async {
      await localDataSource.writeBool(
        _notificationsEnabledKey,
        settings.notificationsEnabled,
      );
      await localDataSource.writeString(
        _weekStartDayKey,
        settings.weekStartDay.name,
      );
      await localDataSource.writeString(
        _weightUnitKey,
        settings.weightUnit.name,
      );
      await localDataSource.writeJsonObject(
        _uiExpansionStateKey,
        settings.uiExpansionState.cast<String, dynamic>(),
      );
      await _writeVoiceSettings(settings.voiceSettings);

      // Only emit AFTER every write succeeds. RepositoryGuard.run catches
      // a throw above and short-circuits this line, so failures never
      // propagate to listeners.
      _lastCached = settings;
      _controller?.add(settings);
    });
  }

  @override
  Stream<AppSettings> watchSettings() {
    // `Stream.multi` creates a per-subscriber controller, which lets us
    // replay [_lastCached] only to the subscriber that just connected
    // (not to existing listeners again). The merged inner subscription
    // forwards all subsequent broadcast events.
    return Stream<AppSettings>.multi((listener) {
      final cached = _lastCached;
      if (cached != null) listener.add(cached);
      final sub = _ensureController().stream.listen(
        listener.add,
        onError: listener.addError,
      );
      listener.onCancel = () async {
        await sub.cancel();
      };
    });
  }

  // ---------------------------------------------------------------------------
  // VoiceSettings persistence
  // ---------------------------------------------------------------------------

  Future<VoiceSettings> _readVoiceSettings() async {
    const defaults = VoiceSettings.defaults();

    final wakePresetRaw = await localDataSource.readString(
      _voiceWakeWordPresetKey,
    );
    final sessionLogging = await localDataSource.readBool(
      _voiceSessionLoggingKey,
    );
    final workoutAuto = await localDataSource.readBool(
      _voiceWorkoutModeAutoKey,
    );
    final ttsVolumeRaw = await localDataSource.readString(_voiceTtsVolumeKey);
    final ttsSpeechRateRaw = await localDataSource.readString(
      _voiceTtsSpeechRateKey,
    );
    final wakeArmed = await localDataSource.readBool(_voiceWakeWordArmedKey);

    return VoiceSettings(
      wakeWordPreset: _parseEnum(
        WakeWordPreset.values,
        wakePresetRaw,
        defaults.wakeWordPreset,
      ),
      sessionLoggingEnabled: sessionLogging ?? defaults.sessionLoggingEnabled,
      workoutModeAutoEnable: workoutAuto ?? defaults.workoutModeAutoEnable,
      ttsVolume: _clampedDouble(
        ttsVolumeRaw,
        min: 0.0,
        max: 1.0,
        fallback: defaults.ttsVolume,
      ),
      ttsSpeechRate: _clampedDouble(
        ttsSpeechRateRaw,
        min: VoiceConstants.minTtsSpeechRate,
        max: VoiceConstants.maxTtsSpeechRate,
        fallback: defaults.ttsSpeechRate,
      ),
      wakeWordArmedInForeground:
          wakeArmed ?? defaults.wakeWordArmedInForeground,
    );
  }

  Future<void> _writeVoiceSettings(VoiceSettings voice) async {
    await localDataSource.writeString(
      _voiceWakeWordPresetKey,
      voice.wakeWordPreset.name,
    );
    await localDataSource.writeBool(
      _voiceSessionLoggingKey,
      voice.sessionLoggingEnabled,
    );
    await localDataSource.writeBool(
      _voiceWorkoutModeAutoKey,
      voice.workoutModeAutoEnable,
    );
    await localDataSource.writeString(
      _voiceTtsVolumeKey,
      voice.ttsVolume.toString(),
    );
    await localDataSource.writeString(
      _voiceTtsSpeechRateKey,
      voice.ttsSpeechRate.toString(),
    );
    await localDataSource.writeBool(
      _voiceWakeWordArmedKey,
      voice.wakeWordArmedInForeground,
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Parses an enum value by `.name`. Falls back to `fallback` on null,
  /// empty, or unknown values — so an out-of-range row from an older
  /// build never crashes the app.
  static T _parseEnum<T extends Enum>(
    List<T> values,
    String? rawName,
    T fallback,
  ) {
    if (rawName == null || rawName.isEmpty) return fallback;
    for (final value in values) {
      if (value.name == rawName) return value;
    }
    return fallback;
  }

  /// Parses a stored double; falls back when missing or unparseable.
  /// Clamps to the valid range so a corrupt row can't push the UI
  /// outside the user-tunable bounds.
  static double _clampedDouble(
    String? raw, {
    required double min,
    required double max,
    required double fallback,
  }) {
    if (raw == null || raw.isEmpty) return fallback;
    final parsed = double.tryParse(raw);
    if (parsed == null) return fallback;
    return parsed.clamp(min, max).toDouble();
  }

  Map<String, bool> _parseUiExpansionState(Map<String, dynamic>? raw) {
    if (raw == null) return const <String, bool>{};
    try {
      return raw.map((String k, dynamic v) => MapEntry(k, v == true));
    } catch (_) {
      return const <String, bool>{};
    }
  }

  WeekStartDay _parseWeekStartDay(String? rawValue) {
    switch (rawValue) {
      case 'sunday':
        return WeekStartDay.sunday;
      case 'monday':
      default:
        return WeekStartDay.monday;
    }
  }

  WeightUnit _parseWeightUnit(String? rawValue) {
    switch (rawValue) {
      case 'pounds':
        return WeightUnit.pounds;
      case 'kilograms':
      default:
        return WeightUnit.kilograms;
    }
  }
}

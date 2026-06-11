import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/errors/failures.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/voice_settings.dart';
import '../../../domain/repositories/app_settings_repository.dart';
import '../../../domain/usecases/voice/delete_voice_history.dart';

/// Read-write facade for the voice-specific slice of [AppSettings].
///
/// **Why a separate cubit:** the Voice Settings page (and the voice
/// overlay) need a focused stream of just [VoiceSettings] instead of the
/// whole `AppSettingsState`. Widget tests can also inject a simpler
/// fake here than the full settings cubit.
///
/// **Why it does not depend on `AppSettingsCubit`:** cross-feature
/// application-layer imports create dependency cycles between features.
/// Both this cubit and `AppSettingsCubit` subscribe to
/// `AppSettingsRepository.watchSettings()` — the repository's broadcast
/// stream is the single propagation channel. A write here is observed
/// by `AppSettingsCubit` and vice versa, without either feature
/// importing the other.
///
/// **Setter shape:** every setter reads the current [AppSettings] from
/// the repository, applies its mutation to the voice slice, and writes
/// the full settings back. The extra read costs one disk hit per setter
/// call (rare, user-initiated) and guarantees no other-feature setting
/// gets clobbered when two writers race.
///
/// **Lifecycle:** subscribes to `watchSettings()` in the constructor;
/// cancels the subscription in [close]. The behavior-subject replay of
/// the stream populates the initial state if `getSettings` has been
/// called anywhere in the app; otherwise the [_init] bootstrap triggers
/// a read.
class VoiceSettingsCubit extends Cubit<VoiceSettings> {
  VoiceSettingsCubit({
    required AppSettingsRepository repository,
    required DeleteVoiceHistory deleteVoiceHistory,
  }) : _repository = repository,
       _deleteVoiceHistory = deleteVoiceHistory,
       super(const VoiceSettings.defaults()) {
    _subscription = _repository
        .watchSettings()
        .map((s) => s.voiceSettings)
        .distinct()
        .listen(_emitIfOpen);
    ready = _init();
  }

  final AppSettingsRepository _repository;
  final DeleteVoiceHistory _deleteVoiceHistory;
  late final StreamSubscription<VoiceSettings> _subscription;

  /// Completes once the initial [AppSettingsRepository.getSettings] read
  /// finishes (success or failure). Callers that must not arm the wake-word
  /// engine with un-hydrated defaults await this before reading [state].
  late final Future<void> ready;

  /// Bootstrap: triggers an initial read so the cubit's state reflects
  /// persisted values even when no other subscriber has populated the
  /// repository's cache yet. A subsequent stream emission from
  /// `getSettings`'s cache-update is filtered by `distinct` upstream.
  Future<void> _init() async {
    final result = await _repository.getSettings();
    if (isClosed) return;
    result.fold((_) {
      /* failure: keep defaults */
    }, (settings) => _emitIfOpen(settings.voiceSettings));
  }

  void _emitIfOpen(VoiceSettings next) {
    if (isClosed) return;
    if (next == state) return;
    emit(next);
  }

  // ---------------------------------------------------------------------------
  // Setters — all delegate to [_updateVoice], which performs an atomic
  // read-modify-write against the repository. Returns `Future<bool>`
  // mirroring the save result so the UI can show a "couldn't save"
  // toast on disk failure.
  // ---------------------------------------------------------------------------

  Future<bool> setWakeWordPreset(WakeWordPreset preset) =>
      _updateVoice((v) => v.copyWith(wakeWordPreset: preset));

  Future<bool> setSessionLoggingEnabled(bool enabled) =>
      _updateVoice((v) => v.copyWith(sessionLoggingEnabled: enabled));

  Future<bool> setWorkoutModeAutoEnable(bool enabled) =>
      _updateVoice((v) => v.copyWith(workoutModeAutoEnable: enabled));

  Future<bool> setTtsVolume(double volume) =>
      _updateVoice((v) => v.copyWith(ttsVolume: volume));

  Future<bool> setTtsSpeechRate(double rate) =>
      _updateVoice((v) => v.copyWith(ttsSpeechRate: rate));

  Future<bool> setWakeWordArmedInForeground(bool armed) =>
      _updateVoice((v) => v.copyWith(wakeWordArmedInForeground: armed));

  /// Reads the latest [AppSettings], applies [mutate] to its voice slice,
  /// and saves the full settings back. Returns `true` on success, `false`
  /// on either the read or the write failing.
  Future<bool> _updateVoice(
    VoiceSettings Function(VoiceSettings) mutate,
  ) async {
    final getResult = await _repository.getSettings();
    return getResult.fold<Future<bool>>((Failure _) async => false, (
      AppSettings current,
    ) async {
      final updated = current.copyWith(
        voiceSettings: mutate(current.voiceSettings),
      );
      final saveResult = await _repository.saveSettings(updated);
      return saveResult.isRight();
    });
  }

  // ---------------------------------------------------------------------------
  // Slider previews — emit local state without writing to disk.
  // Pair with the corresponding setter on [Slider.onChangeEnd].
  // ---------------------------------------------------------------------------

  /// Live volume preview — does NOT persist. Pair with [setTtsVolume].
  void previewTtsVolume(double volume) {
    _emitIfOpen(state.copyWith(ttsVolume: volume));
  }

  /// Live speech-rate preview — does NOT persist. Pair with [setTtsSpeechRate].
  void previewTtsSpeechRate(double rate) {
    _emitIfOpen(state.copyWith(ttsSpeechRate: rate));
  }

  // ---------------------------------------------------------------------------
  // History
  // ---------------------------------------------------------------------------

  /// Deletes all stored voice conversation history.
  /// Returns `true` on success, `false` on failure.
  Future<bool> clearHistory() async {
    final result = await _deleteVoiceHistory();
    return result.isRight();
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}

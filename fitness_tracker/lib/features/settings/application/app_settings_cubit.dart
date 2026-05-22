import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/voice_constants.dart';
import '../../../domain/entities/app_settings.dart';
import '../../../domain/entities/voice_settings.dart';
import '../../../domain/repositories/app_settings_repository.dart';

class AppSettingsState extends Equatable {
  const AppSettingsState({
    required this.settings,
    required this.isLoading,
    required this.isSaving,
    required this.hasLoaded,
    this.errorMessage,
  });

  final AppSettings settings;
  final bool isLoading;
  final bool isSaving;
  final bool hasLoaded;
  final String? errorMessage;

  factory AppSettingsState.initial() {
    return const AppSettingsState(
      settings: AppSettings.defaults(),
      isLoading: false,
      isSaving: false,
      hasLoaded: false,
      errorMessage: null,
    );
  }

  AppSettingsState copyWith({
    AppSettings? settings,
    bool? isLoading,
    bool? isSaving,
    bool? hasLoaded,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return AppSettingsState(
      settings: settings ?? this.settings,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => <Object?>[
    settings,
    isLoading,
    isSaving,
    hasLoaded,
    errorMessage,
  ];
}

class AppSettingsCubit extends Cubit<AppSettingsState> {
  AppSettingsCubit({required AppSettingsRepository repository})
    : _repository = repository,
      super(AppSettingsState.initial()) {
    // Subscribe to repository-driven changes so writes from anywhere
    // (e.g. VoiceSettingsCubit) propagate into this cubit's state.
    // The `if (settings == state.settings)` guard inside the handler
    // suppresses the redundant emit when the write originated here.
    _subscription = _repository.watchSettings().listen(_onSettingsChanged);
  }

  final AppSettingsRepository _repository;
  late final StreamSubscription<AppSettings> _subscription;

  void _onSettingsChanged(AppSettings settings) {
    if (isClosed) return;
    if (settings == state.settings) return;
    emit(state.copyWith(settings: settings, hasLoaded: true));
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }

  Future<void> ensureLoaded() async {
    if (state.hasLoaded || state.isLoading || state.isSaving) {
      return;
    }

    await _loadSettings();
  }

  Future<void> loadSettings() async {
    if (state.isLoading || state.isSaving) {
      return;
    }

    await _loadSettings();
  }

  Future<void> refreshSettings() async {
    if (state.isSaving || state.isLoading) {
      return;
    }

    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    emit(state.copyWith(isLoading: true, clearErrorMessage: true));

    final result = await _repository.getSettings();

    result.fold(
      (failure) {
        emit(
          state.copyWith(
            settings: const AppSettings.defaults(),
            isLoading: false,
            hasLoaded: true,
            errorMessage: failure.message,
          ),
        );
      },
      (settings) {
        emit(
          state.copyWith(
            settings: settings,
            isLoading: false,
            hasLoaded: true,
            clearErrorMessage: true,
          ),
        );
      },
    );
  }

  Future<bool> saveSettings(AppSettings nextSettings) async {
    emit(state.copyWith(isSaving: true, clearErrorMessage: true));

    final result = await _repository.saveSettings(nextSettings);

    return result.fold(
      (failure) {
        emit(state.copyWith(isSaving: false, errorMessage: failure.message));
        return false;
      },
      (_) {
        emit(
          state.copyWith(
            settings: nextSettings,
            isSaving: false,
            hasLoaded: true,
            clearErrorMessage: true,
          ),
        );
        return true;
      },
    );
  }

  Future<bool> setNotificationsEnabled(bool value) {
    return saveSettings(state.settings.copyWith(notificationsEnabled: value));
  }

  Future<bool> setWeekStartDay(WeekStartDay value) {
    return saveSettings(state.settings.copyWith(weekStartDay: value));
  }

  Future<bool> setWeightUnit(WeightUnit value) {
    return saveSettings(state.settings.copyWith(weightUnit: value));
  }

  Future<bool> setSectionExpanded(String sectionId, {required bool expanded}) {
    final Map<String, bool> updated = Map<String, bool>.from(
      state.settings.uiExpansionState,
    )..[sectionId] = expanded;
    return saveSettings(state.settings.copyWith(uiExpansionState: updated));
  }

  // ---------------------------------------------------------------------------
  // Voice settings setters
  //
  // Each setter writes the whole `AppSettings` via `saveSettings`, which is
  // the single persistence path. This keeps voice-settings storage uniform
  // with every other setting and avoids any per-field shortcut that could
  // diverge from the source of truth.
  // ---------------------------------------------------------------------------

  Future<bool> setVoiceSettings(VoiceSettings voice) {
    return saveSettings(state.settings.copyWith(voiceSettings: voice));
  }

  Future<bool> setVoiceWakeWordPreset(WakeWordPreset preset) {
    return setVoiceSettings(
      state.settings.voiceSettings.copyWith(wakeWordPreset: preset),
    );
  }

  Future<bool> setVoiceSessionLoggingEnabled(bool enabled) {
    return setVoiceSettings(
      state.settings.voiceSettings.copyWith(sessionLoggingEnabled: enabled),
    );
  }

  Future<bool> setVoiceWorkoutModeAutoEnable(bool enabled) {
    return setVoiceSettings(
      state.settings.voiceSettings.copyWith(workoutModeAutoEnable: enabled),
    );
  }

  Future<bool> setVoiceTtsVolume(double volume) {
    return setVoiceSettings(
      state.settings.voiceSettings.copyWith(
        ttsVolume: volume.clamp(0.0, 1.0).toDouble(),
      ),
    );
  }

  Future<bool> setVoiceTtsSpeechRate(double rate) {
    return setVoiceSettings(
      state.settings.voiceSettings.copyWith(
        ttsSpeechRate: rate
            .clamp(
              VoiceConstants.minTtsSpeechRate,
              VoiceConstants.maxTtsSpeechRate,
            )
            .toDouble(),
      ),
    );
  }

  Future<bool> setVoiceWakeWordArmedInForeground(bool armed) {
    return setVoiceSettings(
      state.settings.voiceSettings.copyWith(wakeWordArmedInForeground: armed),
    );
  }

  void clearError() {
    if (state.errorMessage == null) {
      return;
    }

    emit(state.copyWith(clearErrorMessage: true));
  }
}

import 'package:equatable/equatable.dart';

import '../../core/constants/voice_constants.dart';

/// Curated wake-word presets. Each one is a Picovoice Porcupine model
/// bundled with the app. The Porcupine engine (wired up in C-4) picks
/// the right `.ppn` file for the selected preset.
enum WakeWordPreset { samoLevski, trainer, thomas }

extension WakeWordPresetLabel on WakeWordPreset {
  String get displayName {
    switch (this) {
      case WakeWordPreset.samoLevski:
        return 'Samo Levski';
      case WakeWordPreset.trainer:
        return 'Trainer';
      case WakeWordPreset.thomas:
        return 'Thomas';
    }
  }
}

/// Voice-bot preferences. **All fields are device-local**, persisted via
/// the existing `AppSettings` repository (key-value rows in the
/// `app_metadata` SQLite table). No cloud sync.
///
/// Defaults mirror the master spec §3.6 — change them there first if
/// you change them here.
class VoiceSettings extends Equatable {
  const VoiceSettings({
    this.wakeWordPreset = WakeWordPreset.samoLevski,
    this.sessionLoggingEnabled = false,
    this.workoutModeAutoEnable = false,
    this.ttsVolume = VoiceConstants.defaultTtsVolume,
    this.ttsSpeechRate = VoiceConstants.defaultTtsSpeechRate,
    this.wakeWordArmedInForeground = true,
  });

  const VoiceSettings.defaults() : this();

  /// Which wake-word model the Porcupine engine listens for.
  final WakeWordPreset wakeWordPreset;

  /// When `true`, every voice turn is logged to `voice_sessions` for
  /// post-hoc inspection. Default OFF — full transcripts are PII.
  final bool sessionLoggingEnabled;

  /// When `true`, entering Workout Mode automatically arms the wake
  /// word and keeps the app foregrounded.
  final bool workoutModeAutoEnable;

  /// TTS playback volume (0.0 – 1.0). Applied via `flutter_tts.setVolume`.
  final double ttsVolume;

  /// TTS speech rate (0.5 – 2.0; 1.0 = system default). Replaces the
  /// previous OpenAI voice picker — device-native TTS uses the OS
  /// default voice, but speech rate is universally tunable.
  final double ttsSpeechRate;

  /// Whether the wake-word engine should be armed whenever the app is
  /// foregrounded. False means the user must tap the FAB to start a
  /// voice session.
  final bool wakeWordArmedInForeground;

  VoiceSettings copyWith({
    WakeWordPreset? wakeWordPreset,
    bool? sessionLoggingEnabled,
    bool? workoutModeAutoEnable,
    double? ttsVolume,
    double? ttsSpeechRate,
    bool? wakeWordArmedInForeground,
  }) {
    return VoiceSettings(
      wakeWordPreset: wakeWordPreset ?? this.wakeWordPreset,
      sessionLoggingEnabled:
          sessionLoggingEnabled ?? this.sessionLoggingEnabled,
      workoutModeAutoEnable:
          workoutModeAutoEnable ?? this.workoutModeAutoEnable,
      ttsVolume: ttsVolume ?? this.ttsVolume,
      ttsSpeechRate: ttsSpeechRate ?? this.ttsSpeechRate,
      wakeWordArmedInForeground:
          wakeWordArmedInForeground ?? this.wakeWordArmedInForeground,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    wakeWordPreset,
    sessionLoggingEnabled,
    workoutModeAutoEnable,
    ttsVolume,
    ttsSpeechRate,
    wakeWordArmedInForeground,
  ];
}

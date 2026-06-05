import 'package:flutter/widgets.dart';

abstract final class VoiceSettingsPageKeys {
  VoiceSettingsPageKeys._();

  static const Key pageKey = ValueKey<String>('voice_settings_page');
  static const Key wakeWordSectionKey = ValueKey<String>(
    'voice_settings_wake_word_section',
  );
  static const Key wakeWordSamoLevskiKey = ValueKey<String>(
    'voice_settings_wake_word_samo_levski',
  );
  static const Key wakeWordTrainerKey = ValueKey<String>(
    'voice_settings_wake_word_trainer',
  );
  static const Key wakeWordThomasKey = ValueKey<String>(
    'voice_settings_wake_word_thomas',
  );
  static const Key wakeWordArmedToggleKey = ValueKey<String>(
    'voice_settings_wake_word_armed_toggle',
  );
  static const Key sessionLoggingToggleKey = ValueKey<String>(
    'voice_settings_session_logging_toggle',
  );
  static const Key workoutModeAutoToggleKey = ValueKey<String>(
    'voice_settings_workout_mode_auto_toggle',
  );
  static const Key ttsVolumeSliderKey = ValueKey<String>(
    'voice_settings_tts_volume_slider',
  );
  static const Key ttsSpeechRateSliderKey = ValueKey<String>(
    'voice_settings_tts_speech_rate_slider',
  );
  static const Key budgetMeterKey = ValueKey<String>(
    'voice_settings_budget_meter',
  );
  static const Key deleteHistoryButtonKey = ValueKey<String>(
    'voice_settings_delete_history_button',
  );
}

import 'package:flutter/widgets.dart';

abstract final class VoiceOverlayKeys {
  VoiceOverlayKeys._();

  static const Key fabKey = ValueKey<String>('voice_fab');
  static const Key overlayPageKey = ValueKey<String>('voice_overlay_page');
  static const Key micButtonKey = ValueKey<String>('voice_overlay_mic_button');
  static const Key stopButtonKey = ValueKey<String>(
    'voice_overlay_stop_button',
  );
  static const Key retryButtonKey = ValueKey<String>(
    'voice_overlay_retry_button',
  );
  static const Key interruptButtonKey = ValueKey<String>(
    'voice_overlay_interrupt_button',
  );
  static const Key workoutModeToggleKey = ValueKey<String>(
    'voice_overlay_workout_mode_toggle',
  );
  static const Key transcriptListKey = ValueKey<String>(
    'voice_overlay_transcript_list',
  );
  static const Key confirmationCardKey = ValueKey<String>(
    'voice_overlay_confirmation_card',
  );
  static const Key confirmationYesKey = ValueKey<String>(
    'voice_overlay_confirmation_yes',
  );
  static const Key confirmationEditKey = ValueKey<String>(
    'voice_overlay_confirmation_edit',
  );
  static const Key confirmationCancelKey = ValueKey<String>(
    'voice_overlay_confirmation_cancel',
  );
  static const Key workoutModeBannerKey = ValueKey<String>(
    'voice_overlay_workout_mode_banner',
  );
  static const Key statusViewKey = ValueKey<String>(
    'voice_overlay_status_view',
  );
  static const Key closeButtonKey = ValueKey<String>(
    'voice_overlay_close_button',
  );
  static const Key settingsButtonKey = ValueKey<String>(
    'voice_overlay_settings_button',
  );
  static const Key budgetIndicatorKey = ValueKey<String>(
    'voice_overlay_budget_indicator',
  );

  // Edit bar (appears after tapping Edit on the confirmation card)
  static const Key editBarKey = ValueKey<String>('voice_edit_bar');
  static const Key editBarFieldKey = ValueKey<String>('voice_edit_bar_field');
  static const Key editBarSendKey = ValueKey<String>('voice_edit_bar_send');
  static const Key editBarDiscardKey = ValueKey<String>(
    'voice_edit_bar_discard',
  );
}

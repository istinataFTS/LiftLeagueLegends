import 'package:flutter/material.dart';

class SettingsPageKeys {
  const SettingsPageKeys._();

  static const Key loadingIndicatorKey = ValueKey<String>(
    'settings_loading_indicator',
  );
  static const Key refreshListKey = ValueKey<String>('settings_refresh_list');
  static const Key notificationsSwitchKey = ValueKey<String>(
    'settings_notifications_switch',
  );
  static const Key weekStartTileKey = ValueKey<String>(
    'settings_week_start_tile',
  );
  static const Key weightUnitTileKey = ValueKey<String>(
    'settings_weight_unit_tile',
  );
  static const Key savingIndicatorKey = ValueKey<String>(
    'settings_saving_indicator',
  );
  static const Key errorBannerKey = ValueKey<String>('settings_error_banner');
  static const Key usernameTileKey = ValueKey<String>('settings_username_tile');
  static const Key usernameDialogFieldKey = ValueKey<String>(
    'settings_username_dialog_field',
  );
  static const Key usernameDialogSaveKey = ValueKey<String>(
    'settings_username_dialog_save',
  );
}

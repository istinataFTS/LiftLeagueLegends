import 'package:flutter/material.dart';

class ProfilePageKeys {
  const ProfilePageKeys._();

  static const Key loadingIndicatorKey = ValueKey<String>(
    'profile_loading_indicator',
  );
  static const Key refreshListKey = ValueKey<String>('profile_refresh_list');
  static const Key titleKey = ValueKey<String>('profile_title');
  static const Key subtitleKey = ValueKey<String>('profile_subtitle');
  static const Key sessionBannerKey = ValueKey<String>(
    'profile_session_banner',
  );
  static const Key settingsTileKey = ValueKey<String>('profile_settings_tile');
  static const Key accountModeBannerKey = ValueKey<String>(
    'profile_account_mode_banner',
  );
}

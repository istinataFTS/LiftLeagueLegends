import 'package:flutter/material.dart';

class HomePageKeys {
  const HomePageKeys._();

  static const Key pageLoadingIndicatorKey = ValueKey<String>(
    'home_page_loading_indicator',
  );
  static const Key refreshListKey = ValueKey<String>('home_refresh_list');
  static const Key progressCardKey = ValueKey<String>('home_progress_card');
  static const Key progressLoadingIndicatorKey = ValueKey<String>(
    'home_progress_loading_indicator',
  );
  static const Key progressRetryButtonKey = ValueKey<String>(
    'home_progress_retry_button',
  );
  static const Key homeRetryButtonKey = ValueKey<String>(
    'home_page_retry_button',
  );
  static const Key macroStripKey = ValueKey<String>('home_macro_strip');
  static const Key bodyVisualKey = ValueKey<String>('home_body_visual');
  static const Key bodyVisualFlipButtonKey = ValueKey<String>(
    'home_body_visual_flip_button',
  );
  static const Key bodyVisualPanelKey = ValueKey<String>(
    'home_body_visual_panel',
  );
}

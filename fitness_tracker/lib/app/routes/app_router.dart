import 'package:flutter/material.dart';

import '../../features/auth/presentation/sign_in_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../../features/voice/presentation/voice_settings_page.dart';
import '../../presentation/navigation/bottom_navigation.dart';
import 'app_routes.dart';

/// Single-source `onGenerateRoute` for the app's `MaterialApp`.
///
/// This file is intentionally the only one in the codebase that imports
/// page classes from multiple features' presentation/ directories — and
/// it's allowed to because it lives in `lib/app/`, the cross-feature
/// composition root. The `cross-feature-presentation-import` convention
/// rule scopes itself to `lib/features/*/presentation/` and therefore
/// does not flag this file.
///
/// Adding a new top-level page:
/// 1. Add the route constant in [AppRoutes].
/// 2. Add a `case` here that returns a [MaterialPageRoute] for the page.
/// 3. Push from anywhere via `Navigator.pushNamed(context, AppRoutes.xxx)`.
abstract final class AppRouter {
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.home:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const BottomNavigation(),
        );
      case AppRoutes.settings:
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const SettingsPage(),
        );
      case AppRoutes.voiceSettings:
        // `VoiceSettingsCubit` is provided once at the auth-session shell
        // level (a navigator ancestor), so the bare page is fine here —
        // `context.read<VoiceSettingsCubit>()` resolves up the tree.
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const VoiceSettingsPage(),
        );
      case AppRoutes.signIn:
        return MaterialPageRoute<bool>(
          settings: settings,
          builder: (_) => const SignInPage(),
        );
    }
    return null;
  }
}

/// Canonical route-name registry for the app.
///
/// Pages push other pages via `Navigator.pushNamed(context, AppRoutes.xxx)`.
/// The named-route registry is the single source of truth that maps a
/// route name to a page class — feature presentation files never import
/// other features' presentation files for navigation.
///
/// The actual page-class wiring lives in [AppRouter.onGenerateRoute]
/// (`lib/app/routes/app_router.dart`). The router is the only file in
/// the codebase allowed to import page classes from multiple features'
/// presentation/ directories, by virtue of living in `lib/app/`.
abstract final class AppRoutes {
  /// Top-level navigator entry. Hosts [BottomNavigation].
  static const String home = '/';

  /// Main settings page.
  static const String settings = '/settings';

  /// Voice-specific settings page. The required [VoiceSettingsCubit] is
  /// provided once at the auth-session shell level, so this route does
  /// not need a nested `BlocProvider`.
  static const String voiceSettings = '/settings/voice';

  /// Sign-in form. Returns `bool` via `Navigator.pop(context, true|false)`
  /// — `true` indicates a successful sign-in. Callers should treat any
  /// other value (including `null`) as "user cancelled".
  static const String signIn = '/auth/sign-in';
}

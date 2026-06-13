import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/constants/app_strings.dart';
import '../core/themes/app_theme.dart';
import '../features/profile/application/profile_cubit.dart';
import '../features/settings/application/app_settings_cubit.dart';
import '../features/settings/presentation/settings_scope.dart';
import '../injection/injection_container.dart' as di;
import '../presentation/navigation/bottom_navigation.dart';
import 'auth_gate.dart';
import 'auth_session_shell.dart';
import 'listeners/app_domain_effects_listener.dart';
import 'listeners/sync_completion_listener.dart';
import 'routes/app_router.dart';
import 'startup/app_startup_listener.dart';

class AppHost extends StatelessWidget {
  const AppHost({super.key});

  @override
  Widget build(BuildContext context) {
    return const FitnessTrackerApp();
  }
}

class FitnessTrackerApp extends StatelessWidget {
  const FitnessTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Only app-lifetime (non-user-scoped) state lives here.
    // All user-data BLoCs live inside AuthSessionShell, which is keyed on the
    // authenticated user id and is therefore rebuilt on every session change.
    return MultiBlocProvider(
      providers: <BlocProvider<dynamic>>[
        BlocProvider<AppSettingsCubit>(
          // Lazy singleton from DI — `VoiceSettingsCubit` reads/writes
          // through this same instance, so a factory here would split
          // the source of truth.
          create: (_) => di.sl<AppSettingsCubit>()..loadSettings(),
        ),
        BlocProvider<ProfileCubit>(
          create: (_) => di.sl<ProfileCubit>()..loadProfile(),
        ),
      ],
      child: AuthSessionShell(
        child: SettingsScope(
          child: AppShell(
            // AuthGate sits above the startup listeners so the initial-load
            // dispatch (LoadWeeklySetsEvent, LoadHomeDataEvent, etc.) only
            // mounts when a real authenticated user is present. Unauthenticated
            // launches go straight to SignInPage and skip the listeners
            // entirely.
            //
            // AppStartupListener and AppDomainEffectsListener are intentionally
            // inside the AppShell (MaterialApp) so they re-subscribe to streams
            // and re-dispatch initial loads for every new session. They sit
            // *inside* the navigator, which means they are descendants of the
            // user-scoped MultiBlocProvider inside AuthSessionShell — as are
            // all routes pushed onto the navigator and every modal sheet.
            home: const AuthGate(
              authenticatedChild: AppStartupListener(
                child: AppDomainEffectsListener(
                  child: SyncCompletionListener(child: BottomNavigation()),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.home, super.key});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // `home:` builds the initial route directly (instead of going
      // through `onGenerateRoute` for '/'). Keeping `home:` for the
      // initial widget lets the existing AppStartupListener →
      // AppDomainEffectsListener → SyncCompletionListener → BottomNavigation
      // composition stay in one place. Pushed routes go through
      // [AppRouter.onGenerateRoute] via `Navigator.pushNamed`.
      home: home,
      onGenerateRoute: AppRouter.onGenerateRoute,
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: const <PointerDeviceKind>{
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.unknown,
        },
      ),
    );
  }
}

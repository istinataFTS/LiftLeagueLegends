import 'dart:ui';
import 'dart:math' as math;

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../config/env_config.dart';
import '../core/constants/app_dimensions.dart';
import '../core/constants/app_strings.dart';
import '../core/themes/app_theme.dart';
import '../features/profile/application/profile_cubit.dart';
import '../features/settings/application/app_settings_cubit.dart';
import '../features/settings/presentation/settings_scope.dart';
import '../injection/injection_container.dart' as di;
import '../presentation/navigation/bottom_navigation.dart';
import 'auth_session_shell.dart';
import 'listeners/app_domain_effects_listener.dart';
import 'listeners/sync_completion_listener.dart';
import 'routes/app_router.dart';
import 'startup/app_startup_listener.dart';

class AppHost extends StatelessWidget {
  const AppHost({super.key});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !EnvConfig.enableDevicePreview) {
      return const FitnessTrackerApp(useDevicePreviewAdapters: false);
    }

    return DevicePreview(
      enabled: true,
      builder: (_) => const FitnessTrackerApp(useDevicePreviewAdapters: true),
    );
  }
}

class FitnessTrackerApp extends StatelessWidget {
  const FitnessTrackerApp({super.key, this.useDevicePreviewAdapters = false});

  final bool useDevicePreviewAdapters;

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
            builder: (BuildContext context, Widget? child) {
              Widget builtChild = child ?? const SizedBox.shrink();

              if (useDevicePreviewAdapters) {
                builtChild = DevicePreview.appBuilder(context, builtChild);
              }

              if (EnvConfig.enableWebPhoneFrame) {
                builtChild = _WebPhoneFrame(child: builtChild);
              }

              return builtChild;
            },
            locale: useDevicePreviewAdapters
                ? DevicePreview.locale(context)
                : null,
            // AppStartupListener and AppDomainEffectsListener are intentionally
            // inside the AppShell (MaterialApp) so they re-subscribe to streams
            // and re-dispatch initial loads for every new session. They sit
            // *inside* the navigator, which means they are descendants of the
            // user-scoped MultiBlocProvider inside AuthSessionShell — as are
            // all routes pushed onto the navigator and every modal sheet.
            home: const AppStartupListener(
              child: AppDomainEffectsListener(
                child: SyncCompletionListener(child: BottomNavigation()),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WebPhoneFrame extends StatelessWidget {
  const _WebPhoneFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth <= AppDimensions.webPhoneBreakpoint) {
          return child;
        }

        final double availableHeight = math.max(
          0,
          constraints.maxHeight - AppDimensions.webPhoneFramePadding,
        );
        final double phoneHeight = math.min(
          AppDimensions.webPhoneMaxHeight,
          availableHeight,
        );

        return ColoredBox(
          color: AppTheme.webFrameBackground,
          child: Center(
            child: Container(
              width: AppDimensions.webPhoneWidth,
              height: phoneHeight,
              decoration: BoxDecoration(
                color: AppTheme.backgroundDark,
                borderRadius: BorderRadius.circular(
                  AppDimensions.webPhoneFrameRadius,
                ),
                border: Border.all(color: AppTheme.borderDark, width: 1.5),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: AppTheme.webFrameShadow,
                    blurRadius: 28,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(
                  AppDimensions.webPhoneContentRadius,
                ),
                child: Stack(
                  children: <Widget>[
                    Positioned.fill(child: child),
                    const Positioned(
                      top: AppDimensions.webPhoneNotchTopOffset,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.webFrameNotch,
                              borderRadius: BorderRadius.all(
                                Radius.circular(999),
                              ),
                            ),
                            child: SizedBox(
                              width: AppDimensions.webPhoneNotchWidth,
                              height: AppDimensions.webPhoneNotchHeight,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AppShell extends StatelessWidget {
  const AppShell({required this.home, super.key, this.builder, this.locale});

  final Widget home;
  final TransitionBuilder? builder;
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      locale: locale,
      builder: builder,
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

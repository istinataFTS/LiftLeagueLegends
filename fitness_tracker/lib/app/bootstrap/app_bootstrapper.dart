import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env_config.dart';
import '../../core/enums/sync_trigger.dart';
import '../../core/logging/app_logger.dart';
import '../../core/network/network_status_service.dart';
import '../../core/sync/remote_sync_runtime_policy.dart';
import '../../core/sync/sync_orchestrator.dart';
import '../../core/utils/app_lifecycle_manager.dart';
import '../../core/utils/performance_monitor.dart';
import '../../demo/web_demo_runtime.dart';
import '../../domain/services/voice_credential_service.dart';
import '../../injection/injection_container.dart' as di;
import 'app_data_seeder.dart';
import 'app_debug_diagnostics_runner.dart';

class AppBootstrapper {
  static const String _startupTimerName = 'app_initialization';
  static const String _dependencyInitTimerName = 'dependency_initialization';
  static const String _supabaseInitTimerName = 'supabase_initialization';
  static const String _dataSeedTimerName = 'default_data_seed';
  static const String _diagnosticsTimerName = 'startup_diagnostics';
  static const String _systemUiTimerName = 'system_ui_configuration';

  const AppBootstrapper();

  Future<void> bootstrap() async {
    AppLogger.info('Bootstrap started', category: 'bootstrap');
    PerformanceMonitor.startTimer(_startupTimerName);

    try {
      _logRuntimeConfig();
      EnvConfig.ensureValidRuntimeConfig();

      _initializeLifecycle();
      await _initializeRemoteBackend();
      await _initializeDependencies();
      _registerSyncLifecycleHooks();
      // Initial sync must not block startup: the data layer is offline-first,
      // so a slow or unreachable backend would otherwise freeze the app until
      // each feature sync hits its network timeout. Run it in the background.
      unawaited(_runInitialSync());
      _configureSystemUi();

      // Seeding and diagnostics are non-critical — defer them until after the
      // first frame so the app is visible before any DB work runs.
      _schedulePostFrameTasks();

      final totalInitTimeMs = PerformanceMonitor.stopTimer(_startupTimerName);
      AppLogger.info(
        'Bootstrap finished in ${totalInitTimeMs}ms',
        category: 'bootstrap',
      );
      PerformanceMonitor.logSummary(
        _startupTimerName,
        category: 'bootstrap',
      );
    } catch (error, stackTrace) {
      final totalInitTimeMs = PerformanceMonitor.stopTimer(_startupTimerName);

      AppLogger.error(
        'Bootstrap failed after ${totalInitTimeMs}ms',
        category: 'bootstrap',
        error: error,
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  void _logRuntimeConfig() {
    if (!kDebugMode) {
      return;
    }

    AppLogger.debug('Printing runtime configuration', category: 'bootstrap');
    EnvConfig.printConfig();
  }

  void _initializeLifecycle() {
    AppLogger.debug('Initializing app lifecycle manager', category: 'bootstrap');
    AppLifecycleManager().initialize();
  }

  Future<void> _initializeRemoteBackend() async {
    if (kIsWeb) {
      AppLogger.info(
        'Skipping remote backend initialization on web bootstrap path',
        category: 'bootstrap',
      );
      return;
    }

    const runtimePolicy = RemoteSyncRuntimePolicy(
      isSupabaseEnabled: EnvConfig.enableSupabase,
      supabaseUrl: EnvConfig.supabaseUrl,
      supabaseAnonKey: EnvConfig.supabaseAnonKey,
    );

    if (!runtimePolicy.isRemoteSyncConfigured) {
      AppLogger.info(
        'Remote sync runtime policy is not configured; continuing without remote backend',
        category: 'bootstrap',
      );
      return;
    }

    AppLogger.info('Initializing Supabase', category: 'bootstrap');

    await PerformanceMonitor.trackAsync<void>(
      _supabaseInitTimerName,
      () => Supabase.initialize(
        url: EnvConfig.supabaseUrl,
        anonKey: EnvConfig.supabaseAnonKey,
      ),
      slowThresholdMs: 300,
      category: 'bootstrap',
    );

    final summary = PerformanceMonitor.getSummary(_supabaseInitTimerName);
    if (summary != null) {
      AppLogger.info(
        'Supabase initialized in ${summary.latestMs}ms',
        category: 'bootstrap',
      );
    }
  }

  Future<void> _initializeDependencies() async {
    AppLogger.info('Initializing dependencies', category: 'bootstrap');
    await PerformanceMonitor.trackAsync<void>(
      _dependencyInitTimerName,
      () => di.init(
        registerOverrides: kIsWeb ? registerWebDemoOverrides : null,
      ),
      slowThresholdMs: 300,
      category: 'bootstrap',
    );

    final summary = PerformanceMonitor.getSummary(_dependencyInitTimerName);
    if (summary != null) {
      AppLogger.info(
        'Dependencies initialized in ${summary.latestMs}ms',
        category: 'bootstrap',
      );
    }
  }

  void _registerSyncLifecycleHooks() {
    if (kIsWeb) {
      return;
    }

    final SyncOrchestrator syncOrchestrator = di.sl<SyncOrchestrator>();
    final NetworkStatusService networkStatusService =
        di.sl<NetworkStatusService>();

    AppLifecycleManager().addResumeCallback(() {
      unawaited(syncOrchestrator.run(SyncTrigger.appResume));
    });

    // Trigger sync immediately when internet connectivity is restored,
    // so offline-queued changes flush without waiting for app resume.
    networkStatusService.onConnectivityRestored.listen((_) {
      AppLogger.info(
        'Connectivity restored — triggering sync',
        category: 'sync',
      );
      unawaited(syncOrchestrator.run(SyncTrigger.appResume));
    });
  }

  void _schedulePostFrameTasks() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_seedDefaultDataIfNeeded());
      unawaited(_runDiagnosticsIfNeeded());
      unawaited(_seedPicovoiceKeyFromEnvIfNeeded());
    });
  }

  /// At every launch: if `--dart-define=PICOVOICE_ACCESS_KEY=...` was
  /// supplied at build time, write it into secure storage — overwriting any
  /// previously stored value that differs. This keeps the stored key in sync
  /// with the shipped binary without requiring manual user setup.
  ///
  /// If the dart-define is absent (empty string) the method is a no-op.
  /// Safe on every platform (the credential service is registered
  /// unconditionally in `register_voice_module.dart`); silently no-ops on
  /// web where secure storage is a `localStorage` shim.
  Future<void> _seedPicovoiceKeyFromEnvIfNeeded() async {
    final fromEnv = EnvConfig.picovoiceAccessKey.trim();
    if (fromEnv.isEmpty) return;

    try {
      final credentials = di.sl<VoiceCredentialService>();
      final stored = await credentials.getPicovoiceAccessKey();
      if (stored == fromEnv) {
        AppLogger.debug(
          'Picovoice key already in sync with PICOVOICE_ACCESS_KEY dart-define; '
          'skipping write.',
          category: 'bootstrap',
        );
        return;
      }
      await credentials.setPicovoiceAccessKey(fromEnv);
      AppLogger.info(
        'Synced Picovoice access key from PICOVOICE_ACCESS_KEY dart-define '
        'into secure storage.',
        category: 'bootstrap',
      );
    } catch (error, stackTrace) {
      // Non-fatal: voice will fail to start the wake-word engine and log a
      // warning — the app remains fully usable without wake word.
      AppLogger.warning(
        'Failed to sync Picovoice access key from dart-define',
        category: 'bootstrap',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _seedDefaultDataIfNeeded() async {
    if (kIsWeb) {
      AppLogger.info(
        'Skipping default data seeding on web',
        category: 'bootstrap',
      );
      return;
    }

    AppLogger.debug(
      'Running default data seeding check',
      category: 'bootstrap',
    );

    await PerformanceMonitor.trackAsync<void>(
      _dataSeedTimerName,
      () => const AppDataSeeder().seedIfEnabled(),
      slowThresholdMs: 250,
      category: 'bootstrap',
    );

    final summary = PerformanceMonitor.getSummary(_dataSeedTimerName);
    if (summary != null) {
      AppLogger.info(
        'Default data seeding step completed in ${summary.latestMs}ms',
        category: 'bootstrap',
      );
    }
  }

  Future<void> _runInitialSync() async {
    if (kIsWeb) {
      AppLogger.info(
        'Skipping initial sync orchestration on web',
        category: 'bootstrap',
      );
      return;
    }

    final SyncOrchestrator syncOrchestrator = di.sl<SyncOrchestrator>();
    final result = await syncOrchestrator.run(SyncTrigger.appLaunch);

    AppLogger.info(
      'Initial sync orchestration finished with status ${result.status.name}: ${result.message}',
      category: 'sync',
    );
  }

  Future<void> _runDiagnosticsIfNeeded() async {
    if (kIsWeb) {
      AppLogger.info(
        'Skipping startup diagnostics on web',
        category: 'bootstrap',
      );
      return;
    }

    AppLogger.debug('Running startup diagnostics check', category: 'bootstrap');

    await PerformanceMonitor.trackAsync<void>(
      _diagnosticsTimerName,
      () => const AppDebugDiagnosticsRunner().runIfEnabled(),
      slowThresholdMs: 250,
      category: 'bootstrap',
    );

    final summary = PerformanceMonitor.getSummary(_diagnosticsTimerName);
    if (summary != null) {
      AppLogger.info(
        'Startup diagnostics step completed in ${summary.latestMs}ms',
        category: 'bootstrap',
      );
    }
  }

  void _configureSystemUi() {
    if (kIsWeb) {
      AppLogger.info(
        'Skipping system UI configuration on web',
        category: 'bootstrap',
      );
      return;
    }

    PerformanceMonitor.trackSync<void>(
      _systemUiTimerName,
      () {
        SystemChrome.setSystemUIOverlayStyle(
          const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            systemNavigationBarColor: Colors.white,
            systemNavigationBarIconBrightness: Brightness.dark,
          ),
        );
      },
      slowThresholdMs: 16,
      category: 'bootstrap',
    );

    final summary = PerformanceMonitor.getSummary(_systemUiTimerName);
    if (summary != null) {
      AppLogger.debug(
        'System UI configured in ${summary.latestMs}ms',
        category: 'bootstrap',
      );
    }
  }
}
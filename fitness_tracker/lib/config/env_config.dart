import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;

import '../core/logging/app_logger.dart';

class EnvConfig {
  EnvConfig._();

  static const Set<String> _supportedEnvironments = {
    'development',
    'staging',
    'production',
  };

  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Fitness Tracker',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';
  static bool get isStaging => environment == 'staging';

  /// DevicePreview must be explicitly enabled.
  /// This avoids dev-only wrappers accidentally becoming part of the runtime path
  /// just because the build is debug.
  static const bool _devicePreviewFlag = bool.fromEnvironment(
    'ENABLE_DEVICE_PREVIEW',
    defaultValue: false,
  );

  static bool get enableDevicePreview => kDebugMode && _devicePreviewFlag;

  static const bool _webPhoneFrameFlag = bool.fromEnvironment(
    'ENABLE_WEB_PHONE_FRAME',
    defaultValue: true,
  );

  static bool get enableWebPhoneFrame =>
      kIsWeb && kDebugMode && _webPhoneFrameFlag;

  static const bool enablePerformanceMonitoring = bool.fromEnvironment(
    'ENABLE_PERFORMANCE_MONITORING',
    defaultValue: true,
  );

  static const String databaseName = String.fromEnvironment(
    'DATABASE_NAME',
    defaultValue: 'fitness_tracker.db',
  );

  /// Database version for migrations.
  /// Version 5: Added exercise_muscle_factors and muscle_stimulus tables, intensity column.
  /// Version 6: Added meal_name column to nutrition_logs table.
  /// Version 7: Added serving_size_grams column to meals table.
  /// Version 8: Reworked targets into typed goals (training + macro targets).
  /// Version 9: Added remote-ready sync metadata columns to workout_sets.
  /// Version 10: Added pending delete sync queue for durable remote deletions.
  /// Version 11: Added remote-ready sync metadata columns to targets.
  /// Version 12: Added remote-ready sync metadata columns to exercises.
  /// Version 13: Added remote-ready sync metadata columns to meals and nutrition logs.
  /// Version 14: Added app metadata storage for session and migration state.
  /// Version 15: Replaced destructive legacy upgrade behavior with explicit compatibility failure.
  /// Version 16: Clear stale exercise_muscle_factors and muscle_stimulus to force reseed with corrected factor names.
  /// Version 17: Added owner_user_id to muscle_stimulus; updated UNIQUE to (owner_user_id, muscle_group, date).
  /// Version 18: Replaced global UNIQUE(name) on exercises and meals with per-owner expression index
  ///             UNIQUE(name, COALESCE(owner_user_id, '')) so system and user rows may share a name.
  /// Version 19: Dropped the targets table — the Targets feature has been removed from the app.
  /// Version 20: Collapsed legacy NULL owner_user_id on exercises and meals to the guest
  ///             sentinel '' so ownership is never NULL (per-user catalog model).
  /// Version 21: Rewrote default exercise/meal rows to deterministic name-derived
  ///             UUIDv5 ids and repointed workout_sets / exercise_muscle_factors /
  ///             nutrition_logs so identity is stable across reseed/device/account.
  /// Version 22: Purged every guest-owned row (owner_user_id IS NULL or '') from
  ///             user-scoped tables and removed the guest catalog-init flags from
  ///             app_metadata. Pre-condition to removing guest mode entirely. See
  ///             KNOWN_ISSUES.md#guest-catalog-pk-collision-blocks-initial-sign-in.
  /// Version 23: Added `daily_volume` (REAL NOT NULL DEFAULT 0.0) to
  ///             muscle_stimulus. Populated by RebuildMuscleStimulusFromWorkoutHistory
  ///             (weight×reps×factor per muscle per day); used by GetMuscleVisualData
  ///             All-time relative total-volume ranking.
  /// Version 24: Added `fatigue_score` (REAL NOT NULL DEFAULT 0.0) to
  ///             muscle_stimulus. Stores running 0–100 fatigue as of the last set;
  ///             populated by RebuildMuscleStimulusFromWorkoutHistory using delayed-
  ///             recovery decay accumulation; read-time decay applied by GetMuscleVisualData.
  /// Version 25: Added `fatigue_anchor_ts` (INTEGER nullable) to muscle_stimulus.
  ///             Epoch-ms (local midnight) of the last day fatigue actually
  ///             accumulated (gain > 0). Decouples the fatigue decay anchor from
  ///             last_set_timestamp so bodyweight/zero-gain sets cannot
  ///             artificially advance the anchor and under-decay fatigue.
  static const int databaseVersion = int.fromEnvironment(
    'DATABASE_VERSION',
    defaultValue: 25,
  );

  static const bool seedDefaultData = bool.fromEnvironment(
    'SEED_DEFAULT_DATA',
    defaultValue: true,
  );

  static const int seedDataVersion = int.fromEnvironment(
    'SEED_DATA_VERSION',
    defaultValue: 1,
  );

  static const bool enableSeedingLogs = bool.fromEnvironment(
    'ENABLE_SEEDING_LOGS',
    defaultValue: true,
  );

  static const bool forceReseed = bool.fromEnvironment(
    'FORCE_RESEED',
    defaultValue: false,
  );

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const String apiKey = String.fromEnvironment(
    'API_KEY',
    defaultValue: '',
  );

  static const int apiTimeoutSeconds = int.fromEnvironment(
    'API_TIMEOUT_SECONDS',
    defaultValue: 30,
  );

  static const bool enableSupabase = bool.fromEnvironment(
    'ENABLE_SUPABASE',
    defaultValue: false,
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );

  static bool get isSupabaseConfigured =>
      enableSupabase &&
      supabaseUrl.trim().isNotEmpty &&
      supabaseAnonKey.trim().isNotEmpty;

  static bool get enableDebugLogs => isDevelopment || kDebugMode;

  static const String logLevel = String.fromEnvironment(
    'LOG_LEVEL',
    defaultValue: 'debug',
  );

  static List<String> getRuntimeConfigIssues() {
    final issues = <String>[];

    if (!_supportedEnvironments.contains(environment)) {
      issues.add(
        'ENVIRONMENT must be one of: ${_supportedEnvironments.join(', ')}.',
      );
    }

    if (databaseName.trim().isEmpty) {
      issues.add('DATABASE_NAME must not be empty.');
    }

    if (databaseVersion < 1) {
      issues.add('DATABASE_VERSION must be greater than or equal to 1.');
    }

    if (apiTimeoutSeconds <= 0) {
      issues.add('API_TIMEOUT_SECONDS must be greater than 0.');
    }

    if (isProduction && forceReseed) {
      issues.add('FORCE_RESEED must be false in production.');
    }

    if (isProduction && apiBaseUrl.isEmpty) {
      issues.add('API_BASE_URL must be set in production.');
    }

    if (isProduction && apiKey.isEmpty) {
      issues.add('API_KEY must be set in production.');
    }

    if (isProduction && enableDevicePreview) {
      issues.add('ENABLE_DEVICE_PREVIEW must be false in production.');
    }

    if (isProduction && enableWebPhoneFrame) {
      issues.add('ENABLE_WEB_PHONE_FRAME must be false in production.');
    }

    if (enableSupabase &&
        (supabaseUrl.trim().isEmpty || supabaseAnonKey.trim().isEmpty)) {
      issues.add(
        'SUPABASE_URL and SUPABASE_ANON_KEY must both be set when ENABLE_SUPABASE is true.',
      );
    }

    return issues;
  }

  static void ensureValidRuntimeConfig() {
    final issues = getRuntimeConfigIssues();

    if (issues.isEmpty) {
      return;
    }

    throw StateError(
      'Invalid runtime configuration:\n- ${issues.join('\n- ')}',
    );
  }

  @Deprecated('Use ensureValidRuntimeConfig() instead.')
  static void validateProductionConfig() {
    ensureValidRuntimeConfig();
  }

  static void printConfig() {
    if (!enableDebugLogs) {
      return;
    }

    AppLogger.debug(
      '========== Environment Configuration ==========',
      category: 'config',
    );
    AppLogger.debug('App Name: $appName', category: 'config');
    AppLogger.debug('App Version: $appVersion', category: 'config');
    AppLogger.debug('Environment: $environment', category: 'config');
    AppLogger.debug(
      'Database: $databaseName (v$databaseVersion)',
      category: 'config',
    );
    AppLogger.debug('Seed Default Data: $seedDefaultData', category: 'config');
    AppLogger.debug('Seed Data Version: $seedDataVersion', category: 'config');
    AppLogger.debug('Force Reseed: $forceReseed', category: 'config');
    AppLogger.debug(
      'Enable Seeding Logs: $enableSeedingLogs',
      category: 'config',
    );
    AppLogger.debug(
      'Enable Device Preview: $enableDevicePreview',
      category: 'config',
    );
    AppLogger.debug('API Base URL: $apiBaseUrl', category: 'config');
    AppLogger.debug(
      'API Timeout Seconds: $apiTimeoutSeconds',
      category: 'config',
    );
    AppLogger.debug('Enable Supabase: $enableSupabase', category: 'config');
    AppLogger.debug(
      'Supabase Configured: $isSupabaseConfigured',
      category: 'config',
    );
    AppLogger.debug('Log Level: $logLevel', category: 'config');
    AppLogger.debug(
      '==============================================',
      category: 'config',
    );
  }
}

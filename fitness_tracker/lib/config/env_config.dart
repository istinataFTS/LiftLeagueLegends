import 'package:flutter/foundation.dart' show kDebugMode;

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

  static const bool enablePerformanceMonitoring = bool.fromEnvironment(
    'ENABLE_PERFORMANCE_MONITORING',
    defaultValue: true,
  );

  static const String databaseName = String.fromEnvironment(
    'DATABASE_NAME',
    defaultValue: 'fitness_tracker.db',
  );

  static const int databaseVersion = int.fromEnvironment(
    'DATABASE_VERSION',
    defaultValue: 26,
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

    if (isProduction && forceReseed) {
      issues.add('FORCE_RESEED must be false in production.');
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

import 'package:flutter/foundation.dart' show kDebugMode;

class EnvConfig {
  // App Configuration
  static const String appName = String.fromEnvironment(
    'APP_NAME',
    defaultValue: 'Fitness Tracker',
  );

  static const String appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0',
  );

  // User Configuration
  static const String userName = String.fromEnvironment(
    'USER_NAME',
    defaultValue: 'Fitness User',
  );

  // Environment
  static const String environment = String.fromEnvironment(
    'ENVIRONMENT',
    defaultValue: 'development',
  );

  static bool get isDevelopment => environment == 'development';
  static bool get isProduction => environment == 'production';

  // Feature Flags - Automatically enabled in debug mode
  static bool get enableDevicePreview => kDebugMode;

  // Database Configuration
  static const String databaseName = String.fromEnvironment(
    'DATABASE_NAME',
    defaultValue: 'fitness_tracker.db',
  );

  static const int databaseVersion = int.fromEnvironment(
    'DATABASE_VERSION',
    defaultValue: 1,
  );

  // API Configuration (for future use)
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.yourapp.com',
  );
}

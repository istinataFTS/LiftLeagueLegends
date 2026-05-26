import '../../config/env_config.dart';

class AppInfo {
  AppInfo._();

  static String get name => EnvConfig.appName;
  static String get version => EnvConfig.appVersion;

  static String get versionLabel => 'Version $version';

  static String get aboutDescription =>
      'A personal fitness tracking app to monitor weekly muscle group training goals.';
}

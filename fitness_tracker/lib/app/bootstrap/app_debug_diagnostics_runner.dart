import 'package:flutter/foundation.dart' show kDebugMode;

import '../../core/utils/app_diagnostics.dart';

class AppDebugDiagnosticsRunner {
  const AppDebugDiagnosticsRunner();

  Future<void> runIfEnabled() async {
    if (!kDebugMode) {
      return;
    }

    await AppDiagnostics.runDiagnostics();
  }
}

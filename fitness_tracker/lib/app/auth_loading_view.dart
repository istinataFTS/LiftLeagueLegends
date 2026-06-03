import 'package:flutter/material.dart';

import '../core/themes/app_theme.dart';

/// Neutral splash shown while [ProfileCubit] resolves the persisted session
/// on launch. Rendered instead of the sign-in page during that brief async
/// window so an already-authenticated user never sees the sign-in surface
/// flash. See KNOWN_ISSUES.md `#auth-gate-must-not-flash-signin-before-session-resolves`.
class AuthLoadingView extends StatelessWidget {
  const AuthLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundDark,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/sign_in_page.dart';
import '../features/profile/application/profile_cubit.dart';

/// Routes unauthenticated users to [SignInPage] and authenticated users to
/// [authenticatedChild].
///
/// Sits inside `MaterialApp.home:` so it can swap the rendered widget purely
/// from [ProfileCubit] state — no imperative navigation. Listens for
/// `state.session != null` via [BlocSelector] so the gate rebuilds only
/// on a real auth transition (not on profile-edit or loading-flag updates).
///
/// Mounted above [AppStartupListener] so the initial-load dispatch
/// (`WorkoutBloc.LoadWeeklySetsEvent`, `HomeBloc.LoadHomeDataEvent`, etc.) is
/// only invoked once a real user is present — unauthenticated launches stay
/// quiet.
class AuthGate extends StatelessWidget {
  const AuthGate({required this.authenticatedChild, super.key});

  /// The widget tree to mount when an authenticated user is present. Should
  /// contain whatever startup listeners and navigation host the app needs
  /// for an active session.
  final Widget authenticatedChild;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ProfileCubit, ProfileState, bool>(
      selector: (ProfileState state) => state.session != null,
      builder: (BuildContext context, bool isAuthenticated) {
        if (!isAuthenticated) {
          return const SignInPage();
        }
        return authenticatedChild;
      },
    );
  }
}

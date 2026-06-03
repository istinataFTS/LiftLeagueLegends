import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/auth/presentation/sign_in_page.dart';
import '../features/profile/application/profile_cubit.dart';
import 'auth_loading_view.dart';

/// The three mutually-exclusive surfaces the gate can show, derived from
/// [ProfileState]. Distinguishing [resolving] from [signedOut] is what stops
/// the sign-in page flashing on an authenticated launch while the session is
/// still being resolved asynchronously by [ProfileCubit.loadProfile].
enum _AuthGateStatus { resolving, signedIn, signedOut }

/// Routes unauthenticated users to [SignInPage] and authenticated users to
/// [authenticatedChild].
///
/// Sits inside `MaterialApp.home:` so it can swap the rendered widget purely
/// from [ProfileCubit] state — no imperative navigation. Uses a three-way
/// [_AuthGateStatus] derived from [ProfileState] so the gate rebuilds only
/// on a real auth transition (not on profile-edit or loading-flag updates),
/// and shows [AuthLoadingView] instead of [SignInPage] while the session is
/// still being resolved asynchronously on cold start.
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
    return BlocSelector<ProfileCubit, ProfileState, _AuthGateStatus>(
      selector: (ProfileState state) {
        if (!state.hasLoaded) return _AuthGateStatus.resolving;
        return state.session != null
            ? _AuthGateStatus.signedIn
            : _AuthGateStatus.signedOut;
      },
      builder: (BuildContext context, _AuthGateStatus status) {
        switch (status) {
          case _AuthGateStatus.resolving:
            return const AuthLoadingView();
          case _AuthGateStatus.signedIn:
            return authenticatedChild;
          case _AuthGateStatus.signedOut:
            return const SignInPage();
        }
      },
    );
  }
}

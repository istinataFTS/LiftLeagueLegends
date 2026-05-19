import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/history/history.dart';
import '../features/home/application/home_bloc.dart';
import '../features/home/application/muscle_visual_bloc.dart';
import '../features/library/application/exercise_bloc.dart';
import '../features/library/application/meal_bloc.dart';
import '../features/log/log.dart';
import '../features/profile/application/profile_cubit.dart';
import '../features/voice/application/voice_bloc.dart';
import '../features/voice/application/voice_settings_cubit.dart';
import '../injection/injection_container.dart' as di;

/// Establishes the authentication boundary in the widget tree.
///
/// Listens to [ProfileCubit] and derives a stable *session key* from the
/// current user id (`'guest'` when unauthenticated). A [KeyedSubtree] keyed
/// on that value wraps the entire user-scoped sub-tree, including [child].
///
/// **Why this matters:** when the session key changes (sign-out → `'guest'`,
/// or `'guest'` → a new authenticated user id), Flutter disposes the entire
/// old sub-tree in full before building the new one. Every user-data BLoC
/// underneath is closed and recreated, so no stale state from a previous
/// session can ever leak into the next.
///
/// **Important – navigator scope:** [child] should contain the [MaterialApp]
/// (or equivalent navigator host). Placing [MaterialApp] *inside* the keyed
/// [MultiBlocProvider] means every route pushed onto the navigator, and every
/// modal bottom sheet, is a descendant of this provider. `context.read<T>()`
/// therefore resolves user-scoped blocs correctly from any route or overlay
/// entry — something that would silently fail if [MaterialApp] were an
/// *ancestor* of this widget.
///
/// Blocs that are *not* user-scoped ([AppSettingsCubit], [ProfileCubit]) live
/// above this widget and are unaffected by the key change.
class AuthSessionShell extends StatelessWidget {
  const AuthSessionShell({required this.child, super.key});

  /// The subtree to place inside the user-scoped [MultiBlocProvider].
  ///
  /// Must contain the app's navigator host (e.g. [MaterialApp]) so that all
  /// pushed routes and modal sheets inherit the user-scoped blocs.
  final Widget child;

  // Sentinel key used when no authenticated user is present.
  static const String _guestKey = 'guest';

  @override
  Widget build(BuildContext context) {
    // BlocSelector rebuilds only when the selected value changes, so the
    // keyed sub-tree is only torn down and rebuilt on a genuine user switch —
    // not on every ProfileState update (e.g. loading flags, profile edits).
    return BlocSelector<ProfileCubit, ProfileState, String>(
      selector: (ProfileState state) => state.session.user?.id ?? _guestKey,
      builder: (BuildContext context, String sessionKey) {
        return KeyedSubtree(
          key: ValueKey<String>(sessionKey),
          child: MultiBlocProvider(
            providers: <BlocProvider<dynamic>>[
              BlocProvider<WorkoutBloc>.value(value: di.sl<WorkoutBloc>()),
              BlocProvider<HomeBloc>(create: (_) => di.sl<HomeBloc>()),
              BlocProvider<MuscleVisualBloc>(
                create: (_) => di.sl<MuscleVisualBloc>(),
              ),
              BlocProvider<ExerciseBloc>(create: (_) => di.sl<ExerciseBloc>()),
              BlocProvider<HistoryBloc>.value(value: di.sl<HistoryBloc>()),
              BlocProvider<MealBloc>(create: (_) => di.sl<MealBloc>()),
              BlocProvider<NutritionLogBloc>.value(
                value: di.sl<NutritionLogBloc>(),
              ),
              BlocProvider<VoiceBloc>(create: (_) => di.sl<VoiceBloc>()),
              BlocProvider<VoiceSettingsCubit>(
                create: (_) => di.sl<VoiceSettingsCubit>(),
              ),
            ],
            child: child,
          ),
        );
      },
    );
  }
}

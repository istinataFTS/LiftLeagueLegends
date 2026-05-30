import '../errors/exceptions.dart';
import '../../domain/repositories/app_session_repository.dart';

/// Resolves the identifier of the currently-active authenticated user from
/// the [AppSessionRepository].
///
/// After guest-mode removal, the app has no session-without-user state at
/// runtime — every reachable code path runs above the auth gate. If the
/// session lookup fails or returns no user, [resolve] throws
/// [MissingUserContextException] so the caller surfaces the real cause
/// instead of silently operating on the wrong owner key.
///
/// This must stay the single source of truth for user-id resolution on both
/// the write path (e.g. `WorkoutBloc` recording stimulus) and the read path
/// (e.g. `MuscleVisualBloc` querying stimulus). A mismatch between writer
/// and reader silently hides training data.
class CurrentUserIdResolver {
  const CurrentUserIdResolver({required this.appSessionRepository});

  final AppSessionRepository appSessionRepository;

  /// Resolves the active authenticated user id. Throws
  /// [MissingUserContextException] when no user is in context.
  Future<String> resolve() async {
    final result = await appSessionRepository.getCurrentSession();
    return result.fold(
      (_) =>
          throw const MissingUserContextException(operation: 'session lookup'),
      (session) => session.user.id,
    );
  }
}

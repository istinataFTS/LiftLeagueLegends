import '../../domain/entities/app_session.dart';
import '../../domain/entities/user_profile.dart';

/// Resolves the human-facing name for the current session.
///
/// Single source of truth shared by the Profile header and the Home
/// greeting so the two surfaces can never disagree. Precedence:
/// profile display name → auth display name → username → fallback.
abstract final class SessionDisplayName {
  SessionDisplayName._();

  static String resolve(AppSession session, UserProfile? profile) {
    final String? name =
        profile?.displayName?.trim().nullIfEmpty() ??
        session.user.displayName?.trim().nullIfEmpty();

    return name ?? profile?.username ?? 'Signed-in User';
  }
}

extension _NullIfEmpty on String {
  String? nullIfEmpty() => isEmpty ? null : this;
}

import '../../../../core/session/session_display_name.dart';
import '../../../../domain/entities/app_session.dart';
import '../../../../domain/entities/user_profile.dart';
import '../../application/profile_cubit.dart';
import '../models/profile_view_data.dart';

class ProfileViewDataMapper {
  const ProfileViewDataMapper._();

  static ProfilePageViewData map(ProfileState state) {
    final AppSession? session = state.session;
    final UserProfile? profile = state.userProfile;

    final String title = session == null
        ? 'Signed out'
        : SessionDisplayName.resolve(session, profile);
    final String subtitle = _resolveSubtitle(session, profile);

    const String sessionBannerMessage =
        'Your data is backed by the cloud and stays in sync across devices.';
    const String accountModeTitle = 'Cloud account';
    const String accountModeSubtitle =
        'Data is owned and synced with your authenticated account';

    return ProfilePageViewData(
      title: title,
      subtitle: subtitle,
      sessionBannerMessage: sessionBannerMessage,
      accountModeTitle: accountModeTitle,
      accountModeSubtitle: accountModeSubtitle,
      isLoading: state.isLoading && !state.hasLoaded,
      errorMessage: state.errorMessage,
      username: profile?.username,
      bio: profile?.bio,
    );
  }

  static String _resolveSubtitle(AppSession? session, UserProfile? profile) {
    if (session == null) {
      return 'Sign in to continue.';
    }

    final String? handle = profile?.username;
    if (handle != null && handle.isNotEmpty) {
      return '@$handle';
    }

    return session.user.email.trim().nullIfEmpty() ?? 'Authenticated session';
  }
}

extension _NullIfEmpty on String {
  String? nullIfEmpty() => isEmpty ? null : this;
}

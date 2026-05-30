import 'package:fitness_tracker/core/session/session_display_name.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/user_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AppSession authed({String displayName = ''}) => AppSession(
    user: AppUser(id: 'u1', email: 'a@b.com', displayName: displayName),
    requiresInitialCloudMigration: false,
    lastCloudSyncAt: null,
  );

  UserProfile profile({String? displayName, String username = 'handle'}) =>
      UserProfile(
        id: 'u1',
        username: username,
        displayName: displayName,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  group('SessionDisplayName.resolve', () {
    // Guest-session case removed: every session at runtime is authenticated.

    test('prefers the profile display name', () {
      expect(
        SessionDisplayName.resolve(
          authed(displayName: 'Auth Name'),
          profile(displayName: 'Profile Name'),
        ),
        'Profile Name',
      );
    });

    test('falls back to the auth display name when profile name is blank', () {
      expect(
        SessionDisplayName.resolve(
          authed(displayName: 'Auth Name'),
          profile(displayName: '  '),
        ),
        'Auth Name',
      );
    });

    test('falls back to the username when no display name is present', () {
      expect(
        SessionDisplayName.resolve(authed(), profile(username: 'alice')),
        'alice',
      );
    });

    test('falls back to a generic label with no profile', () {
      expect(SessionDisplayName.resolve(authed(), null), 'Signed-in User');
    });
  });
}

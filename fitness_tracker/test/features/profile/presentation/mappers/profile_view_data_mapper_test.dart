import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/features/profile/application/profile_cubit.dart';
import 'package:fitness_tracker/features/profile/presentation/mappers/profile_view_data_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // "maps guest profile state into stable view data" removed: guest
  // sessions no longer exist.

  test('maps authenticated profile state into stable view data', () {
    final ProfileState state = ProfileState(
      session: AppSession(
        user: const AppUser(
          id: 'user-1',
          email: 'marin@test.com',
          displayName: 'Marin Dinchev',
        ),
        requiresInitialCloudMigration: true,
        lastCloudSyncAt: DateTime(2026, 3, 18, 14, 45),
      ),
      isLoading: false,
      hasLoaded: true,
      errorMessage: null,
    );

    final viewData = ProfileViewDataMapper.map(state);

    expect(viewData.title, 'Marin Dinchev');
    expect(viewData.subtitle, 'marin@test.com');
    expect(viewData.accountModeTitle, 'Cloud account');
    expect(
      viewData.accountModeSubtitle,
      'Data is owned and synced with your authenticated account',
    );
  });

  test('keeps loading visible only before first successful load', () {
    const ProfileState state = ProfileState(
      session: AppSession(
        user: AppUser(id: '__test_guest__', email: 'guest@test.local'),
      ),
      isLoading: true,
      hasLoaded: false,
      errorMessage: null,
    );

    final viewData = ProfileViewDataMapper.map(state);

    expect(viewData.isLoading, isTrue);
  });
}

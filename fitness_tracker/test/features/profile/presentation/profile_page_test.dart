import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/core/config/app_sync_policy.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/session/session_sync_service.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/repositories/user_profile_repository.dart';
import 'package:fitness_tracker/features/profile/application/profile_cubit.dart';
import 'package:fitness_tracker/features/profile/presentation/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockSessionSyncService extends Mock implements SessionSyncService {}

class MockAuthSessionService extends Mock implements AuthSessionService {}

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

void main() {
  late MockAppSessionRepository repository;
  late MockSessionSyncService sessionSyncService;
  late MockAuthSessionService authSessionService;
  late MockUserProfileRepository userProfileRepository;

  setUp(() {
    repository = MockAppSessionRepository();
    sessionSyncService = MockSessionSyncService();
    authSessionService = MockAuthSessionService();
    userProfileRepository = MockUserProfileRepository();

    when(
      () => repository.syncPolicy,
    ).thenReturn(AppSyncPolicy.productionDefault);

    when(() => sessionSyncService.runManualRefresh()).thenAnswer(
      (_) async => const SessionSyncActionResult(
        status: SessionSyncActionStatus.completed,
        message: 'manual refresh completed successfully',
      ),
    );

    // getProfile is called when the session is authenticated.
    // Return a Left so the cubit falls back to null profile — sufficient
    // for the presentation tests that only inspect session/user fields.
    when(
      () => userProfileRepository.getProfile(any()),
    ).thenAnswer((_) async => const Left(CacheFailure('no profile')));
  });

  // ProfilePage reads ProfileCubit from its ancestor. Each test pumps a
  // fresh BlocProvider so the cubit starts from ProfileState.initial().
  Widget buildSubject() {
    return BlocProvider<ProfileCubit>(
      create: (_) => ProfileCubit(
        repository: repository,
        sessionSyncService: sessionSyncService,
        authSessionService: authSessionService,
        userProfileRepository: userProfileRepository,
      ),
      child: const MaterialApp(home: ProfilePage()),
    );
  }

  testWidgets('shows dedicated loading indicator before session resolves', (
    WidgetTester tester,
  ) async {
    when(() => repository.getCurrentSession()).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return const Right(
        AppSession(
          user: AppUser(id: '__test_guest__', email: 'guest@test.local'),
        ),
      );
    });

    await tester.pumpWidget(buildSubject());
    await tester
        .pump(); // process post-frame callbacks so loading state renders

    expect(find.byKey(ProfilePage.loadingIndicatorKey), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.byKey(ProfilePage.titleKey), findsOneWidget);
  });

  // "renders guest profile shell through stable keys" removed: the page
  // only renders above the auth gate.

  testWidgets('renders authenticated profile shell through stable keys', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    when(() => repository.getCurrentSession()).thenAnswer(
      (_) async => Right(
        AppSession(
          user: const AppUser(
            id: 'user-1',
            email: 'marin@test.com',
            displayName: 'Marin Dinchev',
          ),
          requiresInitialCloudMigration: true,
          lastCloudSyncAt: DateTime(2026, 3, 18, 14, 45),
        ),
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(ProfilePage.titleKey), findsOneWidget);
    expect(find.byKey(ProfilePage.subtitleKey), findsOneWidget);
    expect(find.text('Marin Dinchev'), findsOneWidget);
    expect(find.text('marin@test.com'), findsOneWidget);
    expect(find.text('Cloud account'), findsWidgets);
  });

  testWidgets(
    'authenticated session without display name uses fallback title',
    (WidgetTester tester) async {
      when(() => repository.getCurrentSession()).thenAnswer(
        (_) async => Right(
          AppSession(
            user: const AppUser(
              id: 'user-1',
              email: 'marin@test.com',
              displayName: '',
            ),
            requiresInitialCloudMigration: false,
            lastCloudSyncAt: null,
          ),
        ),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byKey(ProfilePage.titleKey), findsOneWidget);
      expect(find.text('Signed-in User'), findsOneWidget);
      expect(find.text('marin@test.com'), findsOneWidget);
    },
  );

  testWidgets('authenticated session without email uses fallback subtitle', (
    WidgetTester tester,
  ) async {
    when(() => repository.getCurrentSession()).thenAnswer(
      (_) async => Right(
        AppSession(
          user: const AppUser(
            id: 'user-1',
            email: '',
            displayName: 'Marin Dinchev',
          ),
          requiresInitialCloudMigration: false,
          lastCloudSyncAt: null,
        ),
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.byKey(ProfilePage.subtitleKey), findsOneWidget);
    expect(find.text('Authenticated session'), findsOneWidget);
  });

  testWidgets('session failure surfaces the error message', (
    WidgetTester tester,
  ) async {
    when(
      () => repository.getCurrentSession(),
    ).thenAnswer((_) async => const Left(CacheFailure('session unavailable')));

    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('session unavailable'), findsOneWidget);
  });

  testWidgets('pull to refresh runs manual refresh and reloads session', (
    WidgetTester tester,
  ) async {
    when(() => repository.getCurrentSession()).thenAnswer(
      (_) async => const Right(
        AppSession(
          user: AppUser(id: '__test_guest__', email: 'guest@test.local'),
        ),
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(ProfilePage.refreshListKey),
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    verify(() => sessionSyncService.runManualRefresh()).called(1);
    verify(
      () => repository.getCurrentSession(),
    ).called(greaterThanOrEqualTo(2));
  });

  testWidgets('manual refresh failure is shown in snackbar', (
    WidgetTester tester,
  ) async {
    when(() => repository.getCurrentSession()).thenAnswer(
      (_) async => const Right(
        AppSession(
          user: AppUser(id: '__test_guest__', email: 'guest@test.local'),
        ),
      ),
    );

    when(() => sessionSyncService.runManualRefresh()).thenAnswer(
      (_) async => const SessionSyncActionResult(
        status: SessionSyncActionStatus.failed,
        message: 'manual refresh failed: session is not authenticated',
      ),
    );

    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(ProfilePage.refreshListKey),
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(
      find.text('manual refresh failed: session is not authenticated'),
      findsOneWidget,
    );
  });
}

import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/core/auth/auth_session_service_impl.dart';
import 'package:fitness_tracker/core/errors/sync_exceptions.dart';
import 'package:fitness_tracker/core/session/session_sync_service.dart';
import 'package:fitness_tracker/data/datasources/remote/auth_remote_datasource.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/user_profile.dart';
import 'package:fitness_tracker/domain/repositories/user_profile_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthRemoteDataSource extends Mock implements AuthRemoteDataSource {}

class MockSessionSyncService extends Mock implements SessionSyncService {}

class MockUserProfileRepository extends Mock implements UserProfileRepository {}

void main() {
  late MockAuthRemoteDataSource authRemoteDataSource;
  late MockSessionSyncService sessionSyncService;
  late MockUserProfileRepository userProfileRepository;
  late AuthSessionService service;

  const user = AppUser(
    id: 'user-1',
    email: 'marin@test.com',
    displayName: 'Marin',
  );

  final profileFixture = UserProfile(
    id: 'user-1',
    username: 'marin',
    displayName: 'Marin',
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  const sessionCompleted = SessionSyncActionResult(
    status: SessionSyncActionStatus.completed,
    message: 'authenticated session established',
  );

  const sessionFailed = SessionSyncActionResult(
    status: SessionSyncActionStatus.failed,
    message: 'initial sign-in sync failed: sync failed',
  );

  const sessionSkipped = SessionSyncActionResult(
    status: SessionSyncActionStatus.skipped,
    message: 'initial sign-in sync skipped: migration pending',
  );

  setUpAll(() {
    registerFallbackValue(profileFixture);
    registerFallbackValue(
      const AppUser(id: 'fallback-id', email: 'fallback@test.com'),
    );
  });

  setUp(() {
    authRemoteDataSource = MockAuthRemoteDataSource();
    sessionSyncService = MockSessionSyncService();
    userProfileRepository = MockUserProfileRepository();

    service = AuthSessionServiceImpl(
      authRemoteDataSource: authRemoteDataSource,
      sessionSyncService: sessionSyncService,
      userProfileRepository: userProfileRepository,
    );
  });

  // ---------------------------------------------------------------------------
  // signInWithEmail
  // ---------------------------------------------------------------------------

  group('signInWithEmail', () {
    test('authenticates remotely then establishes app session', () async {
      when(
        () => authRemoteDataSource.signInWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
        ),
      ).thenAnswer((_) async => user);

      when(
        () => sessionSyncService.establishAuthenticatedSession(user),
      ).thenAnswer((_) async => sessionCompleted);

      // _ensureProfileExists reads the profile; stub it to report exists.
      when(
        () => userProfileRepository.getProfile('user-1'),
      ).thenAnswer((_) async => Right(profileFixture));

      final result = await service.signInWithEmail(
        email: ' marin@test.com ',
        password: 'secret-password',
      );

      expect(result.isSuccess, isTrue);
      expect(result.message, 'sign-in completed successfully');
      expect(result.user, user);
      expect(result.requiresEmailConfirmation, isFalse);

      verify(
        () => authRemoteDataSource.signInWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
        ),
      ).called(1);

      verify(
        () => sessionSyncService.establishAuthenticatedSession(user),
      ).called(1);
    });

    test(
      'returns failure with auth message when credentials are wrong',
      () async {
        when(
          () => authRemoteDataSource.signInWithEmail(
            email: 'marin@test.com',
            password: 'bad-password',
          ),
        ).thenAnswer(
          (_) async =>
              throw const AuthSyncException('invalid login credentials'),
        );

        final result = await service.signInWithEmail(
          email: 'marin@test.com',
          password: 'bad-password',
        );

        expect(result.isFailure, isTrue);
        expect(result.message, 'sign-in failed: invalid login credentials');

        verifyNever(
          () => sessionSyncService.establishAuthenticatedSession(any()),
        );
      },
    );

    test('returns network message when network is unavailable', () async {
      when(
        () => authRemoteDataSource.signInWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
        ),
      ).thenAnswer(
        (_) async => throw const NetworkSyncException('connection refused'),
      );

      final result = await service.signInWithEmail(
        email: 'marin@test.com',
        password: 'secret-password',
      );

      expect(result.isFailure, isTrue);
      expect(
        result.message,
        'Network unavailable. Please check your connection.',
      );
    });

    test(
      'returns failure when session initialization fails after sign-in',
      () async {
        when(
          () => authRemoteDataSource.signInWithEmail(
            email: 'marin@test.com',
            password: 'secret-password',
          ),
        ).thenAnswer((_) async => user);

        when(
          () => sessionSyncService.establishAuthenticatedSession(user),
        ).thenAnswer((_) async => sessionFailed);

        final result = await service.signInWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
        );

        expect(result.isFailure, isTrue);
        expect(
          result.message,
          'sign-in succeeded but session initialization failed: '
          'initial sign-in sync failed: sync failed',
        );
        expect(result.user, user);
      },
    );

    test('returns failure when session initialization is skipped', () async {
      when(
        () => authRemoteDataSource.signInWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
        ),
      ).thenAnswer((_) async => user);

      when(
        () => sessionSyncService.establishAuthenticatedSession(user),
      ).thenAnswer((_) async => sessionSkipped);

      final result = await service.signInWithEmail(
        email: 'marin@test.com',
        password: 'secret-password',
      );

      expect(result.isFailure, isTrue);
      expect(
        result.message,
        'sign-in succeeded but session initialization was skipped: '
        'initial sign-in sync skipped: migration pending',
      );
      expect(result.user, user);
    });
  });

  // ---------------------------------------------------------------------------
  // signUpWithEmail
  // ---------------------------------------------------------------------------

  group('signUpWithEmail', () {
    const signUpResult = SignUpResult(
      user: user,
      requiresEmailConfirmation: false,
    );

    const signUpResultWithConfirmation = SignUpResult(
      user: user,
      requiresEmailConfirmation: true,
    );

    test(
      'registers and establishes session when no email confirmation needed',
      () async {
        when(
          () => authRemoteDataSource.signUpWithEmail(
            email: 'marin@test.com',
            password: 'secret-password',
            username: 'marin',
          ),
        ).thenAnswer((_) async => signUpResult);

        when(
          () => sessionSyncService.establishAuthenticatedSession(user),
        ).thenAnswer((_) async => sessionCompleted);

        when(
          () => userProfileRepository.upsertProfile(any()),
        ).thenAnswer((_) async => Right(profileFixture));

        final result = await service.signUpWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
          username: 'marin',
        );

        expect(result.isSuccess, isTrue);
        expect(result.message, 'sign-up completed successfully');
        expect(result.requiresEmailConfirmation, isFalse);
        expect(result.user, user);

        verify(
          () => sessionSyncService.establishAuthenticatedSession(user),
        ).called(1);
      },
    );

    test('returns success with requiresEmailConfirmation when backend requires '
        'confirmation', () async {
      when(
        () => authRemoteDataSource.signUpWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
          username: 'marin',
        ),
      ).thenAnswer((_) async => signUpResultWithConfirmation);

      final result = await service.signUpWithEmail(
        email: 'marin@test.com',
        password: 'secret-password',
        username: 'marin',
      );

      expect(result.isSuccess, isTrue);
      expect(result.requiresEmailConfirmation, isTrue);
      expect(result.message, contains('check your email'));

      // Session must NOT be established while email is unconfirmed.
      verifyNever(
        () => sessionSyncService.establishAuthenticatedSession(any()),
      );
    });

    test(
      'returns failure with auth message when sign-up is rejected',
      () async {
        when(
          () => authRemoteDataSource.signUpWithEmail(
            email: 'marin@test.com',
            password: 'secret-password',
            username: 'marin',
          ),
        ).thenAnswer(
          (_) async =>
              throw const AuthSyncException('email already registered'),
        );

        final result = await service.signUpWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
          username: 'marin',
        );

        expect(result.isFailure, isTrue);
        expect(result.message, 'sign-up failed: email already registered');

        verifyNever(
          () => sessionSyncService.establishAuthenticatedSession(any()),
        );
      },
    );

    test(
      'returns network message when network is unavailable during sign-up',
      () async {
        when(
          () => authRemoteDataSource.signUpWithEmail(
            email: 'marin@test.com',
            password: 'secret-password',
            username: 'marin',
          ),
        ).thenAnswer(
          (_) async => throw const NetworkSyncException('no route to host'),
        );

        final result = await service.signUpWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
          username: 'marin',
        );

        expect(result.isFailure, isTrue);
        expect(
          result.message,
          'Network unavailable. Please check your connection.',
        );
      },
    );

    test(
      'returns failure when sign-up succeeds but session initialization fails',
      () async {
        when(
          () => authRemoteDataSource.signUpWithEmail(
            email: 'marin@test.com',
            password: 'secret-password',
            username: 'marin',
          ),
        ).thenAnswer((_) async => signUpResult);

        when(
          () => sessionSyncService.establishAuthenticatedSession(user),
        ).thenAnswer((_) async => sessionFailed);

        final result = await service.signUpWithEmail(
          email: 'marin@test.com',
          password: 'secret-password',
          username: 'marin',
        );

        expect(result.isFailure, isTrue);
        expect(
          result.message,
          contains('sign-up succeeded but session initialization failed'),
        );
        expect(result.user, user);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // verifyEmailOtp
  // ---------------------------------------------------------------------------

  group('verifyEmailOtp', () {
    test(
      'verifies OTP remotely, establishes session, and creates initial profile',
      () async {
        when(
          () => authRemoteDataSource.verifyEmailOtp(
            email: 'marin@test.com',
            token: '123456',
          ),
        ).thenAnswer((_) async => user);

        when(
          () => sessionSyncService.establishAuthenticatedSession(user),
        ).thenAnswer((_) async => sessionCompleted);

        when(
          () => userProfileRepository.upsertProfile(any()),
        ).thenAnswer((_) async => Right(profileFixture));

        final result = await service.verifyEmailOtp(
          email: ' marin@test.com ',
          token: '123456',
        );

        expect(result.isSuccess, isTrue);
        expect(result.message, 'email verified successfully');
        expect(result.user, user);

        verify(
          () => authRemoteDataSource.verifyEmailOtp(
            email: 'marin@test.com',
            token: '123456',
          ),
        ).called(1);

        verify(
          () => sessionSyncService.establishAuthenticatedSession(user),
        ).called(1);

        verify(() => userProfileRepository.upsertProfile(any())).called(1);
      },
    );

    test(
      'returns failure with auth message when OTP is invalid or expired',
      () async {
        when(
          () => authRemoteDataSource.verifyEmailOtp(
            email: 'marin@test.com',
            token: '000000',
          ),
        ).thenAnswer(
          (_) async =>
              throw const AuthSyncException('token has expired or is invalid'),
        );

        final result = await service.verifyEmailOtp(
          email: 'marin@test.com',
          token: '000000',
        );

        expect(result.isFailure, isTrue);
        expect(
          result.message,
          'otp-verification failed: token has expired or is invalid',
        );

        verifyNever(
          () => sessionSyncService.establishAuthenticatedSession(any()),
        );
      },
    );

    test('returns network message when network is unavailable', () async {
      when(
        () => authRemoteDataSource.verifyEmailOtp(
          email: 'marin@test.com',
          token: '123456',
        ),
      ).thenAnswer(
        (_) async => throw const NetworkSyncException('connection timed out'),
      );

      final result = await service.verifyEmailOtp(
        email: 'marin@test.com',
        token: '123456',
      );

      expect(result.isFailure, isTrue);
      expect(
        result.message,
        'Network unavailable. Please check your connection.',
      );
    });

    test(
      'returns failure when OTP is valid but session initialization fails',
      () async {
        when(
          () => authRemoteDataSource.verifyEmailOtp(
            email: 'marin@test.com',
            token: '123456',
          ),
        ).thenAnswer((_) async => user);

        when(
          () => sessionSyncService.establishAuthenticatedSession(user),
        ).thenAnswer((_) async => sessionFailed);

        final result = await service.verifyEmailOtp(
          email: 'marin@test.com',
          token: '123456',
        );

        expect(result.isFailure, isTrue);
        expect(
          result.message,
          contains(
            'otp-verification succeeded but session initialization failed',
          ),
        );
        expect(result.user, user);

        // Profile must not be created when session fails.
        verifyNever(() => userProfileRepository.upsertProfile(any()));
      },
    );
  });
}

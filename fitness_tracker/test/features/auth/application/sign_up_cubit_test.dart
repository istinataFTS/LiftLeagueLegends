import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/features/auth/application/sign_up_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthSessionService extends Mock implements AuthSessionService {}

void main() {
  late MockAuthSessionService authSessionService;
  late SignUpCubit cubit;

  const user = AppUser(id: 'user-1', email: 'marin@test.com');

  const successResult = AuthSessionActionResult(
    status: AuthSessionActionStatus.completed,
    message: 'sign-up completed successfully',
    user: user,
  );

  const confirmationResult = AuthSessionActionResult(
    status: AuthSessionActionStatus.completed,
    message:
        'registration successful; check your email to confirm your account',
    user: user,
    requiresEmailConfirmation: true,
  );

  const failureResult = AuthSessionActionResult(
    status: AuthSessionActionStatus.failed,
    message: 'sign-up failed: email already registered',
  );

  const networkFailureResult = AuthSessionActionResult(
    status: AuthSessionActionStatus.failed,
    message: 'Network unavailable. Please check your connection.',
  );

  setUp(() {
    authSessionService = MockAuthSessionService();
    cubit = SignUpCubit(authSessionService: authSessionService);
  });

  tearDown(() async {
    await cubit.close();
  });

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  test('starts in initial state', () {
    expect(cubit.state.isInitial, isTrue);
    expect(cubit.state.errorMessage, isNull);
  });

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  group('validation', () {
    test('rejects empty fields without calling service', () async {
      await cubit.submit(
        email: '',
        password: '',
        confirmPassword: '',
        username: '',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.errorMessage, 'All fields are required.');

      verifyNever(
        () => authSessionService.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      );
    });

    test('rejects invalid email format', () async {
      await cubit.submit(
        email: 'notanemail',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'marin',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.errorMessage, 'Enter a valid email address.');
    });

    test('rejects password shorter than 8 characters', () async {
      await cubit.submit(
        email: 'marin@test.com',
        password: 'short',
        confirmPassword: 'short',
        username: 'marin',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'Password must be at least 8 characters.',
      );
    });

    test('rejects mismatched passwords', () async {
      await cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'different123',
        username: 'marin',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.errorMessage, 'Passwords do not match.');
    });

    test('rejects username shorter than 3 characters', () async {
      await cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'ab',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.errorMessage, contains('between 3 and 30 characters'));
    });

    test('rejects username with special characters', () async {
      await cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'bad username!',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'Username may only contain letters, numbers, and underscores.',
      );
    });

    test('accepts username with underscores and numbers', () async {
      when(
        () => authSessionService.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => successResult);

      await cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'marin_01',
      );

      expect(cubit.state.isSuccess, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Success paths
  // ---------------------------------------------------------------------------

  group('success', () {
    test(
      'transitions to success when sign-up completes without confirmation',
      () async {
        when(
          () => authSessionService.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer((_) async => successResult);

        await cubit.submit(
          email: ' marin@test.com ',
          password: 'password123',
          confirmPassword: 'password123',
          username: ' marin ',
        );

        expect(cubit.state.isSuccess, isTrue);
        expect(cubit.state.errorMessage, isNull);

        verify(
          () => authSessionService.signUpWithEmail(
            email: 'marin@test.com',
            password: 'password123',
            username: 'marin',
          ),
        ).called(1);
      },
    );

    test('transitions to awaitingEmailConfirmation when backend requires '
        'confirmation', () async {
      when(
        () => authSessionService.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => confirmationResult);

      await cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'marin',
      );

      expect(cubit.state.isAwaitingEmailConfirmation, isTrue);
      expect(cubit.state.errorMessage, isNull);
    });

    test(
      'stores trimmed email in state when awaiting email confirmation',
      () async {
        when(
          () => authSessionService.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer((_) async => confirmationResult);

        await cubit.submit(
          email: '  marin@test.com  ',
          password: 'password123',
          confirmPassword: 'password123',
          username: 'marin',
        );

        expect(cubit.state.isAwaitingEmailConfirmation, isTrue);
        expect(cubit.state.email, 'marin@test.com');
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Failure paths
  // ---------------------------------------------------------------------------

  group('failure', () {
    test('surfaces service auth failure', () async {
      when(
        () => authSessionService.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => failureResult);

      await cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'marin',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'sign-up failed: email already registered',
      );
    });

    test('surfaces network failure message', () async {
      when(
        () => authSessionService.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async => networkFailureResult);

      await cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'marin',
      );

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'Network unavailable. Please check your connection.',
      );
    });

    test('ignores duplicate submit while already submitting', () async {
      when(
        () => authSessionService.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return successResult;
      });

      // First submit — do not await.
      final firstSubmit = cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'marin',
      );

      // Immediate second submit while first is in-flight.
      await cubit.submit(
        email: 'marin@test.com',
        password: 'password123',
        confirmPassword: 'password123',
        username: 'marin',
      );

      await firstSubmit;

      verify(
        () => authSessionService.signUpWithEmail(
          email: any(named: 'email'),
          password: any(named: 'password'),
          username: any(named: 'username'),
        ),
      ).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // clearError
  // ---------------------------------------------------------------------------

  test('clearError resets to initial state', () async {
    await cubit.submit(
      email: '',
      password: '',
      confirmPassword: '',
      username: '',
    );

    expect(cubit.state.isFailure, isTrue);

    cubit.clearError();

    expect(cubit.state.isInitial, isTrue);
    expect(cubit.state.errorMessage, isNull);
  });

  test('clearError is a no-op when there is no error', () {
    expect(cubit.state.errorMessage, isNull);

    cubit.clearError();

    expect(cubit.state.isInitial, isTrue);
  });
}

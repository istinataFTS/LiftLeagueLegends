import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/features/auth/application/otp_verification_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthSessionService extends Mock implements AuthSessionService {}

void main() {
  late MockAuthSessionService authSessionService;
  late OtpVerificationCubit cubit;

  const email = 'marin@test.com';

  const successResult = AuthSessionActionResult(
    status: AuthSessionActionStatus.completed,
    message: 'email verified successfully',
  );

  const failureResult = AuthSessionActionResult(
    status: AuthSessionActionStatus.failed,
    message: 'otp-verification failed: token has expired or is invalid',
  );

  const networkFailureResult = AuthSessionActionResult(
    status: AuthSessionActionStatus.failed,
    message: 'Network unavailable. Please check your connection.',
  );

  setUp(() {
    authSessionService = MockAuthSessionService();
    cubit = OtpVerificationCubit(
      authSessionService: authSessionService,
      email: email,
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  // ---------------------------------------------------------------------------
  // Initial state
  // ---------------------------------------------------------------------------

  test('starts in initial state with correct email', () {
    expect(cubit.state.status, OtpVerificationStatus.initial);
    expect(cubit.state.errorMessage, isNull);
    expect(cubit.email, email);
  });

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  group('validation', () {
    test('rejects empty token without calling service', () async {
      await cubit.submit('');

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'Enter the 6-digit code from your email.',
      );
      verifyNever(
        () => authSessionService.verifyEmailOtp(
          email: any(named: 'email'),
          token: any(named: 'token'),
        ),
      );
    });

    test('rejects token shorter than 6 digits', () async {
      await cubit.submit('12345');

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'Enter the 6-digit code from your email.',
      );
    });

    test('rejects token longer than 6 digits', () async {
      await cubit.submit('1234567');

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'Enter the 6-digit code from your email.',
      );
    });

    test('rejects non-numeric token', () async {
      await cubit.submit('abcdef');

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'Enter the 6-digit code from your email.',
      );
    });

    test('trims whitespace before validating', () async {
      // "  123  " trims to "123" which is only 3 chars — invalid.
      await cubit.submit('  123  ');

      expect(cubit.state.isFailure, isTrue);
      verifyNever(
        () => authSessionService.verifyEmailOtp(
          email: any(named: 'email'),
          token: any(named: 'token'),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Success paths
  // ---------------------------------------------------------------------------

  group('success', () {
    test(
      'transitions to success and calls service with trimmed token',
      () async {
        when(
          () => authSessionService.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenAnswer((_) async => successResult);

        await cubit.submit(' 123456 ');

        expect(cubit.state.isSuccess, isTrue);
        expect(cubit.state.errorMessage, isNull);

        verify(
          () =>
              authSessionService.verifyEmailOtp(email: email, token: '123456'),
        ).called(1);
      },
    );

    test(
      'passes cubit email — not a user-supplied value — to service',
      () async {
        when(
          () => authSessionService.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenAnswer((_) async => successResult);

        await cubit.submit('123456');

        verify(
          () => authSessionService.verifyEmailOtp(
            email: email,
            token: any(named: 'token'),
          ),
        ).called(1);
      },
    );
  });

  // ---------------------------------------------------------------------------
  // Failure paths
  // ---------------------------------------------------------------------------

  group('failure', () {
    test('surfaces service failure message', () async {
      when(
        () => authSessionService.verifyEmailOtp(
          email: any(named: 'email'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async => failureResult);

      await cubit.submit('123456');

      expect(cubit.state.isFailure, isTrue);
      expect(cubit.state.errorMessage, failureResult.message);
    });

    test('surfaces network failure message', () async {
      when(
        () => authSessionService.verifyEmailOtp(
          email: any(named: 'email'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async => networkFailureResult);

      await cubit.submit('123456');

      expect(cubit.state.isFailure, isTrue);
      expect(
        cubit.state.errorMessage,
        'Network unavailable. Please check your connection.',
      );
    });

    test('ignores duplicate submit while already submitting', () async {
      when(
        () => authSessionService.verifyEmailOtp(
          email: any(named: 'email'),
          token: any(named: 'token'),
        ),
      ).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        return successResult;
      });

      final firstSubmit = cubit.submit('123456');
      await cubit.submit('123456'); // in-flight — should be dropped
      await firstSubmit;

      verify(
        () => authSessionService.verifyEmailOtp(
          email: any(named: 'email'),
          token: any(named: 'token'),
        ),
      ).called(1);
    });
  });
}

import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/features/auth/application/sign_in_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthSessionService extends Mock implements AuthSessionService {}

void main() {
  late MockAuthSessionService authSessionService;
  late SignInCubit cubit;

  setUp(() {
    authSessionService = MockAuthSessionService();
    cubit = SignInCubit(authSessionService: authSessionService);
  });

  tearDown(() async {
    await cubit.close();
  });

  test('submit validates required fields locally', () async {
    await cubit.submit(email: '', password: '');

    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.isSuccess, isFalse);
    expect(cubit.state.errorMessage, 'Email and password are required.');

    verifyNever(
      () => authSessionService.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });

  test('submit reports success when auth session completes', () async {
    when(
      () => authSessionService.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const AuthSessionActionResult(
        status: AuthSessionActionStatus.completed,
        message: 'sign-in completed successfully',
      ),
    );

    await cubit.submit(email: ' marin@test.com ', password: 'secret-password');

    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.isSuccess, isTrue);
    expect(cubit.state.errorMessage, isNull);

    verify(
      () => authSessionService.signInWithEmail(
        email: 'marin@test.com',
        password: 'secret-password',
      ),
    ).called(1);
  });

  test('submit surfaces service failure', () async {
    when(
      () => authSessionService.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenAnswer(
      (_) async => const AuthSessionActionResult(
        status: AuthSessionActionStatus.failed,
        message: 'sign-in failed: invalid credentials',
      ),
    );

    await cubit.submit(email: 'marin@test.com', password: 'wrong-password');

    expect(cubit.state.isSubmitting, isFalse);
    expect(cubit.state.isSuccess, isFalse);
    expect(cubit.state.errorMessage, 'sign-in failed: invalid credentials');
  });
}

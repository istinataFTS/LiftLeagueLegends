import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/features/auth/presentation/sign_in_page.dart';
import 'package:fitness_tracker/injection/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthSessionService extends Mock implements AuthSessionService {}

void main() {
  late MockAuthSessionService authSessionService;

  setUp(() async {
    authSessionService = MockAuthSessionService();

    if (di.sl.isRegistered<AuthSessionService>()) {
      await di.sl.unregister<AuthSessionService>();
    }

    di.sl.registerLazySingleton<AuthSessionService>(() => authSessionService);

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
  });

  tearDown(() async {
    if (di.sl.isRegistered<AuthSessionService>()) {
      await di.sl.unregister<AuthSessionService>();
    }
  });

  testWidgets('renders sign-in form and submits credentials', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignInPage()));

    await tester.enterText(
      find.byKey(SignInPage.emailFieldKey),
      'marin@test.com',
    );
    await tester.enterText(
      find.byKey(SignInPage.passwordFieldKey),
      'secret-password',
    );

    await tester.tap(find.byKey(SignInPage.submitButtonKey));
    await tester.pump();

    verify(
      () => authSessionService.signInWithEmail(
        email: 'marin@test.com',
        password: 'secret-password',
      ),
    ).called(1);
  });

  testWidgets('shows validation feedback without calling service', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignInPage()));

    await tester.tap(find.byKey(SignInPage.submitButtonKey));
    await tester.pump();

    expect(find.text('Email and password are required.'), findsOneWidget);

    verifyNever(
      () => authSessionService.signInWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });
}

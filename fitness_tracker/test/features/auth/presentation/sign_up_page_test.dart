import 'dart:async';

import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/features/auth/presentation/sign_up_page.dart';
import 'package:fitness_tracker/injection/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthSessionService extends Mock implements AuthSessionService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _validEmail = 'test@example.com';
const _validUsername = 'testuser';
const _validPassword = 'password123';

const _completedResult = AuthSessionActionResult(
  status: AuthSessionActionStatus.completed,
  message: 'ok',
);

const _otpResult = AuthSessionActionResult(
  status: AuthSessionActionStatus.completed,
  message: 'check your email',
  requiresEmailConfirmation: true,
);

/// Fills all four fields with valid values.
Future<void> _fillValidForm(WidgetTester tester) async {
  await tester.enterText(find.byKey(SignUpPage.emailFieldKey), _validEmail);
  await tester.enterText(
    find.byKey(SignUpPage.usernameFieldKey),
    _validUsername,
  );
  await tester.enterText(
    find.byKey(SignUpPage.passwordFieldKey),
    _validPassword,
  );
  await tester.enterText(
    find.byKey(SignUpPage.confirmPasswordFieldKey),
    _validPassword,
  );
}

void main() {
  late MockAuthSessionService mockAuth;

  setUp(() async {
    mockAuth = MockAuthSessionService();

    if (di.sl.isRegistered<AuthSessionService>()) {
      await di.sl.unregister<AuthSessionService>();
    }
    di.sl.registerLazySingleton<AuthSessionService>(() => mockAuth);

    when(
      () => mockAuth.signUpWithEmail(
        email: any(named: 'email'),
        password: any(named: 'password'),
        username: any(named: 'username'),
      ),
    ).thenAnswer((_) async => _completedResult);
  });

  tearDown(() async {
    if (di.sl.isRegistered<AuthSessionService>()) {
      await di.sl.unregister<AuthSessionService>();
    }
  });

  group('SignUpPage', () {
    group('rendering', () {
      testWidgets('renders all form fields and submit button', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));

        expect(find.byKey(SignUpPage.emailFieldKey), findsOneWidget);
        expect(find.byKey(SignUpPage.usernameFieldKey), findsOneWidget);
        expect(find.byKey(SignUpPage.passwordFieldKey), findsOneWidget);
        expect(find.byKey(SignUpPage.confirmPasswordFieldKey), findsOneWidget);
        expect(find.byKey(SignUpPage.submitButtonKey), findsOneWidget);
        expect(find.text('Create account'), findsWidgets);
      });

      testWidgets('password fields are obscured by default', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));

        final passwordEditable = tester.widget<EditableText>(
          find
              .descendant(
                of: find.byKey(SignUpPage.passwordFieldKey),
                matching: find.byType(EditableText),
              )
              .first,
        );
        final confirmEditable = tester.widget<EditableText>(
          find
              .descendant(
                of: find.byKey(SignUpPage.confirmPasswordFieldKey),
                matching: find.byType(EditableText),
              )
              .first,
        );

        expect(passwordEditable.obscureText, isTrue);
        expect(confirmEditable.obscureText, isTrue);
      });

      testWidgets(
        'tapping visibility icon toggles password field obscureText',
        (WidgetTester tester) async {
          await tester.pumpWidget(const MaterialApp(home: SignUpPage()));

          // First IconButton in the form is the password visibility toggle
          final passwordIcon = find.byIcon(Icons.visibility_outlined).first;
          await tester.tap(passwordIcon);
          await tester.pump();

          final passwordEditable = tester.widget<EditableText>(
            find
                .descendant(
                  of: find.byKey(SignUpPage.passwordFieldKey),
                  matching: find.byType(EditableText),
                )
                .first,
          );
          expect(passwordEditable.obscureText, isFalse);
        },
      );
    });

    group('validation', () {
      testWidgets('shows snackbar when all fields are empty', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));

        await tester.tap(find.byKey(SignUpPage.submitButtonKey));
        await tester.pump();

        expect(find.text('All fields are required.'), findsOneWidget);
        verifyNever(
          () => mockAuth.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        );
      });

      testWidgets('shows snackbar for invalid email (missing @)', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));

        await tester.enterText(
          find.byKey(SignUpPage.emailFieldKey),
          'notvalid',
        );
        await tester.enterText(
          find.byKey(SignUpPage.usernameFieldKey),
          _validUsername,
        );
        await tester.enterText(
          find.byKey(SignUpPage.passwordFieldKey),
          _validPassword,
        );
        await tester.enterText(
          find.byKey(SignUpPage.confirmPasswordFieldKey),
          _validPassword,
        );

        await tester.tap(find.byKey(SignUpPage.submitButtonKey));
        await tester.pump();

        expect(find.text('Enter a valid email address.'), findsOneWidget);
        verifyNever(
          () => mockAuth.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        );
      });

      testWidgets('shows snackbar when password is too short', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));

        await tester.enterText(
          find.byKey(SignUpPage.emailFieldKey),
          _validEmail,
        );
        await tester.enterText(
          find.byKey(SignUpPage.usernameFieldKey),
          _validUsername,
        );
        await tester.enterText(
          find.byKey(SignUpPage.passwordFieldKey),
          'short',
        );
        await tester.enterText(
          find.byKey(SignUpPage.confirmPasswordFieldKey),
          'short',
        );

        await tester.tap(find.byKey(SignUpPage.submitButtonKey));
        await tester.pump();

        expect(
          find.text('Password must be at least 8 characters.'),
          findsOneWidget,
        );
      });

      testWidgets('shows snackbar when passwords do not match', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));

        await tester.enterText(
          find.byKey(SignUpPage.emailFieldKey),
          _validEmail,
        );
        await tester.enterText(
          find.byKey(SignUpPage.usernameFieldKey),
          _validUsername,
        );
        await tester.enterText(
          find.byKey(SignUpPage.passwordFieldKey),
          _validPassword,
        );
        await tester.enterText(
          find.byKey(SignUpPage.confirmPasswordFieldKey),
          'differentpass',
        );

        await tester.tap(find.byKey(SignUpPage.submitButtonKey));
        await tester.pump();

        expect(find.text('Passwords do not match.'), findsOneWidget);
      });

      testWidgets('shows snackbar for invalid username characters', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));

        await tester.enterText(
          find.byKey(SignUpPage.emailFieldKey),
          _validEmail,
        );
        await tester.enterText(
          find.byKey(SignUpPage.usernameFieldKey),
          'bad user!',
        );
        await tester.enterText(
          find.byKey(SignUpPage.passwordFieldKey),
          _validPassword,
        );
        await tester.enterText(
          find.byKey(SignUpPage.confirmPasswordFieldKey),
          _validPassword,
        );

        await tester.tap(find.byKey(SignUpPage.submitButtonKey));
        await tester.pump();

        expect(
          find.text(
            'Username may only contain letters, numbers, and underscores.',
          ),
          findsOneWidget,
        );
      });
    });

    group('submission', () {
      testWidgets('calls service with trimmed credentials on valid input', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
        await _fillValidForm(tester);

        await tester.tap(find.byKey(SignUpPage.submitButtonKey));
        await tester.pump();

        verify(
          () => mockAuth.signUpWithEmail(
            email: _validEmail,
            password: _validPassword,
            username: _validUsername,
          ),
        ).called(1);
      });

      testWidgets('disables submit button while the request is in-flight', (
        WidgetTester tester,
      ) async {
        final completer = Completer<AuthSessionActionResult>();
        when(
          () => mockAuth.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
        await _fillValidForm(tester);

        await tester.tap(find.byKey(SignUpPage.submitButtonKey));
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.byKey(SignUpPage.submitButtonKey),
        );
        expect(button.onPressed, isNull);

        completer.complete(_completedResult);
        await tester.pumpAndSettle();
      });

      testWidgets('shows snackbar with service error message on failure', (
        WidgetTester tester,
      ) async {
        when(
          () => mockAuth.signUpWithEmail(
            email: any(named: 'email'),
            password: any(named: 'password'),
            username: any(named: 'username'),
          ),
        ).thenAnswer(
          (_) async => const AuthSessionActionResult(
            status: AuthSessionActionStatus.failed,
            message: 'Email already in use',
          ),
        );

        await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
        await _fillValidForm(tester);

        await tester.tap(find.byKey(SignUpPage.submitButtonKey));
        await tester.pumpAndSettle();

        expect(find.text('Email already in use'), findsOneWidget);
      });

      testWidgets(
        'navigates to OtpVerificationPage when email confirmation is required',
        (WidgetTester tester) async {
          when(
            () => mockAuth.signUpWithEmail(
              email: any(named: 'email'),
              password: any(named: 'password'),
              username: any(named: 'username'),
            ),
          ).thenAnswer((_) async => _otpResult);
          // Also stub verifyEmailOtp in case the OTP page is pushed
          when(
            () => mockAuth.verifyEmailOtp(
              email: any(named: 'email'),
              token: any(named: 'token'),
            ),
          ).thenAnswer((_) async => _completedResult);

          await tester.pumpWidget(const MaterialApp(home: SignUpPage()));
          await _fillValidForm(tester);

          await tester.tap(find.byKey(SignUpPage.submitButtonKey));
          await tester.pumpAndSettle();

          expect(find.text('Check your email'), findsOneWidget);
        },
      );
    });
  });
}

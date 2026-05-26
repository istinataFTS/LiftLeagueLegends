import 'dart:async';

import 'package:fitness_tracker/core/auth/auth_session_service.dart';
import 'package:fitness_tracker/features/auth/presentation/otp_verification_page.dart';
import 'package:fitness_tracker/injection/injection_container.dart' as di;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAuthSessionService extends Mock implements AuthSessionService {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testEmail = 'user@example.com';
const _validToken = '123456';

const _completedResult = AuthSessionActionResult(
  status: AuthSessionActionStatus.completed,
  message: 'ok',
);

Widget _buildPage() =>
    MaterialApp(home: OtpVerificationPage(email: _testEmail));

void main() {
  late MockAuthSessionService mockAuth;

  setUp(() async {
    mockAuth = MockAuthSessionService();

    if (di.sl.isRegistered<AuthSessionService>()) {
      await di.sl.unregister<AuthSessionService>();
    }
    di.sl.registerLazySingleton<AuthSessionService>(() => mockAuth);

    when(
      () => mockAuth.verifyEmailOtp(
        email: any(named: 'email'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async => _completedResult);
  });

  tearDown(() async {
    if (di.sl.isRegistered<AuthSessionService>()) {
      await di.sl.unregister<AuthSessionService>();
    }
  });

  group('OtpVerificationPage', () {
    group('rendering', () {
      testWidgets('shows email address in the instructional text', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_buildPage());

        expect(
          find.text('Enter the 6-digit code sent to $_testEmail'),
          findsOneWidget,
        );
      });

      testWidgets('renders Confirm button and OTP text field', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_buildPage());

        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Confirm'), findsOneWidget);
      });

      testWidgets('does not show error text in initial state', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_buildPage());

        // The error text widget is conditionally rendered; it should be absent
        expect(
          find.text('Enter the 6-digit code from your email.'),
          findsNothing,
        );
      });
    });

    group('validation', () {
      testWidgets('shows inline error when token is empty', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_buildPage());

        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(
          find.text('Enter the 6-digit code from your email.'),
          findsOneWidget,
        );
        verifyNever(
          () => mockAuth.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        );
      });

      testWidgets('shows inline error when token is fewer than 6 digits', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_buildPage());

        await tester.enterText(find.byType(TextField), '123');
        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(
          find.text('Enter the 6-digit code from your email.'),
          findsOneWidget,
        );
      });

      testWidgets('shows inline error when token contains non-digits', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_buildPage());

        await tester.enterText(find.byType(TextField), 'abcdef');
        await tester.tap(find.text('Confirm'));
        await tester.pump();

        expect(
          find.text('Enter the 6-digit code from your email.'),
          findsOneWidget,
        );
      });
    });

    group('submission', () {
      testWidgets('calls service with email and trimmed token on valid input', (
        WidgetTester tester,
      ) async {
        await tester.pumpWidget(_buildPage());

        await tester.enterText(find.byType(TextField), _validToken);
        await tester.tap(find.text('Confirm'));
        await tester.pump();

        verify(
          () => mockAuth.verifyEmailOtp(email: _testEmail, token: _validToken),
        ).called(1);
      });

      testWidgets('disables Confirm button while request is in-flight', (
        WidgetTester tester,
      ) async {
        final completer = Completer<AuthSessionActionResult>();
        when(
          () => mockAuth.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenAnswer((_) => completer.future);

        await tester.pumpWidget(_buildPage());

        await tester.enterText(find.byType(TextField), _validToken);
        await tester.tap(find.text('Confirm'));
        await tester.pump();

        final button = tester.widget<ElevatedButton>(
          find.byType(ElevatedButton),
        );
        expect(button.onPressed, isNull);

        completer.complete(_completedResult);
        await tester.pumpAndSettle();
      });

      testWidgets('shows inline error message returned by service on failure', (
        WidgetTester tester,
      ) async {
        when(
          () => mockAuth.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenAnswer(
          (_) async => const AuthSessionActionResult(
            status: AuthSessionActionStatus.failed,
            message: 'Invalid or expired code',
          ),
        );

        await tester.pumpWidget(_buildPage());

        await tester.enterText(find.byType(TextField), _validToken);
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        expect(find.text('Invalid or expired code'), findsOneWidget);
      });

      testWidgets('pops with true result on successful verification', (
        WidgetTester tester,
      ) async {
        bool? poppedResult;

        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  poppedResult = await Navigator.of(context).push<bool>(
                    MaterialPageRoute<bool>(
                      builder: (_) =>
                          const OtpVerificationPage(email: _testEmail),
                    ),
                  );
                },
                child: const Text('Open OTP'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Open OTP'));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField), _validToken);
        await tester.tap(find.text('Confirm'));
        await tester.pumpAndSettle();

        expect(poppedResult, isTrue);
      });
    });
  });
}

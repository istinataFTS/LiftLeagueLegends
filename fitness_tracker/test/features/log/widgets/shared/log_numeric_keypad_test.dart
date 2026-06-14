import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_numeric_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper: build keypad and wrap it in a Scaffold so SafeArea etc. are happy.
  Widget buildSubject({
    num initialValue = 0,
    String label = 'Reps',
    bool allowDecimal = false,
    int maxIntegerDigits = 4,
    ValueChanged<num>? onSubmit,
    VoidCallback? onCancel,
  }) {
    return AppShell(
      home: Scaffold(
        body: LogNumericKeypad(
          initialValue: initialValue,
          label: label,
          allowDecimal: allowDecimal,
          maxIntegerDigits: maxIntegerDigits,
          onSubmit: onSubmit ?? (_) {},
          onCancel: onCancel ?? () {},
        ),
      ),
    );
  }

  group('LogNumericKeypad', () {
    group('initial render', () {
      testWidgets('shows Enter <label> header', (tester) async {
        await tester.pumpWidget(buildSubject(label: 'Reps'));
        await tester.pumpAndSettle();

        expect(find.text('Enter Reps'), findsOneWidget);
      });

      testWidgets('shows formatted initial integer value', (tester) async {
        await tester.pumpWidget(buildSubject(initialValue: 15));
        await tester.pumpAndSettle();

        // Header display of "15"
        expect(find.text('15'), findsWidgets);
      });

      testWidgets('shows formatted initial decimal value', (tester) async {
        await tester.pumpWidget(
          buildSubject(initialValue: 80.0, allowDecimal: true),
        );
        await tester.pumpAndSettle();

        expect(find.text('80.0'), findsWidgets);
      });

      testWidgets('integer layout has all digit keys', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        for (final String d in <String>[
          '1',
          '2',
          '3',
          '4',
          '5',
          '6',
          '7',
          '8',
          '9',
        ]) {
          expect(find.text(d), findsWidgets);
        }
      });

      testWidgets('integer layout has backspace and confirm keys', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.text('⌫'), findsOneWidget);
        expect(find.text('✓'), findsOneWidget);
      });

      testWidgets('decimal layout has decimal point key', (tester) async {
        await tester.pumpWidget(buildSubject(allowDecimal: true));
        await tester.pumpAndSettle();

        expect(find.text('.'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        // No ✓ in decimal layout
        expect(find.text('✓'), findsNothing);
      });
    });

    group('digit entry (fresh-replace behavior)', () {
      testWidgets('first digit replaces initial value', (tester) async {
        await tester.pumpWidget(buildSubject(initialValue: 15));
        await tester.pumpAndSettle();

        // Tap '3' — should replace '15' with '3', not produce '153'
        await tester.tap(find.text('3').last);
        await tester.pumpAndSettle();

        // Header should now show '3'
        expect(find.text('3'), findsWidgets);
        expect(find.text('15'), findsNothing);
      });

      testWidgets('second digit appends to first', (tester) async {
        await tester.pumpWidget(buildSubject(initialValue: 0));
        await tester.pumpAndSettle();

        await tester.tap(find.text('2').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('5').last);
        await tester.pumpAndSettle();

        expect(find.text('25'), findsWidgets);
      });
    });

    group('backspace', () {
      testWidgets('backspace on fresh input clears to 0', (tester) async {
        await tester.pumpWidget(buildSubject(initialValue: 12));
        await tester.pumpAndSettle();

        await tester.tap(find.text('⌫'));
        await tester.pumpAndSettle();

        // After backspace on fresh, input is empty → display shows '0'
        expect(find.text('0'), findsWidgets);
      });

      testWidgets('backspace after digit entry deletes last char', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(initialValue: 0));
        await tester.pumpAndSettle();

        await tester.tap(find.text('2').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('5').last);
        await tester.pumpAndSettle();
        // Should be '25' now
        await tester.tap(find.text('⌫'));
        await tester.pumpAndSettle();

        expect(find.text('2'), findsWidgets);
        expect(find.text('25'), findsNothing);
      });
    });

    group('submit', () {
      testWidgets('tapping ✓ on integer calls onSubmit with parsed value', (
        tester,
      ) async {
        num? submitted;
        await tester.pumpWidget(
          buildSubject(initialValue: 0, onSubmit: (v) => submitted = v),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('8').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('✓'));
        await tester.pumpAndSettle();

        expect(submitted, equals(8));
      });

      testWidgets('empty input submits 0', (tester) async {
        num? submitted;
        await tester.pumpWidget(
          buildSubject(initialValue: 5, onSubmit: (v) => submitted = v),
        );
        await tester.pumpAndSettle();

        // Backspace clears fresh input
        await tester.tap(find.text('⌫'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('✓'));
        await tester.pumpAndSettle();

        expect(submitted, equals(0));
      });

      testWidgets('Done button on decimal calls onSubmit', (tester) async {
        num? submitted;
        await tester.pumpWidget(
          buildSubject(
            initialValue: 0,
            allowDecimal: true,
            onSubmit: (v) => submitted = v,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('7').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(submitted, equals(7));
      });
    });

    group('decimal behavior', () {
      testWidgets('can enter a decimal value', (tester) async {
        num? submitted;
        await tester.pumpWidget(
          buildSubject(
            initialValue: 0,
            allowDecimal: true,
            onSubmit: (v) => submitted = v,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('8').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('.'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('5').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(submitted, closeTo(8.5, 0.001));
      });

      testWidgets('decimal cap: second fractional digit is ignored', (
        tester,
      ) async {
        num? submitted;
        await tester.pumpWidget(
          buildSubject(
            initialValue: 0,
            allowDecimal: true,
            onSubmit: (v) => submitted = v,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('8').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('.'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('5').last);
        await tester.pumpAndSettle();
        // This '3' should be ignored — already at 1 fractional digit
        await tester.tap(find.text('3').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(submitted, closeTo(8.5, 0.001));
      });

      testWidgets('decimal point not available in integer mode', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(allowDecimal: false));
        await tester.pumpAndSettle();

        expect(find.text('.'), findsNothing);
      });
    });

    group('maxIntegerDigits', () {
      testWidgets('respects maxIntegerDigits cap', (tester) async {
        num? submitted;
        await tester.pumpWidget(
          buildSubject(
            initialValue: 0,
            maxIntegerDigits: 2,
            onSubmit: (v) => submitted = v,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('1').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('2').last);
        await tester.pumpAndSettle();
        // Third digit should be ignored
        await tester.tap(find.text('3').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('✓'));
        await tester.pumpAndSettle();

        expect(submitted, equals(12));
      });
    });
  });
}

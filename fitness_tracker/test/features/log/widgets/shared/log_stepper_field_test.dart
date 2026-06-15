import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_stepper_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    String label = 'Reps',
    num value = 10,
    ValueChanged<num>? onChanged,
    VoidCallback? onTapValue,
    num step = 1,
    num min = 0,
    bool allowDecimal = false,
    bool dense = false,
    double? width,
  }) {
    final Widget field = LogStepperField(
      label: label,
      value: value,
      onChanged: onChanged ?? (_) {},
      onTapValue: onTapValue,
      step: step,
      min: min,
      allowDecimal: allowDecimal,
      dense: dense,
    );

    return AppShell(
      home: Scaffold(
        body: Center(
          child: width == null ? field : SizedBox(width: width, child: field),
        ),
      ),
    );
  }

  group('LogStepperField', () {
    testWidgets('renders label and value', (tester) async {
      await tester.pumpWidget(buildSubject(label: 'Reps', value: 10));
      await tester.pumpAndSettle();

      expect(find.text('Reps'), findsOneWidget);
      expect(find.text('10'), findsOneWidget);
    });

    testWidgets('tapping + calls onChanged with incremented value', (
      tester,
    ) async {
      num? received;
      await tester.pumpWidget(
        buildSubject(value: 10, step: 1, onChanged: (v) => received = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      expect(received, equals(11));
    });

    testWidgets('tapping − calls onChanged with decremented value', (
      tester,
    ) async {
      num? received;
      await tester.pumpWidget(
        buildSubject(value: 10, step: 1, onChanged: (v) => received = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('−'));
      await tester.pumpAndSettle();

      expect(received, equals(9));
    });

    testWidgets('tapping − at min clamps to min', (tester) async {
      num? received;
      await tester.pumpWidget(
        buildSubject(value: 0, min: 0, step: 1, onChanged: (v) => received = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('−'));
      await tester.pumpAndSettle();

      expect(received, equals(0));
    });

    testWidgets('tapping value calls onTapValue', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        buildSubject(value: 10, onTapValue: () => tapped = true),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('10'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('decimal value shows one decimal place', (tester) async {
      await tester.pumpWidget(buildSubject(value: 80.0, allowDecimal: true));
      await tester.pumpAndSettle();

      expect(find.text('80.0'), findsOneWidget);
    });

    testWidgets('decimal step increments correctly', (tester) async {
      num? received;
      await tester.pumpWidget(
        buildSubject(
          value: 80.0,
          step: 2.5,
          allowDecimal: true,
          onChanged: (v) => received = v,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('+'));
      await tester.pumpAndSettle();

      expect(received, equals(82.5));
    });

    // Regression: the value text must never overflow its slot, however narrow
    // the column or however many digits the value grows to. Before the
    // FittedBox fix this painted the "OVERFLOWED BY x PIXELS" stripe (e.g.
    // the Meal-tab amount stepper, which lives in a tight flex:2 slot).
    testWidgets('does not overflow in a narrow slot with a long value', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(
          width: 120,
          label: 'Amount (grams)',
          value: 100000,
          onTapValue: () {},
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('100000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'does not overflow in a narrow slot with a long decimal value',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(
            width: 110,
            label: 'grams',
            value: 9999.9,
            allowDecimal: true,
            onTapValue: () {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('9999.9'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    group('dense', () {
      testWidgets('hides label text but keeps ± and value', (tester) async {
        await tester.pumpWidget(
          buildSubject(label: 'Protein', value: 42, dense: true),
        );
        await tester.pumpAndSettle();

        expect(find.text('Protein'), findsNothing);
        expect(find.text('−'), findsOneWidget);
        expect(find.text('42'), findsOneWidget);
        expect(find.text('+'), findsOneWidget);
      });

      testWidgets('keeps 44dp hit targets on ± buttons', (tester) async {
        await tester.pumpWidget(buildSubject(value: 10, dense: true));
        await tester.pumpAndSettle();

        final Size minus = tester.getSize(find.text('−').first);
        final Size plus = tester.getSize(find.text('+').first);
        // The Text itself is smaller than the SizedBox; assert the wrapping
        // SizedBox(width: 44, height: 44) is honoured by the parent.
        final Size minusBox = tester.getSize(
          find
              .ancestor(of: find.text('−'), matching: find.byType(SizedBox))
              .first,
        );
        final Size plusBox = tester.getSize(
          find
              .ancestor(of: find.text('+'), matching: find.byType(SizedBox))
              .first,
        );
        expect(minusBox.width, 44);
        expect(minusBox.height, 44);
        expect(plusBox.width, 44);
        expect(plusBox.height, 44);
        expect(minus.width, lessThanOrEqualTo(44));
        expect(plus.width, lessThanOrEqualTo(44));
      });

      testWidgets('does not overflow in narrow slot with long value', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            width: 110,
            label: 'Protein',
            value: 999999,
            dense: true,
            onTapValue: () {},
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('999999'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    });
  });
}

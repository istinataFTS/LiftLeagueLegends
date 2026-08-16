import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_number.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/exercise_set_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({
    int setNumber = 1,
    int intensity = 3,
    String weightText = '80 kg',
    int reps = 10,
  }) {
    return AppShell(
      home: Scaffold(
        body: ExerciseSetRow(
          setNumber: setNumber,
          intensity: intensity,
          weightText: weightText,
          reps: reps,
        ),
      ),
    );
  }

  group('ExerciseSetRow', () {
    testWidgets('renders set number, weight × reps, and intensity level', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(setNumber: 2, intensity: 4, weightText: '100 kg', reps: 8),
      );
      await tester.pumpAndSettle();

      // Set number is zero-padded mono, not "Set n".
      expect(find.text('02'), findsOneWidget);
      // Weight and reps render through LiftNumber (Text.rich); find.text
      // still resolves it via textSpan.toPlainText(), which concatenates
      // the value and unit spans into one string.
      expect(find.text('100kg'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
    });

    testWidgets('five effort marks render, filled up to the level', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      for (int i = 0; i < 5; i++) {
        final Container mark = tester.widget<Container>(
          find.byKey(ValueKey<String>('set-effort-mark-$i')),
        );
        expect(
          (mark.decoration! as BoxDecoration).color,
          i < 3 ? LiftColors.effortOn : LiftColors.effortOff,
        );
      }
    });

    testWidgets('weight renders with the unit riding it', (tester) async {
      await tester.pumpWidget(buildSubject(weightText: '15 kg'));
      await tester.pumpAndSettle();

      final LiftNumber weight = tester.widget<LiftNumber>(
        find.byType(LiftNumber).first,
      );
      expect(weight.value, '15');
      expect(weight.unit, 'kg');
    });

    testWidgets('no gradient survives on the row', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      for (final Container c in tester.widgetList<Container>(
        find.byType(Container),
      )) {
        expect((c.decoration as BoxDecoration?)?.gradient, isNull);
      }
    });
  });
}

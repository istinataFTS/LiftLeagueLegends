import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/exercise_set_row.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_ui_colors.dart';
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

      expect(find.text('Set 2'), findsOneWidget);
      expect(find.text('100 kg × 8'), findsOneWidget);
      // Intensity pill shows the level number.
      expect(find.text('4'), findsOneWidget);
    });

    Align fillAlign(WidgetTester tester) {
      // A Container with `alignment:` inserts its own Align (widthFactor null);
      // the intensity-bar fill is the only Align that sets a widthFactor.
      return tester
          .widgetList<Align>(find.byType(Align))
          .firstWhere((Align a) => a.widthFactor != null);
    }

    testWidgets('intensity bar fill fraction equals level / 5', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      expect(fillAlign(tester).widthFactor, closeTo(3 / 5, 0.0001));
    });

    testWidgets('level 0 fill fraction is 0', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 0));
      await tester.pumpAndSettle();

      expect(fillAlign(tester).widthFactor, equals(0.0));
    });

    testWidgets('intensity pill color matches the ramp slot', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 5));
      await tester.pumpAndSettle();

      final bool hasRampColoredBox = tester
          .widgetList<Container>(find.byType(Container))
          .any((Container c) {
            final Object? deco = c.decoration;
            return deco is BoxDecoration &&
                deco.color == LogUiColors.intensityRamp[5];
          });
      expect(hasRampColoredBox, isTrue);
    });
  });
}

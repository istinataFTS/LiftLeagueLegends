import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/log_intensity_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({int intensity = 3, ValueChanged<int>? onChanged}) {
    return AppShell(
      home: Scaffold(
        body: LogIntensitySelector(
          intensity: intensity,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
  }

  Container rung(WidgetTester tester, int i) =>
      tester.widget<Container>(find.byKey(ValueKey<String>('effort-rung-$i')));

  group('LogIntensitySelector', () {
    testWidgets('renders all six cells 0..5', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      for (int i = 0; i <= 5; i++) {
        expect(find.byKey(ValueKey<String>('effort-rung-$i')), findsOneWidget);
      }
    });

    testWidgets('shows active level and label', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 4));
      await tester.pumpAndSettle();

      final Text readout = tester.widget<Text>(find.textContaining('4 · '));
      expect(readout.data, '4 · HARD');
      expect(readout.style!.color, LiftColors.actionTint);
      expect(readout.style!.fontFamily, 'JetBrainsMono');
    });

    testWidgets('tapping a cell calls onChanged with that level', (
      tester,
    ) async {
      int? received;
      await tester.pumpWidget(
        buildSubject(intensity: 3, onChanged: (v) => received = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey<String>('effort-rung-5')));
      await tester.pumpAndSettle();

      expect(received, equals(5));
    });

    testWidgets('rungs grow in height with the index', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      double previous = 0;
      for (int i = 0; i <= 5; i++) {
        final double h = rung(tester, i).constraints!.maxHeight;
        expect(h, greaterThan(previous));
        previous = h;
      }
    });

    testWidgets('the gradient legend strip is gone', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final Iterable<Container> containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      for (final Container c in containers) {
        expect((c.decoration as BoxDecoration?)?.gradient, isNull);
      }
    });
  });
}

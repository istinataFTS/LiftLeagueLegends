import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
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

  group('LogIntensitySelector', () {
    testWidgets('renders all six cells 0..5', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      for (int i = 0; i <= 5; i++) {
        expect(find.text('$i'), findsWidgets);
      }
    });

    testWidgets('shows active level and label', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      expect(find.text('3 · Moderate'), findsOneWidget);
    });

    testWidgets('tapping a cell calls onChanged with that level', (
      tester,
    ) async {
      int? received;
      await tester.pumpWidget(
        buildSubject(intensity: 3, onChanged: (v) => received = v),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('5'));
      await tester.pumpAndSettle();

      expect(received, equals(5));
    });

    testWidgets('info button opens the IntensityInfoDialog', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 2));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.intensityLevels), findsOneWidget);
    });
  });
}

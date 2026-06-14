import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_tab_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({int selectedIndex = 0, ValueChanged<int>? onChanged}) {
    return AppShell(
      home: Scaffold(
        body: LogTabSelector(
          selectedIndex: selectedIndex,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
  }

  group('LogTabSelector', () {
    testWidgets('renders all three tab labels', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('Exercise'), findsOneWidget);
      expect(find.text('Meal'), findsOneWidget);
      expect(find.text('Macros'), findsOneWidget);
    });

    testWidgets('renders tab icons', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.fitness_center), findsOneWidget);
      expect(find.byIcon(Icons.restaurant), findsOneWidget);
      expect(find.byIcon(Icons.calculate), findsOneWidget);
    });

    testWidgets('tapping Meal tab calls onChanged with index 1', (
      tester,
    ) async {
      int? received;
      await tester.pumpWidget(buildSubject(onChanged: (i) => received = i));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Meal'));
      await tester.pumpAndSettle();

      expect(received, equals(1));
    });

    testWidgets('tapping Macros tab calls onChanged with index 2', (
      tester,
    ) async {
      int? received;
      await tester.pumpWidget(buildSubject(onChanged: (i) => received = i));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Macros'));
      await tester.pumpAndSettle();

      expect(received, equals(2));
    });

    testWidgets('tapping Exercise tab calls onChanged with index 0', (
      tester,
    ) async {
      int? received;
      await tester.pumpWidget(
        buildSubject(selectedIndex: 2, onChanged: (i) => received = i),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Exercise'));
      await tester.pumpAndSettle();

      expect(received, equals(0));
    });

    testWidgets('does not throw with any valid index', (tester) async {
      for (final int i in <int>[0, 1, 2]) {
        await tester.pumpWidget(buildSubject(selectedIndex: i));
        await tester.pumpAndSettle();
        expect(find.byType(LogTabSelector), findsOneWidget);
      }
    });
  });
}

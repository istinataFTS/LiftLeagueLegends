import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/features/log/presentation/pages/log_page.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_tab_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject({int initialIndex = 0, DateTime? initialDate}) {
    return AppShell(
      home: LogPage(
        initialIndex: initialIndex,
        initialDate: initialDate,
        exerciseTabBuilder: (_) =>
            const Center(child: Text('exercise-tab-content')),
        mealTabBuilder: (_) => const Center(child: Text('meal-tab-content')),
        macrosTabBuilder: (_) =>
            const Center(child: Text('macros-tab-content')),
      ),
    );
  }

  group('LogPage', () {
    testWidgets('renders segmented tabs', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(LogTabSelector), findsOneWidget);
      expect(find.text('Exercise'), findsOneWidget);
      expect(find.text('Meal'), findsOneWidget);
      expect(find.text('Macros'), findsOneWidget);
    });

    testWidgets('shows the exercise tab by default', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('exercise-tab-content'), findsOneWidget);
      expect(find.text('meal-tab-content'), findsNothing);
      expect(find.text('macros-tab-content'), findsNothing);
    });

    testWidgets('switches tabs when tapped', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Meal'));
      await tester.pumpAndSettle();

      expect(find.text('exercise-tab-content'), findsNothing);
      expect(find.text('meal-tab-content'), findsOneWidget);
      expect(find.text('macros-tab-content'), findsNothing);

      await tester.tap(find.text('Macros'));
      await tester.pumpAndSettle();

      expect(find.text('exercise-tab-content'), findsNothing);
      expect(find.text('meal-tab-content'), findsNothing);
      expect(find.text('macros-tab-content'), findsOneWidget);
    });

    testWidgets('respects the initial tab index', (tester) async {
      await tester.pumpWidget(buildSubject(initialIndex: 2));
      await tester.pumpAndSettle();

      expect(find.text('exercise-tab-content'), findsNothing);
      expect(find.text('meal-tab-content'), findsNothing);
      expect(find.text('macros-tab-content'), findsOneWidget);
    });

    testWidgets('clamps an invalid initial tab index', (tester) async {
      await tester.pumpWidget(buildSubject(initialIndex: 99));
      await tester.pumpAndSettle();

      expect(find.text('macros-tab-content'), findsOneWidget);
      expect(find.text('exercise-tab-content'), findsNothing);
      expect(find.text('meal-tab-content'), findsNothing);
    });

    testWidgets('renders no AppBar (slim header)', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byType(AppBar), findsNothing);
      expect(find.byType(LogTabSelector), findsOneWidget);
    });

    testWidgets('shows a back button when pushed onto a route', (tester) async {
      await tester.pumpWidget(
        AppShell(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LogPage(
                          exerciseTabBuilder: (_) =>
                              const Center(child: Text('exercise-tab-content')),
                          mealTabBuilder: (_) =>
                              const Center(child: Text('meal-tab-content')),
                          macrosTabBuilder: (_) =>
                              const Center(child: Text('macros-tab-content')),
                        ),
                      ),
                    ),
                    child: const Text('go'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    });

    testWidgets('hides the back button when rendered as a root tab', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });
  });
}

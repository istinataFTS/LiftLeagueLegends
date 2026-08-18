import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/features/log/presentation/pages/log_page.dart';
import 'package:fitness_tracker/presentation/shared/widgets/lift_tab_selector.dart';
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

      expect(find.byType(LiftTabSelector), findsOneWidget);
      expect(find.text('EXERCISE'), findsOneWidget);
      expect(find.text('MEAL'), findsOneWidget);
      expect(find.text('MACROS'), findsOneWidget);
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

      await tester.tap(find.text('MEAL'));
      await tester.pumpAndSettle();

      expect(find.text('exercise-tab-content'), findsNothing);
      expect(find.text('meal-tab-content'), findsOneWidget);
      expect(find.text('macros-tab-content'), findsNothing);

      await tester.tap(find.text('MACROS'));
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
      expect(find.byType(LiftTabSelector), findsOneWidget);
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

    testWidgets(
      'Deep Mist chrome: the tab selector is not wrapped in a bordered '
      'container and no Card is present',
      (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pumpAndSettle();

        expect(find.byType(Card), findsNothing);
        expect(find.byType(LiftTabSelector), findsOneWidget);

        // Pre-restyle chrome wrapped the tab selector in a bordered
        // decorative Container ("chip") — Deep Mist drops that treatment
        // entirely. Scanning every Container on the page (not just direct
        // ancestors of LiftTabSelector, which turns out to have none — a
        // vacuous check that would pass even if the border came back one
        // level up the tree) is what actually catches that regression.
        final Iterable<Container> containers = tester.widgetList<Container>(
          find.byType(Container),
        );
        expect(containers, isNotEmpty);
        for (final Container c in containers) {
          final Decoration? decoration = c.decoration;
          if (decoration is BoxDecoration) {
            expect(decoration.border, isNull);
          }
        }
      },
    );
  });
}

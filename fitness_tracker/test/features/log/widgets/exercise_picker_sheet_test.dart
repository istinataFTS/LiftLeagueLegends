import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/muscle_groups.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/exercise_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../log_phone_viewport.dart';

void main() {
  final Exercise bench = Exercise(
    id: 'ex-bench',
    name: 'Bench Press',
    muscleGroups: const <String>['chest', 'triceps'],
    createdAt: DateTime(2024, 1, 1),
  );
  final Exercise squat = Exercise(
    id: 'ex-squat',
    name: 'Back Squat',
    muscleGroups: const <String>['quads', 'glutes'],
    createdAt: DateTime(2024, 1, 1),
  );
  final Exercise benchPressCompound = Exercise(
    id: 'ex-bench-compound',
    name: 'Barbell Bench Press',
    muscleGroups: const <String>['chest', 'triceps', 'shoulders'],
    createdAt: DateTime(2024, 1, 1),
  );

  Future<void> pumpPicker(
    WidgetTester tester, {
    required List<Exercise> exercises,
    List<String> recentExerciseIds = const <String>[],
    Exercise? selected,
  }) async {
    await tester.pumpWidget(
      AppShell(
        home: Builder(
          builder: (BuildContext context) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => ExercisePickerSheet.show(
                    context,
                    exercises: exercises,
                    recentExerciseIds: recentExerciseIds,
                    selected: selected,
                  ),
                  child: const Text('open'),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  // The muscle filter row scrolls horizontally and only builds chips within
  // (or near) the viewport, so tests that need a chip further down the list
  // (e.g. "quads") must scroll it into view first.
  Future<void> scrollFilterChipIntoView(WidgetTester tester, Key key) async {
    await tester.dragUntilVisible(
      find.byKey(key),
      find.byKey(const ValueKey<String>('muscle-filter-row')),
      const Offset(-200, 0),
    );
    await tester.pumpAndSettle();
  }

  group('ExercisePickerSheet livened tile', () {
    // Rewritten from the pre-restyle "renders muscle pills (display names,
    // not comma text)" test. Task 17 (Spec B, PR B2) replaces the per-muscle
    // pill row with a single right-aligned joined-uppercase metadata string
    // (CONTROLLER AMENDMENT B/C in b-task-17-brief.md), so the old assertion
    // that each muscle's display name renders as its own findable Text is no
    // longer true by design — it is superseded, not abandoned. This keeps
    // the same behavioural intent (muscle groups are visibly associated with
    // the row) under the new chrome, and adds the "no chip/pill" guarantee.
    testWidgets('renders muscle metadata as joined uppercase text, no chip', (
      tester,
    ) async {
      await pumpPicker(tester, exercises: <Exercise>[bench]);

      expect(find.text('Bench Press'), findsOneWidget);
      final String expected =
          '${MuscleGroups.getDisplayName('chest')} · '
          '${MuscleGroups.getDisplayName('triceps')}';
      expect(find.text(expected.toUpperCase()), findsOneWidget);

      // Per-row muscle metadata never uses a Chip/FilterChip to display a
      // value (Deep Mist reserves chips for filters). The muscle filter row
      // itself is restored below, but built from Material/InkWell/Container
      // rather than the framework's FilterChip widget, so this stays true.
      expect(find.byType(FilterChip), findsNothing);
      expect(find.byType(Chip), findsNothing);
    });

    testWidgets('renders leading fitness_center icon tile per row', (
      tester,
    ) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      expect(find.byIcon(Icons.fitness_center), findsNWidgets(2));
    });

    testWidgets('selected row shows trailing check_circle', (tester) async {
      await pumpPicker(
        tester,
        exercises: <Exercise>[bench, squat],
        selected: bench,
      );

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('unselected rows show no check_circle', (tester) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets('tapping a row pops with the chosen exercise', (tester) async {
      Exercise? popped;
      await tester.pumpWidget(
        AppShell(
          home: Builder(
            builder: (BuildContext context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      popped = await ExercisePickerSheet.show(
                        context,
                        exercises: <Exercise>[bench, squat],
                        recentExerciseIds: const <String>[],
                      );
                    },
                    child: const Text('open'),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Back Squat'));
      await tester.pumpAndSettle();

      expect(popped?.id, 'ex-squat');
    });
  });

  group('ExercisePickerSheet Deep Mist chrome', () {
    testWidgets('panel is square (BorderRadius.zero)', (tester) async {
      await pumpPicker(tester, exercises: <Exercise>[bench]);

      final Container panel = tester.widget<Container>(
        find.byKey(const ValueKey<String>('exercise-picker-panel')),
      );
      final BoxDecoration decoration = panel.decoration! as BoxDecoration;
      expect(decoration.borderRadius, BorderRadius.zero);
    });

    testWidgets('selected row has actionWash background and w700 name weight', (
      tester,
    ) async {
      await pumpPicker(
        tester,
        exercises: <Exercise>[bench, squat],
        selected: bench,
      );

      final Container row = tester.widget<Container>(
        find.byKey(const ValueKey<String>('exercise-row-ex-bench')),
      );
      final BoxDecoration decoration = row.decoration! as BoxDecoration;
      expect(decoration.color, LiftColors.actionWash);

      final Text name = tester.widget<Text>(find.text('Bench Press'));
      expect(name.style?.fontWeight, FontWeight.w700);
    });

    testWidgets('unselected row has no actionWash background', (tester) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      final Container row = tester.widget<Container>(
        find.byKey(const ValueKey<String>('exercise-row-ex-bench')),
      );
      final BoxDecoration decoration = row.decoration! as BoxDecoration;
      expect(decoration.color, isNot(LiftColors.actionWash));
    });

    testWidgets("row metadata text uses JetBrainsMono", (tester) async {
      await pumpPicker(tester, exercises: <Exercise>[bench]);

      final String expected =
          ('${MuscleGroups.getDisplayName('chest')} · '
                  '${MuscleGroups.getDisplayName('triceps')}')
              .toUpperCase();
      final Text metadata = tester.widget<Text>(find.text(expected));
      expect(metadata.style?.fontFamily, 'JetBrainsMono');
    });

    testWidgets('shows a right-aligned result count', (tester) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      expect(find.text('2 ITEMS'), findsOneWidget);
    });
  });

  group('ExercisePickerSheet at phone width', () {
    testWidgets(
      'a three-muscle-group compound lift tile does not overflow at 360dp',
      (tester) async {
        await pumpAtPhoneWidth(
          tester,
          AppShell(
            home: Builder(
              builder: (BuildContext context) {
                return Scaffold(
                  body: Center(
                    child: ElevatedButton(
                      onPressed: () => ExercisePickerSheet.show(
                        context,
                        exercises: <Exercise>[benchPressCompound],
                        recentExerciseIds: const <String>[],
                      ),
                      child: const Text('open'),
                    ),
                  ),
                );
              },
            ),
          ),
        );

        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();

        expect(find.text('Barbell Bench Press'), findsOneWidget);
        expectNoOverflow(tester);
      },
    );
  });

  group('ExercisePickerSheet muscle filter', () {
    testWidgets('renders an All option plus one option per muscle group', (
      tester,
    ) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      expect(
        find.byKey(const ValueKey<String>('muscle-filter-all')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('muscle-filter-chest')),
        findsOneWidget,
      );

      // Scroll to the far end of the row to prove every entry in
      // MuscleGroups.all made it into the filter, not just the ones that
      // happen to fit in the initial viewport.
      final String lastMuscle = MuscleGroups.all.last;
      await scrollFilterChipIntoView(
        tester,
        ValueKey<String>('muscle-filter-$lastMuscle'),
      );
      expect(
        find.byKey(ValueKey<String>('muscle-filter-$lastMuscle')),
        findsOneWidget,
      );
      await scrollFilterChipIntoView(
        tester,
        const ValueKey<String>('muscle-filter-quads'),
      );
      expect(
        find.byKey(const ValueKey<String>('muscle-filter-quads')),
        findsOneWidget,
      );
    });

    testWidgets('tapping a muscle narrows results to that muscle group', (
      tester,
    ) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Back Squat'), findsOneWidget);

      const ValueKey<String> quadsKey = ValueKey<String>('muscle-filter-quads');
      await scrollFilterChipIntoView(tester, quadsKey);
      await tester.tap(find.byKey(quadsKey));
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsNothing);
      expect(find.text('Back Squat'), findsOneWidget);
    });

    testWidgets('tapping the selected muscle again clears the filter', (
      tester,
    ) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      const ValueKey<String> quadsKey = ValueKey<String>('muscle-filter-quads');
      await scrollFilterChipIntoView(tester, quadsKey);
      final Finder quadsChip = find.byKey(quadsKey);

      await tester.tap(quadsChip);
      await tester.pumpAndSettle();
      expect(find.text('Bench Press'), findsNothing);

      await tester.tap(quadsChip);
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Back Squat'), findsOneWidget);
    });

    testWidgets('selected chip is filled actionFill; unselected is transparent '
        'with a 1.5px border', (tester) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      final Container allChip = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('muscle-filter-all')),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration allDecoration = allChip.decoration! as BoxDecoration;
      expect(allDecoration.color, LiftColors.actionFill);

      const ValueKey<String> quadsKey = ValueKey<String>('muscle-filter-quads');
      await scrollFilterChipIntoView(tester, quadsKey);

      final Container quadsChip = tester.widget<Container>(
        find.descendant(
          of: find.byKey(quadsKey),
          matching: find.byType(Container),
        ),
      );
      final BoxDecoration quadsDecoration =
          quadsChip.decoration! as BoxDecoration;
      expect(quadsDecoration.color, Colors.transparent);
      final Border quadsBorder = quadsDecoration.border! as Border;
      expect(quadsBorder.top.color, LiftColors.border);
      expect(quadsBorder.top.width, 1.5);

      await tester.tap(find.byKey(quadsKey));
      await tester.pumpAndSettle();

      // Scroll back to the start of the row — tapping "quads" earlier
      // scrolled it out of view, and the row only builds chips near the
      // viewport.
      await tester.dragUntilVisible(
        find.byKey(const ValueKey<String>('muscle-filter-all')),
        find.byKey(const ValueKey<String>('muscle-filter-row')),
        const Offset(200, 0),
      );
      await tester.pumpAndSettle();

      final Container allChipAfter = tester.widget<Container>(
        find.descendant(
          of: find.byKey(const ValueKey<String>('muscle-filter-all')),
          matching: find.byType(Container),
        ),
      );
      expect(
        (allChipAfter.decoration! as BoxDecoration).color,
        Colors.transparent,
      );

      await scrollFilterChipIntoView(tester, quadsKey);
      final Container quadsChipAfter = tester.widget<Container>(
        find.descendant(
          of: find.byKey(quadsKey),
          matching: find.byType(Container),
        ),
      );
      expect(
        (quadsChipAfter.decoration! as BoxDecoration).color,
        LiftColors.actionFill,
      );
    });

    testWidgets('muscle filter composes with an active search query', (
      tester,
    ) async {
      await pumpPicker(tester, exercises: <Exercise>[bench, squat]);

      await tester.enterText(find.byType(TextField), 'press');
      await tester.pumpAndSettle();

      expect(find.text('Bench Press'), findsOneWidget);
      expect(find.text('Back Squat'), findsNothing);

      const ValueKey<String> quadsKey = ValueKey<String>('muscle-filter-quads');
      await scrollFilterChipIntoView(tester, quadsKey);
      await tester.tap(find.byKey(quadsKey));
      await tester.pumpAndSettle();

      // "press" matches Bench Press's name, but Bench Press is chest/triceps
      // not quads, so the muscle filter narrows it out on top of the query.
      expect(find.text('Bench Press'), findsNothing);
      expect(find.text('Back Squat'), findsNothing);
    });
  });
}

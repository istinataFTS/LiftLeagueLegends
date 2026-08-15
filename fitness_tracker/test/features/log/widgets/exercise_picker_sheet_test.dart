import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/muscle_groups.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/exercise_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

      // The muscle filter bar (FilterChip) is gone entirely, and nothing in
      // the sheet uses a Chip to display a value.
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
}

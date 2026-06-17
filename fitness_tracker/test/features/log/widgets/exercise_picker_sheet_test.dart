import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/muscle_groups.dart';
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
    testWidgets('renders muscle pills (display names, not comma text)', (
      tester,
    ) async {
      // Use a wide viewport so all 18+ filter chips are visible and findable.
      tester.view.physicalSize = const Size(2000, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pumpPicker(tester, exercises: <Exercise>[bench]);

      expect(find.text('Bench Press'), findsOneWidget);
      // Pills render each muscle group's display name independently
      // (both the muscle filter chip and the row pill match).
      expect(find.text(MuscleGroups.getDisplayName('chest')), findsNWidgets(2));
      expect(
        find.text(MuscleGroups.getDisplayName('triceps')),
        findsNWidgets(2),
      );
      // Comma-joined subtitle is gone.
      final String joined =
          '${MuscleGroups.getDisplayName('chest')}, '
          '${MuscleGroups.getDisplayName('triceps')}';
      expect(find.text(joined), findsNothing);
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
}

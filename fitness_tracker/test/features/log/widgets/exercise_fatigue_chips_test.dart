import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/features/log/application/exercise_insight.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/exercise_fatigue_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MuscleFatigue chip(String name, int percent, MuscleVisualBucket bucket) {
    return MuscleFatigue(
      coarseGroup: name.toLowerCase(),
      displayName: name,
      percent: percent,
      bucket: bucket,
      color: const Color(0xFF4CAF50),
    );
  }

  Widget buildSubject(List<MuscleFatigue> muscles) {
    return AppShell(
      home: Scaffold(body: ExerciseFatigueChips(muscles: muscles)),
    );
  }

  group('ExerciseFatigueChips', () {
    testWidgets('renders nothing when muscles is empty', (tester) async {
      await tester.pumpWidget(buildSubject(const <MuscleFatigue>[]));
      await tester.pumpAndSettle();

      expect(find.text('Fatigue'), findsNothing);
    });

    testWidgets('renders a chip per muscle with name and percent', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(<MuscleFatigue>[
          chip('Chest', 42, MuscleVisualBucket.moderate),
          chip('Triceps', 18, MuscleVisualBucket.light),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fatigue'), findsOneWidget);
      expect(find.text('Chest'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('Triceps'), findsOneWidget);
      expect(find.text('18%'), findsOneWidget);
    });

    testWidgets('verdict reflects the worst bucket among groups', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildSubject(<MuscleFatigue>[
          chip('Chest', 18, MuscleVisualBucket.light),
          chip('Triceps', 85, MuscleVisualBucket.maximum),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('needs rest'), findsOneWidget);
    });

    testWidgets('low fatigue reads fresh enough', (tester) async {
      await tester.pumpWidget(
        buildSubject(<MuscleFatigue>[
          chip('Chest', 10, MuscleVisualBucket.light),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('fresh enough'), findsOneWidget);
    });

    testWidgets('heavy bucket reads fatigued', (tester) async {
      await tester.pumpWidget(
        buildSubject(<MuscleFatigue>[
          chip('Quads', 65, MuscleVisualBucket.heavy),
        ]),
      );
      await tester.pumpAndSettle();

      expect(find.text('fatigued'), findsOneWidget);
    });
  });
}

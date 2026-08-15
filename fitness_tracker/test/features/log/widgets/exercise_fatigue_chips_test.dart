import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/domain/muscle_visual/muscle_visual_contract.dart';
import 'package:fitness_tracker/features/log/application/exercise_insight.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/exercise_fatigue_chips.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../log_phone_viewport.dart';

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

      expect(find.text('FATIGUE'), findsNothing);
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

      expect(find.text('FATIGUE'), findsOneWidget);
      expect(find.text('CHEST'), findsOneWidget);
      expect(find.text('42%'), findsOneWidget);
      expect(find.text('TRICEPS'), findsOneWidget);
      expect(find.text('18%'), findsOneWidget);

      // No pills/chips — this widget renders values, never a Chip.
      expect(find.byType(Chip), findsNothing);

      // Muscle name uses the label style: uppercase letterspaced mono.
      final Text nameText = tester.widget<Text>(find.text('CHEST'));
      expect(nameText.style?.fontFamily, 'JetBrainsMono');
      expect(nameText.style?.color, LiftColors.textStrong);

      // The fatigue swatch is a flat 14x14 square colored from the Deep
      // Mist fatigue ramp, indexed by the muscle's bucket — never a dot,
      // never a green-to-red ramp.
      final Iterable<Container> swatches = tester.widgetList<Container>(
        find.byType(Container),
      );
      expect(
        swatches.any(
          (Container c) =>
              c.color ==
                  LiftColors.fatigue[MuscleVisualBucket.moderate.index] &&
              c.constraints?.maxWidth == 14 &&
              c.constraints?.maxHeight == 14,
        ),
        isTrue,
      );
      expect(
        swatches.any(
          (Container c) =>
              c.color == LiftColors.fatigue[MuscleVisualBucket.light.index] &&
              c.constraints?.maxWidth == 14 &&
              c.constraints?.maxHeight == 14,
        ),
        isTrue,
      );
      // No rounded corners anywhere in this widget. Checked across every
      // Container it builds, not just the swatches: the swatches carry a
      // plain `color:` and so never have a decoration at all, which would
      // make a decoration-only assertion vacuously true.
      final Iterable<Container> all = tester.widgetList<Container>(
        find.descendant(
          of: find.byType(ExerciseFatigueChips),
          matching: find.byType(Container),
        ),
      );
      expect(all, isNotEmpty);
      for (final Container c in all) {
        final BoxDecoration? decoration = c.decoration as BoxDecoration?;
        if (decoration?.borderRadius != null) {
          expect(decoration!.borderRadius, BorderRadius.zero);
        }
      }
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

      final Text verdictText = tester.widget<Text>(find.text('needs rest'));
      expect(verdictText.style?.fontStyle, FontStyle.italic);
      expect(verdictText.style?.color, LiftColors.textDim);
      expect(verdictText.style?.fontSize, LiftText.bodyMedium.fontSize);
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

    testWidgets('three fatigued muscle-group rows do not overflow at 360dp', (
      tester,
    ) async {
      await pumpAtPhoneWidth(
        tester,
        buildSubject(<MuscleFatigue>[
          chip('Chest', 42, MuscleVisualBucket.moderate),
          chip('Triceps', 68, MuscleVisualBucket.heavy),
          chip('Shoulders', 15, MuscleVisualBucket.light),
        ]),
      );

      expect(find.text('CHEST'), findsOneWidget);
      expect(find.text('TRICEPS'), findsOneWidget);
      expect(find.text('SHOULDERS'), findsOneWidget);
      expectNoOverflow(tester);
    });
  });
}

import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/presentation/shared/widgets/lift_effort_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/phone_viewport.dart';

void main() {
  Widget buildSubject({int intensity = 3, ValueChanged<int>? onChanged}) {
    return AppShell(
      home: Scaffold(
        body: LiftEffortSelector(
          intensity: intensity,
          onChanged: onChanged ?? (_) {},
        ),
      ),
    );
  }

  Container cell(WidgetTester tester, int i) =>
      tester.widget<Container>(find.byKey(ValueKey<String>('effort-cell-$i')));

  BoxDecoration decorationOf(Container c) => c.decoration! as BoxDecoration;

  group('LiftEffortSelector', () {
    testWidgets('renders all six cells 0..5', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      for (int i = 0; i <= 5; i++) {
        expect(find.byKey(ValueKey<String>('effort-cell-$i')), findsOneWidget);
      }
    });

    testWidgets('shows active level and label in the ramp colour', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(intensity: 4));
      await tester.pumpAndSettle();

      final Text readout = tester.widget<Text>(find.textContaining('4 · '));
      expect(readout.data, '4 · HARD');
      expect(readout.style!.color, LiftColors.effortRamp[4]);
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

      await tester.tap(find.byKey(const ValueKey<String>('effort-cell-5')));
      await tester.pumpAndSettle();

      expect(received, equals(5));
    });

    testWidgets('exactly one cell is filled, at the selected index, in its '
        'own ramp colour', (tester) async {
      // Pins the picker's encoding: hue + single fill, not a count. A
      // count-style (cumulative) fill would leave more than one cell filled
      // for any level above 0, so this discriminates the two encodings — a
      // spot-check at index == level alone would not, since both encodings
      // agree that cell `level` is filled.
      for (int level = 0; level <= 5; level++) {
        await pumpAtPhoneWidth(tester, buildSubject(intensity: level));

        int filled = 0;
        for (int i = 0; i <= 5; i++) {
          final BoxDecoration decoration = decorationOf(cell(tester, i));

          if (i == level) {
            filled++;
            expect(
              decoration.color,
              LiftColors.effortRamp[i],
              reason: 'cell $i at level $level should take ramp colour $i',
            );
            expect(
              decoration.border,
              isNull,
              reason: 'the filled cell carries no border',
            );
          } else {
            expect(
              decoration.color,
              Colors.transparent,
              reason: 'cell $i should be unfilled at level $level',
            );
            expect(
              decoration.border,
              isNotNull,
              reason: 'unfilled cell $i keeps its outline',
            );
          }
        }

        expect(
          filled,
          1,
          reason:
              'expected exactly one filled cell at level $level, got $filled',
        );
      }
    });

    testWidgets('a cell is activatable from assistive technology', (
      tester,
    ) async {
      // The cell wraps its GestureDetector in `Semantics(excludeSemantics:
      // true)`, which drops the detector's own tap action along with the rest
      // of the subtree. Without an `onTap` on the wrapping node the cell
      // announces as a button that cannot be pressed.
      final SemanticsHandle handle = tester.ensureSemantics();

      int? received;
      await tester.pumpWidget(
        buildSubject(intensity: 3, onChanged: (v) => received = v),
      );
      await tester.pumpAndSettle();

      final Finder cell5 = find.byKey(const ValueKey<String>('effort-cell-5'));
      expect(
        tester
            .getSemantics(cell5)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );

      tester.binding.pipelineOwner.semanticsOwner!.performAction(
        tester.getSemantics(cell5).id,
        SemanticsAction.tap,
      );
      await tester.pumpAndSettle();

      expect(received, equals(5));
      handle.dispose();
    });

    testWidgets('every cell renders at one size, at least 44px tall', (
      tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());
      expectNoOverflow(tester);

      final List<Size> sizes = <Size>[
        for (int i = 0; i <= 5; i++)
          tester.getSize(find.byKey(ValueKey<String>('effort-cell-$i'))),
      ];

      for (int i = 0; i <= 5; i++) {
        expect(
          sizes[i].height,
          greaterThanOrEqualTo(44),
          reason: 'cell $i height was ${sizes[i].height}',
        );
        expect(
          sizes[i].width,
          closeTo(sizes[0].width, 0.5),
          reason:
              'cell $i width was ${sizes[i].width}, expected '
              '~${sizes[0].width} — size carries nothing here, hue does',
        );
      }
    });

    testWidgets('the legend strip spells the whole ramp, green to red', (
      tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final Finder strip = find.byKey(
        const ValueKey<String>('effort-legend-strip'),
      );
      expect(strip, findsOneWidget);

      final BoxDecoration decoration = decorationOf(
        tester.widget<Container>(strip),
      );
      final LinearGradient gradient = decoration.gradient! as LinearGradient;

      expect(gradient.colors, LiftColors.effortRamp);
      expect(gradient.colors.first, LiftColors.effortRamp.first);
      expect(gradient.colors.last, LiftColors.effortRamp.last);

      // Narrow: a legend, not a bar the user might try to drag.
      expect(tester.getSize(strip).height, closeTo(6, 0.01));
    });

    testWidgets('the ramp runs from green to red', (tester) async {
      // The one property the picker exists to carry. Green at the low end,
      // red at the top; index 0 is a neutral warm-up and is exempt.
      final Color low = LiftColors.effortRamp[1];
      final Color high = LiftColors.effortRamp[5];

      expect(
        low.g,
        greaterThan(low.r),
        reason: 'level 1 should read green, got $low',
      );
      expect(
        high.r,
        greaterThan(high.g),
        reason: 'level 5 should read red, got $high',
      );
    });
  });
}

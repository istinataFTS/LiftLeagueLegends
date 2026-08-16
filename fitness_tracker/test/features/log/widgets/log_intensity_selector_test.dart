import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/log_intensity_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/phone_viewport.dart';

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

  Container rung(WidgetTester tester, int i) =>
      tester.widget<Container>(find.byKey(ValueKey<String>('effort-rung-$i')));

  group('LogIntensitySelector', () {
    testWidgets('renders all six cells 0..5', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      for (int i = 0; i <= 5; i++) {
        expect(find.byKey(ValueKey<String>('effort-rung-$i')), findsOneWidget);
      }
    });

    testWidgets('shows active level and label', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 4));
      await tester.pumpAndSettle();

      final Text readout = tester.widget<Text>(find.textContaining('4 · '));
      expect(readout.data, '4 · HARD');
      expect(readout.style!.color, LiftColors.actionTint);
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

      await tester.tap(find.byKey(const ValueKey<String>('effort-rung-5')));
      await tester.pumpAndSettle();

      expect(received, equals(5));
    });

    testWidgets(
      'rung heights climb by one constant step; all six rungs render at one '
      'width',
      (tester) async {
        // Declared BoxConstraints (`.constraints!.maxHeight`) reads what the
        // widget asked for, not what actually painted — a childless
        // Container with only `constraints` can render at zero size under
        // unbounded constraints while its declared maxHeight still reads
        // correctly. Assert rendered geometry instead.
        await pumpAtPhoneWidth(tester, buildSubject());
        expectNoOverflow(tester);

        final List<Size> sizes = <Size>[
          for (int i = 0; i <= 5; i++)
            // Measure the rung `Container` itself, not an ancestor:
            // `Expanded` hands its child a tight main-axis width equal to
            // its flex share, which depends only on the number of rungs and
            // the row's width — it is completely decoupled from whatever
            // width the `Container` chooses. If a future change added a
            // `_widths[i]` list to the `Container` (the width analogue of
            // `_heights`), every ancestor slot would still measure
            // identically and this test would keep passing while the visual
            // encoding broke. The `Container` is the only element whose
            // width can actually reveal that regression.
            tester.getSize(find.byKey(ValueKey<String>('effort-rung-$i'))),
        ];

        // Height is *the* channel this widget encodes the value in, so
        // assert the shape of the ladder, not merely that it ascends.
        // `greaterThan(previous)` alone passes for a nearly flat ladder
        // (e.g. [36, 36.5, 37, 37.5, 38, 38.5]) that has destroyed the
        // encoding — and so does a bare "the step is constant" check, since
        // that ladder's step is a perfectly constant 0.5. The step's
        // magnitude has to be pinned too. The frame's rungs measure 24, 42,
        // 60, 78, 96, 114 image px, i.e. 8, 14, 20, 26, 32, 38 logical at
        // 3x: a uniform +6. Assert exactly that, on rendered geometry.
        const double expectedStep = 6;
        final List<double> heights = <double>[
          for (final Size s in sizes) s.height,
        ];
        for (int i = 1; i <= 5; i++) {
          expect(
            heights[i] - heights[i - 1],
            closeTo(expectedStep, 0.01),
            reason:
                'the step from rung ${i - 1} to rung $i was '
                '${heights[i] - heights[i - 1]}, expected the frame\'s '
                'uniform +$expectedStep; measured heights $heights',
          );
        }

        // Width carries nothing: the frame shows all six rungs equal — 160
        // image px wide with uniform 18px gaps. The separation comes from
        // the `Row`'s `spacing`, which sits between the `Expanded` slots, so
        // it never eats into a rung's own box the way a per-child left
        // `Padding` inside a tight slot did.
        for (int i = 1; i <= 5; i++) {
          expect(
            sizes[i].width,
            closeTo(sizes[0].width, 0.5),
            reason:
                'rung $i width was ${sizes[i].width}, expected '
                '~${sizes[0].width} (every rung renders at one width); '
                'measured widths ${sizes.map((Size s) => s.width).toList()}',
          );
        }
      },
    );

    testWidgets('exactly one rung is filled, at the selected index', (
      tester,
    ) async {
      // Pins the picker's encoding: height + single fill, not a count.
      // A count-style (cumulative) fill would leave more than one rung
      // `effortOn` for any level above 0, so this discriminates the two
      // encodings — a spot-check at index == level alone would not, since
      // both encodings agree that rung `level` is filled.
      for (int level = 0; level <= 5; level++) {
        await pumpAtPhoneWidth(tester, buildSubject(intensity: level));

        int onCount = 0;
        for (int i = 0; i <= 5; i++) {
          final Color color =
              (rung(tester, i).decoration! as BoxDecoration).color!;
          if (color == LiftColors.effortOn) {
            onCount++;
            expect(
              i,
              level,
              reason:
                  'rung $i was effortOn at level $level; '
                  'only rung == level should be',
            );
          } else {
            expect(
              color,
              LiftColors.effortOff,
              reason: 'rung $i at level $level',
            );
          }
        }
        expect(
          onCount,
          1,
          reason:
              'expected exactly one filled rung at level $level, got $onCount',
        );
      }
    });

    testWidgets('every rung has a tappable area at least 44px tall', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      for (int i = 0; i <= 5; i++) {
        final Finder gestureDetector = find.ancestor(
          of: find.byKey(ValueKey<String>('effort-rung-$i')),
          matching: find.byType(GestureDetector),
        );
        expect(gestureDetector, findsOneWidget);
        final Size size = tester.getSize(gestureDetector);
        expect(
          size.height,
          greaterThanOrEqualTo(44),
          reason: 'rung $i tappable height was ${size.height}',
        );
      }
    });

    testWidgets('the gradient legend strip is gone', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final Iterable<Container> containers = tester.widgetList<Container>(
        find.byType(Container),
      );
      for (final Container c in containers) {
        expect((c.decoration as BoxDecoration?)?.gradient, isNull);
      }
    });
  });
}

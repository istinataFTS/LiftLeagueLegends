import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/log_intensity_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../log_phone_viewport.dart';

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
      'rungs grow in height with the index; rungs 1-5 render at one width '
      'and rung 0 renders 5px wider (missing left gutter)',
      (tester) async {
        // Declared BoxConstraints (`.constraints!.maxHeight`) reads what the
        // widget asked for, not what actually painted — a childless
        // Container with only `constraints` can render at zero size under
        // unbounded constraints while its declared maxHeight still reads
        // correctly. Assert rendered geometry instead.
        await pumpAtPhoneWidth(tester, buildSubject());
        expectNoOverflow(tester);

        double previousHeight = 0;
        double? sharedWidth;
        double? rungZeroWidth;
        for (int i = 0; i <= 5; i++) {
          // Measure the rung `Container` itself, not the `Padding`
          // ancestor: `Expanded` hands the `Padding` a tight main-axis
          // width equal to its flex share, which depends only on the
          // number of rungs and the row's width — it is completely
          // decoupled from whatever width the `Container` chooses. If a
          // future change added a `_widths[i]` list to the `Container`
          // (the width analogue of `_heights`), every `Padding` would
          // still measure identically and this test would keep passing
          // while the visual encoding broke. The `Container` is the only
          // element whose width can actually reveal that regression.
          final Finder fillMark = find.byKey(
            ValueKey<String>('effort-rung-$i'),
          );
          final Size fillSize = tester.getSize(fillMark);
          expect(
            fillSize.height,
            greaterThan(previousHeight),
            reason: 'rung $i rendered height was ${fillSize.height}',
          );
          previousHeight = fillSize.height;

          // The rungs are NOT all the same width today. The gutter
          // (`EdgeInsets.only(left: i == 0 ? 0 : 5)`) sits inside a tight
          // `Expanded` slot, so it shrinks the rung's own box rather than
          // adding external spacing: rung 0 has no left gutter and
          // renders 5px wider than rungs 1-5, which each lose 5px to
          // theirs. The design frame (`export/02-log-exercise.png`) shows
          // all six rungs equal — 160px wide with uniform 18px gaps — so
          // this is a known mismatch against the frame. It is tracked for
          // a later PR and deliberately not fixed here.
          if (i == 0) {
            rungZeroWidth = fillSize.width;
          } else {
            sharedWidth ??= fillSize.width;
            expect(
              fillSize.width,
              closeTo(sharedWidth, 0.5),
              reason:
                  'rung $i width was ${fillSize.width}, '
                  'expected ~$sharedWidth (same as the other non-zero rungs)',
            );
          }
        }

        expect(
          rungZeroWidth,
          closeTo(sharedWidth! + 5, 0.5),
          reason:
              'rung 0 width was $rungZeroWidth, expected '
              '~${sharedWidth + 5} (rungs 1-5 width plus the missing '
              '5px left gutter)',
        );
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
      for (final int level in <int>[0, 3, 4, 5]) {
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

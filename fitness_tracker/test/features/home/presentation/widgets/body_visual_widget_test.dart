import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/home/presentation/home_page_keys.dart';
import 'package:fitness_tracker/features/home/presentation/models/home_view_data.dart';
import 'package:fitness_tracker/features/home/presentation/widgets/body_visual_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../support/phone_viewport.dart';

void main() {
  HomeBodyVisualViewData buildViewData() {
    return const HomeBodyVisualViewData(
      frontLayers: <HomeBodyOverlayViewData>[
        HomeBodyOverlayViewData(
          assetPath: 'assets/images/body/front_chest.png',
          color: Color(0xFF00FF00),
          opacity: 0.8,
          label: 'Chest',
        ),
      ],
      backLayers: <HomeBodyOverlayViewData>[
        HomeBodyOverlayViewData(
          assetPath: 'assets/images/body/back_lats.png',
          color: Color(0xFF0000FF),
          opacity: 0.6,
          label: 'Lats',
        ),
      ],
      subtitle: 'Front and back load',
    );
  }

  Widget buildSubject({BodySide initialSide = BodySide.front}) {
    return AppShell(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: BodyVisualWidget(
            viewData: buildViewData(),
            initialSide: initialSide,
          ),
        ),
      ),
    );
  }

  group('BodyVisualWidget', () {
    testWidgets('renders the front side and a flip control by default', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('FRONT'), findsOneWidget);
      expect(find.text('BACK'), findsNothing);
      expect(find.byKey(HomePageKeys.bodyVisualFlipButtonKey), findsOneWidget);
      expect(find.text('SHOW BACK'), findsOneWidget);
    });

    testWidgets('flips to the back side when the flip control is tapped', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('FRONT'), findsNothing);
      expect(find.text('SHOW FRONT'), findsOneWidget);
    });

    testWidgets('flips back to the front on a second tap', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(HomePageKeys.bodyVisualFlipButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('FRONT'), findsOneWidget);
      expect(find.text('SHOW BACK'), findsOneWidget);
    });

    testWidgets('honours initialSide override', (WidgetTester tester) async {
      await pumpAtPhoneWidth(tester, buildSubject(initialSide: BodySide.back));

      expect(find.text('BACK'), findsOneWidget);
      expect(find.text('SHOW FRONT'), findsOneWidget);
    });

    testWidgets('does not render the removed Sets/Target/Muscles labels', (
      WidgetTester tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      expect(find.text('Sets'), findsNothing);
      expect(find.text('Target'), findsNothing);
      expect(find.text('Muscles'), findsNothing);
    });

    testWidgets('the panel fills the width and the remaining height', (
      tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final Size panel = tester.getSize(
        find.byKey(HomePageKeys.bodyVisualPanelKey),
      );
      // 360 logical wide minus the 20px page gutters this test supplies.
      expect(panel.width, 320);
      // A width-capped figure could only reach 240 / 0.62 = 387 tall.
      expect(panel.height, greaterThan(500));
      expectNoOverflow(tester);
    });

    testWidgets('no 240px width cap survives', (tester) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      final Iterable<ConstrainedBox> capped = tester
          .widgetList<ConstrainedBox>(find.byType(ConstrainedBox))
          .where((ConstrainedBox b) => b.constraints.maxWidth == 240);
      expect(capped, isEmpty);
    });

    testWidgets('the panel draws no frame and no fill', (tester) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // The map is the screen on Home. A bordered, surface-filled panel drew
      // a box around it that the figure then had to letterbox inside, so the
      // panel is a bare layout box now and the two-tone ground shows through.
      expect(
        find.descendant(
          of: find.byKey(HomePageKeys.bodyVisualPanelKey),
          matching: find.byType(DecoratedBox),
        ),
        findsNothing,
      );
      expect(
        tester.widget<SizedBox>(find.byKey(HomePageKeys.bodyVisualPanelKey)),
        isNotNull,
      );
    });

    testWidgets('the figure is cropped to its ink box, not its canvas', (
      tester,
    ) async {
      await pumpAtPhoneWidth(tester, buildSubject());

      // 340x657 of the 440x956 art canvas is the figure; the rest is
      // transparent margin. Fitting the canvas instead would letterbox the
      // figure into roughly two thirds of the panel's height.
      final AspectRatio box = tester.widget<AspectRatio>(
        find.descendant(
          of: find.byKey(HomePageKeys.bodyVisualPanelKey),
          matching: find.byType(AspectRatio),
        ),
      );
      expect(box.aspectRatio, closeTo(340 / 657, 0.0001));

      final Size panel = tester.getSize(
        find.byKey(HomePageKeys.bodyVisualPanelKey),
      );
      final Size figure = tester.getSize(
        find.descendant(
          of: find.byKey(HomePageKeys.bodyVisualPanelKey),
          matching: find.byType(AspectRatio),
        ),
      );
      // Width-limited at phone width: the figure spans the panel edge to
      // edge. The old canvas fit reached 0.62 of that width and then let the
      // art's transparent margin eat a third of the height on top.
      expect(figure.width, panel.width);
      expect(
        figure.height,
        moreOrLessEquals(panel.width * 657 / 340, epsilon: 0.5),
      );
    });

    testWidgets(
      'the side label is mono caps and the flip control is a themed filled button',
      (tester) async {
        await pumpAtPhoneWidth(tester, buildSubject());

        expect(
          tester.widget<Text>(find.text('FRONT')).style!.fontFamily,
          'JetBrainsMono',
        );

        final Finder flip = find.byKey(HomePageKeys.bodyVisualFlipButtonKey);
        expect(flip, findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        // Deliberately styled off-theme: `elevatedButtonTheme`'s
        // `Size.fromHeight(52)` CTA shape is what pushed the figure off
        // centre between the two section rules. The control is compact and
        // shrink-wrapped instead.
        final ButtonStyle? style = tester.widget<ElevatedButton>(flip).style;
        expect(style, isNotNull);
        expect(style!.minimumSize!.resolve(<WidgetState>{}), Size.zero);
        expect(style.tapTargetSize, MaterialTapTargetSize.shrinkWrap);
        expect(
          tester.getSize(flip).height,
          lessThan(36),
          reason: 'the flip control is a secondary toggle, not a 52dp CTA',
        );
        // The old pill control carried an Icons.cached glyph; the frame shows none.
        expect(
          find.descendant(of: flip, matching: find.byType(Icon)),
          findsNothing,
        );
      },
    );

    // The only test in this file that can see the *blend*. Every other
    // assertion here reads declared widget properties, which is exactly how
    // PR B3 shipped a fatigue ramp that was structurally correct
    // (`LiftColors.fatigue[bucket.index]` reached the `Image`) and visually
    // absent (a 5%-alpha white over grey-195 art moves the pixel by 3).
    //
    // Shaped after `test/core/themes/lift_theme_test.dart`'s `LiftGround`
    // readback, including its `pixelRatio` gotcha: `toImage()` defaults to
    // `pixelRatio: 1.0`, so it captures at the 360x800 *logical* size, not
    // the 1080x2400 physical surface.
    testWidgets(
      'a fatigue overlay renders materially brighter than untrained muscle',
      (WidgetTester tester) async {
        final GlobalKey boundaryKey = GlobalKey();

        // The colour the Home mapper hands the widget: the ramp stop
        // composited onto `bodyBase`, i.e. opaque. Duplicated here rather
        // than imported from the mapper because this test owns the *widget*
        // end of the contract; `home_view_data_mapper_test.dart` owns the
        // mapper end.
        HomeBodyVisualViewData figure(int? rampStop, double opacity) {
          return HomeBodyVisualViewData(
            frontLayers: rampStop == null
                ? const <HomeBodyOverlayViewData>[]
                : <HomeBodyOverlayViewData>[
                    HomeBodyOverlayViewData(
                      assetPath: 'assets/images/body/front_chest.png',
                      color: Color.alphaBlend(
                        LiftColors.fatigue[rampStop],
                        LiftColors.bodyBase,
                      ),
                      opacity: opacity,
                      label: 'Chest',
                    ),
                  ],
            backLayers: const <HomeBodyOverlayViewData>[],
            subtitle: 'Current fatigue level',
          );
        }

        Future<(ByteData, int, int)> capture(HomeBodyVisualViewData vd) async {
          await pumpAtPhoneWidth(
            tester,
            RepaintBoundary(
              key: boundaryKey,
              child: AppShell(
                home: Scaffold(
                  body: Padding(
                    padding: const EdgeInsets.all(20),
                    child: BodyVisualWidget(viewData: vd),
                  ),
                ),
              ),
            ),
          );

          // `Image.asset` decodes on a real event loop, which the fake-async
          // test clock never advances -- without this the figure paints as
          // an empty box and every sample below reads the panel colour.
          await tester.runAsync(() async {
            for (final Element element in find.byType(Image).evaluate()) {
              await precacheImage((element.widget as Image).image, element);
            }
          });
          await tester.pumpAndSettle();

          late ByteData bytes;
          late int width;
          late int height;
          await tester.runAsync(() async {
            final RenderRepaintBoundary boundary =
                boundaryKey.currentContext!.findRenderObject()!
                    as RenderRepaintBoundary;
            final ui.Image image = await boundary.toImage();
            bytes = (await image.toByteData())!;
            width = image.width;
            height = image.height;
          });
          return (bytes, width, height);
        }

        double grey(ByteData d, int i) {
          final int o = i * 4;
          return (d.getUint8(o) + d.getUint8(o + 1) + d.getUint8(o + 2)) / 3;
        }

        /// Mean grey-level rise of [lit] over [dark] across the muscle
        /// region, where "the region" is every pixel the overlay changed,
        /// eroded by one pixel.
        ///
        /// The erosion is what keeps the mean honest: the overlay PNG's
        /// outline pixels are only partially covered, so they read somewhere
        /// between the two tones and would drag a boundary-inclusive mean
        /// down for reasons that have nothing to do with the blend.
        (double, int) regionRise(ByteData dark, ByteData lit, int w, int h) {
          final List<bool> changed = List<bool>.filled(w * h, false);
          for (int i = 0; i < w * h; i++) {
            final int o = i * 4;
            changed[i] =
                dark.getUint8(o) != lit.getUint8(o) ||
                dark.getUint8(o + 1) != lit.getUint8(o + 1) ||
                dark.getUint8(o + 2) != lit.getUint8(o + 2);
          }

          double sum = 0;
          int count = 0;
          for (int y = 1; y < h - 1; y++) {
            for (int x = 1; x < w - 1; x++) {
              final int i = y * w + x;
              if (!changed[i]) continue;
              if (!changed[i - 1] ||
                  !changed[i + 1] ||
                  !changed[i - w] ||
                  !changed[i + w]) {
                continue;
              }
              sum += grey(lit, i) - grey(dark, i);
              count++;
            }
          }
          return (count == 0 ? 0 : sum / count, count);
        }

        final (ByteData untrained, int w, int h) = await capture(
          figure(null, 0),
        );
        // `light`  = ramp stop 1 at the 0.72 overlay opacity
        // `MuscleVisualData` fixes for a partially covered light muscle.
        final (ByteData light, _, _) = await capture(figure(1, 0.72));
        // `maximum` = ramp stop 4 at 0.90, the same class's top partial stop.
        final (ByteData maximum, _, _) = await capture(figure(4, 0.90));

        final (double lightRise, int lightPx) = regionRise(
          untrained,
          light,
          w,
          h,
        );
        final (double maxRise, int maxPx) = regionRise(
          untrained,
          maximum,
          w,
          h,
        );

        // A figure that painted no overlay at all would produce an empty
        // region and a rise of 0; requiring a substantial covered area is
        // what stops that degenerate case from passing vacuously.
        expect(
          lightPx,
          greaterThan(200),
          reason: 'the chest overlay must actually cover the figure',
        );
        expect(maxPx, greaterThan(200));

        // 20 grey levels sits well above the 8 the pre-fix code produced for
        // `light` (a 0x33 white over the art's own grey 195, then attenuated
        // by `Opacity`) and below the 25.1 this code measures (ramp stop
        // composited onto `bodyBase`, over a base image modulated down to
        // `bodyBase`). That is a 20% margin, not a wide one — but the
        // quantity is deterministic image blending rather than font metrics,
        // and it reproduces to two decimals across runs, so the margin is
        // headroom against a real regression, not against renderer noise. If
        // it ever fires, re-measure; do not lower it. The whole point of the
        // number is that a veil cannot meet it.
        expect(
          lightRise,
          greaterThan(20),
          reason:
              'a light-fatigue muscle must read materially brighter than '
              'untrained muscle, not 3% brighter (measured rise: $lightRise)',
        );
        expect(maxRise, greaterThan(20), reason: 'measured rise: $maxRise');
        // Direction: the ramp must climb, not just clear the floor.
        expect(maxRise, greaterThan(lightRise));
      },
    );
  });
}

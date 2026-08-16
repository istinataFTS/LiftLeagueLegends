// test/core/themes/lift_theme_test.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/phone_viewport.dart';

void main() {
  group('LiftColors', () {
    test('action roles are distinct', () {
      expect(LiftColors.actionFill, const Color(0xFF226096));
      expect(LiftColors.actionTint, const Color(0xFF7BB6EB));
    });

    test('fatigue ramp is 5 stops of increasing white density', () {
      expect(LiftColors.fatigue, hasLength(5));
      for (int i = 1; i < LiftColors.fatigue.length; i++) {
        expect(
          LiftColors.fatigue[i].a,
          greaterThan(LiftColors.fatigue[i - 1].a),
        );
      }
    });

    test('macro colors sit off the azure axis', () {
      expect(LiftColors.protein, const Color(0xFFA78BFA));
      expect(LiftColors.carbs, const Color(0xFF5FD08A));
      expect(LiftColors.fats, const Color(0xFFF0A93B));
    });
  });

  group('LiftText', () {
    test('data styles are JetBrains Mono and bold', () {
      for (final TextStyle s in <TextStyle>[
        LiftText.dataHero,
        LiftText.dataLarge,
        LiftText.dataMedium,
        LiftText.dataSmall,
        LiftText.dataMeta,
      ]) {
        expect(s.fontFamily, 'JetBrainsMono');
        expect(s.fontWeight, FontWeight.w700);
      }
    });

    test('headlines are Space Grotesk', () {
      expect(LiftText.headlineLarge.fontFamily, 'SpaceGrotesk');
      expect(LiftText.titleLarge.fontFamily, 'SpaceGrotesk');
    });

    test('labels are letterspaced mono', () {
      expect(LiftText.labelLarge.fontFamily, 'JetBrainsMono');
      expect(LiftText.labelLarge.letterSpacing, greaterThan(1.0));
    });
  });

  group('LiftShape', () {
    test('panels are square, buttons are 8', () {
      expect(LiftShape.radiusPanel, 0);
      expect(LiftShape.radiusInput, 0);
      expect(LiftShape.radiusChip, 0);
      expect(LiftShape.radiusButton, 8);
      expect(LiftShape.borderWidth, 1.5);
      expect(LiftShape.borderWidthActive, 2.5);
    });
  });

  group('LiftGround', () {
    testWidgets(
      'paints an opaque top-left highlight near groundLight fading to a '
      'bottom-right shade near groundDark',
      (tester) async {
        final GlobalKey boundaryKey = GlobalKey();
        const Key childKey = Key('lift-ground-child');

        await pumpAtPhoneWidth(
          tester,
          RepaintBoundary(
            key: boundaryKey,
            child: const MaterialApp(
              home: LiftGround(child: SizedBox(key: childKey, width: 1)),
            ),
          ),
          // Pinned explicitly rather than left to phone_viewport.dart's
          // defaults: the sampled pixel coordinates and the measured RGB
          // constants below are derived for this exact 1080x2400 @3x
          // surface, and must not silently drift if that shared helper's
          // defaults ever change for some other caller's reason.
          physicalSize: const Size(1080, 2400),
          devicePixelRatio: 3,
        );

        // The inverse of the mutation this test exists to catch: paint the
        // gradient but drop the child. LiftGround must put its child in the
        // tree, not just decorate the space around it.
        expect(
          find.byKey(childKey),
          findsOneWidget,
          reason: 'LiftGround must render its child, not only its gradient',
        );

        await tester.runAsync(() async {
          final RenderRepaintBoundary boundary =
              boundaryKey.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final ui.Image image = await boundary.toImage();
          final ByteData byteData = (await image.toByteData())!;
          final int width = image.width;
          final int height = image.height;

          // Raw RGBA bytes (0..255), sampled well inside the 360x800
          // logical surface (toImage defaults to pixelRatio 1.0, so it
          // captures at logical size, not the 1080x2400 physical size) so
          // edge antialiasing cannot pollute the reading.
          List<int> pixelAt(int x, int y) {
            final int offset = (y * width + x) * 4;
            return <int>[
              byteData.getUint8(offset),
              byteData.getUint8(offset + 1),
              byteData.getUint8(offset + 2),
              byteData.getUint8(offset + 3),
            ];
          }

          // The measured colour constants below are only valid at this
          // exact surface size. If this fails, the surface size changed
          // (e.g. an unrelated edit to phone_viewport.dart's defaults)
          // and the constants need re-measuring -- do not widen the
          // tolerance instead.
          expect(
            image.width,
            360,
            reason:
                'LiftGround pixel constants below were measured at a '
                '360-wide (logical) surface -- 1080 physical @3x; '
                're-measure them if this changes instead of widening the '
                'colour tolerance',
          );
          expect(
            image.height,
            800,
            reason:
                'LiftGround pixel constants below were measured at a '
                '800-tall (logical) surface -- 2400 physical @3x; '
                're-measure them if this changes instead of widening the '
                'colour tolerance',
          );

          final List<int> topLeft = pixelAt(30, 30);
          final List<int> bottomRight = pixelAt(width - 30, height - 30);

          // Measured against the real, unmutated LiftGround on this exact
          // 360x800 surface:
          //   topLeft(30,30)       rgba = [45, 56, 67, 255]
          //   bottomRight(330,770) rgba = [20, 27, 34, 255]
          // Target tokens:
          //   LiftColors.groundLight (#2E3944) = (46, 57, 68)
          //   LiftColors.groundDark  (#141A21) = (20, 26, 33)
          // Both samples land within 1 unit/channel of their token, because
          // (30,30) sits close to the radial highlight's centre
          // (Alignment(-0.7,-0.9) resolves to roughly (54, 40) in this box)
          // while (330,770) is far enough from it that the radial layer has
          // faded to ~0 alpha, leaving the outer linear gradient's own
          // groundDark-ward end colour showing through.
          //
          // Tolerance: with the inner radial DecoratedBox removed (outer
          // linear gradient only), the same top-left sample moves toward
          // groundMid (#28323B = 40,50,59) instead of groundLight -- a
          // deviation of 7 (red), 8 (green), 10 (blue). The real widget
          // deviates from its token by <=1 on every channel. `closeTo` is
          // inclusive (it passes when `diff <= delta`), so a tolerance of 6
          // would let a 6-unit deviation through, and the mutation's
          // narrowest channel (red, 7) would clear it by only 1. A
          // tolerance of 3 is strictly better on both sides: 2 units of
          // headroom above the real widget's <=1 drift, and 4 units of
          // margin below the mutation's smallest deviation. If this ever
          // fails, report the measured channel values -- do not widen it
          // back.
          const int tol = 3;

          expect(
            topLeft,
            <Matcher>[
              closeTo(46, tol), // groundLight red
              closeTo(57, tol), // groundLight green
              closeTo(68, tol), // groundLight blue
              equals(255), // fully opaque
            ],
            reason: 'top-left should read close to LiftColors.groundLight',
          );
          expect(
            bottomRight,
            <Matcher>[
              closeTo(20, tol), // groundDark red
              closeTo(26, tol), // groundDark green
              closeTo(33, tol), // groundDark blue
              equals(255), // fully opaque
            ],
            reason: 'bottom-right should read close to LiftColors.groundDark',
          );

          // Directional sanity check: top-left must be materially lighter
          // than bottom-right. A margin of 40 is well under the ~87 margin
          // measured on the real widget, and cannot be satisfied by a flat
          // single-colour fill (margin 0) or by two swapped-but-equal
          // corners.
          final int topLeftSum = topLeft[0] + topLeft[1] + topLeft[2];
          final int bottomRightSum =
              bottomRight[0] + bottomRight[1] + bottomRight[2];
          expect(
            topLeftSum - bottomRightSum,
            greaterThan(40),
            reason: 'top-left should be materially lighter than bottom-right',
          );
        });
      },
    );
  });
}

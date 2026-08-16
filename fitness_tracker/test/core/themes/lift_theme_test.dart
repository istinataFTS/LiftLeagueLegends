// test/core/themes/lift_theme_test.dart
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/log/log_phone_viewport.dart';

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

        await pumpAtPhoneWidth(
          tester,
          RepaintBoundary(
            key: boundaryKey,
            child: const MaterialApp(
              home: LiftGround(child: SizedBox.shrink()),
            ),
          ),
          // Pinned explicitly rather than left to log_phone_viewport.dart's
          // defaults: the sampled pixel coordinates and the measured RGB
          // constants below are derived for this exact 1080x2400 @3x
          // surface, and must not silently drift if that Log-owned helper's
          // defaults ever change for a Log-specific reason.
          physicalSize: const Size(1080, 2400),
          devicePixelRatio: 3,
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
          // (e.g. an unrelated edit to log_phone_viewport.dart's defaults)
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
          // groundMid (#28323B = 40,50,59) instead of groundLight -- a gap
          // of 6-10 units/channel. A tolerance of 6 stays clear of both the
          // <=1 real-widget deviation and that mutation's >=6 deviation.
          const int tol = 6;

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

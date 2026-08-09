// test/core/themes/lift_theme_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';

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

  testWidgets('LiftGround paints a gradient behind its child', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LiftGround(child: SizedBox.shrink())),
    );
    expect(find.byType(DecoratedBox), findsWidgets);
  });
}

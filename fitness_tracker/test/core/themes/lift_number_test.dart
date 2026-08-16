import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/themes/lift_number.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';

void main() {
  /// Returns the span [LiftNumber] itself built.
  ///
  /// `Text.rich` wraps the supplied span in an outer [TextSpan] that carries
  /// the inherited [DefaultTextStyle], so the widget's own span is one level
  /// down from [RichText.text].
  Future<TextSpan> pumpSpan(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: Center(child: child)),
      ),
    );
    final RichText rich = tester.widget<RichText>(find.byType(RichText));
    return (rich.text as TextSpan).children!.single as TextSpan;
  }

  testWidgets('unit rides the value small and dim', (tester) async {
    final TextSpan root = await pumpSpan(
      tester,
      const LiftNumber('155', 'g', LiftText.dataMedium),
    );
    final TextSpan unit = root.children!.single as TextSpan;

    expect(root.text, '155');
    expect(root.style!.color, LiftColors.textPrimary);
    expect(root.style!.fontFeatures, LiftText.dataFeatures);
    expect(unit.text, 'g');
    expect(unit.style!.color, LiftColors.textDim);
    expect(
      unit.style!.fontSize,
      closeTo(LiftText.dataMedium.fontSize! * 0.42, 0.01),
    );
  });

  testWidgets('of() formats to the requested decimals', (tester) async {
    final TextSpan root = await pumpSpan(
      tester,
      const LiftNumber.of(42.5, 'kg', LiftText.dataSmall, decimals: 1),
    );
    expect(root.text, '42.5');
  });

  testWidgets('an empty unit renders no child span', (tester) async {
    final TextSpan root = await pumpSpan(
      tester,
      const LiftNumber('12', '', LiftText.dataHero),
    );
    expect(root.children, isNull);
  });

  testWidgets('no colour supplied renders spans unchanged from today', (
    tester,
  ) async {
    final TextSpan root = await pumpSpan(
      tester,
      const LiftNumber('155', 'g', LiftText.dataMedium),
    );
    final TextSpan unit = root.children!.single as TextSpan;

    expect(root.style!.color, LiftColors.textPrimary);
    expect(root.style!.fontFeatures, LiftText.dataFeatures);
    expect(unit.style!.color, LiftColors.textDim);
    expect(
      unit.style!.fontSize,
      closeTo(LiftText.dataMedium.fontSize! * 0.42, 0.01),
    );
    expect(unit.style!.fontWeight, FontWeight.w500);
  });

  testWidgets('a supplied colour reaches the rendered value span', (
    tester,
  ) async {
    final TextSpan root = await pumpSpan(
      tester,
      const LiftNumber(
        '155',
        'g',
        LiftText.dataMedium,
        color: LiftColors.error,
      ),
    );

    expect(root.style!.color, LiftColors.error);
  });

  testWidgets('of() with a supplied colour reaches the rendered value span', (
    tester,
  ) async {
    final TextSpan root = await pumpSpan(
      tester,
      const LiftNumber.of(
        42.5,
        'kg',
        LiftText.dataSmall,
        decimals: 1,
        color: LiftColors.actionTint,
      ),
    );

    expect(root.style!.color, LiftColors.actionTint);
  });

  testWidgets(
    'a supplied colour keeps the unit subordinate at 60% opacity, not full strength',
    (tester) async {
      final TextSpan root = await pumpSpan(
        tester,
        const LiftNumber(
          '155',
          'g',
          LiftText.dataMedium,
          color: LiftColors.error,
        ),
      );
      final TextSpan unit = root.children!.single as TextSpan;

      expect(unit.style!.color, LiftColors.error.withValues(alpha: 0.6));
      expect(unit.style!.color, isNot(LiftColors.error));
    },
  );

  testWidgets('tabular figures survive a supplied colour', (tester) async {
    final TextSpan root = await pumpSpan(
      tester,
      const LiftNumber(
        '155',
        'g',
        LiftText.dataMedium,
        color: LiftColors.error,
      ),
    );

    expect(root.style!.fontFeatures, LiftText.dataFeatures);
  });

  testWidgets(
    'a caller colour already below full opacity keeps the unit strictly '
    'more transparent than the value (multiplicative, not absolute, alpha)',
    (tester) async {
      final TextSpan root = await pumpSpan(
        tester,
        const LiftNumber(
          '155',
          'g',
          LiftText.dataMedium,
          color: LiftColors.textDim,
        ),
      );
      final TextSpan unit = root.children!.single as TextSpan;

      final double valueAlpha = root.style!.color!.a;
      final double unitAlpha = unit.style!.color!.a;

      expect(root.style!.color, LiftColors.textDim);
      expect(unitAlpha, lessThan(valueAlpha));
      expect(
        unit.style!.color,
        LiftColors.textDim.withValues(alpha: valueAlpha * 0.6),
      );
    },
  );

  testWidgets(
    'the no-colour default renders the value at exactly textPrimary and '
    'the unit at exactly textDim',
    (tester) async {
      final TextSpan root = await pumpSpan(
        tester,
        const LiftNumber('155', 'g', LiftText.dataMedium),
      );
      final TextSpan unit = root.children!.single as TextSpan;

      expect(root.style!.color, LiftColors.textPrimary);
      expect(unit.style!.color, LiftColors.textDim);
    },
  );

  testWidgets("unit's 0.42 size factor and w500 weight survive a supplied "
      'colour', (tester) async {
    final TextSpan root = await pumpSpan(
      tester,
      const LiftNumber(
        '155',
        'g',
        LiftText.dataMedium,
        color: LiftColors.error,
      ),
    );
    final TextSpan unit = root.children!.single as TextSpan;

    expect(
      unit.style!.fontSize,
      closeTo(LiftText.dataMedium.fontSize! * 0.42, 0.01),
    );
    expect(unit.style!.fontWeight, FontWeight.w500);
  });
}

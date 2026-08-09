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
}

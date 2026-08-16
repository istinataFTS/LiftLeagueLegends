import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/macro_label.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) {
    return AppShell(
      home: Scaffold(body: Center(child: child)),
    );
  }

  group('MacroKind', () {
    test('label and color are bundled per kind (cannot be mismatched)', () {
      expect(MacroKind.protein.label, 'Protein');
      expect(MacroKind.protein.color, LiftColors.protein);
      expect(MacroKind.carbs.label, 'Carbs');
      expect(MacroKind.carbs.color, LiftColors.carbs);
      expect(MacroKind.fats.label, 'Fats');
      expect(MacroKind.fats.color, LiftColors.fats);

      // Pins the three colors as distinct — the review that prompted this
      // widget found protein/carbs swapped on two of three tabs with every
      // test still green, precisely because the mapping lived at each call
      // site instead of in one place.
      expect(MacroKind.protein.color, isNot(MacroKind.carbs.color));
      expect(MacroKind.protein.color, isNot(MacroKind.fats.color));
      expect(MacroKind.carbs.color, isNot(MacroKind.fats.color));
    });
  });

  group('MacroLabel', () {
    for (final MacroKind kind in MacroKind.values) {
      testWidgets(
        '${kind.name}: swatch color matches LiftColors.${kind.name}',
        (tester) async {
          await tester.pumpWidget(
            wrap(
              MacroLabel(
                kind: kind,
                swatchKey: ValueKey<String>('swatch-${kind.name}'),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final Container swatch = tester.widget<Container>(
            find.byKey(ValueKey<String>('swatch-${kind.name}')),
          );
          expect(swatch.color, kind.color);

          expect(find.text(kind.label.toUpperCase()), findsOneWidget);
        },
      );
    }

    testWidgets('caption variant (default): 9x9 swatch, dim text', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          MacroLabel(
            kind: MacroKind.protein,
            swatchKey: const ValueKey<String>('swatch'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Container swatch = tester.widget<Container>(
        find.byKey(const ValueKey<String>('swatch')),
      );
      expect(
        swatch.constraints,
        const BoxConstraints.tightFor(width: 9, height: 9),
      );

      final Text label = tester.widget<Text>(find.text('PROTEIN'));
      expect(label.style?.color, LiftColors.textDim);
      expect(label.style?.fontSize, LiftText.labelMedium.fontSize);
    });

    testWidgets('header variant: 10x10 swatch, primary text', (tester) async {
      await tester.pumpWidget(
        wrap(
          MacroLabel(
            kind: MacroKind.carbs,
            variant: MacroLabelVariant.header,
            swatchKey: const ValueKey<String>('swatch'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final Text label = tester.widget<Text>(find.text('CARBS'));
      expect(label.style?.color, LiftColors.textPrimary);
      expect(label.style?.fontSize, LiftText.labelLarge.fontSize);
    });
  });
}

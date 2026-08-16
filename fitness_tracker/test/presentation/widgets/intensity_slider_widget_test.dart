import 'package:fitness_tracker/app/app.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/presentation/widgets/intensity_slider_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Helper: build the widget wrapped in the real app shell so it picks up
  // LiftTheme.dark() like it does in production (History's edit-set dialog).
  Widget buildSubject({
    int intensity = 3,
    ValueChanged<int>? onChanged,
    bool enabled = true,
  }) {
    return AppShell(
      home: Scaffold(
        body: IntensitySliderWidget(
          intensity: intensity,
          onChanged: onChanged ?? (_) {},
          enabled: enabled,
        ),
      ),
    );
  }

  group('IntensitySliderWidget', () {
    testWidgets('builds and shows the label and current value', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.intensity), findsOneWidget);
      expect(find.text('3/5'), findsOneWidget);
      expect(find.text('Moderate'), findsOneWidget);
    });

    testWidgets('label uses LiftText.titleMedium in LiftColors.textPrimary', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      final Text label = tester.widget<Text>(find.text(AppStrings.intensity));

      expect(label.style?.fontFamily, LiftText.titleMedium.fontFamily);
      expect(label.style?.fontSize, LiftText.titleMedium.fontSize);
      expect(label.style?.color, LiftColors.textPrimary);
    });

    testWidgets('value uses LiftText.dataSmall in LiftColors.actionTint', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      final Text value = tester.widget<Text>(find.text('3/5'));

      expect(value.style?.fontFamily, LiftText.dataSmall.fontFamily);
      expect(value.style?.fontSize, LiftText.dataSmall.fontSize);
      expect(value.style?.color, LiftColors.actionTint);
    });

    testWidgets('dragging the slider reports the new value', (tester) async {
      int? changed;
      await tester.pumpWidget(
        buildSubject(intensity: 0, onChanged: (v) => changed = v),
      );
      await tester.pumpAndSettle();

      final Finder slider = find.byType(Slider);
      final Size size = tester.getSize(slider);
      // Drag from the far left to the far right of the track to land on the
      // maximum division regardless of thumb start position.
      await tester.drag(slider, Offset(size.width, 0));
      await tester.pumpAndSettle();

      expect(changed, isNotNull);
      expect(changed, greaterThan(0));
    });

    testWidgets('tapping the info icon opens IntensityInfoDialog', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.info_outline));
      await tester.pumpAndSettle();

      expect(find.byType(IntensityInfoDialog), findsOneWidget);
      expect(find.text(AppStrings.intensityLevels), findsOneWidget);
    });

    testWidgets('info icon tap target is at least 44px', (tester) async {
      await tester.pumpWidget(buildSubject(intensity: 3));
      await tester.pumpAndSettle();

      final Size size = tester.getSize(
        find
            .ancestor(
              of: find.byIcon(Icons.info_outline),
              matching: find.byType(SizedBox),
            )
            .first,
      );

      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}

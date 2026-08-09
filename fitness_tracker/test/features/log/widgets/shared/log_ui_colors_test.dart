import 'package:fitness_tracker/core/themes/lift_theme.dart';
import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_ui_colors.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogUiColors', () {
    test('rowSurface forwards to LiftColors.surfaceSunken', () {
      expect(LogUiColors.rowSurface, equals(LiftColors.surfaceSunken));
    });

    test('protein forwards to LiftColors.protein', () {
      expect(LogUiColors.protein, equals(LiftColors.protein));
    });

    test('carbs forwards to LiftColors.carbs', () {
      expect(LogUiColors.carbs, equals(LiftColors.carbs));
    });

    test('fats forwards to LiftColors.fats', () {
      expect(LogUiColors.fats, equals(LiftColors.fats));
    });

    test('intensityRamp has 6 entries', () {
      expect(LogUiColors.intensityRamp.length, equals(6));
    });

    test('intensityRamp index 0 is LiftColors.effortOn', () {
      expect(LogUiColors.intensityRamp[0], equals(LiftColors.effortOn));
    });

    test('intensityRamp index 5 is LiftColors.effortOn', () {
      expect(LogUiColors.intensityRamp[5], equals(LiftColors.effortOn));
    });

    test('intensityRamp has all identical entries', () {
      expect(LogUiColors.intensityRamp.toSet(), hasLength(1));
    });
  });
}

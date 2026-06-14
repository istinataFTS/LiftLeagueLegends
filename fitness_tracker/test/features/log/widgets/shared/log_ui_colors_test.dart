import 'package:fitness_tracker/features/log/presentation/widgets/shared/log_ui_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogUiColors', () {
    test('rowSurface is #141414', () {
      expect(LogUiColors.rowSurface, equals(const Color(0xFF141414)));
    });

    test('protein is #5DA9F0', () {
      expect(LogUiColors.protein, equals(const Color(0xFF5DA9F0)));
    });

    test('carbs is #97C459', () {
      expect(LogUiColors.carbs, equals(const Color(0xFF97C459)));
    });

    test('fats is #EF9F27', () {
      expect(LogUiColors.fats, equals(const Color(0xFFEF9F27)));
    });

    test('intensityRamp has 6 entries', () {
      expect(LogUiColors.intensityRamp.length, equals(6));
    });

    test('intensityRamp index 0 is warm-up gray #888888', () {
      expect(LogUiColors.intensityRamp[0], equals(const Color(0xFF888888)));
    });

    test('intensityRamp index 5 is max-effort red #E24B4A', () {
      expect(LogUiColors.intensityRamp[5], equals(const Color(0xFFE24B4A)));
    });
  });
}

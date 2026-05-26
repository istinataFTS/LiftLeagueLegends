import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/utils/weight_unit_utils.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';

void main() {
  group('WeightUnitUtils conversions', () {
    test('keeps kilograms unchanged when unit is kilograms', () {
      expect(
        WeightUnitUtils.fromStoredKilograms(100, WeightUnit.kilograms),
        100,
      );

      expect(WeightUnitUtils.toStoredKilograms(100, WeightUnit.kilograms), 100);
    });

    test('converts kilograms to pounds', () {
      final result = WeightUnitUtils.fromStoredKilograms(
        100,
        WeightUnit.pounds,
      );

      expect(result, closeTo(220.4623, 0.0001));
    });

    test('converts pounds back to kilograms', () {
      final result = WeightUnitUtils.toStoredKilograms(
        220.4623,
        WeightUnit.pounds,
      );

      expect(result, closeTo(100, 0.001));
    });
  });

  group('WeightUnitUtils labels', () {
    test('returns correct unit labels', () {
      expect(WeightUnitUtils.unitLabel(WeightUnit.kilograms), 'kg');
      expect(WeightUnitUtils.unitLabel(WeightUnit.pounds), 'lbs');
    });

    test('returns correct input labels', () {
      expect(WeightUnitUtils.inputLabel(WeightUnit.kilograms), 'Weight (kg)');
      expect(WeightUnitUtils.inputLabel(WeightUnit.pounds), 'Weight (lbs)');
    });

    test('returns correct input hints', () {
      expect(
        WeightUnitUtils.inputHint(WeightUnit.kilograms),
        'Enter weight in kg',
      );
      expect(
        WeightUnitUtils.inputHint(WeightUnit.pounds),
        'Enter weight in lbs',
      );
    });
  });

  group('WeightUnitUtils formatting', () {
    test('formats kilograms for display', () {
      expect(
        WeightUnitUtils.formatForDisplay(100, WeightUnit.kilograms),
        '100 kg',
      );
    });

    test('formats pounds for display', () {
      expect(
        WeightUnitUtils.formatForDisplay(100, WeightUnit.pounds),
        '220.5 lbs',
      );
    });

    test('formats editable input value from stored kilograms', () {
      expect(
        WeightUnitUtils.formatInputValueFromStoredKilograms(
          100,
          WeightUnit.kilograms,
        ),
        '100',
      );

      expect(
        WeightUnitUtils.formatInputValueFromStoredKilograms(
          100,
          WeightUnit.pounds,
        ),
        '220.5',
      );
    });

    test('formatNumber drops trailing decimal for whole numbers', () {
      expect(WeightUnitUtils.formatNumber(42), '42');
    });

    test('formatNumber keeps one decimal for fractional values', () {
      expect(WeightUnitUtils.formatNumber(42.25), '42.3');
    });
  });
}

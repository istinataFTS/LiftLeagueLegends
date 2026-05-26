import 'package:flutter_test/flutter_test.dart';
import 'package:fitness_tracker/core/utils/macro_calculator.dart';

void main() {
  group('MacroCalculator', () {
    group('calculateCalories', () {
      test('returns 0 for all-zero macros', () {
        expect(
          MacroCalculator.calculateCalories(carbs: 0, protein: 0, fat: 0),
          0.0,
        );
      });

      test('computes correct total for typical macros', () {
        // 50g carbs × 4 + 30g protein × 4 + 20g fat × 9 = 200 + 120 + 180 = 500
        expect(
          MacroCalculator.calculateCalories(carbs: 50, protein: 30, fat: 20),
          500.0,
        );
      });

      test('handles fractional gram values with float precision', () {
        // 33.3×4 + 22.2×4 + 11.1×9 = 133.2 + 88.8 + 99.9 = 321.9
        expect(
          MacroCalculator.calculateCalories(
            carbs: 33.3,
            protein: 22.2,
            fat: 11.1,
          ),
          closeTo(321.9, 0.001),
        );
      });
    });

    group('validateCalories', () {
      test('returns true when stated calories exactly match calculated', () {
        expect(
          MacroCalculator.validateCalories(
            carbs: 50,
            protein: 30,
            fat: 20,
            statedCalories: 500.0,
          ),
          isTrue,
        );
      });

      test('returns true when stated calories are within tolerance', () {
        // calculated = 500, stated = 500.9 → diff = 0.9 ≤ 1.0
        expect(
          MacroCalculator.validateCalories(
            carbs: 50,
            protein: 30,
            fat: 20,
            statedCalories: 500.9,
          ),
          isTrue,
        );
      });

      test('returns false when stated calories exceed tolerance', () {
        // calculated = 500, stated = 501.1 → diff = 1.1 > 1.0
        expect(
          MacroCalculator.validateCalories(
            carbs: 50,
            protein: 30,
            fat: 20,
            statedCalories: 501.1,
          ),
          isFalse,
        );
      });
    });

    group('calculateCarbsFromCalories', () {
      test('calculates carbs from remaining calories after protein and fat', () {
        // total=400, protein=20 (80 cal), fat=10 (90 cal) → remaining=230 → carbs=57.5
        expect(
          MacroCalculator.calculateCarbsFromCalories(
            totalCalories: 400,
            protein: 20,
            fat: 10,
          ),
          closeTo(57.5, 0.001),
        );
      });

      test('returns 0 when protein and fat calories exceed total', () {
        expect(
          MacroCalculator.calculateCarbsFromCalories(
            totalCalories: 50,
            protein: 20,
            fat: 10,
          ),
          0.0,
        );
      });
    });

    group('calculateProteinFromCalories', () {
      test('calculates protein from remaining calories after carbs and fat', () {
        // total=400, carbs=20 (80 cal), fat=10 (90 cal) → remaining=230 → protein=57.5
        expect(
          MacroCalculator.calculateProteinFromCalories(
            totalCalories: 400,
            carbs: 20,
            fat: 10,
          ),
          closeTo(57.5, 0.001),
        );
      });

      test('returns 0 when carbs and fat calories exceed total', () {
        expect(
          MacroCalculator.calculateProteinFromCalories(
            totalCalories: 50,
            carbs: 20,
            fat: 10,
          ),
          0.0,
        );
      });
    });

    group('calculateFatFromCalories', () {
      test('calculates fat from remaining calories after carbs and protein', () {
        // total=400, carbs=20 (80 cal), protein=20 (80 cal) → remaining=240 → fat=240/9≈26.667
        expect(
          MacroCalculator.calculateFatFromCalories(
            totalCalories: 400,
            carbs: 20,
            protein: 20,
          ),
          closeTo(26.667, 0.001),
        );
      });

      test('returns 0 when carbs and protein calories exceed total', () {
        expect(
          MacroCalculator.calculateFatFromCalories(
            totalCalories: 50,
            carbs: 20,
            protein: 20,
          ),
          0.0,
        );
      });
    });

    group('scaleNutrition', () {
      test('scales all fields by the given multiplier', () {
        final result = MacroCalculator.scaleNutrition(
          carbs: 10,
          protein: 20,
          fat: 5,
          calories: 165,
          multiplier: 2,
        );

        expect(result.carbs, 20.0);
        expect(result.protein, 40.0);
        expect(result.fat, 10.0);
        expect(result.calories, 330.0);
      });

      test('scales fractional multiplier correctly', () {
        final result = MacroCalculator.scaleNutrition(
          carbs: 100,
          protein: 100,
          fat: 100,
          calories: 1300,
          multiplier: 0.5,
        );

        expect(result.carbs, 50.0);
        expect(result.protein, 50.0);
        expect(result.fat, 50.0);
        expect(result.calories, 650.0);
      });
    });

    group('formatMacro', () {
      test('formats whole number without decimal', () {
        expect(MacroCalculator.formatMacro(15.0), '15');
      });

      test('formats single decimal place value', () {
        expect(MacroCalculator.formatMacro(15.5), '15.5');
      });

      test('truncates to one decimal place', () {
        expect(MacroCalculator.formatMacro(15.123), '15.1');
      });

      test('formats zero as integer', () {
        expect(MacroCalculator.formatMacro(0.0), '0');
      });
    });

    group('formatCalories', () {
      test('rounds up to nearest integer', () {
        expect(MacroCalculator.formatCalories(276.8), '277');
      });

      test('rounds down to nearest integer', () {
        expect(MacroCalculator.formatCalories(210.2), '210');
      });

      test('formats exact integer without decimal', () {
        expect(MacroCalculator.formatCalories(500.0), '500');
      });
    });
  });
}

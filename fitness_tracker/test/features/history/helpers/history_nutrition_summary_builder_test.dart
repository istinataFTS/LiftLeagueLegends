import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/features/history/presentation/helpers/history_nutrition_summary_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final createdAt = DateTime(2026, 3, 19, 12, 30);

  NutritionLog buildLog({
    required String id,
    required String mealName,
    required double protein,
    required double carbs,
    required double fats,
    required double calories,
    double? gramsConsumed,
  }) {
    return NutritionLog(
      id: id,
      mealId: 'meal-$id',
      mealName: mealName,
      gramsConsumed: gramsConsumed,
      proteinGrams: protein,
      carbsGrams: carbs,
      fatGrams: fats,
      calories: calories,
      loggedAt: createdAt,
      createdAt: createdAt,
    );
  }

  group('HistoryNutritionSummaryBuilder.buildSummary', () {
    test('aggregates totals into summary metrics', () {
      final logs = <NutritionLog>[
        buildLog(
          id: '1',
          mealName: 'Chicken Rice',
          protein: 40,
          carbs: 60,
          fats: 10,
          calories: 490,
        ),
        buildLog(
          id: '2',
          mealName: 'Yogurt',
          protein: 20,
          carbs: 12,
          fats: 5,
          calories: 170,
        ),
      ];

      final result = HistoryNutritionSummaryBuilder.buildSummary(logs);

      expect(result.metrics, hasLength(4));
      expect(result.metrics[0].label, 'Protein');
      expect(result.metrics[0].value, '60g');
      expect(result.metrics[1].label, 'Carbs');
      expect(result.metrics[1].value, '72g');
      expect(result.metrics[2].label, 'Fats');
      expect(result.metrics[2].value, '15g');
      expect(result.metrics[3].label, 'Calories');
      expect(result.metrics[3].value, '660 kcal');
    });

    test('returns zeroed metrics for empty logs', () {
      final result = HistoryNutritionSummaryBuilder.buildSummary(
        const <NutritionLog>[],
      );

      expect(result.metrics, hasLength(4));
      expect(result.metrics[0].value, '0g');
      expect(result.metrics[1].value, '0g');
      expect(result.metrics[2].value, '0g');
      expect(result.metrics[3].value, '0 kcal');
    });
  });

  group('HistoryNutritionSummaryBuilder.buildLogMacros', () {
    test('formats per-log macro values', () {
      final log = buildLog(
        id: '1',
        mealName: 'Oats',
        protein: 21,
        carbs: 54,
        fats: 9,
        calories: 377,
      );

      final result = HistoryNutritionSummaryBuilder.buildLogMacros(log);

      expect(result.proteinLabel, '21g');
      expect(result.carbsLabel, '54g');
      expect(result.fatsLabel, '9g');
      expect(result.caloriesLabel, '377');
    });
  });

  group('HistoryNutritionSummaryBuilder.buildConsumedGramsLabel', () {
    test('returns formatted consumed grams label when grams are present', () {
      final log = buildLog(
        id: '1',
        mealName: 'Oats',
        protein: 21,
        carbs: 54,
        fats: 9,
        calories: 377,
        gramsConsumed: 185,
      );

      final result = HistoryNutritionSummaryBuilder.buildConsumedGramsLabel(
        log,
      );

      expect(result, '185 g consumed');
    });

    test('returns null when grams consumed are not available', () {
      final log = buildLog(
        id: '1',
        mealName: 'Oats',
        protein: 21,
        carbs: 54,
        fats: 9,
        calories: 377,
      );

      final result = HistoryNutritionSummaryBuilder.buildConsumedGramsLabel(
        log,
      );

      expect(result, isNull);
    });
  });
}

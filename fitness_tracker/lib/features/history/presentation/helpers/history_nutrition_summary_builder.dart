import 'package:equatable/equatable.dart';

import '../../../../domain/entities/nutrition_log.dart';

class HistoryNutritionSummaryBuilder {
  const HistoryNutritionSummaryBuilder._();

  static HistoryNutritionSummaryViewData buildSummary(List<NutritionLog> logs) {
    double protein = 0;
    double carbs = 0;
    double fats = 0;
    double calories = 0;

    for (final NutritionLog log in logs) {
      protein += log.proteinGrams;
      carbs += log.carbsGrams;
      fats += log.fatGrams;
      calories += log.calories;
    }

    return HistoryNutritionSummaryViewData(
      metrics: <HistoryNutritionMetricViewData>[
        HistoryNutritionMetricViewData(
          label: 'Protein',
          value: '${protein.toStringAsFixed(0)}g',
        ),
        HistoryNutritionMetricViewData(
          label: 'Carbs',
          value: '${carbs.toStringAsFixed(0)}g',
        ),
        HistoryNutritionMetricViewData(
          label: 'Fats',
          value: '${fats.toStringAsFixed(0)}g',
        ),
        HistoryNutritionMetricViewData(
          label: 'Calories',
          value: '${calories.round()} kcal',
        ),
      ],
    );
  }

  static HistoryNutritionLogMacrosViewData buildLogMacros(NutritionLog log) {
    return HistoryNutritionLogMacrosViewData(
      proteinLabel: '${log.proteinGrams.toStringAsFixed(0)}g',
      carbsLabel: '${log.carbsGrams.toStringAsFixed(0)}g',
      fatsLabel: '${log.fatGrams.toStringAsFixed(0)}g',
      caloriesLabel: '${log.calories.round()}',
    );
  }

  static String? buildConsumedGramsLabel(NutritionLog log) {
    final gramsConsumed = log.gramsConsumed;
    if (gramsConsumed == null) {
      return null;
    }

    return '${gramsConsumed.toStringAsFixed(0)} g consumed';
  }
}

class HistoryNutritionSummaryViewData extends Equatable {
  final List<HistoryNutritionMetricViewData> metrics;

  const HistoryNutritionSummaryViewData({required this.metrics});

  @override
  List<Object?> get props => [metrics];
}

class HistoryNutritionMetricViewData extends Equatable {
  final String label;
  final String value;

  const HistoryNutritionMetricViewData({
    required this.label,
    required this.value,
  });

  @override
  List<Object?> get props => [label, value];
}

class HistoryNutritionLogMacrosViewData extends Equatable {
  final String proteinLabel;
  final String carbsLabel;
  final String fatsLabel;
  final String caloriesLabel;

  const HistoryNutritionLogMacrosViewData({
    required this.proteinLabel,
    required this.carbsLabel,
    required this.fatsLabel,
    required this.caloriesLabel,
  });

  @override
  List<Object?> get props => [
    proteinLabel,
    carbsLabel,
    fatsLabel,
    caloriesLabel,
  ];
}

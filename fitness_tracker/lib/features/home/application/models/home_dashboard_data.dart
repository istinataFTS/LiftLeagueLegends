import 'package:equatable/equatable.dart';

import '../../../../domain/entities/nutrition_log.dart';

class HomeDashboardData extends Equatable {
  const HomeDashboardData({
    required this.todaysLogs,
    required this.dailyMacros,
    this.muscleSetCounts = const <String, int>{},
    this.weeklySetCount = 0,
  });

  final List<NutritionLog> todaysLogs;
  final Map<String, double> dailyMacros;

  /// Weekly set counts per muscle group, resolved via [MuscleLoadResolver].
  ///
  /// Keyed by normalised muscle-group slug (lowercase, trimmed).  Empty when
  /// the user is a guest or when the resolver is unavailable.
  final Map<String, int> muscleSetCounts;

  /// Count of distinct weekly sets whose exercise resolves to ≥1 positive
  /// muscle factor — i.e. sets that actually contribute to the body map.
  /// Routed through [MuscleLoadResolver] so the "Sets" stat card and the
  /// map share a single source of truth and cannot disagree. Zero for
  /// guest sessions or when the resolver is unavailable.
  final int weeklySetCount;

  static const Map<String, double> emptyDailyMacros = <String, double>{
    'protein': 0.0,
    'carbs': 0.0,
    'fats': 0.0,
    'calories': 0.0,
  };

  @override
  List<Object?> get props => <Object?>[
    todaysLogs,
    dailyMacros,
    muscleSetCounts,
    weeklySetCount,
  ];
}

import 'package:equatable/equatable.dart';

class RecentSetContext extends Equatable {
  const RecentSetContext({
    required this.setId,
    required this.exerciseName,
    required this.weight,
    required this.reps,
    required this.intensity,
    required this.date,
  });

  final String setId;
  final String exerciseName;
  final double weight;
  final int reps;
  final int intensity;
  final DateTime date;

  @override
  List<Object?> get props => <Object?>[
    setId,
    exerciseName,
    weight,
    reps,
    intensity,
    date,
  ];
}

class RecentNutritionLogContext extends Equatable {
  const RecentNutritionLogContext({
    required this.logId,
    required this.mealName,
    required this.calories,
    required this.date,
  });

  final String logId;
  final String mealName;
  final double calories;
  final DateTime date;

  @override
  List<Object?> get props => <Object?>[logId, mealName, calories, date];
}

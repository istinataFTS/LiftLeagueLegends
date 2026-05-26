import 'package:equatable/equatable.dart';

/// Counts of activity logged on a single calendar day, split by type so the
/// history calendar can render one dot per type (yellow exercise, green
/// nutrition) instead of a combined total.
class DayActivity extends Equatable {
  const DayActivity({required this.exerciseSets, required this.nutritionLogs});

  static const DayActivity none = DayActivity(
    exerciseSets: 0,
    nutritionLogs: 0,
  );

  final int exerciseSets;
  final int nutritionLogs;

  bool get hasExercise => exerciseSets > 0;
  bool get hasNutrition => nutritionLogs > 0;
  bool get hasAny => hasExercise || hasNutrition;
  int get total => exerciseSets + nutritionLogs;

  @override
  List<Object?> get props => <Object?>[exerciseSets, nutritionLogs];
}

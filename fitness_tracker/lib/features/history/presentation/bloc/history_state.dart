import 'package:equatable/equatable.dart';

import '../../../../domain/entities/nutrition_log.dart';
import '../../../../domain/entities/workout_set.dart';

abstract class HistoryState extends Equatable {
  const HistoryState();

  @override
  List<Object?> get props => <Object?>[];
}

class HistoryInitial extends HistoryState {
  const HistoryInitial();
}

class HistoryLoading extends HistoryState {
  const HistoryLoading();
}

class HistoryLoaded extends HistoryState {
  final DateTime currentMonth;
  final Map<DateTime, List<WorkoutSet>> monthSets;
  final Map<DateTime, List<NutritionLog>> monthNutritionLogs;
  final DateTime? selectedDate;
  final List<WorkoutSet> selectedDateSets;
  final List<NutritionLog> selectedDateNutritionLogs;

  const HistoryLoaded({
    required this.currentMonth,
    required this.monthSets,
    required this.monthNutritionLogs,
    this.selectedDate,
    this.selectedDateSets = const <WorkoutSet>[],
    this.selectedDateNutritionLogs = const <NutritionLog>[],
  });

  @override
  List<Object?> get props => <Object?>[
    currentMonth,
    monthSets,
    monthNutritionLogs,
    selectedDate,
    selectedDateSets,
    selectedDateNutritionLogs,
  ];
}

class HistoryError extends HistoryState {
  final String message;

  const HistoryError(this.message);

  @override
  List<Object?> get props => <Object?>[message];
}

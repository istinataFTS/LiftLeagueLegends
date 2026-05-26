import 'package:equatable/equatable.dart';

import '../../../../domain/entities/nutrition_log.dart';
import '../../../../domain/entities/workout_set.dart';

abstract class HistoryEvent extends Equatable {
  const HistoryEvent();

  @override
  List<Object?> get props => <Object?>[];
}

class LoadMonthSetsEvent extends HistoryEvent {
  final DateTime month;

  const LoadMonthSetsEvent(this.month);

  @override
  List<Object?> get props => <Object?>[month];
}

class SelectDateEvent extends HistoryEvent {
  final DateTime date;

  const SelectDateEvent(this.date);

  @override
  List<Object?> get props => <Object?>[date];
}

class ClearDateSelectionEvent extends HistoryEvent {
  const ClearDateSelectionEvent();
}

class UpdateSetEvent extends HistoryEvent {
  final WorkoutSet set;

  const UpdateSetEvent(this.set);

  @override
  List<Object?> get props => <Object?>[set];
}

class DeleteSetEvent extends HistoryEvent {
  final String setId;

  const DeleteSetEvent(this.setId);

  @override
  List<Object?> get props => <Object?>[setId];
}

class DeleteNutritionHistoryLogEvent extends HistoryEvent {
  final String logId;

  const DeleteNutritionHistoryLogEvent(this.logId);

  @override
  List<Object?> get props => <Object?>[logId];
}

class UpdateNutritionHistoryLogEvent extends HistoryEvent {
  final NutritionLog log;

  const UpdateNutritionHistoryLogEvent(this.log);

  @override
  List<Object?> get props => <Object?>[log];
}

class RefreshCurrentMonthEvent extends HistoryEvent {
  const RefreshCurrentMonthEvent();
}

class NavigateToMonthEvent extends HistoryEvent {
  final DateTime month;

  const NavigateToMonthEvent(this.month);

  @override
  List<Object?> get props => <Object?>[month];
}

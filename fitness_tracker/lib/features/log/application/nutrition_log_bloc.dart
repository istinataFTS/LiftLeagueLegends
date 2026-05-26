import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/bloc/bloc_effects_mixin.dart';
import '../../../domain/entities/nutrition_log.dart';
import '../../../domain/usecases/nutrition_logs/add_nutrition_log.dart';
import '../../../domain/usecases/nutrition_logs/delete_nutrition_log.dart';
import '../../../domain/usecases/nutrition_logs/get_daily_macros.dart';
import '../../../domain/usecases/nutrition_logs/get_logs_for_date.dart';
import '../../../domain/usecases/nutrition_logs/update_nutrition_log.dart';

// ==================== Events ====================

abstract class NutritionLogEvent extends Equatable {
  const NutritionLogEvent();

  @override
  List<Object?> get props => [];
}

class LoadDailyLogsEvent extends NutritionLogEvent {
  final DateTime date;

  const LoadDailyLogsEvent(this.date);

  @override
  List<Object?> get props => [date];
}

class AddNutritionLogEvent extends NutritionLogEvent {
  final NutritionLog log;

  const AddNutritionLogEvent(this.log);

  @override
  List<Object?> get props => [log];
}

class UpdateNutritionLogEvent extends NutritionLogEvent {
  final NutritionLog log;

  const UpdateNutritionLogEvent(this.log);

  @override
  List<Object?> get props => [log];
}

class DeleteNutritionLogEvent extends NutritionLogEvent {
  final String id;

  const DeleteNutritionLogEvent(this.id);

  @override
  List<Object?> get props => [id];
}

class RefreshDailyLogsEvent extends NutritionLogEvent {
  final DateTime date;

  const RefreshDailyLogsEvent(this.date);

  @override
  List<Object?> get props => [date];
}

// ==================== States ====================

abstract class NutritionLogState extends Equatable {
  const NutritionLogState();

  @override
  List<Object?> get props => [];
}

class NutritionLogInitial extends NutritionLogState {}

class NutritionLogLoading extends NutritionLogState {}

class DailyLogsLoaded extends NutritionLogState {
  final DateTime date;
  final List<NutritionLog> logs;
  final Map<String, double> dailyMacros;

  const DailyLogsLoaded({
    required this.date,
    required this.logs,
    required this.dailyMacros,
  });

  double get totalProtein => dailyMacros['protein'] ?? 0.0;
  double get totalCarbs => dailyMacros['carbs'] ?? 0.0;
  double get totalFats => dailyMacros['fats'] ?? 0.0;
  double get totalCalories => dailyMacros['calories'] ?? 0.0;

  @override
  List<Object?> get props => [date, logs, dailyMacros];
}

class NutritionLogError extends NutritionLogState {
  final String message;

  const NutritionLogError(this.message);

  @override
  List<Object?> get props => [message];
}

// ==================== Effects ====================

abstract class NutritionLogUiEffect {
  const NutritionLogUiEffect();
}

class NutritionLogSuccessEffect extends NutritionLogUiEffect {
  final String message;

  const NutritionLogSuccessEffect(this.message);
}

// ==================== BLoC ====================

class NutritionLogBloc extends Bloc<NutritionLogEvent, NutritionLogState>
    with BlocEffectsMixin<NutritionLogState, NutritionLogUiEffect> {
  final GetLogsForDate getLogsForDate;
  final AddNutritionLog addNutritionLog;
  final UpdateNutritionLog updateNutritionLog;
  final DeleteNutritionLog deleteNutritionLog;
  final GetDailyMacros getDailyMacros;

  DateTime _currentDate = DateTime.now();

  NutritionLogBloc({
    required this.getLogsForDate,
    required this.addNutritionLog,
    required this.updateNutritionLog,
    required this.deleteNutritionLog,
    required this.getDailyMacros,
  }) : super(NutritionLogInitial()) {
    on<LoadDailyLogsEvent>(_onLoadDailyLogs);
    on<AddNutritionLogEvent>(_onAddNutritionLog);
    on<UpdateNutritionLogEvent>(_onUpdateNutritionLog);
    on<DeleteNutritionLogEvent>(_onDeleteNutritionLog);
    on<RefreshDailyLogsEvent>(_onRefreshDailyLogs);
  }

  Future<void> _onLoadDailyLogs(
    LoadDailyLogsEvent event,
    Emitter<NutritionLogState> emit,
  ) async {
    emit(NutritionLogLoading());
    _currentDate = event.date;
    await _loadDay(event.date, emit);
  }

  Future<void> _onAddNutritionLog(
    AddNutritionLogEvent event,
    Emitter<NutritionLogState> emit,
  ) async {
    await _performNutritionMutation(
      emit,
      action: () => addNutritionLog(event.log),
      successMessage: 'Nutrition log added successfully',
    );
  }

  Future<void> _onUpdateNutritionLog(
    UpdateNutritionLogEvent event,
    Emitter<NutritionLogState> emit,
  ) async {
    await _performNutritionMutation(
      emit,
      action: () => updateNutritionLog(event.log),
      successMessage: 'Nutrition log updated successfully',
    );
  }

  Future<void> _onDeleteNutritionLog(
    DeleteNutritionLogEvent event,
    Emitter<NutritionLogState> emit,
  ) async {
    await _performNutritionMutation(
      emit,
      action: () => deleteNutritionLog(event.id),
      successMessage: 'Nutrition log deleted successfully',
    );
  }

  Future<void> _onRefreshDailyLogs(
    RefreshDailyLogsEvent event,
    Emitter<NutritionLogState> emit,
  ) async {
    _currentDate = event.date;
    await _loadDay(event.date, emit);
  }

  Future<void> _performNutritionMutation(
    Emitter<NutritionLogState> emit, {
    required Future<dynamic> Function() action,
    required String successMessage,
  }) async {
    final result = await action();

    await result.fold(
      (failure) async => emit(NutritionLogError(failure.message)),
      (_) async {
        await _loadDay(_currentDate, emit);
        emitEffect(NutritionLogSuccessEffect(successMessage));
      },
    );
  }

  Future<void> _loadDay(DateTime date, Emitter<NutritionLogState> emit) async {
    final logsResult = await getLogsForDate(date);

    await logsResult.fold(
      (failure) async => emit(NutritionLogError(failure.message)),
      (logs) async {
        final macrosResult = await getDailyMacros(date);

        macrosResult.fold(
          (failure) => emit(NutritionLogError(failure.message)),
          (macros) => emit(
            DailyLogsLoaded(date: date, logs: logs, dailyMacros: macros),
          ),
        );
      },
    );
  }
}

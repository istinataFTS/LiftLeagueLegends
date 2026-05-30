import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/bloc/bloc_effects_mixin.dart';
import '../../../../domain/entities/nutrition_log.dart';
import '../../../../domain/entities/workout_set.dart';
import '../../../../domain/usecases/nutrition_logs/delete_nutrition_log.dart';
import '../../../../domain/usecases/nutrition_logs/get_logs_by_date_range.dart';
import '../../../../domain/usecases/nutrition_logs/update_nutrition_log.dart';
import '../../../../domain/usecases/workout_sets/delete_workout_set.dart';
import '../../../../domain/usecases/workout_sets/get_all_workout_sets.dart';
import '../../../../domain/usecases/workout_sets/get_sets_by_date_range.dart';
import '../../../../domain/usecases/workout_sets/update_workout_set.dart';
import '../history_strings.dart';
import 'history_effect.dart';
import 'history_event.dart';
import 'history_state.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState>
    with BlocEffectsMixin<HistoryState, HistoryUiEffect> {
  final GetAllWorkoutSets getAllWorkoutSets;
  final GetSetsByDateRange getSetsByDateRange;
  final GetLogsByDateRange getNutritionLogsByDateRange;
  final DeleteWorkoutSet deleteWorkoutSet;
  final UpdateWorkoutSet updateWorkoutSet;
  final DeleteNutritionLog deleteNutritionLog;
  final UpdateNutritionLog updateNutritionLog;

  DateTime _currentMonth = DateTime.now();
  Map<DateTime, List<WorkoutSet>> _monthSets = <DateTime, List<WorkoutSet>>{};
  Map<DateTime, List<NutritionLog>> _monthNutritionLogs =
      <DateTime, List<NutritionLog>>{};
  DateTime? _selectedDate;

  HistoryBloc({
    required this.getAllWorkoutSets,
    required this.getSetsByDateRange,
    required this.getNutritionLogsByDateRange,
    required this.deleteWorkoutSet,
    required this.updateWorkoutSet,
    required this.deleteNutritionLog,
    required this.updateNutritionLog,
  }) : super(const HistoryInitial()) {
    on<LoadMonthSetsEvent>(_onLoadMonthSets);
    on<SelectDateEvent>(_onSelectDate);
    on<ClearDateSelectionEvent>(_onClearDateSelection);
    on<UpdateSetEvent>(_onUpdateSet);
    on<DeleteSetEvent>(_onDeleteSet);
    on<DeleteNutritionHistoryLogEvent>(_onDeleteNutritionLog);
    on<UpdateNutritionHistoryLogEvent>(_onUpdateNutritionLog);
    on<RefreshCurrentMonthEvent>(_onRefreshCurrentMonth);
    on<NavigateToMonthEvent>(_onNavigateToMonth);
  }

  Future<void> _onLoadMonthSets(
    LoadMonthSetsEvent event,
    Emitter<HistoryState> emit,
  ) async {
    emit(const HistoryLoading());

    final HistoryLoaded? loaded = await _loadMonthData(event.month);
    if (loaded != null) {
      emit(loaded);
    } else {
      emit(const HistoryError(HistoryStrings.loadFailed));
    }
  }

  void _onSelectDate(SelectDateEvent event, Emitter<HistoryState> emit) {
    _selectedDate = _normalizeDate(event.date);
    emit(_buildLoadedState());
  }

  void _onClearDateSelection(
    ClearDateSelectionEvent event,
    Emitter<HistoryState> emit,
  ) {
    _selectedDate = null;
    emit(_buildLoadedState());
  }

  Future<void> _onUpdateSet(
    UpdateSetEvent event,
    Emitter<HistoryState> emit,
  ) async {
    await _performHistoryMutation(
      emit,
      action: () => updateWorkoutSet(event.set),
      successMessage: HistoryStrings.setUpdated,
    );
  }

  Future<void> _onDeleteSet(
    DeleteSetEvent event,
    Emitter<HistoryState> emit,
  ) async {
    await _performHistoryMutation(
      emit,
      action: () => deleteWorkoutSet(event.setId),
      successMessage: HistoryStrings.setDeleted,
    );
  }

  Future<void> _onDeleteNutritionLog(
    DeleteNutritionHistoryLogEvent event,
    Emitter<HistoryState> emit,
  ) async {
    await _performHistoryMutation(
      emit,
      action: () => deleteNutritionLog(event.logId),
      successMessage: HistoryStrings.nutritionDeleted,
    );
  }

  Future<void> _onUpdateNutritionLog(
    UpdateNutritionHistoryLogEvent event,
    Emitter<HistoryState> emit,
  ) async {
    await _performHistoryMutation(
      emit,
      action: () => updateNutritionLog(event.log),
      successMessage: HistoryStrings.nutritionUpdated,
    );
  }

  Future<void> _onRefreshCurrentMonth(
    RefreshCurrentMonthEvent event,
    Emitter<HistoryState> emit,
  ) async {
    final HistoryLoaded? reloaded = await _reloadCurrentMonth();
    if (reloaded != null) {
      emit(reloaded);
    } else {
      emit(const HistoryError(HistoryStrings.refreshFailed));
    }
  }

  void _onNavigateToMonth(
    NavigateToMonthEvent event,
    Emitter<HistoryState> emit,
  ) {
    _selectedDate = null;
    add(LoadMonthSetsEvent(event.month));
  }

  Future<void> _performHistoryMutation(
    Emitter<HistoryState> emit, {
    required Future<dynamic> Function() action,
    required String successMessage,
  }) async {
    final dynamic result = await action();

    await result.fold(
      (failure) async {
        emit(HistoryError(failure.message));
        emitEffect(HistoryMutationFailedEffect(failure.message));
      },
      (_) async {
        final HistoryLoaded? reloaded = await _reloadCurrentMonth();
        if (reloaded == null) {
          emit(const HistoryError(HistoryStrings.reloadFailed));
          return;
        }

        emit(reloaded);
        emitEffect(HistorySuccessEffect(successMessage));
      },
    );
  }

  Future<HistoryLoaded?> _reloadCurrentMonth() async {
    return _loadMonthData(_currentMonth);
  }

  Future<HistoryLoaded?> _loadMonthData(DateTime month) async {
    final DateTime firstDay = DateTime(month.year, month.month, 1);
    final DateTime lastDay = DateTime(month.year, month.month + 1, 0);

    final dynamic setsResult = await getSetsByDateRange(
      startDate: firstDay,
      endDate: lastDay,
    );

    final dynamic nutritionResult = await getNutritionLogsByDateRange(
      startDate: firstDay,
      endDate: lastDay,
    );

    final Map<DateTime, List<WorkoutSet>>? groupedSets = setsResult
        .fold<Map<DateTime, List<WorkoutSet>>?>((_) => null, (sets) {
          final Map<DateTime, List<WorkoutSet>> grouped =
              <DateTime, List<WorkoutSet>>{};
          for (final WorkoutSet set in sets) {
            final DateTime dateKey = _normalizeDate(set.date);
            grouped.putIfAbsent(dateKey, () => <WorkoutSet>[]);
            grouped[dateKey]!.add(set);
          }
          for (final List<WorkoutSet> items in grouped.values) {
            items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
          return grouped;
        });

    if (groupedSets == null) {
      return null;
    }

    final Map<DateTime, List<NutritionLog>>? groupedNutrition = nutritionResult
        .fold<Map<DateTime, List<NutritionLog>>?>((_) => null, (logs) {
          final Map<DateTime, List<NutritionLog>> grouped =
              <DateTime, List<NutritionLog>>{};
          for (final NutritionLog log in logs) {
            final DateTime dateKey = _normalizeDate(log.loggedAt);
            grouped.putIfAbsent(dateKey, () => <NutritionLog>[]);
            grouped[dateKey]!.add(log);
          }
          for (final List<NutritionLog> items in grouped.values) {
            items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          }
          return grouped;
        });

    if (groupedNutrition == null) {
      return null;
    }

    _currentMonth = firstDay;
    _monthSets = groupedSets;
    _monthNutritionLogs = groupedNutrition;

    if (_selectedDate != null) {
      final DateTime normalizedSelectedDate = _normalizeDate(_selectedDate!);
      final bool hasActivity =
          (_monthSets[normalizedSelectedDate] ?? <WorkoutSet>[]).isNotEmpty ||
          (_monthNutritionLogs[normalizedSelectedDate] ?? <NutritionLog>[])
              .isNotEmpty;

      if (!hasActivity) {
        _selectedDate = null;
      }
    }

    if (_selectedDate == null && _isSameMonth(firstDay, DateTime.now())) {
      _selectedDate = _normalizeDate(DateTime.now());
    }

    return _buildLoadedState();
  }

  HistoryLoaded _buildLoadedState() {
    final List<WorkoutSet> selectedDateSets = _selectedDate != null
        ? (_monthSets[_selectedDate!] ?? <WorkoutSet>[])
        : <WorkoutSet>[];

    final List<NutritionLog> selectedDateNutritionLogs = _selectedDate != null
        ? (_monthNutritionLogs[_selectedDate!] ?? <NutritionLog>[])
        : <NutritionLog>[];

    return HistoryLoaded(
      currentMonth: _currentMonth,
      monthSets: _monthSets,
      monthNutritionLogs: _monthNutritionLogs,
      selectedDate: _selectedDate,
      selectedDateSets: selectedDateSets,
      selectedDateNutritionLogs: selectedDateNutritionLogs,
    );
  }

  DateTime _normalizeDate(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/calendar_constants.dart';
import '../../../core/themes/lift_theme.dart';
import '../../../core/utils/error_handler.dart';
import '../../../core/utils/week_date_utils.dart';
import '../../../domain/entities/app_settings.dart';
import 'bloc/history_bloc.dart';
import 'bloc/history_effect.dart';
import 'bloc/history_event.dart';
import 'bloc/history_state.dart';
import 'helpers/history_activity_aggregator.dart';
import 'history_strings.dart';
import 'widgets/history_calendar_widget.dart';
import 'widgets/history_day_content.dart';

/// History, rebuilt from frames 08–10 of the Deep Mist export.
///
/// The page has no gutter of its own. Each block below owns its own 20dp
/// horizontal padding so the rules that separate them can run the full width
/// of the screen, edge to edge, which is what the frames show. Wrapping the
/// scroll view in a padding — as this page did before the restyle — would
/// inset those rules and turn the whole page back into a stack of cards.
class HistoryPage extends StatefulWidget {
  const HistoryPage({required this.settings, super.key});

  final AppSettings settings;

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  StreamSubscription<HistoryUiEffect>? _historyEffectsSub;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _historyDayContentKey = GlobalKey();

  DateTime? _lastSelectedDate;
  int _lastSelectedActivityCount = 0;

  @override
  void initState() {
    super.initState();

    final HistoryBloc historyBloc = context.read<HistoryBloc>();

    _historyEffectsSub = historyBloc.effects.listen((HistoryUiEffect effect) {
      if (!mounted) {
        return;
      }

      if (effect is HistorySuccessEffect) {
        ErrorHandler.showSuccess(context, effect.message);
      }
    });

    historyBloc.add(LoadMonthSetsEvent(DateTime.now()));
  }

  @override
  void dispose() {
    _historyEffectsSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = widget.settings;

    return Scaffold(
      appBar: AppBar(title: const Text(HistoryStrings.title), elevation: 0),
      body: BlocConsumer<HistoryBloc, HistoryState>(
        listener: (BuildContext context, HistoryState state) {
          if (state is! HistoryLoaded) {
            return;
          }

          final DateTime? selectedDate = state.selectedDate;
          final int selectedActivityCount =
              state.selectedDateSets.length +
              state.selectedDateNutritionLogs.length;

          if (selectedDate == null) {
            _lastSelectedDate = null;
            _lastSelectedActivityCount = 0;
            return;
          }

          final bool selectedDateChanged =
              _lastSelectedDate == null ||
              !WeekDateUtils.isSameDay(_lastSelectedDate!, selectedDate);

          final bool selectedActivityChanged =
              selectedActivityCount != _lastSelectedActivityCount;

          if (selectedDateChanged || selectedActivityChanged) {
            _focusSelectedDayContent();
          }

          _lastSelectedDate = selectedDate;
          _lastSelectedActivityCount = selectedActivityCount;
        },
        builder: (BuildContext context, HistoryState state) {
          if (state is HistoryLoading) {
            return const Center(
              child: CircularProgressIndicator(color: LiftColors.actionTint),
            );
          }

          if (state is HistoryError) {
            return _buildErrorState(context, state);
          }

          if (state is HistoryLoaded) {
            return _buildLoadedState(context, state, settings);
          }

          return _buildInitialState(context);
        },
      ),
    );
  }

  Widget _buildLoadedState(
    BuildContext context,
    HistoryLoaded state,
    AppSettings settings,
  ) {
    return GestureDetector(
      onHorizontalDragEnd: (DragEndDetails details) {
        if (details.primaryVelocity != null &&
            details.primaryVelocity! > CalendarConstants.swipeThreshold) {
          _navigateToPreviousMonth(context, state.currentMonth);
        } else if (details.primaryVelocity != null &&
            details.primaryVelocity! < -CalendarConstants.swipeThreshold) {
          _navigateToNextMonth(context, state.currentMonth);
        }
      },
      child: RefreshIndicator(
        color: LiftColors.actionTint,
        onRefresh: () async {
          context.read<HistoryBloc>().add(const RefreshCurrentMonthEvent());
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Frame 08 drops the two chevrons that used to flank the month
              // name, which leaves the horizontal swipe above as the only way
              // to change month. A swipe is not operable from a screen reader,
              // so the same two moves are published here as semantic actions.
              Semantics(
                container: true,
                label: HistoryStrings.calendarSemanticLabel,
                customSemanticsActions: <CustomSemanticsAction, VoidCallback>{
                  const CustomSemanticsAction(
                    label: HistoryStrings.previousMonthLabel,
                  ): () =>
                      _navigateToPreviousMonth(context, state.currentMonth),
                  const CustomSemanticsAction(
                    label: HistoryStrings.nextMonthLabel,
                  ): () =>
                      _navigateToNextMonth(context, state.currentMonth),
                },
                child: HistoryCalendarWidget(
                  displayedMonth: state.currentMonth,
                  selectedDate: state.selectedDate,
                  today: DateTime.now(),
                  dayActivity: HistoryActivityAggregator.buildActivityCounts(
                    monthSets: state.monthSets,
                    monthNutritionLogs: state.monthNutritionLogs,
                  ),
                  weekStartDay: settings.weekStartDay,
                  onDateSelected: (DateTime date) {
                    _onDateSelected(context, state.selectedDate, date);
                  },
                ),
              ),
              KeyedSubtree(
                key: _historyDayContentKey,
                child: HistoryDayContent(
                  selectedDate: state.selectedDate,
                  workoutSets: state.selectedDateSets,
                  nutritionLogs: state.selectedDateNutritionLogs,
                  weightUnit: settings.weightUnit,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Frame 08 has no `x` on the day strip, so re-tapping the day that is
  /// already selected is what clears the selection now. Without this the
  /// `ClearDateSelectionEvent` path would have no caller left in the UI.
  void _onDateSelected(
    BuildContext context,
    DateTime? currentSelection,
    DateTime tappedDate,
  ) {
    final bool isAlreadySelected =
        currentSelection != null &&
        WeekDateUtils.isSameDay(currentSelection, tappedDate);

    context.read<HistoryBloc>().add(
      isAlreadySelected
          ? const ClearDateSelectionEvent()
          : SelectDateEvent(tappedDate),
    );
  }

  Widget _buildInitialState(BuildContext context) {
    return Center(
      child: Text(
        HistoryStrings.loading.toUpperCase(),
        style: LiftText.labelMedium.copyWith(color: LiftColors.textDim),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, HistoryError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline, size: 48, color: LiftColors.error),
            const SizedBox(height: 12),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                context.read<HistoryBloc>().add(
                  LoadMonthSetsEvent(DateTime.now()),
                );
              },
              child: const Text(HistoryStrings.retry),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToPreviousMonth(BuildContext context, DateTime currentMonth) {
    final DateTime previousMonth = DateTime(
      currentMonth.year,
      currentMonth.month - 1,
    );

    if (previousMonth.isBefore(CalendarConstants.minAllowedDate)) {
      ErrorHandler.showInfo(context, HistoryStrings.cannotViewTooFarPast);
      return;
    }

    context.read<HistoryBloc>().add(NavigateToMonthEvent(previousMonth));
  }

  void _navigateToNextMonth(BuildContext context, DateTime currentMonth) {
    final DateTime nextMonth = DateTime(
      currentMonth.year,
      currentMonth.month + 1,
    );

    final DateTime now = DateTime.now();
    final DateTime currentMonthDate = DateTime(now.year, now.month, 1);
    final DateTime nextMonthDate = DateTime(nextMonth.year, nextMonth.month, 1);

    if (nextMonthDate.isAfter(currentMonthDate)) {
      ErrorHandler.showInfo(context, HistoryStrings.cannotViewFutureMonths);
      return;
    }

    context.read<HistoryBloc>().add(NavigateToMonthEvent(nextMonth));
  }

  void _focusSelectedDayContent() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) {
        return;
      }

      final BuildContext? targetContext = _historyDayContentKey.currentContext;
      if (targetContext == null) {
        return;
      }

      await Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        alignment: 0.08,
      );
    });
  }
}

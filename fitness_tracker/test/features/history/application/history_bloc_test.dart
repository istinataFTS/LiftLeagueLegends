import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/delete_nutrition_log.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_logs_by_date_range.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/update_nutrition_log.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/delete_workout_set.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_all_workout_sets.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_sets_by_date_range.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/update_workout_set.dart';
import 'package:fitness_tracker/features/history/history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAllWorkoutSets extends Mock implements GetAllWorkoutSets {}

class MockGetSetsByDateRange extends Mock implements GetSetsByDateRange {}

class MockGetLogsByDateRange extends Mock implements GetLogsByDateRange {}

class MockDeleteWorkoutSet extends Mock implements DeleteWorkoutSet {}

class MockUpdateWorkoutSet extends Mock implements UpdateWorkoutSet {}

class MockDeleteNutritionLog extends Mock implements DeleteNutritionLog {}

class MockUpdateNutritionLog extends Mock implements UpdateNutritionLog {}

void main() {
  late MockGetAllWorkoutSets mockGetAllWorkoutSets;
  late MockGetSetsByDateRange mockGetSetsByDateRange;
  late MockGetLogsByDateRange mockGetLogsByDateRange;
  late MockDeleteWorkoutSet mockDeleteWorkoutSet;
  late MockUpdateWorkoutSet mockUpdateWorkoutSet;
  late MockDeleteNutritionLog mockDeleteNutritionLog;
  late MockUpdateNutritionLog mockUpdateNutritionLog;
  late HistoryBloc bloc;

  final DateTime january = DateTime(2024, 1, 1);
  final DateTime firstActivityDate = DateTime(2024, 1, 15);
  final DateTime secondActivityDate = DateTime(2024, 1, 18);

  WorkoutSet buildWorkoutSet({
    required String id,
    required DateTime date,
    required DateTime createdAt,
  }) {
    return WorkoutSet(
      id: id,
      exerciseId: 'exercise-1',
      reps: 10,
      weight: 80,
      date: date,
      createdAt: createdAt,
    );
  }

  NutritionLog buildNutritionLog({
    required String id,
    required DateTime loggedAt,
    required DateTime createdAt,
  }) {
    return NutritionLog(
      id: id,
      mealName: 'Chicken bowl',
      proteinGrams: 40,
      carbsGrams: 55,
      fatGrams: 12,
      calories: 488,
      loggedAt: loggedAt,
      createdAt: createdAt,
    );
  }

  setUpAll(() {
    registerFallbackValue(DateTime(2024, 1, 1));
  });

  setUp(() {
    mockGetAllWorkoutSets = MockGetAllWorkoutSets();
    mockGetSetsByDateRange = MockGetSetsByDateRange();
    mockGetLogsByDateRange = MockGetLogsByDateRange();
    mockDeleteWorkoutSet = MockDeleteWorkoutSet();
    mockUpdateWorkoutSet = MockUpdateWorkoutSet();
    mockDeleteNutritionLog = MockDeleteNutritionLog();
    mockUpdateNutritionLog = MockUpdateNutritionLog();

    bloc = HistoryBloc(
      getAllWorkoutSets: mockGetAllWorkoutSets,
      getSetsByDateRange: mockGetSetsByDateRange,
      getNutritionLogsByDateRange: mockGetLogsByDateRange,
      deleteWorkoutSet: mockDeleteWorkoutSet,
      updateWorkoutSet: mockUpdateWorkoutSet,
      deleteNutritionLog: mockDeleteNutritionLog,
      updateNutritionLog: mockUpdateNutritionLog,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  void stubMonthLoadSuccess({
    List<WorkoutSet> sets = const <WorkoutSet>[],
    List<NutritionLog> logs = const <NutritionLog>[],
  }) {
    when(
      () => mockGetSetsByDateRange(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => Right(sets));

    when(
      () => mockGetLogsByDateRange(
        startDate: any(named: 'startDate'),
        endDate: any(named: 'endDate'),
      ),
    ).thenAnswer((_) async => Right(logs));
  }

  group('HistoryBloc', () {
    blocTest<HistoryBloc, HistoryState>(
      'emits loading then loaded with grouped month activity',
      build: () {
        stubMonthLoadSuccess(
          sets: <WorkoutSet>[
            buildWorkoutSet(
              id: 'set-1',
              date: firstActivityDate,
              createdAt: firstActivityDate.add(const Duration(hours: 2)),
            ),
            buildWorkoutSet(
              id: 'set-2',
              date: firstActivityDate,
              createdAt: firstActivityDate.add(const Duration(hours: 1)),
            ),
          ],
          logs: <NutritionLog>[
            buildNutritionLog(
              id: 'log-1',
              loggedAt: secondActivityDate,
              createdAt: secondActivityDate.add(const Duration(minutes: 5)),
            ),
          ],
        );
        return bloc;
      },
      act: (bloc) => bloc.add(LoadMonthSetsEvent(january)),
      expect: () => <Matcher>[
        isA<HistoryLoading>(),
        isA<HistoryLoaded>()
            .having((state) => state.currentMonth, 'currentMonth', january)
            .having(
              (state) => state.monthSets[DateTime(2024, 1, 15)]?.length,
              'workout count on Jan 15',
              2,
            )
            .having(
              (state) =>
                  state.monthNutritionLogs[DateTime(2024, 1, 18)]?.length,
              'nutrition count on Jan 18',
              1,
            )
            .having((state) => state.selectedDate, 'selectedDate', isNull),
      ],
    );

    blocTest<HistoryBloc, HistoryState>(
      'emits error when workout history loading fails',
      build: () {
        when(
          () => mockGetSetsByDateRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer(
          (_) async => const Left(DatabaseFailure('Failed to load sets')),
        );

        when(
          () => mockGetLogsByDateRange(
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => const Right(<NutritionLog>[]));

        return bloc;
      },
      act: (bloc) => bloc.add(LoadMonthSetsEvent(january)),
      expect: () => <Matcher>[
        isA<HistoryLoading>(),
        isA<HistoryError>().having(
          (state) => state.message,
          'message',
          'Failed to load history data',
        ),
      ],
    );

    blocTest<HistoryBloc, HistoryState>(
      'selects a date from loaded month data',
      build: () {
        stubMonthLoadSuccess(
          sets: <WorkoutSet>[
            buildWorkoutSet(
              id: 'set-1',
              date: firstActivityDate,
              createdAt: firstActivityDate.add(const Duration(hours: 2)),
            ),
          ],
          logs: <NutritionLog>[
            buildNutritionLog(
              id: 'log-1',
              loggedAt: firstActivityDate,
              createdAt: firstActivityDate.add(const Duration(minutes: 5)),
            ),
          ],
        );
        return bloc;
      },
      act: (bloc) async {
        bloc.add(LoadMonthSetsEvent(january));
        await Future<void>.delayed(Duration.zero);
        bloc.add(SelectDateEvent(firstActivityDate));
      },
      expect: () => <Matcher>[
        isA<HistoryLoading>(),
        isA<HistoryLoaded>(),
        isA<HistoryLoaded>()
            .having(
              (state) => state.selectedDate,
              'selectedDate',
              DateTime(2024, 1, 15),
            )
            .having(
              (state) => state.selectedDateSets.length,
              'selectedDateSets length',
              1,
            )
            .having(
              (state) => state.selectedDateNutritionLogs.length,
              'selectedDateNutritionLogs length',
              1,
            ),
      ],
    );

    blocTest<HistoryBloc, HistoryState>(
      'clears the selected date',
      build: () {
        stubMonthLoadSuccess(
          sets: <WorkoutSet>[
            buildWorkoutSet(
              id: 'set-1',
              date: firstActivityDate,
              createdAt: firstActivityDate.add(const Duration(hours: 2)),
            ),
          ],
        );
        return bloc;
      },
      act: (bloc) async {
        bloc.add(LoadMonthSetsEvent(january));
        await Future<void>.delayed(Duration.zero);
        bloc.add(SelectDateEvent(firstActivityDate));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const ClearDateSelectionEvent());
      },
      expect: () => <Matcher>[
        isA<HistoryLoading>(),
        isA<HistoryLoaded>(),
        isA<HistoryLoaded>().having(
          (state) => state.selectedDate,
          'selectedDate',
          DateTime(2024, 1, 15),
        ),
        isA<HistoryLoaded>()
            .having((state) => state.selectedDate, 'selectedDate', isNull)
            .having(
              (state) => state.selectedDateSets,
              'selectedDateSets',
              isEmpty,
            )
            .having(
              (state) => state.selectedDateNutritionLogs,
              'selectedDateNutritionLogs',
              isEmpty,
            ),
      ],
    );

    blocTest<HistoryBloc, HistoryState>(
      'refreshes the currently loaded month',
      build: () {
        stubMonthLoadSuccess(
          sets: <WorkoutSet>[
            buildWorkoutSet(
              id: 'set-1',
              date: firstActivityDate,
              createdAt: firstActivityDate.add(const Duration(hours: 2)),
            ),
          ],
        );
        return bloc;
      },
      act: (bloc) async {
        bloc.add(LoadMonthSetsEvent(january));
        await Future<void>.delayed(Duration.zero);
        bloc.add(const RefreshCurrentMonthEvent());
      },
      expect: () => <Matcher>[
        isA<HistoryLoading>(),
        isA<HistoryLoaded>()
            .having((state) => state.currentMonth, 'currentMonth', january)
            .having(
              (state) => state.monthSets[DateTime(2024, 1, 15)]?.length,
              'workout count on Jan 15',
              1,
            ),
      ],
      verify: (_) {
        verify(
          () => mockGetSetsByDateRange(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 31),
          ),
        ).called(2);

        verify(
          () => mockGetLogsByDateRange(
            startDate: DateTime(2024, 1, 1),
            endDate: DateTime(2024, 1, 31),
          ),
        ).called(2);
      },
    );
  });
}

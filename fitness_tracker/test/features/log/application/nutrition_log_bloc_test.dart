import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/add_nutrition_log.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/delete_nutrition_log.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_daily_macros.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_logs_for_date.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/update_nutrition_log.dart';
import 'package:fitness_tracker/features/log/application/nutrition_log_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetLogsForDate extends Mock implements GetLogsForDate {}

class MockAddNutritionLog extends Mock implements AddNutritionLog {}

class MockUpdateNutritionLog extends Mock implements UpdateNutritionLog {}

class MockDeleteNutritionLog extends Mock implements DeleteNutritionLog {}

class MockGetDailyMacros extends Mock implements GetDailyMacros {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _logDate = DateTime(2026, 4, 7);

final _logFixture = NutritionLog(
  id: 'log-1',
  mealName: 'Oats',
  proteinGrams: 10,
  carbsGrams: 40,
  fatGrams: 5,
  calories: 245,
  loggedAt: _logDate,
  createdAt: _logDate,
);

const _macros = <String, double>{
  'protein': 10.0,
  'carbs': 40.0,
  'fats': 5.0,
  'calories': 245.0,
};

const _dbFailure = DatabaseFailure('db error');

void main() {
  late MockGetLogsForDate mockGetLogs;
  late MockAddNutritionLog mockAdd;
  late MockUpdateNutritionLog mockUpdate;
  late MockDeleteNutritionLog mockDelete;
  late MockGetDailyMacros mockGetMacros;

  NutritionLogBloc buildBloc() => NutritionLogBloc(
    getLogsForDate: mockGetLogs,
    addNutritionLog: mockAdd,
    updateNutritionLog: mockUpdate,
    deleteNutritionLog: mockDelete,
    getDailyMacros: mockGetMacros,
  );

  setUpAll(() {
    registerFallbackValue(_logFixture);
  });

  setUp(() {
    mockGetLogs = MockGetLogsForDate();
    mockAdd = MockAddNutritionLog();
    mockUpdate = MockUpdateNutritionLog();
    mockDelete = MockDeleteNutritionLog();
    mockGetMacros = MockGetDailyMacros();
  });

  group('NutritionLogBloc', () {
    group('LoadDailyLogsEvent', () {
      blocTest<NutritionLogBloc, NutritionLogState>(
        'emits [Loading, DailyLogsLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetLogs(_logDate),
          ).thenAnswer((_) async => Right([_logFixture]));
          when(
            () => mockGetMacros(_logDate),
          ).thenAnswer((_) async => const Right(_macros));
        },
        act: (bloc) => bloc.add(LoadDailyLogsEvent(_logDate)),
        expect: () => [
          isA<NutritionLogLoading>(),
          DailyLogsLoaded(
            date: _logDate,
            logs: [_logFixture],
            dailyMacros: _macros,
          ),
        ],
      );

      blocTest<NutritionLogBloc, NutritionLogState>(
        'emits [Loading, NutritionLogError] when logs fetch fails',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetLogs(_logDate),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(LoadDailyLogsEvent(_logDate)),
        expect: () => [
          isA<NutritionLogLoading>(),
          const NutritionLogError('db error'),
        ],
      );

      blocTest<NutritionLogBloc, NutritionLogState>(
        'emits [Loading, NutritionLogError] when macros fetch fails',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetLogs(_logDate),
          ).thenAnswer((_) async => Right([_logFixture]));
          when(
            () => mockGetMacros(_logDate),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(LoadDailyLogsEvent(_logDate)),
        expect: () => [
          isA<NutritionLogLoading>(),
          const NutritionLogError('db error'),
        ],
      );
    });

    group('AddNutritionLogEvent', () {
      blocTest<NutritionLogBloc, NutritionLogState>(
        'reloads the day and emits DailyLogsLoaded on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockAdd(_logFixture),
          ).thenAnswer((_) async => const Right(null));
          when(
            () => mockGetLogs(any()),
          ).thenAnswer((_) async => Right([_logFixture]));
          when(
            () => mockGetMacros(any()),
          ).thenAnswer((_) async => const Right(_macros));
        },
        act: (bloc) => bloc.add(AddNutritionLogEvent(_logFixture)),
        expect: () => [isA<DailyLogsLoaded>()],
      );

      blocTest<NutritionLogBloc, NutritionLogState>(
        'emits NutritionLogError on failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockAdd(_logFixture),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(AddNutritionLogEvent(_logFixture)),
        expect: () => [const NutritionLogError('db error')],
      );

      test('emits NutritionLogSuccessEffect on success', () async {
        when(
          () => mockAdd(_logFixture),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockGetLogs(any()),
        ).thenAnswer((_) async => Right([_logFixture]));
        when(
          () => mockGetMacros(any()),
        ).thenAnswer((_) async => const Right(_macros));

        final bloc = buildBloc();
        final effects = <NutritionLogUiEffect>[];
        final subscription = bloc.effects.listen(effects.add);

        bloc.add(AddNutritionLogEvent(_logFixture));
        await Future<void>.delayed(Duration.zero);

        expect(effects, hasLength(1));
        expect(effects.first, isA<NutritionLogSuccessEffect>());
        expect(
          (effects.first as NutritionLogSuccessEffect).message,
          'Nutrition log added successfully',
        );

        await subscription.cancel();
        await bloc.close();
      });
    });

    group('UpdateNutritionLogEvent', () {
      blocTest<NutritionLogBloc, NutritionLogState>(
        'reloads the day and emits DailyLogsLoaded on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockUpdate(_logFixture),
          ).thenAnswer((_) async => const Right(null));
          when(
            () => mockGetLogs(any()),
          ).thenAnswer((_) async => Right([_logFixture]));
          when(
            () => mockGetMacros(any()),
          ).thenAnswer((_) async => const Right(_macros));
        },
        act: (bloc) => bloc.add(UpdateNutritionLogEvent(_logFixture)),
        expect: () => [isA<DailyLogsLoaded>()],
      );

      blocTest<NutritionLogBloc, NutritionLogState>(
        'emits NutritionLogError on failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockUpdate(_logFixture),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(UpdateNutritionLogEvent(_logFixture)),
        expect: () => [const NutritionLogError('db error')],
      );

      test('emits NutritionLogSuccessEffect on success', () async {
        when(
          () => mockUpdate(_logFixture),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockGetLogs(any()),
        ).thenAnswer((_) async => Right([_logFixture]));
        when(
          () => mockGetMacros(any()),
        ).thenAnswer((_) async => const Right(_macros));

        final bloc = buildBloc();
        final effects = <NutritionLogUiEffect>[];
        final subscription = bloc.effects.listen(effects.add);

        bloc.add(UpdateNutritionLogEvent(_logFixture));
        await Future<void>.delayed(Duration.zero);

        expect(effects, hasLength(1));
        expect(
          (effects.first as NutritionLogSuccessEffect).message,
          'Nutrition log updated successfully',
        );

        await subscription.cancel();
        await bloc.close();
      });
    });

    group('DeleteNutritionLogEvent', () {
      blocTest<NutritionLogBloc, NutritionLogState>(
        'reloads the day and emits DailyLogsLoaded on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockDelete('log-1'),
          ).thenAnswer((_) async => const Right(null));
          when(
            () => mockGetLogs(any()),
          ).thenAnswer((_) async => const Right([]));
          when(() => mockGetMacros(any())).thenAnswer(
            (_) async => const Right({
              'protein': 0.0,
              'carbs': 0.0,
              'fats': 0.0,
              'calories': 0.0,
            }),
          );
        },
        act: (bloc) => bloc.add(const DeleteNutritionLogEvent('log-1')),
        expect: () => [isA<DailyLogsLoaded>()],
      );

      blocTest<NutritionLogBloc, NutritionLogState>(
        'emits NutritionLogError on failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockDelete('log-1'),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(const DeleteNutritionLogEvent('log-1')),
        expect: () => [const NutritionLogError('db error')],
      );

      test('emits NutritionLogSuccessEffect on success', () async {
        when(
          () => mockDelete('log-1'),
        ).thenAnswer((_) async => const Right(null));
        when(() => mockGetLogs(any())).thenAnswer((_) async => const Right([]));
        when(() => mockGetMacros(any())).thenAnswer(
          (_) async => const Right({
            'protein': 0.0,
            'carbs': 0.0,
            'fats': 0.0,
            'calories': 0.0,
          }),
        );

        final bloc = buildBloc();
        final effects = <NutritionLogUiEffect>[];
        final subscription = bloc.effects.listen(effects.add);

        bloc.add(const DeleteNutritionLogEvent('log-1'));
        await Future<void>.delayed(Duration.zero);

        expect(effects, hasLength(1));
        expect(
          (effects.first as NutritionLogSuccessEffect).message,
          'Nutrition log deleted successfully',
        );

        await subscription.cancel();
        await bloc.close();
      });
    });

    group('RefreshDailyLogsEvent', () {
      blocTest<NutritionLogBloc, NutritionLogState>(
        'reloads the specified date without emitting Loading',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetLogs(_logDate),
          ).thenAnswer((_) async => Right([_logFixture]));
          when(
            () => mockGetMacros(_logDate),
          ).thenAnswer((_) async => const Right(_macros));
        },
        act: (bloc) => bloc.add(RefreshDailyLogsEvent(_logDate)),
        expect: () => [
          DailyLogsLoaded(
            date: _logDate,
            logs: [_logFixture],
            dailyMacros: _macros,
          ),
        ],
      );
    });
  });
}

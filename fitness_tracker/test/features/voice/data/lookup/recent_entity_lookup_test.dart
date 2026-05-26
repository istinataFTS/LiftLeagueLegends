import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/time/clock.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/usecases/nutrition_logs/get_logs_for_date.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_sets_by_date_range.dart';
import 'package:fitness_tracker/features/voice/data/lookup/recent_entity_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetSetsByDateRange extends Mock implements GetSetsByDateRange {}

class MockGetLogsForDate extends Mock implements GetLogsForDate {}

class FakeClock extends Clock {
  FakeClock(this._now);
  final DateTime _now;

  @override
  DateTime now() => _now;
}

WorkoutSet _set(String id) => WorkoutSet(
  id: id,
  exerciseId: 'ex-1',
  reps: 10,
  weight: 80,
  intensity: 7,
  date: DateTime(2026, 5, 15),
  createdAt: DateTime(2026, 5, 15),
  syncMetadata: const EntitySyncMetadata(),
);

NutritionLog _log(String id) => NutritionLog(
  id: id,
  mealName: 'Oats',
  proteinGrams: 10,
  carbsGrams: 30,
  fatGrams: 5,
  calories: 200,
  loggedAt: DateTime(2026, 5, 15, 8),
  createdAt: DateTime(2026, 5, 15, 8),
);

void main() {
  late MockGetSetsByDateRange mockSets;
  late MockGetLogsForDate mockLogs;
  late RecentEntityLookup lookup;

  final fixedNow = DateTime(2026, 5, 15, 12);

  setUp(() {
    mockSets = MockGetSetsByDateRange();
    mockLogs = MockGetLogsForDate();
    lookup = RecentEntityLookup(
      getSetsByDateRange: mockSets,
      getLogsForDate: mockLogs,
      clock: FakeClock(fixedNow),
    );
    registerFallbackValue(DateTime(2026));
  });

  group('mostRecentSet', () {
    test('returns first set (datasource orders newest-first)', () async {
      final s1 = _set('s-1');
      final s2 = _set('s-2');
      when(
        () => mockSets(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).thenAnswer((_) async => Right([s1, s2]));

      final result = await lookup.mostRecentSet();
      expect(result, s1);
    });

    test('returns null when no sets in window', () async {
      when(
        () => mockSets(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).thenAnswer((_) async => const Right([]));

      final result = await lookup.mostRecentSet();
      expect(result, isNull);
    });

    test('returns null on use case failure', () async {
      when(
        () => mockSets(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).thenAnswer((_) async => Left(ServerFailure('error')));

      final result = await lookup.mostRecentSet();
      expect(result, isNull);
    });

    test('queries startDate = now - within, endDate = now', () async {
      when(
        () => mockSets(
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).thenAnswer((_) async => const Right([]));

      await lookup.mostRecentSet(within: const Duration(hours: 12));

      final captured = verify(
        () => mockSets(
          startDate: captureAny(named: 'startDate'),
          endDate: captureAny(named: 'endDate'),
          muscleGroup: any(named: 'muscleGroup'),
        ),
      ).captured;

      expect(captured[0], fixedNow.subtract(const Duration(hours: 12)));
      expect(captured[1], fixedNow);
    });
  });

  group('mostRecentLog', () {
    test('returns first log (datasource orders newest-first)', () async {
      final l1 = _log('l-1');
      final l2 = _log('l-2');
      when(() => mockLogs(any())).thenAnswer((_) async => Right([l1, l2]));

      final result = await lookup.mostRecentLog();
      expect(result, l1);
    });

    test('returns null when no logs today', () async {
      when(() => mockLogs(any())).thenAnswer((_) async => const Right([]));

      final result = await lookup.mostRecentLog();
      expect(result, isNull);
    });

    test('returns null on use case failure', () async {
      when(
        () => mockLogs(any()),
      ).thenAnswer((_) async => Left(ServerFailure('error')));

      final result = await lookup.mostRecentLog();
      expect(result, isNull);
    });

    test('queries with today from clock', () async {
      when(() => mockLogs(any())).thenAnswer((_) async => const Right([]));

      await lookup.mostRecentLog();

      final captured =
          verify(() => mockLogs(captureAny())).captured.single as DateTime;
      expect(captured.year, fixedNow.year);
      expect(captured.month, fixedNow.month);
      expect(captured.day, fixedNow.day);
    });
  });
}

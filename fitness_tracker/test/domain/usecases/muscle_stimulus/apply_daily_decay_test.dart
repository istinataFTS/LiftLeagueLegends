import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart'
    as constants;
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/muscle_stimulus.dart';
import 'package:fitness_tracker/domain/repositories/muscle_stimulus_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/apply_daily_decay.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMuscleStimulusRepository extends Mock
    implements MuscleStimulusRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const String _testUserId = 'user-1';

MuscleStimulus _makeStimulus({
  required String id,
  required double rollingWeeklyLoad,
  double dailyStimulus = 2.0,
}) {
  final date = DateTime(2026, 4, 1);
  return MuscleStimulus(
    id: id,
    ownerUserId: _testUserId,
    muscleGroup: constants.MuscleStimulus.lats,
    date: date,
    dailyStimulus: dailyStimulus,
    rollingWeeklyLoad: rollingWeeklyLoad,
    createdAt: date,
    updatedAt: date,
  );
}

const _dbFailure = DatabaseFailure('db error');

void main() {
  late MockMuscleStimulusRepository mockRepo;
  late ApplyDailyDecay useCase;

  setUpAll(() {
    registerFallbackValue(_makeStimulus(id: 'fallback', rollingWeeklyLoad: 0));
  });

  setUp(() {
    mockRepo = MockMuscleStimulusRepository();
    useCase = ApplyDailyDecay(mockRepo);
  });

  group('ApplyDailyDecay', () {
    group('call', () {
      test('returns Right(20) on repository success', () async {
        when(
          () => mockRepo.applyDailyDecayToAll(_testUserId),
        ).thenAnswer((_) async => const Right(null));

        final result = await useCase(_testUserId);

        expect(result, const Right(20));
      });

      test('returns Left(failure) on repository failure', () async {
        when(
          () => mockRepo.applyDailyDecayToAll(_testUserId),
        ).thenAnswer((_) async => const Left(_dbFailure));

        final result = await useCase(_testUserId);

        expect(result, const Left(_dbFailure));
      });

      test('forwards userId to applyDailyDecayToAll', () async {
        when(
          () => mockRepo.applyDailyDecayToAll(_testUserId),
        ).thenAnswer((_) async => const Right(null));

        await useCase(_testUserId);

        verify(() => mockRepo.applyDailyDecayToAll(_testUserId)).called(1);
        verifyNever(() => mockRepo.applyDailyDecayToAll(any()));
      });
    });

    group('applyDecayForDate', () {
      final date = DateTime(2026, 4, 1);

      test('returns Right(0) when no records exist for the date', () async {
        when(
          () => mockRepo.getAllStimulusForDate(_testUserId, date),
        ).thenAnswer((_) async => const Right([]));

        final result = await useCase.applyDecayForDate(_testUserId, date);

        expect(result, const Right(0));
        verifyNever(
          () => mockRepo.updateStimulusValues(
            id: any(named: 'id'),
            dailyStimulus: any(named: 'dailyStimulus'),
            rollingWeeklyLoad: any(named: 'rollingWeeklyLoad'),
          ),
        );
      });

      test(
        'updates each record and returns count of successful updates',
        () async {
          final rec1 = _makeStimulus(id: 'rec-1', rollingWeeklyLoad: 10.0);
          final rec2 = _makeStimulus(id: 'rec-2', rollingWeeklyLoad: 20.0);

          when(
            () => mockRepo.getAllStimulusForDate(_testUserId, date),
          ).thenAnswer((_) async => Right([rec1, rec2]));
          // 10.0 × 0.6 = 6.0,  20.0 × 0.6 = 12.0
          when(
            () => mockRepo.updateStimulusValues(
              id: 'rec-1',
              dailyStimulus: rec1.dailyStimulus,
              rollingWeeklyLoad: 6.0,
              lastSetTimestamp: rec1.lastSetTimestamp,
              lastSetStimulus: rec1.lastSetStimulus,
            ),
          ).thenAnswer((_) async => const Right(null));
          when(
            () => mockRepo.updateStimulusValues(
              id: 'rec-2',
              dailyStimulus: rec2.dailyStimulus,
              rollingWeeklyLoad: 12.0,
              lastSetTimestamp: rec2.lastSetTimestamp,
              lastSetStimulus: rec2.lastSetStimulus,
            ),
          ).thenAnswer((_) async => const Right(null));

          final result = await useCase.applyDecayForDate(_testUserId, date);

          expect(result, const Right(2));
        },
      );

      test('counts only successful updates on partial failure', () async {
        final rec1 = _makeStimulus(id: 'rec-1', rollingWeeklyLoad: 10.0);
        final rec2 = _makeStimulus(id: 'rec-2', rollingWeeklyLoad: 20.0);

        when(
          () => mockRepo.getAllStimulusForDate(_testUserId, date),
        ).thenAnswer((_) async => Right([rec1, rec2]));
        when(
          () => mockRepo.updateStimulusValues(
            id: 'rec-1',
            dailyStimulus: rec1.dailyStimulus,
            rollingWeeklyLoad: 6.0,
            lastSetTimestamp: rec1.lastSetTimestamp,
            lastSetStimulus: rec1.lastSetStimulus,
          ),
        ).thenAnswer((_) async => const Left(_dbFailure));
        when(
          () => mockRepo.updateStimulusValues(
            id: 'rec-2',
            dailyStimulus: rec2.dailyStimulus,
            rollingWeeklyLoad: 12.0,
            lastSetTimestamp: rec2.lastSetTimestamp,
            lastSetStimulus: rec2.lastSetStimulus,
          ),
        ).thenAnswer((_) async => const Right(null));

        final result = await useCase.applyDecayForDate(_testUserId, date);

        // rec-1 failed, rec-2 succeeded → count = 1
        expect(result, const Right(1));
      });

      test(
        'propagates repository failure from getAllStimulusForDate',
        () async {
          when(
            () => mockRepo.getAllStimulusForDate(_testUserId, date),
          ).thenAnswer((_) async => const Left(_dbFailure));

          final result = await useCase.applyDecayForDate(_testUserId, date);

          expect(result, const Left(_dbFailure));
        },
      );
    });

    group('shouldApplyDecayToday', () {
      test('returns false when records already exist for today', () async {
        when(
          () => mockRepo.getAllStimulusForDate(_testUserId, any()),
        ).thenAnswer(
          (_) async =>
              Right([_makeStimulus(id: 'rec-1', rollingWeeklyLoad: 5.0)]),
        );

        final result = await useCase.shouldApplyDecayToday(_testUserId);

        expect(result, const Right(false));
      });

      test('returns true when no records exist for today', () async {
        when(
          () => mockRepo.getAllStimulusForDate(_testUserId, any()),
        ).thenAnswer((_) async => const Right([]));

        final result = await useCase.shouldApplyDecayToday(_testUserId);

        expect(result, const Right(true));
      });

      test('propagates repository failure', () async {
        when(
          () => mockRepo.getAllStimulusForDate(_testUserId, any()),
        ).thenAnswer((_) async => const Left(_dbFailure));

        final result = await useCase.shouldApplyDecayToday(_testUserId);

        expect(result, const Left(_dbFailure));
      });
    });

    group('previewDecay', () {
      test('multiplies value by weekly decay factor', () {
        // weeklyDecayFactor = 0.6
        expect(useCase.previewDecay(10.0), closeTo(6.0, 0.001));
      });

      test('returns 0 for zero load', () {
        expect(useCase.previewDecay(0.0), 0.0);
      });
    });

    group('estimateRecoveryDays', () {
      test('returns 0 when load is already at or below threshold', () {
        // threshold = 1.0, currentLoad = 0.5 → already recovered
        expect(useCase.estimateRecoveryDays(0.5, threshold: 1.0), 0);
      });

      test('iterates daily decay until load falls below default threshold', () {
        // currentLoad=10, defaultThreshold=10*0.1=1.0
        // 10→6→3.6→2.16→1.296→0.7776 → 5 days
        expect(useCase.estimateRecoveryDays(10.0), 5);
      });

      test('caps at 30 days', () {
        // Very high load with tiny threshold will never recover in 30 iterations
        expect(useCase.estimateRecoveryDays(1e12, threshold: 0.0001), 30);
      });
    });
  });
}

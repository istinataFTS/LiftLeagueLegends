import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/exceptions.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/data/datasources/local/muscle_stimulus_local_datasource.dart';
import 'package:fitness_tracker/data/models/muscle_stimulus_model.dart';
import 'package:fitness_tracker/data/repositories/muscle_stimulus_repository_impl.dart';
import 'package:fitness_tracker/domain/entities/muscle_stimulus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMuscleStimulusLocalDataSource extends Mock
    implements MuscleStimulusLocalDataSource {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _date = DateTime(2026, 4, 7);
const _userId = 'user-1';

final _stimulusModel = MuscleStimulusModel(
  id: 'stim-1',
  ownerUserId: _userId,
  muscleGroup: 'chest',
  date: _date,
  dailyStimulus: 5.0,
  rollingWeeklyLoad: 10.0,
  createdAt: _date,
  updatedAt: _date,
);

final _stimulusEntity = MuscleStimulus(
  id: 'stim-1',
  ownerUserId: _userId,
  muscleGroup: 'chest',
  date: _date,
  dailyStimulus: 5.0,
  rollingWeeklyLoad: 10.0,
  createdAt: _date,
  updatedAt: _date,
);

const _dbException = CacheDatabaseException('db error');

void main() {
  late MockMuscleStimulusLocalDataSource mockDataSource;
  late MuscleStimulusRepositoryImpl repository;

  setUpAll(() {
    registerFallbackValue(_stimulusModel);
    registerFallbackValue(_stimulusEntity);
  });

  setUp(() {
    mockDataSource = MockMuscleStimulusLocalDataSource();
    repository = MuscleStimulusRepositoryImpl(localDataSource: mockDataSource);
  });

  group('MuscleStimulusRepositoryImpl', () {
    group('getStimulusByMuscleAndDate', () {
      test('returns model from datasource on success', () async {
        when(
          () => mockDataSource.getStimulusByMuscleAndDate(
            muscleGroup: 'chest',
            date: _date,
          ),
        ).thenAnswer((_) async => _stimulusModel);

        final result = await repository.getStimulusByMuscleAndDate(
          userId: _userId,
          muscleGroup: 'chest',
          date: _date,
        );

        expect(result.isRight(), isTrue);
        expect((result as Right).value, _stimulusModel);
      });

      test('returns null from datasource when no record exists', () async {
        when(
          () => mockDataSource.getStimulusByMuscleAndDate(
            muscleGroup: 'chest',
            date: _date,
          ),
        ).thenAnswer((_) async => null);

        final result = await repository.getStimulusByMuscleAndDate(
          userId: _userId,
          muscleGroup: 'chest',
          date: _date,
        );

        expect(result.isRight(), isTrue);
        expect((result as Right).value, isNull);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.getStimulusByMuscleAndDate(
            muscleGroup: 'chest',
            date: _date,
          ),
        ).thenThrow(_dbException);

        final result = await repository.getStimulusByMuscleAndDate(
          userId: _userId,
          muscleGroup: 'chest',
          date: _date,
        );

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('getStimulusByDateRange', () {
      final startDate = DateTime(2026, 4, 1);
      final endDate = DateTime(2026, 4, 7);

      test('returns list from datasource on success', () async {
        when(
          () => mockDataSource.getStimulusByDateRange(
            muscleGroup: 'chest',
            startDate: startDate,
            endDate: endDate,
          ),
        ).thenAnswer((_) async => [_stimulusModel]);

        final result = await repository.getStimulusByDateRange(
          userId: _userId,
          muscleGroup: 'chest',
          startDate: startDate,
          endDate: endDate,
        );

        expect(result.isRight(), isTrue);
        expect((result as Right).value, [_stimulusModel]);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.getStimulusByDateRange(
            muscleGroup: 'chest',
            startDate: startDate,
            endDate: endDate,
          ),
        ).thenThrow(_dbException);

        final result = await repository.getStimulusByDateRange(
          userId: _userId,
          muscleGroup: 'chest',
          startDate: startDate,
          endDate: endDate,
        );

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('getTodayStimulus', () {
      test('returns model from datasource on success', () async {
        when(
          () => mockDataSource.getTodayStimulus('chest'),
        ).thenAnswer((_) async => _stimulusModel);

        final result = await repository.getTodayStimulus(_userId, 'chest');

        expect(result.isRight(), isTrue);
        expect((result as Right).value, _stimulusModel);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.getTodayStimulus('chest'),
        ).thenThrow(_dbException);

        final result = await repository.getTodayStimulus(_userId, 'chest');

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('getAllStimulusForDate', () {
      test('returns list from datasource on success', () async {
        when(
          () => mockDataSource.getAllStimulusForDate(_date),
        ).thenAnswer((_) async => [_stimulusModel]);

        final result = await repository.getAllStimulusForDate(_userId, _date);

        expect(result.isRight(), isTrue);
        expect((result as Right).value, [_stimulusModel]);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.getAllStimulusForDate(_date),
        ).thenThrow(_dbException);

        final result = await repository.getAllStimulusForDate(_userId, _date);

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('upsertStimulus', () {
      test('converts entity to model and delegates to datasource', () async {
        when(
          () => mockDataSource.upsertStimulus(any()),
        ).thenAnswer((_) async {});

        final result = await repository.upsertStimulus(_stimulusEntity);

        expect(result.isRight(), isTrue);
        final captured =
            verify(
                  () => mockDataSource.upsertStimulus(captureAny()),
                ).captured.single
                as MuscleStimulusModel;
        expect(captured.id, _stimulusEntity.id);
        expect(captured.ownerUserId, _stimulusEntity.ownerUserId);
        expect(captured.muscleGroup, _stimulusEntity.muscleGroup);
        expect(captured.dailyStimulus, _stimulusEntity.dailyStimulus);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.upsertStimulus(any()),
        ).thenThrow(_dbException);

        final result = await repository.upsertStimulus(_stimulusEntity);

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('updateStimulusValues', () {
      test('delegates to datasource on success', () async {
        when(
          () => mockDataSource.updateStimulusValues(
            id: 'stim-1',
            dailyStimulus: 6.0,
            rollingWeeklyLoad: 12.0,
            lastSetTimestamp: 1000,
            lastSetStimulus: 2.0,
          ),
        ).thenAnswer((_) async {});

        final result = await repository.updateStimulusValues(
          id: 'stim-1',
          dailyStimulus: 6.0,
          rollingWeeklyLoad: 12.0,
          lastSetTimestamp: 1000,
          lastSetStimulus: 2.0,
        );

        expect(result.isRight(), isTrue);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.updateStimulusValues(
            id: 'stim-1',
            dailyStimulus: 6.0,
            rollingWeeklyLoad: 12.0,
          ),
        ).thenThrow(_dbException);

        final result = await repository.updateStimulusValues(
          id: 'stim-1',
          dailyStimulus: 6.0,
          rollingWeeklyLoad: 12.0,
        );

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('applyDailyDecayToAll', () {
      test('delegates to datasource on success', () async {
        when(
          () => mockDataSource.applyDailyDecayToAll(),
        ).thenAnswer((_) async {});

        final result = await repository.applyDailyDecayToAll(_userId);

        expect(result.isRight(), isTrue);
        verify(() => mockDataSource.applyDailyDecayToAll()).called(1);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.applyDailyDecayToAll(),
        ).thenThrow(_dbException);

        final result = await repository.applyDailyDecayToAll(_userId);

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('getMaxStimulusForMuscle', () {
      test('returns value from datasource on success', () async {
        when(
          () => mockDataSource.getMaxStimulusForMuscle('chest'),
        ).thenAnswer((_) async => 15.0);

        final result = await repository.getMaxStimulusForMuscle(
          _userId,
          'chest',
        );

        expect(result.isRight(), isTrue);
        expect((result as Right).value, 15.0);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.getMaxStimulusForMuscle('chest'),
        ).thenThrow(_dbException);

        final result = await repository.getMaxStimulusForMuscle(
          _userId,
          'chest',
        );

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('deleteOlderThan', () {
      test('delegates to datasource on success', () async {
        when(
          () => mockDataSource.deleteOlderThan(_date),
        ).thenAnswer((_) async {});

        final result = await repository.deleteOlderThan(_userId, _date);

        expect(result.isRight(), isTrue);
        verify(() => mockDataSource.deleteOlderThan(_date)).called(1);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.deleteOlderThan(_date),
        ).thenThrow(_dbException);

        final result = await repository.deleteOlderThan(_userId, _date);

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('clearAllStimulus', () {
      test('delegates to datasource on success', () async {
        when(() => mockDataSource.clearAllStimulus()).thenAnswer((_) async {});

        final result = await repository.clearAllStimulus();

        expect(result.isRight(), isTrue);
        verify(() => mockDataSource.clearAllStimulus()).called(1);
      });

      test('returns DatabaseFailure on exception', () async {
        when(() => mockDataSource.clearAllStimulus()).thenThrow(_dbException);

        final result = await repository.clearAllStimulus();

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });

    group('clearStimulusForUser', () {
      test('delegates to datasource on success', () async {
        when(
          () => mockDataSource.clearStimulusForUser(_userId),
        ).thenAnswer((_) async {});

        final result = await repository.clearStimulusForUser(_userId);

        expect(result.isRight(), isTrue);
        verify(() => mockDataSource.clearStimulusForUser(_userId)).called(1);
      });

      test('returns DatabaseFailure on exception', () async {
        when(
          () => mockDataSource.clearStimulusForUser(_userId),
        ).thenThrow(_dbException);

        final result = await repository.clearStimulusForUser(_userId);

        expect(result.isLeft(), isTrue);
        expect((result as Left).value, isA<DatabaseFailure>());
      });
    });
  });
}

import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/muscle_stimulus.dart';
import 'package:fitness_tracker/domain/repositories/muscle_factor_repository.dart';
import 'package:fitness_tracker/domain/repositories/muscle_stimulus_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/calculate_muscle_stimulus.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/record_workout_set.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMuscleFactorRepository extends Mock
    implements MuscleFactorRepository {}

class MockMuscleStimulusRepository extends Mock
    implements MuscleStimulusRepository {}

class MockCalculateMuscleStimulus extends Mock
    implements CalculateMuscleStimulus {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const String _testUserId = 'user-1';
final _testDate = DateTime(2026, 4, 6);

MuscleStimulus _makeStimulusRecord({
  String id = 'stim-1',
  String muscleGroup = 'chest',
  double dailyStimulus = 1.0,
  double rollingWeeklyLoad = 5.0,
}) {
  return MuscleStimulus(
    id: id,
    ownerUserId: _testUserId,
    muscleGroup: muscleGroup,
    date: _testDate,
    dailyStimulus: dailyStimulus,
    rollingWeeklyLoad: rollingWeeklyLoad,
    createdAt: _testDate,
    updatedAt: _testDate,
  );
}

const _calcFailure = ValidationFailure('invalid input');

void main() {
  late MockMuscleFactorRepository mockFactorRepo;
  late MockMuscleStimulusRepository mockStimulusRepo;
  late MockCalculateMuscleStimulus mockCalculate;
  late RecordWorkoutSet useCase;

  setUpAll(() {
    registerFallbackValue(_makeStimulusRecord());
  });

  setUp(() {
    mockFactorRepo = MockMuscleFactorRepository();
    mockStimulusRepo = MockMuscleStimulusRepository();
    mockCalculate = MockCalculateMuscleStimulus();
    useCase = RecordWorkoutSet(
      muscleFactorRepository: mockFactorRepo,
      muscleStimulusRepository: mockStimulusRepo,
      calculateMuscleStimulus: mockCalculate,
    );
  });

  group('RecordWorkoutSet', () {
    group('call', () {
      test('propagates failure when stimulus calculation fails', () async {
        when(
          () => mockCalculate.calculateForSet(
            exerciseId: 'ex-1',
            sets: 1,
            intensity: 3,
          ),
        ).thenAnswer((_) async => const Left(_calcFailure));

        final result = await useCase(
          userId: _testUserId,
          exerciseId: 'ex-1',
          sets: 1,
          intensity: 3,
          timestamp: _testDate,
        );

        expect(result, const Left(_calcFailure));
        verifyNever(() => mockStimulusRepo.upsertStimulus(any()));
      });

      test('returns empty list when exercise has no muscle factors', () async {
        when(
          () => mockCalculate.calculateForSet(
            exerciseId: 'ex-1',
            sets: 1,
            intensity: 3,
          ),
        ).thenAnswer((_) async => const Right(<String, double>{}));

        final result = await useCase(
          userId: _testUserId,
          exerciseId: 'ex-1',
          sets: 1,
          intensity: 3,
          timestamp: _testDate,
        );

        expect(result, const Right(<String>[]));
        verifyNever(() => mockStimulusRepo.upsertStimulus(any()));
      });

      test(
        'creates new record and returns affected muscles when none exist',
        () async {
          when(
            () => mockCalculate.calculateForSet(
              exerciseId: 'ex-1',
              sets: 1,
              intensity: 5,
            ),
          ).thenAnswer(
            (_) async => const Right(<String, double>{'chest': 1.0}),
          );

          // No existing record for today
          when(
            () => mockStimulusRepo.getStimulusByMuscleAndDate(
              userId: _testUserId,
              muscleGroup: any(named: 'muscleGroup'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => const Right(null));

          // No past records in date range
          when(
            () => mockStimulusRepo.getStimulusByDateRange(
              userId: _testUserId,
              muscleGroup: any(named: 'muscleGroup'),
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          ).thenAnswer((_) async => const Right([]));

          when(
            () => mockStimulusRepo.upsertStimulus(any()),
          ).thenAnswer((_) async => const Right(null));

          final result = await useCase(
            userId: _testUserId,
            exerciseId: 'ex-1',
            sets: 1,
            intensity: 5,
            timestamp: _testDate,
          );

          expect(result.isRight(), isTrue);
          final muscles = (result as Right).value as List<String>;
          expect(muscles, contains('chest'));
          verify(() => mockStimulusRepo.upsertStimulus(any())).called(1);
        },
      );

      test(
        'new record date matches the set timestamp, not the current time',
        () async {
          // Simulates back-filling a historical set from the History page.
          // If the impl used DateTime.now() the captured date would be today
          // instead of the set's actual date.
          final historicalDate = DateTime(2025, 1, 15);
          MuscleStimulus? capturedStimulus;

          when(
            () => mockCalculate.calculateForSet(
              exerciseId: 'ex-1',
              sets: 1,
              intensity: 5,
            ),
          ).thenAnswer(
            (_) async => const Right(<String, double>{'chest': 1.0}),
          );

          when(
            () => mockStimulusRepo.getStimulusByMuscleAndDate(
              userId: _testUserId,
              muscleGroup: any(named: 'muscleGroup'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => const Right(null));

          when(
            () => mockStimulusRepo.getStimulusByDateRange(
              userId: _testUserId,
              muscleGroup: any(named: 'muscleGroup'),
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate'),
            ),
          ).thenAnswer((_) async => const Right([]));

          when(() => mockStimulusRepo.upsertStimulus(any())).thenAnswer((
            inv,
          ) async {
            capturedStimulus = inv.positionalArguments.first as MuscleStimulus;
            return const Right(null);
          });

          await useCase(
            userId: _testUserId,
            exerciseId: 'ex-1',
            sets: 1,
            intensity: 5,
            timestamp: historicalDate,
          );

          expect(capturedStimulus?.date, DateTime(2025, 1, 15));
        },
      );

      test('new record is stamped with the provided userId', () async {
        MuscleStimulus? capturedStimulus;

        when(
          () => mockCalculate.calculateForSet(
            exerciseId: 'ex-1',
            sets: 1,
            intensity: 5,
          ),
        ).thenAnswer((_) async => const Right(<String, double>{'chest': 1.0}));

        when(
          () => mockStimulusRepo.getStimulusByMuscleAndDate(
            userId: _testUserId,
            muscleGroup: any(named: 'muscleGroup'),
            date: any(named: 'date'),
          ),
        ).thenAnswer((_) async => const Right(null));

        when(
          () => mockStimulusRepo.getStimulusByDateRange(
            userId: _testUserId,
            muscleGroup: any(named: 'muscleGroup'),
            startDate: any(named: 'startDate'),
            endDate: any(named: 'endDate'),
          ),
        ).thenAnswer((_) async => const Right([]));

        when(() => mockStimulusRepo.upsertStimulus(any())).thenAnswer((
          inv,
        ) async {
          capturedStimulus = inv.positionalArguments.first as MuscleStimulus;
          return const Right(null);
        });

        await useCase(
          userId: _testUserId,
          exerciseId: 'ex-1',
          sets: 1,
          intensity: 5,
          timestamp: _testDate,
        );

        expect(capturedStimulus?.ownerUserId, _testUserId);
      });

      test(
        'updates existing record when stimulus for today already exists',
        () async {
          final existing = _makeStimulusRecord(
            dailyStimulus: 2.0,
            rollingWeeklyLoad: 5.0,
          );

          when(
            () => mockCalculate.calculateForSet(
              exerciseId: 'ex-1',
              sets: 1,
              intensity: 5,
            ),
          ).thenAnswer(
            (_) async => const Right(<String, double>{'chest': 1.0}),
          );

          // Existing record found for today
          when(
            () => mockStimulusRepo.getStimulusByMuscleAndDate(
              userId: _testUserId,
              muscleGroup: any(named: 'muscleGroup'),
              date: any(named: 'date'),
            ),
          ).thenAnswer((_) async => Right(existing));

          when(
            () => mockStimulusRepo.updateStimulusValues(
              id: any(named: 'id'),
              dailyStimulus: any(named: 'dailyStimulus'),
              rollingWeeklyLoad: any(named: 'rollingWeeklyLoad'),
              lastSetTimestamp: any(named: 'lastSetTimestamp'),
              lastSetStimulus: any(named: 'lastSetStimulus'),
            ),
          ).thenAnswer((_) async => const Right(null));

          final result = await useCase(
            userId: _testUserId,
            exerciseId: 'ex-1',
            sets: 1,
            intensity: 5,
            timestamp: _testDate,
          );

          expect(result.isRight(), isTrue);
          verify(
            () => mockStimulusRepo.updateStimulusValues(
              id: any(named: 'id'),
              dailyStimulus: any(named: 'dailyStimulus'),
              rollingWeeklyLoad: any(named: 'rollingWeeklyLoad'),
              lastSetTimestamp: any(named: 'lastSetTimestamp'),
              lastSetStimulus: any(named: 'lastSetStimulus'),
            ),
          ).called(1);
          verifyNever(() => mockStimulusRepo.upsertStimulus(any()));
        },
      );
    });

    group('validateInputs', () {
      test('delegates to calculateMuscleStimulus.validateInputs', () {
        when(
          () => mockCalculate.validateInputs(
            exerciseId: 'ex-1',
            sets: 1,
            intensity: 3,
          ),
        ).thenReturn(true);

        final result = useCase.validateInputs(
          exerciseId: 'ex-1',
          sets: 1,
          intensity: 3,
        );

        expect(result, isTrue);
        verify(
          () => mockCalculate.validateInputs(
            exerciseId: 'ex-1',
            sets: 1,
            intensity: 3,
          ),
        ).called(1);
      });
    });
  });
}

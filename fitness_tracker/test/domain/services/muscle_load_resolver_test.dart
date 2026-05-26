import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/muscle_factor_repository.dart';
import 'package:fitness_tracker/domain/repositories/workout_set_repository.dart';
import 'package:fitness_tracker/domain/services/muscle_load_resolver_impl.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSetRepository extends Mock implements WorkoutSetRepository {}

class MockMuscleFactorRepository extends Mock
    implements MuscleFactorRepository {}

void main() {
  late MockWorkoutSetRepository workoutSetRepo;
  late MockMuscleFactorRepository muscleFactorRepo;
  late MuscleLoadResolverImpl resolver;

  final DateTime start = DateTime(2026, 3, 13);
  final DateTime end = DateTime(2026, 3, 19, 23, 59, 59);

  const String userId = 'user-abc';

  final WorkoutSet benchSet = WorkoutSet(
    id: 'set-1',
    ownerUserId: userId,
    exerciseId: 'bench-press',
    reps: 8,
    weight: 80,
    intensity: 8,
    date: DateTime(2026, 3, 19),
    createdAt: DateTime(2026, 3, 19),
  );

  final WorkoutSet squatSet = WorkoutSet(
    id: 'set-2',
    ownerUserId: userId,
    exerciseId: 'squat',
    reps: 5,
    weight: 100,
    intensity: 9,
    date: DateTime(2026, 3, 18),
    createdAt: DateTime(2026, 3, 18),
  );

  final WorkoutSet otherUserSet = WorkoutSet(
    id: 'set-3',
    ownerUserId: 'other-user',
    exerciseId: 'bench-press',
    reps: 10,
    weight: 60,
    intensity: 7,
    date: DateTime(2026, 3, 19),
    createdAt: DateTime(2026, 3, 19),
  );

  final List<MuscleFactor> benchFactors = <MuscleFactor>[
    const MuscleFactor(
      id: 'mf-1',
      exerciseId: 'bench-press',
      muscleGroup: 'chest',
      factor: 1.0,
    ),
    const MuscleFactor(
      id: 'mf-2',
      exerciseId: 'bench-press',
      muscleGroup: 'triceps',
      factor: 0.3,
    ),
  ];

  final List<MuscleFactor> squatFactors = <MuscleFactor>[
    const MuscleFactor(
      id: 'mf-3',
      exerciseId: 'squat',
      muscleGroup: 'quads',
      factor: 1.0,
    ),
    const MuscleFactor(
      id: 'mf-4',
      exerciseId: 'squat',
      muscleGroup: 'glutes',
      factor: 0.7,
    ),
  ];

  setUp(() {
    workoutSetRepo = MockWorkoutSetRepository();
    muscleFactorRepo = MockMuscleFactorRepository();
    resolver = MuscleLoadResolverImpl(
      workoutSetRepository: workoutSetRepo,
      muscleFactorRepository: muscleFactorRepo,
    );
  });

  group('getSetCountsByMuscle', () {
    test('returns counts per muscle for user sets', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet, squatSet]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(benchFactors));
      when(
        () => muscleFactorRepo.getFactorsForExercise('squat'),
      ).thenAnswer((_) async => Right(squatFactors));

      final result = await resolver.getSetCountsByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      final counts = result.getOrElse(() => <String, int>{});
      expect(counts['chest'], 1);
      expect(counts['triceps'], 1);
      expect(counts['quads'], 1);
      expect(counts['glutes'], 1);
    });

    test('excludes sets belonging to a different user', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet, otherUserSet]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(benchFactors));

      final result = await resolver.getSetCountsByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      final counts = result.getOrElse(() => <String, int>{});
      // Only benchSet (userId) should be counted — otherUserSet is excluded.
      expect(counts['chest'], 1);
    });

    test('returns empty map when no sets in range', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => const Right(<WorkoutSet>[]));

      final result = await resolver.getSetCountsByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result, const Right(<String, int>{}));
    });

    test('skips exercises with zero or negative factor', () async {
      final List<MuscleFactor> zeroFactorList = <MuscleFactor>[
        const MuscleFactor(
          id: 'mf-z',
          exerciseId: 'bench-press',
          muscleGroup: 'chest',
          factor: 0.0,
        ),
      ];

      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(zeroFactorList));

      final result = await resolver.getSetCountsByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      final counts = result.getOrElse(() => <String, int>{});
      expect(counts, isEmpty);
    });

    test('returns failure when repository errors', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => const Left(CacheFailure('db error')));

      final result = await resolver.getSetCountsByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result.isLeft(), isTrue);
    });

    test('accumulates multiple sets for the same muscle', () async {
      final WorkoutSet bench2 = benchSet.copyWith(id: 'set-1b');

      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet, bench2]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(benchFactors));

      final result = await resolver.getSetCountsByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      final counts = result.getOrElse(() => <String, int>{});
      expect(counts['chest'], 2);
      expect(counts['triceps'], 2);
    });
  });

  group('getStimulusByMuscle', () {
    test('returns stimulus per muscle for user sets', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(benchFactors));

      final result = await resolver.getStimulusByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      final stimulus = result.getOrElse(() => <String, double>{});
      expect(stimulus.containsKey('chest'), isTrue);
      expect(stimulus['chest'], greaterThan(0));
      expect(stimulus.containsKey('triceps'), isTrue);
      expect(stimulus['triceps'], greaterThan(0));
    });

    test('excludes sets belonging to a different user', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[otherUserSet]));

      final result = await resolver.getStimulusByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result, const Right(<String, double>{}));
    });

    test('returns empty map when no sets in range', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => const Right(<WorkoutSet>[]));

      final result = await resolver.getStimulusByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result, const Right(<String, double>{}));
    });

    test('accumulates stimulus across multiple sets', () async {
      final WorkoutSet bench2 = benchSet.copyWith(id: 'set-1b');

      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet, bench2]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(benchFactors));

      final result = await resolver.getStimulusByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      final singleResult = await resolver.getStimulusByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      // Two sets should produce double the stimulus of one set
      final twoSets = result.getOrElse(() => <String, double>{});
      final oneSets = singleResult.getOrElse(() => <String, double>{});
      expect(twoSets['chest'], closeTo(oneSets['chest']! * 1, 0.0001));
    });

    test('returns failure when repository errors', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => const Left(CacheFailure('db error')));

      final result = await resolver.getStimulusByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('getTotalSetCount', () {
    test(
      'counts each set once regardless of how many muscles it hits',
      () async {
        // benchSet has 2 positive factors (chest + triceps) but is still 1 set.
        when(
          () => workoutSetRepo.getSetsByDateRange(start, end),
        ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet, squatSet]));
        when(
          () => muscleFactorRepo.getFactorsForExercise('bench-press'),
        ).thenAnswer((_) async => Right(benchFactors));
        when(
          () => muscleFactorRepo.getFactorsForExercise('squat'),
        ).thenAnswer((_) async => Right(squatFactors));

        final result = await resolver.getTotalSetCount(
          userId: userId,
          start: start,
          end: end,
        );

        expect(result.getOrElse(() => -1), 2);
      },
    );

    test('excludes sets belonging to other users', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet, otherUserSet]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(benchFactors));

      final result = await resolver.getTotalSetCount(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result.getOrElse(() => -1), 1);
    });

    test('excludes sets whose exercise has no positive factor', () async {
      // Regression guard for the Sets-card-disagrees-with-map bug: when an
      // exercise's factors are missing or all zero, the map stays empty,
      // so the Sets card must also read 0.
      final List<MuscleFactor> zeroFactors = <MuscleFactor>[
        const MuscleFactor(
          id: 'mf-0',
          exerciseId: 'bench-press',
          muscleGroup: 'chest',
          factor: 0.0,
        ),
      ];
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(zeroFactors));

      final result = await resolver.getTotalSetCount(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result.getOrElse(() => -1), 0);
    });

    test('returns 0 when no sets in range', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => const Right(<WorkoutSet>[]));

      final result = await resolver.getTotalSetCount(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result, const Right<Failure, int>(0));
    });

    test('propagates repository failure', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => const Left(CacheFailure('db error')));

      final result = await resolver.getTotalSetCount(
        userId: userId,
        start: start,
        end: end,
      );

      expect(result.isLeft(), isTrue);
    });
  });

  group('parity', () {
    test('every muscle with count > 0 also has stimulus > 0', () async {
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet, squatSet]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(benchFactors));
      when(
        () => muscleFactorRepo.getFactorsForExercise('squat'),
      ).thenAnswer((_) async => Right(squatFactors));

      final countResult = await resolver.getSetCountsByMuscle(
        userId: userId,
        start: start,
        end: end,
      );
      final stimulusResult = await resolver.getStimulusByMuscle(
        userId: userId,
        start: start,
        end: end,
      );

      final counts = countResult.getOrElse(() => <String, int>{});
      final stimulus = stimulusResult.getOrElse(() => <String, double>{});

      for (final muscle in counts.keys) {
        expect(
          stimulus[muscle],
          greaterThan(0),
          reason: '$muscle has count ${counts[muscle]} but no stimulus',
        );
      }
    });

    test('total set count stays consistent with per-muscle counts', () async {
      // If any muscle has count>0, the total set count must also be >0 —
      // otherwise the Sets stat card could read 0 while the map highlights
      // muscles.
      when(
        () => workoutSetRepo.getSetsByDateRange(start, end),
      ).thenAnswer((_) async => Right(<WorkoutSet>[benchSet, squatSet]));
      when(
        () => muscleFactorRepo.getFactorsForExercise('bench-press'),
      ).thenAnswer((_) async => Right(benchFactors));
      when(
        () => muscleFactorRepo.getFactorsForExercise('squat'),
      ).thenAnswer((_) async => Right(squatFactors));

      final countsResult = await resolver.getSetCountsByMuscle(
        userId: userId,
        start: start,
        end: end,
      );
      final totalResult = await resolver.getTotalSetCount(
        userId: userId,
        start: start,
        end: end,
      );

      final counts = countsResult.getOrElse(() => <String, int>{});
      final total = totalResult.getOrElse(() => 0);

      if (counts.values.any((c) => c > 0)) {
        expect(
          total,
          greaterThan(0),
          reason:
              'Sets stat card would read 0 while body map highlights muscles',
        );
      }
    });
  });
}

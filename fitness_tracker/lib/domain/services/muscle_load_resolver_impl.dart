import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../core/logging/app_logger.dart';
import '../entities/muscle_factor.dart';
import '../entities/stimulus_calculation_rules.dart';
import '../repositories/muscle_factor_repository.dart';
import '../repositories/workout_set_repository.dart';
import 'muscle_load_resolver.dart';

class MuscleLoadResolverImpl implements MuscleLoadResolver {
  const MuscleLoadResolverImpl({
    required this.workoutSetRepository,
    required this.muscleFactorRepository,
  });

  final WorkoutSetRepository workoutSetRepository;
  final MuscleFactorRepository muscleFactorRepository;

  @override
  Future<Either<Failure, Map<String, double>>> getStimulusByMuscle({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final setsResult = await workoutSetRepository.getSetsByDateRange(
        start,
        end,
      );
      return await setsResult.fold((f) async => Left(f), (allSets) async {
        final userSets = allSets.where((s) => s.ownerUserId == userId).toList();
        if (userSets.isEmpty) return const Right({});

        final factorCache = await _loadFactors(
          userSets.map((s) => s.exerciseId).toSet(),
        );

        final stimulus = <String, double>{};
        for (final set in userSets) {
          final factors = factorCache[set.exerciseId];
          if (factors == null || factors.isEmpty) continue;
          for (final factor in factors) {
            if (factor.factor <= 0) continue;
            final value = StimulusCalculationRules.calculateSetStimulus(
              sets: 1,
              intensity: set.intensity,
              exerciseFactor: factor.factor,
            );
            stimulus[factor.muscleGroup] =
                (stimulus[factor.muscleGroup] ?? 0.0) + value;
          }
        }
        return Right(stimulus);
      });
    } catch (e) {
      AppLogger.error(
        'MuscleLoadResolver.getStimulusByMuscle failed: $e',
        category: 'resolver',
      );
      return Left(UnexpectedFailure('getStimulusByMuscle failed: $e'));
    }
  }

  @override
  Future<Either<Failure, Map<String, int>>> getSetCountsByMuscle({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final setsResult = await workoutSetRepository.getSetsByDateRange(
        start,
        end,
      );
      return await setsResult.fold((f) async => Left(f), (allSets) async {
        final userSets = allSets.where((s) => s.ownerUserId == userId).toList();
        if (userSets.isEmpty) return const Right({});

        final factorCache = await _loadFactors(
          userSets.map((s) => s.exerciseId).toSet(),
        );

        final counts = <String, int>{};
        for (final set in userSets) {
          final factors = factorCache[set.exerciseId];
          if (factors == null || factors.isEmpty) continue;
          for (final factor in factors) {
            if (factor.factor <= 0) continue;
            counts[factor.muscleGroup] = (counts[factor.muscleGroup] ?? 0) + 1;
          }
        }
        return Right(counts);
      });
    } catch (e) {
      AppLogger.error(
        'MuscleLoadResolver.getSetCountsByMuscle failed: $e',
        category: 'resolver',
      );
      return Left(UnexpectedFailure('getSetCountsByMuscle failed: $e'));
    }
  }

  @override
  Future<Either<Failure, int>> getTotalSetCount({
    required String userId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final setsResult = await workoutSetRepository.getSetsByDateRange(
        start,
        end,
      );
      return await setsResult.fold((f) async => Left(f), (allSets) async {
        final userSets = allSets.where((s) => s.ownerUserId == userId).toList();
        if (userSets.isEmpty) return const Right(0);

        final factorCache = await _loadFactors(
          userSets.map((s) => s.exerciseId).toSet(),
        );

        // A set counts once if it has at least one positive factor — we
        // count sets, not muscle-mappings, so multi-muscle exercises do
        // not inflate the total.
        var count = 0;
        for (final set in userSets) {
          final factors = factorCache[set.exerciseId];
          if (factors == null || factors.isEmpty) continue;
          if (factors.any((f) => f.factor > 0)) count++;
        }
        return Right(count);
      });
    } catch (e) {
      AppLogger.error(
        'MuscleLoadResolver.getTotalSetCount failed: $e',
        category: 'resolver',
      );
      return Left(UnexpectedFailure('getTotalSetCount failed: $e'));
    }
  }

  /// Loads factors for every exercise in [exerciseIds] in parallel.
  ///
  /// All per-exercise queries are dispatched concurrently via [Future.wait],
  /// reducing total latency from O(N × query_time) to O(1 × query_time).
  /// Exercises that return an error or have no factors are stored as an empty
  /// list so callers skip them safely without aborting the whole resolution.
  Future<Map<String, List<MuscleFactor>>> _loadFactors(
    Set<String> exerciseIds,
  ) async {
    final entries = await Future.wait(
      exerciseIds.map((id) async {
        final result = await muscleFactorRepository.getFactorsForExercise(id);
        return MapEntry(
          id,
          result.fold((_) => const <MuscleFactor>[], (factors) => factors),
        );
      }),
    );
    return Map.fromEntries(entries);
  }
}

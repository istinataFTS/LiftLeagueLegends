import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../entities/muscle_factor.dart';

abstract class MuscleFactorRepository {
  Future<Either<Failure, MuscleFactor?>> getFactorById(String id);

  Future<Either<Failure, List<MuscleFactor>>> getAllFactors();

  Future<Either<Failure, List<MuscleFactor>>> getFactorsForExercise(
    String exerciseId,
  );

  Future<Either<Failure, List<MuscleFactor>>> getFactorsByMuscleGroup(
    String muscleGroup,
  );

  Future<Either<Failure, void>> addMuscleFactor(MuscleFactor factor);

  Future<Either<Failure, void>> addMuscleFactorsBatch(
    List<MuscleFactor> factors,
  );

  Future<Either<Failure, void>> updateMuscleFactor(MuscleFactor factor);

  Future<Either<Failure, void>> deleteMuscleFactor(String id);

  Future<Either<Failure, void>> deleteMuscleFactorsByExerciseId(
    String exerciseId,
  );

  Future<Either<Failure, void>> clearAllFactors();
}

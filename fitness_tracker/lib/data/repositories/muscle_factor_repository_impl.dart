import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../core/errors/repository_guard.dart';
import '../../domain/entities/muscle_factor.dart';
import '../../domain/repositories/muscle_factor_repository.dart';
import '../datasources/local/muscle_factor_local_datasource.dart';
import '../models/muscle_factor_model.dart';

/// Implementation of [MuscleFactorRepository].
///
/// Keeps failure mapping centralized and avoids parsing raw DB rows here.
class MuscleFactorRepositoryImpl implements MuscleFactorRepository {
  final MuscleFactorLocalDataSource localDataSource;

  const MuscleFactorRepositoryImpl({required this.localDataSource});

  @override
  Future<Either<Failure, MuscleFactor?>> getFactorById(String id) {
    return RepositoryGuard.run(() async {
      return localDataSource.getFactorById(id);
    });
  }

  @override
  Future<Either<Failure, List<MuscleFactor>>> getAllFactors() {
    return RepositoryGuard.run(() async {
      return localDataSource.getAllFactors();
    });
  }

  @override
  Future<Either<Failure, List<MuscleFactor>>> getFactorsForExercise(
    String exerciseId,
  ) {
    return RepositoryGuard.run(() async {
      return localDataSource.getFactorsForExercise(exerciseId);
    });
  }

  @override
  Future<Either<Failure, List<MuscleFactor>>> getFactorsByMuscleGroup(
    String muscleGroup,
  ) {
    return RepositoryGuard.run(() async {
      final List<MuscleFactorModel> allFactors = await localDataSource
          .getAllFactors();

      return allFactors
          .where((MuscleFactor factor) => factor.muscleGroup == muscleGroup)
          .toList(growable: false);
    });
  }

  @override
  Future<Either<Failure, void>> addMuscleFactor(MuscleFactor factor) {
    return RepositoryGuard.run(() async {
      final MuscleFactorModel model = MuscleFactorModel.fromEntity(factor);
      await localDataSource.addFactor(model);
    });
  }

  @override
  Future<Either<Failure, void>> addMuscleFactorsBatch(
    List<MuscleFactor> factors,
  ) {
    return RepositoryGuard.run(() async {
      final List<MuscleFactorModel> models = factors
          .map(MuscleFactorModel.fromEntity)
          .toList(growable: false);

      await localDataSource.addFactorsBatch(models);
    });
  }

  @override
  Future<Either<Failure, void>> updateMuscleFactor(MuscleFactor factor) {
    return RepositoryGuard.run(() async {
      final MuscleFactorModel model = MuscleFactorModel.fromEntity(factor);
      await localDataSource.updateFactor(model);
    });
  }

  @override
  Future<Either<Failure, void>> deleteMuscleFactor(String id) {
    return RepositoryGuard.run(() async {
      await localDataSource.deleteFactor(id);
    });
  }

  @override
  Future<Either<Failure, void>> deleteMuscleFactorsByExerciseId(
    String exerciseId,
  ) {
    return RepositoryGuard.run(() async {
      await localDataSource.deleteFactorsByExerciseId(exerciseId);
    });
  }

  @override
  Future<Either<Failure, void>> clearAllFactors() {
    return RepositoryGuard.run(() async {
      await localDataSource.clearAllFactors();
    });
  }
}

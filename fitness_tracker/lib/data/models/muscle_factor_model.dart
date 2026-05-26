import '../../core/constants/database_tables.dart';
import '../../domain/entities/muscle_factor.dart';

/// Data model for MuscleFactor with database serialization
class MuscleFactorModel extends MuscleFactor {
  const MuscleFactorModel({
    required super.id,
    required super.exerciseId,
    required super.muscleGroup,
    required super.factor,
  });

  /// Create model from entity
  factory MuscleFactorModel.fromEntity(MuscleFactor muscleFactor) {
    return MuscleFactorModel(
      id: muscleFactor.id,
      exerciseId: muscleFactor.exerciseId,
      muscleGroup: muscleFactor.muscleGroup,
      factor: muscleFactor.factor,
    );
  }

  /// Create model from database map.
  ///
  /// Muscle-group strings are normalised to lowercase + trimmed at this
  /// boundary so that lookups against [MuscleStimulus.allMuscleGroups]
  /// work regardless of how the row was produced (seed, sync, legacy
  /// migration, …).  This is the single source of normalisation on the
  /// read path — callers and mappers must not re-normalise.
  factory MuscleFactorModel.fromMap(Map<String, dynamic> map) {
    return MuscleFactorModel(
      id: map[DatabaseTables.factorId] as String,
      exerciseId: map[DatabaseTables.factorExerciseId] as String,
      muscleGroup: _normaliseMuscleGroup(
        map[DatabaseTables.factorMuscleGroup] as String,
      ),
      factor: (map[DatabaseTables.factorValue] as num).toDouble(),
    );
  }

  /// Convert model to database map
  Map<String, dynamic> toMap() {
    return {
      DatabaseTables.factorId: id,
      DatabaseTables.factorExerciseId: exerciseId,
      DatabaseTables.factorMuscleGroup: muscleGroup,
      DatabaseTables.factorValue: factor,
    };
  }

  /// Create model from JSON (for API compatibility if needed).
  ///
  /// See [MuscleFactorModel.fromMap] — muscle-group strings are normalised
  /// to lowercase + trimmed at this boundary as well.
  factory MuscleFactorModel.fromJson(Map<String, dynamic> json) {
    return MuscleFactorModel(
      id: json['id'] as String,
      exerciseId: json['exerciseId'] as String,
      muscleGroup: _normaliseMuscleGroup(json['muscleGroup'] as String),
      factor: (json['factor'] as num).toDouble(),
    );
  }

  /// Lowercase + trim a muscle-group key.  Kept private to the model because
  /// every other layer should treat stored groups as already normalised.
  static String _normaliseMuscleGroup(String raw) => raw.trim().toLowerCase();

  /// Convert model to JSON (for API compatibility if needed)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'exerciseId': exerciseId,
      'muscleGroup': muscleGroup,
      'factor': factor,
    };
  }
}

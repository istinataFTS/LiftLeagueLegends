import 'package:equatable/equatable.dart';

class MuscleFactor extends Equatable {
  final String id;
  final String exerciseId;
  final String muscleGroup;

  /// Factor value indicating muscle engagement level
  /// Must be between 0.0 and 1.0
  /// Higher value = more muscle engagement
  final double factor;

  const MuscleFactor({
    required this.id,
    required this.exerciseId,
    required this.muscleGroup,
    required this.factor,
  }) : assert(
         factor >= 0.0 && factor <= 1.0,
         'Factor must be between 0.0 and 1.0',
       );

  /// Check if this is a primary muscle (factor >= 0.8)
  bool get isPrimaryMuscle => factor >= 0.8;

  /// Check if this is a secondary muscle (0.4 <= factor < 0.8)
  bool get isSecondaryMuscle => factor >= 0.4 && factor < 0.8;

  /// Check if this is a tertiary muscle (factor < 0.4)
  bool get isTertiaryMuscle => factor < 0.4;

  /// Get engagement level as string
  String get engagementLevel {
    if (isPrimaryMuscle) return 'Primary';
    if (isSecondaryMuscle) return 'Secondary';
    return 'Tertiary';
  }

  MuscleFactor copyWith({
    String? id,
    String? exerciseId,
    String? muscleGroup,
    double? factor,
  }) {
    return MuscleFactor(
      id: id ?? this.id,
      exerciseId: exerciseId ?? this.exerciseId,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      factor: factor ?? this.factor,
    );
  }

  @override
  List<Object?> get props => [id, exerciseId, muscleGroup, factor];
}

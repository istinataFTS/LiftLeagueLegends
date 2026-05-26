import 'package:equatable/equatable.dart';

class InitialCloudMigrationState extends Equatable {
  final String userId;
  final bool workoutSetsCompleted;
  final bool exercisesCompleted;
  final bool mealsCompleted;
  final bool nutritionLogsCompleted;
  final bool targetsCompleted;
  final DateTime startedAt;
  final DateTime updatedAt;
  final String? lastError;

  const InitialCloudMigrationState({
    required this.userId,
    required this.startedAt,
    required this.updatedAt,
    this.workoutSetsCompleted = false,
    this.exercisesCompleted = false,
    this.mealsCompleted = false,
    this.nutritionLogsCompleted = false,
    this.targetsCompleted = false,
    this.lastError,
  });

  bool get isCompleted =>
      workoutSetsCompleted &&
      exercisesCompleted &&
      mealsCompleted &&
      nutritionLogsCompleted &&
      targetsCompleted;

  InitialCloudMigrationState copyWith({
    String? userId,
    bool? workoutSetsCompleted,
    bool? exercisesCompleted,
    bool? mealsCompleted,
    bool? nutritionLogsCompleted,
    bool? targetsCompleted,
    DateTime? startedAt,
    DateTime? updatedAt,
    String? lastError,
    bool clearLastError = false,
  }) {
    return InitialCloudMigrationState(
      userId: userId ?? this.userId,
      workoutSetsCompleted: workoutSetsCompleted ?? this.workoutSetsCompleted,
      exercisesCompleted: exercisesCompleted ?? this.exercisesCompleted,
      mealsCompleted: mealsCompleted ?? this.mealsCompleted,
      nutritionLogsCompleted:
          nutritionLogsCompleted ?? this.nutritionLogsCompleted,
      targetsCompleted: targetsCompleted ?? this.targetsCompleted,
      startedAt: startedAt ?? this.startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'userId': userId,
      'workoutSetsCompleted': workoutSetsCompleted,
      'exercisesCompleted': exercisesCompleted,
      'mealsCompleted': mealsCompleted,
      'nutritionLogsCompleted': nutritionLogsCompleted,
      'targetsCompleted': targetsCompleted,
      'startedAt': startedAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastError': lastError,
    };
  }

  factory InitialCloudMigrationState.fromJson(Map<String, dynamic> json) {
    return InitialCloudMigrationState(
      userId: json['userId'] as String,
      workoutSetsCompleted: json['workoutSetsCompleted'] as bool? ?? false,
      exercisesCompleted: json['exercisesCompleted'] as bool? ?? false,
      mealsCompleted: json['mealsCompleted'] as bool? ?? false,
      nutritionLogsCompleted: json['nutritionLogsCompleted'] as bool? ?? false,
      targetsCompleted: json['targetsCompleted'] as bool? ?? false,
      startedAt: DateTime.parse(json['startedAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastError: json['lastError'] as String?,
    );
  }

  factory InitialCloudMigrationState.started(String userId) {
    final now = DateTime.now();
    return InitialCloudMigrationState(
      userId: userId,
      startedAt: now,
      updatedAt: now,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    userId,
    workoutSetsCompleted,
    exercisesCompleted,
    mealsCompleted,
    nutritionLogsCompleted,
    targetsCompleted,
    startedAt,
    updatedAt,
    lastError,
  ];
}

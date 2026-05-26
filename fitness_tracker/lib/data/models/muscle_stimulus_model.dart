import '../../core/constants/database_tables.dart';
import '../../domain/entities/muscle_stimulus.dart';

class MuscleStimulusModel extends MuscleStimulus {
  const MuscleStimulusModel({
    required super.id,
    required super.ownerUserId,
    required super.muscleGroup,
    required super.date,
    required super.dailyStimulus,
    required super.rollingWeeklyLoad,
    super.lastSetTimestamp,
    super.lastSetStimulus,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Create model from entity
  factory MuscleStimulusModel.fromEntity(MuscleStimulus stimulus) {
    return MuscleStimulusModel(
      id: stimulus.id,
      ownerUserId: stimulus.ownerUserId,
      muscleGroup: stimulus.muscleGroup,
      date: stimulus.date,
      dailyStimulus: stimulus.dailyStimulus,
      rollingWeeklyLoad: stimulus.rollingWeeklyLoad,
      lastSetTimestamp: stimulus.lastSetTimestamp,
      lastSetStimulus: stimulus.lastSetStimulus,
      createdAt: stimulus.createdAt,
      updatedAt: stimulus.updatedAt,
    );
  }

  factory MuscleStimulusModel.fromMap(Map<String, dynamic> map) {
    return MuscleStimulusModel(
      id: map[DatabaseTables.stimulusId] as String,
      ownerUserId: map[DatabaseTables.ownerUserId] as String? ?? '',
      muscleGroup: map[DatabaseTables.stimulusMuscleGroup] as String,
      date: DateTime.parse(map[DatabaseTables.stimulusDate] as String),
      dailyStimulus: (map[DatabaseTables.stimulusDailyStimulus] as num)
          .toDouble(),
      rollingWeeklyLoad: (map[DatabaseTables.stimulusRollingWeeklyLoad] as num)
          .toDouble(),
      lastSetTimestamp: map[DatabaseTables.stimulusLastSetTimestamp] as int?,
      lastSetStimulus: (map[DatabaseTables.stimulusLastSetStimulus] as num?)
          ?.toDouble(),
      createdAt: DateTime.parse(
        map[DatabaseTables.stimulusCreatedAt] as String,
      ),
      updatedAt: DateTime.parse(
        map[DatabaseTables.stimulusUpdatedAt] as String,
      ),
    );
  }

  /// Convert model to database map
  ///
  /// Stores date in YYYY-MM-DD format for efficient querying
  /// Stores timestamps as Unix milliseconds (INTEGER) for precise time tracking
  Map<String, dynamic> toMap() {
    return {
      DatabaseTables.stimulusId: id,
      DatabaseTables.ownerUserId: ownerUserId,
      DatabaseTables.stimulusMuscleGroup: muscleGroup,
      DatabaseTables.stimulusDate: formatDateForDb(date),
      DatabaseTables.stimulusDailyStimulus: dailyStimulus,
      DatabaseTables.stimulusRollingWeeklyLoad: rollingWeeklyLoad,
      DatabaseTables.stimulusLastSetTimestamp: lastSetTimestamp,
      DatabaseTables.stimulusLastSetStimulus: lastSetStimulus,
      DatabaseTables.stimulusCreatedAt: createdAt.toIso8601String(),
      DatabaseTables.stimulusUpdatedAt: updatedAt.toIso8601String(),
    };
  }

  /// Format date as YYYY-MM-DD for database storage.
  ///
  /// Public so that datasource classes can use it directly without
  /// duplicating the formatting logic.
  static String formatDateForDb(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Parse date from YYYY-MM-DD string
  /// Used when querying database by date
  static DateTime parseDateFromDb(String dateString) {
    return DateTime.parse(dateString);
  }

  /// Create model from JSON (for API compatibility)
  factory MuscleStimulusModel.fromJson(Map<String, dynamic> json) {
    return MuscleStimulusModel(
      id: json['id'] as String,
      ownerUserId: json['ownerUserId'] as String? ?? '',
      muscleGroup: json['muscleGroup'] as String,
      date: DateTime.parse(json['date'] as String),
      dailyStimulus: (json['dailyStimulus'] as num).toDouble(),
      rollingWeeklyLoad: (json['rollingWeeklyLoad'] as num).toDouble(),
      lastSetTimestamp: json['lastSetTimestamp'] as int?,
      lastSetStimulus: (json['lastSetStimulus'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Convert model to JSON (for API compatibility)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ownerUserId': ownerUserId,
      'muscleGroup': muscleGroup,
      'date': date.toIso8601String(),
      'dailyStimulus': dailyStimulus,
      'rollingWeeklyLoad': rollingWeeklyLoad,
      'lastSetTimestamp': lastSetTimestamp,
      'lastSetStimulus': lastSetStimulus,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}

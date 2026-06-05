import 'dart:math';
import 'package:equatable/equatable.dart';
import '../../core/constants/muscle_stimulus_constants.dart' as constants;

class MuscleStimulus extends Equatable {
  final String id;

  /// The authenticated user who owns this record.
  final String ownerUserId;

  final String muscleGroup;

  /// Date in YYYY-MM-DD format
  final DateTime date;

  /// Total stimulus accumulated for this muscle on this date
  /// Calculated as sum of all set stimuli for the day
  final double dailyStimulus;

  /// Rolling weekly load with exponential decay
  /// Formula: previousWeeklyLoad * 0.6 + dailyStimulus
  final double rollingWeeklyLoad;

  /// Unix timestamp (milliseconds) of the last set performed for this muscle
  /// Used for calculating real-time recovery decay
  final int? lastSetTimestamp;

  /// Stimulus value of the last set performed
  /// Used as starting point for decay calculation
  final double? lastSetStimulus;

  /// Per-day, per-muscle training volume (Σ weight×reps×factor) used by
  /// the Month/All-time relative-volume comparison. Carry-forward (gap) days
  /// and rows from before the v23 migration default to 0.0.
  final double dailyVolume;

  /// Running fatigue (0–100) as of [lastSetTimestamp]; the read layer applies
  /// recovery decay to "now". Carry-forward (gap) days store the at-last-set
  /// value unchanged. Rows from before the v24 migration default to 0.0.
  final double fatigueScore;

  /// Epoch-ms (local midnight) of the last day this muscle's [fatigueScore]
  /// was accumulated (a gain > 0 day). The fatigue read decays [fatigueScore]
  /// from this anchor — NOT from [lastSetTimestamp], which a later zero-gain
  /// (e.g. bodyweight) set can advance independently. null ⇒ never accumulated
  /// fatigue (rows from before v25 migration, or bodyweight-only history).
  final int? fatigueAnchorTimestamp;

  final DateTime createdAt;
  final DateTime updatedAt;

  const MuscleStimulus({
    required this.id,
    required this.ownerUserId,
    required this.muscleGroup,
    required this.date,
    required this.dailyStimulus,
    required this.rollingWeeklyLoad,
    this.lastSetTimestamp,
    this.lastSetStimulus,
    this.dailyVolume = 0.0,
    this.fatigueScore = 0.0,
    this.fatigueAnchorTimestamp,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Calculate remaining stimulus after recovery decay
  ///
  /// Uses exponential decay formula: stimulus * e^(-k * hours)
  /// where k is the muscle-specific recovery rate
  ///
  /// Returns the current remaining stimulus based on time elapsed since last set
  double calculateRemainingStimulus() {
    // If no last set recorded, return 0
    if (lastSetTimestamp == null || lastSetStimulus == null) {
      return 0.0;
    }

    // Calculate hours elapsed since last set
    final lastSetTime = DateTime.fromMillisecondsSinceEpoch(lastSetTimestamp!);
    final now = DateTime.now();
    final hoursElapsed =
        now.difference(lastSetTime).inMilliseconds / (1000 * 60 * 60);

    // Get recovery rate for this muscle
    final k = constants.MuscleStimulus.getRecoveryRate(muscleGroup);

    // Calculate remaining stimulus using exponential decay
    // Formula: S(t) = S₀ * e^(-k*t)
    final remainingStimulus = lastSetStimulus! * exp(-k * hoursElapsed);

    return remainingStimulus.clamp(0.0, lastSetStimulus!);
  }

  /// Get date as string in YYYY-MM-DD format
  String get dateString {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if this stimulus record is from today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year &&
        date.month == now.month &&
        date.day == now.day;
  }

  /// Check if last set was performed today
  bool get lastSetWasToday {
    if (lastSetTimestamp == null) return false;

    final lastSetTime = DateTime.fromMillisecondsSinceEpoch(lastSetTimestamp!);
    final now = DateTime.now();

    return lastSetTime.year == now.year &&
        lastSetTime.month == now.month &&
        lastSetTime.day == now.day;
  }

  /// Get hours since last set
  double? get hoursSinceLastSet {
    if (lastSetTimestamp == null) return null;

    final lastSetTime = DateTime.fromMillisecondsSinceEpoch(lastSetTimestamp!);
    final now = DateTime.now();

    return now.difference(lastSetTime).inMilliseconds / (1000 * 60 * 60);
  }

  MuscleStimulus copyWith({
    String? id,
    String? ownerUserId,
    String? muscleGroup,
    DateTime? date,
    double? dailyStimulus,
    double? rollingWeeklyLoad,
    int? lastSetTimestamp,
    double? lastSetStimulus,
    double? dailyVolume,
    double? fatigueScore,
    int? fatigueAnchorTimestamp,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MuscleStimulus(
      id: id ?? this.id,
      ownerUserId: ownerUserId ?? this.ownerUserId,
      muscleGroup: muscleGroup ?? this.muscleGroup,
      date: date ?? this.date,
      dailyStimulus: dailyStimulus ?? this.dailyStimulus,
      rollingWeeklyLoad: rollingWeeklyLoad ?? this.rollingWeeklyLoad,
      lastSetTimestamp: lastSetTimestamp ?? this.lastSetTimestamp,
      lastSetStimulus: lastSetStimulus ?? this.lastSetStimulus,
      dailyVolume: dailyVolume ?? this.dailyVolume,
      fatigueScore: fatigueScore ?? this.fatigueScore,
      fatigueAnchorTimestamp:
          fatigueAnchorTimestamp ?? this.fatigueAnchorTimestamp,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    ownerUserId,
    muscleGroup,
    date,
    dailyStimulus,
    rollingWeeklyLoad,
    lastSetTimestamp,
    lastSetStimulus,
    dailyVolume,
    fatigueScore,
    fatigueAnchorTimestamp,
    createdAt,
    updatedAt,
  ];
}

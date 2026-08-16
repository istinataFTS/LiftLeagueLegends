import 'package:equatable/equatable.dart';

/// Counts of activity logged on a single calendar day, split by type.
///
/// The calendar itself only asks [hasAny] — frame 08 marks a logged day with
/// a single tint underline, not with the per-type amber/green dot pair this
/// split was originally introduced for. The two counts are kept because the
/// day strip and the section subtitles still spell them out separately.
class DayActivity extends Equatable {
  const DayActivity({required this.exerciseSets, required this.nutritionLogs});

  static const DayActivity none = DayActivity(
    exerciseSets: 0,
    nutritionLogs: 0,
  );

  final int exerciseSets;
  final int nutritionLogs;

  bool get hasExercise => exerciseSets > 0;
  bool get hasNutrition => nutritionLogs > 0;
  bool get hasAny => hasExercise || hasNutrition;
  int get total => exerciseSets + nutritionLogs;

  @override
  List<Object?> get props => <Object?>[exerciseSets, nutritionLogs];
}

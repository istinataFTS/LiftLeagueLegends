import 'package:equatable/equatable.dart';

import '../../../../core/constants/muscle_groups.dart';
import '../../../../domain/entities/exercise.dart';

class LibraryExercisePageViewData extends Equatable {
  const LibraryExercisePageViewData({
    required this.items,
    required this.resultCountLabel,
    required this.hasExercises,
    required this.hasResults,
    required this.hasActiveFilters,
    required this.searchQuery,
    required this.selectedMuscle,
  });

  final List<LibraryExerciseItemViewData> items;
  final String resultCountLabel;
  final bool hasExercises;
  final bool hasResults;
  final bool hasActiveFilters;
  final String searchQuery;
  final String? selectedMuscle;

  @override
  List<Object?> get props => <Object?>[
    items,
    resultCountLabel,
    hasExercises,
    hasResults,
    hasActiveFilters,
    searchQuery,
    selectedMuscle,
  ];
}

class LibraryExerciseItemViewData extends Equatable {
  const LibraryExerciseItemViewData({
    required this.id,
    required this.title,
    required this.muscleTags,
    required this.overflowLabel,
    required this.exercise,
  });

  final String id;
  final String title;
  final List<String> muscleTags;
  final String? overflowLabel;
  final Exercise exercise;

  @override
  List<Object?> get props => <Object?>[
    id,
    title,
    muscleTags,
    overflowLabel,
    exercise,
  ];
}

class LibraryExerciseViewDataMapper {
  const LibraryExerciseViewDataMapper._();

  static LibraryExercisePageViewData map({
    required List<Exercise> allExercises,
    required List<Exercise> filteredExercises,
    required String searchQuery,
    required String? selectedMuscle,
  }) {
    return LibraryExercisePageViewData(
      items: filteredExercises
          .map(
            (Exercise exercise) => LibraryExerciseItemViewData(
              id: exercise.id,
              title: exercise.name,
              muscleTags: exercise.muscleGroups
                  .take(3)
                  .map(MuscleGroups.getDisplayName)
                  .toList(growable: false),
              overflowLabel: exercise.muscleGroups.length > 3
                  ? '+${exercise.muscleGroups.length - 3} more'
                  : null,
              exercise: exercise,
            ),
          )
          .toList(growable: false),
      resultCountLabel:
          '${filteredExercises.length} of ${allExercises.length} exercises',
      hasExercises: allExercises.isNotEmpty,
      hasResults: filteredExercises.isNotEmpty,
      hasActiveFilters: searchQuery.trim().isNotEmpty || selectedMuscle != null,
      searchQuery: searchQuery,
      selectedMuscle: selectedMuscle,
    );
  }
}

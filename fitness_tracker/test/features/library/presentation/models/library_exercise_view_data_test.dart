import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/features/library/presentation/models/library_exercise_view_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime createdAt = DateTime(2026, 1, 1);

  Exercise buildExercise({
    required String id,
    required String name,
    required List<String> muscleGroups,
  }) {
    return Exercise(
      id: id,
      name: name,
      muscleGroups: muscleGroups,
      createdAt: createdAt,
    );
  }

  group('LibraryExerciseViewDataMapper', () {
    test('maps exercise items, counts, and active filter state', () {
      final Exercise benchPress = buildExercise(
        id: '1',
        name: 'Bench Press',
        muscleGroups: const <String>[
          'chest',
          'triceps',
          'front-delts',
          'biceps',
        ],
      );
      final Exercise pullUp = buildExercise(
        id: '2',
        name: 'Pull Up',
        muscleGroups: const <String>['back', 'biceps'],
      );

      final LibraryExercisePageViewData viewData =
          LibraryExerciseViewDataMapper.map(
            allExercises: <Exercise>[benchPress, pullUp],
            filteredExercises: <Exercise>[benchPress],
            searchQuery: 'bench',
            selectedMuscle: 'chest',
          );

      expect(viewData.resultCountLabel, '1 of 2 exercises');
      expect(viewData.hasExercises, isTrue);
      expect(viewData.hasResults, isTrue);
      expect(viewData.hasActiveFilters, isTrue);
      expect(viewData.searchQuery, 'bench');
      expect(viewData.selectedMuscle, 'chest');
      expect(viewData.items, hasLength(1));

      final LibraryExerciseItemViewData item = viewData.items.single;
      expect(item.id, '1');
      expect(item.title, 'Bench Press');
      expect(item.muscleTags, <String>['Chest', 'Triceps', 'front-delts']);
      expect(item.overflowLabel, '+1 more');
      expect(item.exercise, benchPress);
    });

    test('maps empty state without active filters', () {
      final LibraryExercisePageViewData viewData =
          LibraryExerciseViewDataMapper.map(
            allExercises: const <Exercise>[],
            filteredExercises: const <Exercise>[],
            searchQuery: '   ',
            selectedMuscle: null,
          );

      expect(viewData.items, isEmpty);
      expect(viewData.resultCountLabel, '0 of 0 exercises');
      expect(viewData.hasExercises, isFalse);
      expect(viewData.hasResults, isFalse);
      expect(viewData.hasActiveFilters, isFalse);
      expect(viewData.selectedMuscle, isNull);
    });
  });
}

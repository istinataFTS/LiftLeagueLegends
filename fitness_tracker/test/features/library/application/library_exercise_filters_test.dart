import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/features/library/application/library_exercise_filters.dart';
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

  final List<Exercise> exercises = <Exercise>[
    buildExercise(
      id: '1',
      name: 'Bench Press',
      muscleGroups: const <String>['chest', 'triceps', 'lats'],
    ),
    buildExercise(
      id: '2',
      name: 'Pull Up',
      muscleGroups: const <String>['back', 'biceps'],
    ),
    buildExercise(
      id: '3',
      name: 'Overhead Press',
      muscleGroups: const <String>['shoulders', 'triceps'],
    ),
  ];

  group('LibraryExerciseFilters', () {
    test(
      'returns all exercises when query is blank and no muscle is selected',
      () {
        final List<Exercise> result = LibraryExerciseFilters.apply(
          exercises: exercises,
          query: '   ',
          selectedMuscle: null,
        );

        expect(result, hasLength(3));
        expect(result.map((Exercise item) => item.name), <String>[
          'Bench Press',
          'Pull Up',
          'Overhead Press',
        ]);
      },
    );

    test('filters by exercise name using case-insensitive matching', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: 'bench',
        selectedMuscle: null,
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Bench Press');
    });

    test('filters by muscle display name using case-insensitive matching', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: 'should',
        selectedMuscle: null,
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Overhead Press');
    });

    test('filters by selected muscle only', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: '',
        selectedMuscle: 'triceps',
      );

      expect(result, hasLength(2));
      expect(result.map((Exercise item) => item.name), <String>[
        'Bench Press',
        'Overhead Press',
      ]);
    });

    test('combines query and selected muscle filters', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: 'press',
        selectedMuscle: 'triceps',
      );

      expect(result, hasLength(2));
      expect(result.map((Exercise item) => item.name), <String>[
        'Bench Press',
        'Overhead Press',
      ]);
    });

    test('returns empty list when no exercises match combined filters', () {
      final List<Exercise> result = LibraryExerciseFilters.apply(
        exercises: exercises,
        query: 'pull',
        selectedMuscle: 'chest',
      );

      expect(result, isEmpty);
    });
  });
}

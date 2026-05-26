import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:fitness_tracker/domain/usecases/exercises/add_exercise.dart';
import 'package:fitness_tracker/domain/usecases/exercises/delete_exercise.dart';
import 'package:fitness_tracker/domain/usecases/exercises/ensure_default_exercises.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_all_exercises.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_exercise_by_id.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_exercises_for_muscle.dart';
import 'package:fitness_tracker/domain/usecases/exercises/update_exercise.dart';
import 'package:fitness_tracker/domain/usecases/muscle_factors/get_muscle_factors_for_exercise.dart';
import 'package:fitness_tracker/features/library/application/exercise_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAllExercises extends Mock implements GetAllExercises {}

class MockGetExerciseById extends Mock implements GetExerciseById {}

class MockGetExercisesForMuscle extends Mock implements GetExercisesForMuscle {}

class MockAddExercise extends Mock implements AddExercise {}

class MockUpdateExercise extends Mock implements UpdateExercise {}

class MockDeleteExercise extends Mock implements DeleteExercise {}

class MockEnsureDefaultExercises extends Mock
    implements EnsureDefaultExercises {}

class MockGetMuscleFactorsForExercise extends Mock
    implements GetMuscleFactorsForExercise {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _exercise = Exercise(
  id: 'ex-1',
  name: 'Bench Press',
  muscleGroups: const ['chest'],
  createdAt: DateTime(2026),
);

const _dbFailure = DatabaseFailure('db error');

void main() {
  late MockGetAllExercises mockGetAll;
  late MockGetExerciseById mockGetById;
  late MockGetExercisesForMuscle mockGetForMuscle;
  late MockAddExercise mockAdd;
  late MockUpdateExercise mockUpdate;
  late MockDeleteExercise mockDelete;
  late MockEnsureDefaultExercises mockEnsureDefaultExercises;
  late MockGetMuscleFactorsForExercise mockGetFactors;

  ExerciseBloc buildBloc() => ExerciseBloc(
    getAllExercises: mockGetAll,
    getExerciseById: mockGetById,
    getExercisesForMuscle: mockGetForMuscle,
    addExercise: mockAdd,
    updateExercise: mockUpdate,
    deleteExercise: mockDelete,
    ensureDefaultExercises: mockEnsureDefaultExercises,
    getMuscleFactorsForExercise: mockGetFactors,
  );

  setUpAll(() {
    registerFallbackValue(_exercise);
  });

  setUp(() {
    mockGetAll = MockGetAllExercises();
    mockGetById = MockGetExerciseById();
    mockGetForMuscle = MockGetExercisesForMuscle();
    mockAdd = MockAddExercise();
    mockUpdate = MockUpdateExercise();
    mockDelete = MockDeleteExercise();
    mockEnsureDefaultExercises = MockEnsureDefaultExercises();
    mockGetFactors = MockGetMuscleFactorsForExercise();
  });

  group('ExerciseBloc', () {
    group('LoadExercisesEvent', () {
      blocTest<ExerciseBloc, ExerciseState>(
        'emits [Loading, ExercisesLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(() => mockGetAll()).thenAnswer((_) async => Right([_exercise]));
        },
        act: (bloc) => bloc.add(LoadExercisesEvent()),
        expect: () => [
          isA<ExerciseLoading>(),
          ExercisesLoaded([_exercise]),
        ],
      );

      blocTest<ExerciseBloc, ExerciseState>(
        'emits [Loading, ExerciseError] on failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetAll(),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(LoadExercisesEvent()),
        expect: () => [isA<ExerciseLoading>(), const ExerciseError('db error')],
      );
    });

    group('LoadExerciseByIdEvent', () {
      blocTest<ExerciseBloc, ExerciseState>(
        'emits [Loading, ExerciseLoaded] when exercise is found',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetById('ex-1'),
          ).thenAnswer((_) async => Right(_exercise));
        },
        act: (bloc) => bloc.add(const LoadExerciseByIdEvent('ex-1')),
        expect: () => [isA<ExerciseLoading>(), ExerciseLoaded(_exercise)],
      );

      blocTest<ExerciseBloc, ExerciseState>(
        'emits [Loading, ExerciseError] when exercise is not found',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetById('ex-1'),
          ).thenAnswer((_) async => const Right(null));
        },
        act: (bloc) => bloc.add(const LoadExerciseByIdEvent('ex-1')),
        expect: () => [
          isA<ExerciseLoading>(),
          const ExerciseError('Exercise not found'),
        ],
      );

      blocTest<ExerciseBloc, ExerciseState>(
        'emits [Loading, ExerciseError] on repository failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetById('ex-1'),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(const LoadExerciseByIdEvent('ex-1')),
        expect: () => [isA<ExerciseLoading>(), const ExerciseError('db error')],
      );
    });

    group('LoadExercisesForMuscleEvent', () {
      blocTest<ExerciseBloc, ExerciseState>(
        'emits [Loading, ExercisesLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetForMuscle('chest'),
          ).thenAnswer((_) async => Right([_exercise]));
        },
        act: (bloc) => bloc.add(const LoadExercisesForMuscleEvent('chest')),
        expect: () => [
          isA<ExerciseLoading>(),
          ExercisesLoaded([_exercise]),
        ],
      );

      blocTest<ExerciseBloc, ExerciseState>(
        'emits [Loading, ExerciseError] on failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetForMuscle('chest'),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(const LoadExercisesForMuscleEvent('chest')),
        expect: () => [isA<ExerciseLoading>(), const ExerciseError('db error')],
      );
    });

    group('AddExerciseEvent', () {
      blocTest<ExerciseBloc, ExerciseState>(
        'emits [OperationSuccess, Loading, ExercisesLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockAdd(_exercise),
          ).thenAnswer((_) async => const Right(null));
          when(() => mockGetAll()).thenAnswer((_) async => Right([_exercise]));
        },
        act: (bloc) => bloc.add(AddExerciseEvent(_exercise)),
        expect: () => [
          const ExerciseOperationSuccess('Exercise added successfully'),
          isA<ExerciseLoading>(),
          ExercisesLoaded([_exercise]),
        ],
      );

      blocTest<ExerciseBloc, ExerciseState>(
        'emits [ExerciseError] on failure without reloading',
        build: buildBloc,
        setUp: () {
          when(
            () => mockAdd(_exercise),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(AddExerciseEvent(_exercise)),
        expect: () => [const ExerciseError('db error')],
        verify: (_) => verifyNever(() => mockGetAll()),
      );
    });

    group('UpdateExerciseEvent', () {
      blocTest<ExerciseBloc, ExerciseState>(
        'emits [OperationSuccess, Loading, ExercisesLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockUpdate(_exercise),
          ).thenAnswer((_) async => const Right(null));
          when(() => mockGetAll()).thenAnswer((_) async => Right([_exercise]));
        },
        act: (bloc) => bloc.add(UpdateExerciseEvent(_exercise)),
        expect: () => [
          const ExerciseOperationSuccess('Exercise updated successfully'),
          isA<ExerciseLoading>(),
          ExercisesLoaded([_exercise]),
        ],
      );

      blocTest<ExerciseBloc, ExerciseState>(
        'emits [ExerciseError] on failure without reloading',
        build: buildBloc,
        setUp: () {
          when(
            () => mockUpdate(_exercise),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(UpdateExerciseEvent(_exercise)),
        expect: () => [const ExerciseError('db error')],
        verify: (_) => verifyNever(() => mockGetAll()),
      );
    });

    group('DeleteExerciseEvent', () {
      blocTest<ExerciseBloc, ExerciseState>(
        'emits [OperationSuccess, Loading, ExercisesLoaded] on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockDelete('ex-1'),
          ).thenAnswer((_) async => const Right(null));
          when(() => mockGetAll()).thenAnswer((_) async => Right([_exercise]));
        },
        act: (bloc) => bloc.add(const DeleteExerciseEvent('ex-1')),
        expect: () => [
          const ExerciseOperationSuccess('Exercise deleted successfully'),
          isA<ExerciseLoading>(),
          ExercisesLoaded([_exercise]),
        ],
      );

      blocTest<ExerciseBloc, ExerciseState>(
        'emits [ExerciseError] on failure without reloading',
        build: buildBloc,
        setUp: () {
          when(
            () => mockDelete('ex-1'),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(const DeleteExerciseEvent('ex-1')),
        expect: () => [const ExerciseError('db error')],
        verify: (_) => verifyNever(() => mockGetAll()),
      );
    });

    group('LoadExerciseFactorsEvent', () {
      final factors = [
        MuscleFactor(
          id: 'f-1',
          exerciseId: 'ex-1',
          muscleGroup: 'chest',
          factor: 0.8,
        ),
        MuscleFactor(
          id: 'f-2',
          exerciseId: 'ex-1',
          muscleGroup: 'triceps',
          factor: 0.5,
        ),
      ];

      blocTest<ExerciseBloc, ExerciseState>(
        'emits ExerciseFactorsLoaded with a factor map on success',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetFactors('ex-1'),
          ).thenAnswer((_) async => Right(factors));
        },
        act: (bloc) => bloc.add(const LoadExerciseFactorsEvent('ex-1')),
        expect: () => [
          ExerciseFactorsLoaded(
            exerciseId: 'ex-1',
            factors: const <String, double>{'chest': 0.8, 'triceps': 0.5},
          ),
        ],
      );

      blocTest<ExerciseBloc, ExerciseState>(
        'emits nothing (silent fail) when repository returns a failure',
        build: buildBloc,
        setUp: () {
          when(
            () => mockGetFactors('ex-1'),
          ).thenAnswer((_) async => const Left(_dbFailure));
        },
        act: (bloc) => bloc.add(const LoadExerciseFactorsEvent('ex-1')),
        expect: () => <ExerciseState>[],
      );
    });
  });
}

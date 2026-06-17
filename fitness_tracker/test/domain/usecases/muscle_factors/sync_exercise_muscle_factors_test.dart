import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/constants/muscle_stimulus_constants.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:fitness_tracker/domain/repositories/muscle_factor_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_factors/sync_exercise_muscle_factors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMuscleFactorRepository extends Mock
    implements MuscleFactorRepository {}

void main() {
  late MockMuscleFactorRepository muscleFactorRepository;
  late SyncExerciseMuscleFactors usecase;
  late List<MuscleFactor> savedFactors;

  // Exercise with granular-taxonomy muscle groups (matches seed-data style).
  final exerciseGranular = Exercise(
    id: 'exercise-1',
    name: 'Klek',
    muscleGroups: <String>[
      MuscleStimulus.hamstrings,
      MuscleStimulus.quads,
      MuscleStimulus.glutes,
      MuscleStimulus.lowerBack,
    ],
    createdAt: DateTime(2026, 3, 27),
  );

  // Exercise with legacy simple-taxonomy muscle groups (matches user-created
  // style). 'shoulder' is a legacy key that canonicalises to 'shoulders'.
  final exerciseSimple = Exercise(
    id: 'exercise-2',
    name: 'Bench Press',
    muscleGroups: const <String>['chest', 'shoulder', 'triceps'],
    createdAt: DateTime(2026, 3, 27),
  );

  setUpAll(() {
    registerFallbackValue(const <MuscleFactor>[]);
  });

  setUp(() {
    muscleFactorRepository = MockMuscleFactorRepository();
    usecase = SyncExerciseMuscleFactors(muscleFactorRepository);
    savedFactors = <MuscleFactor>[];

    when(
      () => muscleFactorRepository.deleteMuscleFactorsByExerciseId(any()),
    ).thenAnswer((_) async => const Right(null));

    when(() => muscleFactorRepository.addMuscleFactorsBatch(any())).thenAnswer((
      invocation,
    ) async {
      savedFactors = invocation.positionalArguments.first as List<MuscleFactor>;
      return const Right(null);
    });
  });

  group('no muscleFactors map supplied (default behaviour)', () {
    test('creates factor 1.0 for each granular muscle group', () async {
      final result = await usecase(exerciseGranular);

      expect(result, const Right(null));
      expect(savedFactors, hasLength(4));
      expect(
        savedFactors.map((f) => f.muscleGroup),
        containsAll(exerciseGranular.muscleGroups),
      );
      expect(savedFactors.every((f) => f.factor == 1.0), isTrue);
    });

    test(
      'creates factor 1.0 for each simple muscle group (canonicalised)',
      () async {
        final result = await usecase(exerciseSimple);

        expect(result, const Right(null));
        expect(savedFactors, hasLength(3));
        // Legacy 'shoulder' is stored as canonical 'shoulders'.
        expect(
          savedFactors.map((f) => f.muscleGroup),
          containsAll(<String>['chest', 'shoulders', 'triceps']),
        );
        expect(savedFactors.every((f) => f.factor == 1.0), isTrue);
      },
    );
  });

  group('muscleFactors map supplied (user-edited weights)', () {
    test('uses provided factors instead of defaulting to 1.0', () async {
      final result = await usecase(
        exerciseSimple,
        muscleFactors: const <String, double>{
          'chest': 0.8,
          'shoulder': 0.5,
          'triceps': 0.3,
        },
      );

      expect(result, const Right(null));
      expect(savedFactors, hasLength(3));

      final Map<String, double> byMuscle = <String, double>{
        for (final f in savedFactors) f.muscleGroup: f.factor,
      };
      expect(byMuscle['chest'], closeTo(0.8, 0.001));
      expect(byMuscle['shoulders'], closeTo(0.5, 0.001));
      expect(byMuscle['triceps'], closeTo(0.3, 0.001));
    });

    test('muscles absent from the factor map default to 1.0', () async {
      // Only 'chest' is in the map; 'shoulder' and 'triceps' should use 1.0.
      final result = await usecase(
        exerciseSimple,
        muscleFactors: const <String, double>{'chest': 0.6},
      );

      expect(result, const Right(null));
      final Map<String, double> byMuscle = <String, double>{
        for (final f in savedFactors) f.muscleGroup: f.factor,
      };
      expect(byMuscle['chest'], closeTo(0.6, 0.001));
      expect(byMuscle['shoulders'], closeTo(1.0, 0.001));
      expect(byMuscle['triceps'], closeTo(1.0, 0.001));
    });

    test(
      'factor 0.0 entries are skipped — no row saved for that muscle',
      () async {
        final result = await usecase(
          exerciseSimple,
          muscleFactors: const <String, double>{
            'chest': 0.8,
            'shoulder': 0.0, // should be skipped
            'triceps': 0.5,
          },
        );

        expect(result, const Right(null));
        // Only chest and triceps should be saved.
        expect(savedFactors, hasLength(2));
        expect(
          savedFactors.map((f) => f.muscleGroup),
          containsAll(<String>['chest', 'triceps']),
        );
        expect(
          savedFactors.map((f) => f.muscleGroup),
          isNot(contains('shoulder')),
        );
      },
    );

    test('factors are clamped to [0.0, 1.0]', () async {
      final result = await usecase(
        exerciseSimple,
        muscleFactors: const <String, double>{
          'chest': 1.5, // above max → clamped to 1.0
          'shoulder': -0.2, // below min → clamped to 0.0 → skipped
          'triceps': 0.7,
        },
      );

      expect(result, const Right(null));
      final Map<String, double> byMuscle = <String, double>{
        for (final f in savedFactors) f.muscleGroup: f.factor,
      };
      expect(byMuscle['chest'], closeTo(1.0, 0.001));
      expect(byMuscle.containsKey('shoulder'), isFalse); // skipped after clamp
      expect(byMuscle['triceps'], closeTo(0.7, 0.001));
    });
  });
}

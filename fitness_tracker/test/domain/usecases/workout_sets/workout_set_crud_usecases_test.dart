import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/repositories/exercise_repository.dart';
import 'package:fitness_tracker/domain/repositories/workout_set_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/delete_workout_set.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_all_workout_sets.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/get_sets_by_date_range.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/update_workout_set.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSetRepository extends Mock implements WorkoutSetRepository {}

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockRebuildMuscleStimulusFromWorkoutHistory extends Mock
    implements RebuildMuscleStimulusFromWorkoutHistory {}

class MockAuthenticatedDataSourcePreferenceResolver extends Mock
    implements AuthenticatedDataSourcePreferenceResolver {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _setDate = DateTime(2026, 4, 1);

final _workoutSetFixture = WorkoutSet(
  id: 'ws-1',
  exerciseId: 'ex-1',
  reps: 10,
  weight: 100.0,
  date: _setDate,
  createdAt: _setDate,
);

final _exerciseFixture = Exercise(
  id: 'ex-1',
  name: 'Bench Press',
  muscleGroups: const ['chest'],
  createdAt: DateTime(2026),
);

const _authenticatedSession = AppSession(
  user: AppUser(id: 'user-1', email: 'test@example.com'),
);

const _dbFailure = DatabaseFailure('db error');

void main() {
  late MockWorkoutSetRepository mockSetRepo;
  late MockExerciseRepository mockExerciseRepo;
  late MockAppSessionRepository mockSessionRepo;
  late MockRebuildMuscleStimulusFromWorkoutHistory mockRebuild;
  late MockAuthenticatedDataSourcePreferenceResolver mockResolver;

  setUpAll(() {
    registerFallbackValue(_workoutSetFixture);
    registerFallbackValue(_exerciseFixture);
  });

  setUp(() {
    mockSetRepo = MockWorkoutSetRepository();
    mockExerciseRepo = MockExerciseRepository();
    mockSessionRepo = MockAppSessionRepository();
    mockRebuild = MockRebuildMuscleStimulusFromWorkoutHistory();
    mockResolver = MockAuthenticatedDataSourcePreferenceResolver();
  });

  // ---------------------------------------------------------------------------
  // DeleteWorkoutSet
  // ---------------------------------------------------------------------------

  group('DeleteWorkoutSet', () {
    late DeleteWorkoutSet useCase;

    setUp(() {
      useCase = DeleteWorkoutSet(
        mockSetRepo,
        appSessionRepository: mockSessionRepo,
        rebuildMuscleStimulusFromWorkoutHistory: mockRebuild,
      );
    });

    test('deletes set and rebuilds stimulus on success', () async {
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockSetRepo.deleteSet('ws-1'),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockRebuild('user-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase('ws-1');

      expect(result.isRight(), isTrue);
      verify(() => mockRebuild('user-1')).called(1);
    });

    test('propagates repository failure without rebuilding', () async {
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockSetRepo.deleteSet('ws-1'),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase('ws-1');

      expect(result, const Left(_dbFailure));
      verifyNever(() => mockRebuild(any()));
    });
  });

  // ---------------------------------------------------------------------------
  // GetAllWorkoutSets
  // ---------------------------------------------------------------------------

  group('GetAllWorkoutSets', () {
    late GetAllWorkoutSets useCase;

    setUp(() {
      useCase = GetAllWorkoutSets(
        mockSetRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns all workout sets from repository', () async {
      when(
        () => mockSetRepo.getAllSets(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_workoutSetFixture]));

      final result = await useCase();

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_workoutSetFixture]);
    });

    test('propagates repository failure', () async {
      when(
        () => mockSetRepo.getAllSets(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase();

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetSetsByDateRange
  // ---------------------------------------------------------------------------

  group('GetSetsByDateRange', () {
    late GetSetsByDateRange useCase;

    final startDate = DateTime(2026, 4, 1);
    final endDate = DateTime(2026, 4, 7);

    setUp(() {
      useCase = GetSetsByDateRange(
        workoutSetRepository: mockSetRepo,
        exerciseRepository: mockExerciseRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns all sets when no muscle group filter is applied', () async {
      when(
        () => mockSetRepo.getSetsByDateRange(
          startDate,
          endDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_workoutSetFixture]));

      final result = await useCase(startDate: startDate, endDate: endDate);

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_workoutSetFixture]);
      verifyNever(
        () => mockExerciseRepo.getAllExercises(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      );
    });

    test('filters sets by muscle group when filter is provided', () async {
      final setForBack = WorkoutSet(
        id: 'ws-2',
        exerciseId: 'ex-2',
        reps: 8,
        weight: 80.0,
        date: _setDate,
        createdAt: _setDate,
      );
      final backExercise = Exercise(
        id: 'ex-2',
        name: 'Pull Up',
        muscleGroups: const ['back'],
        createdAt: DateTime(2026),
      );

      when(
        () => mockSetRepo.getSetsByDateRange(
          startDate,
          endDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_workoutSetFixture, setForBack]));
      when(
        () => mockExerciseRepo.getAllExercises(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_exerciseFixture, backExercise]));

      final result = await useCase(
        startDate: startDate,
        endDate: endDate,
        muscleGroup: 'chest',
      );

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_workoutSetFixture]);
    });

    test('excludes sets whose exercise is not in the exercise list', () async {
      final orphanSet = WorkoutSet(
        id: 'ws-orphan',
        exerciseId: 'ex-deleted',
        reps: 5,
        weight: 60.0,
        date: _setDate,
        createdAt: _setDate,
      );

      when(
        () => mockSetRepo.getSetsByDateRange(
          startDate,
          endDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_workoutSetFixture, orphanSet]));
      when(
        () => mockExerciseRepo.getAllExercises(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_exerciseFixture]));

      final result = await useCase(
        startDate: startDate,
        endDate: endDate,
        muscleGroup: 'chest',
      );

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_workoutSetFixture]);
    });

    test('propagates workout set repository failure', () async {
      when(
        () => mockSetRepo.getSetsByDateRange(
          startDate,
          endDate,
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(startDate: startDate, endDate: endDate);

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // UpdateWorkoutSet
  // ---------------------------------------------------------------------------

  group('UpdateWorkoutSet', () {
    late UpdateWorkoutSet useCase;

    setUp(() {
      useCase = UpdateWorkoutSet(
        mockSetRepo,
        appSessionRepository: mockSessionRepo,
        rebuildMuscleStimulusFromWorkoutHistory: mockRebuild,
      );
    });

    test('updates set and rebuilds stimulus on success', () async {
      final setWithOwner = _workoutSetFixture.copyWith(ownerUserId: 'user-1');
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockSetRepo.updateSet(setWithOwner),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockRebuild('user-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(_workoutSetFixture);

      expect(result.isRight(), isTrue);
      verify(() => mockRebuild('user-1')).called(1);
    });

    test('sets ownerUserId when session is authenticated', () async {
      final setWithOwner = _workoutSetFixture.copyWith(ownerUserId: 'user-1');

      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockSetRepo.updateSet(setWithOwner),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockRebuild('user-1'),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(_workoutSetFixture);

      expect(result.isRight(), isTrue);
      verify(() => mockSetRepo.updateSet(setWithOwner)).called(1);
    });

    test('propagates repository failure without rebuilding', () async {
      final setWithOwner = _workoutSetFixture.copyWith(ownerUserId: 'user-1');
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockSetRepo.updateSet(setWithOwner),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_workoutSetFixture);

      expect(result, const Left(_dbFailure));
      verifyNever(() => mockRebuild(any()));
    });
  });
}

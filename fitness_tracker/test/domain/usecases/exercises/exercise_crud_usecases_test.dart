import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/repositories/exercise_repository.dart';
import 'package:fitness_tracker/domain/repositories/muscle_factor_repository.dart';
import 'package:fitness_tracker/domain/services/authenticated_data_source_preference_resolver.dart';
import 'package:fitness_tracker/domain/usecases/exercises/add_exercise.dart';
import 'package:fitness_tracker/domain/usecases/exercises/delete_exercise.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_all_exercises.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_exercise_by_id.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_exercises_for_muscle.dart';
import 'package:fitness_tracker/domain/usecases/exercises/update_exercise.dart';
import 'package:fitness_tracker/domain/usecases/muscle_factors/sync_exercise_muscle_factors.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockExerciseRepository extends Mock implements ExerciseRepository {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockMuscleFactorRepository extends Mock
    implements MuscleFactorRepository {}

class MockSyncExerciseMuscleFactors extends Mock
    implements SyncExerciseMuscleFactors {}

class MockRebuildMuscleStimulusFromWorkoutHistory extends Mock
    implements RebuildMuscleStimulusFromWorkoutHistory {}

class MockAuthenticatedDataSourcePreferenceResolver extends Mock
    implements AuthenticatedDataSourcePreferenceResolver {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _exerciseFixture = Exercise(
  id: 'ex-1',
  name: 'Bench Press',
  muscleGroups: const ['chest'],
  createdAt: DateTime(2026),
);

// Per-user catalog model: AddExercise always stamps the resolved owner.
// Guest / failed-session resolves to the guest sentinel '' ('').
final _guestOwnedFixture = _exerciseFixture.copyWith(ownerUserId: '');

const _authenticatedSession = AppSession(
  user: AppUser(id: 'user-1', email: 'test@example.com'),
);

const _dbFailure = DatabaseFailure('db error');

void main() {
  late MockExerciseRepository mockExerciseRepo;
  late MockAppSessionRepository mockSessionRepo;
  late MockMuscleFactorRepository mockMuscleFactorRepo;
  late MockSyncExerciseMuscleFactors mockSyncFactors;
  late MockRebuildMuscleStimulusFromWorkoutHistory mockRebuild;
  late MockAuthenticatedDataSourcePreferenceResolver mockResolver;

  setUpAll(() {
    registerFallbackValue(_exerciseFixture);
  });

  setUp(() {
    mockExerciseRepo = MockExerciseRepository();
    mockSessionRepo = MockAppSessionRepository();
    mockMuscleFactorRepo = MockMuscleFactorRepository();
    mockSyncFactors = MockSyncExerciseMuscleFactors();
    mockRebuild = MockRebuildMuscleStimulusFromWorkoutHistory();
    mockResolver = MockAuthenticatedDataSourcePreferenceResolver();
  });

  // ---------------------------------------------------------------------------
  // AddExercise
  // ---------------------------------------------------------------------------

  group('AddExercise', () {
    late AddExercise useCase;

    setUp(() {
      useCase = AddExercise(
        mockExerciseRepo,
        appSessionRepository: mockSessionRepo,
        syncExerciseMuscleFactors: mockSyncFactors,
      );
    });

    // "stamps the guest sentinel owner when session fails" removed: after
    // guest-mode removal, AddExercise propagates the session failure instead
    // of falling back to a guest owner.

    test('sets ownerUserId when session is authenticated', () async {
      final exerciseWithOwner = _exerciseFixture.copyWith(
        ownerUserId: 'user-1',
      );

      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockExerciseRepo.addExercise(exerciseWithOwner),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockSyncFactors(exerciseWithOwner),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase(_exerciseFixture);

      expect(result.isRight(), isTrue);
      verify(() => mockExerciseRepo.addExercise(exerciseWithOwner)).called(1);
    });

    test('propagates repository failure', () async {
      final exerciseWithOwner = _exerciseFixture.copyWith(
        ownerUserId: 'user-1',
      );
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockExerciseRepo.addExercise(exerciseWithOwner),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_exerciseFixture);

      expect(result, const Left(_dbFailure));
      verifyNever(() => mockSyncFactors(any()));
    });

    test('triggers syncExerciseMuscleFactors on success', () async {
      final exerciseWithOwner = _exerciseFixture.copyWith(
        ownerUserId: 'user-1',
      );
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockExerciseRepo.addExercise(exerciseWithOwner),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockSyncFactors(exerciseWithOwner),
      ).thenAnswer((_) async => const Right(null));

      await useCase(_exerciseFixture);

      verify(() => mockSyncFactors(exerciseWithOwner)).called(1);
    });
  });

  // ---------------------------------------------------------------------------
  // DeleteExercise
  // ---------------------------------------------------------------------------

  group('DeleteExercise', () {
    late DeleteExercise useCase;

    setUp(() {
      useCase = DeleteExercise(
        mockExerciseRepo,
        appSessionRepository: mockSessionRepo,
        muscleFactorRepository: mockMuscleFactorRepo,
        rebuildMuscleStimulusFromWorkoutHistory: mockRebuild,
      );
    });

    test(
      'deletes exercise, factors, and rebuilds stimulus on success',
      () async {
        when(
          () => mockSessionRepo.getCurrentSession(),
        ).thenAnswer((_) async => const Right(_authenticatedSession));
        when(
          () => mockExerciseRepo.deleteExercise('ex-1'),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockMuscleFactorRepo.deleteMuscleFactorsByExerciseId('ex-1'),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockRebuild('user-1'),
        ).thenAnswer((_) async => const Right(null));

        final result = await useCase('ex-1');

        expect(result.isRight(), isTrue);
        verify(() => mockRebuild('user-1')).called(1);
      },
    );

    test('propagates repository failure without deleting factors', () async {
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockExerciseRepo.deleteExercise('ex-1'),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase('ex-1');

      expect(result, const Left(_dbFailure));
      verifyNever(
        () => mockMuscleFactorRepo.deleteMuscleFactorsByExerciseId(any()),
      );
      verifyNever(() => mockRebuild(any()));
    });
  });

  // ---------------------------------------------------------------------------
  // GetAllExercises
  // ---------------------------------------------------------------------------

  group('GetAllExercises', () {
    late GetAllExercises useCase;

    setUp(() {
      useCase = GetAllExercises(
        mockExerciseRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns list of exercises from repository', () async {
      when(
        () => mockExerciseRepo.getAllExercises(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_exerciseFixture]));

      final result = await useCase();

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_exerciseFixture]);
    });

    test('propagates repository failure', () async {
      when(
        () => mockExerciseRepo.getAllExercises(
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase();

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetExerciseById
  // ---------------------------------------------------------------------------

  group('GetExerciseById', () {
    late GetExerciseById useCase;

    setUp(() {
      useCase = GetExerciseById(
        mockExerciseRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns exercise when found', () async {
      when(
        () => mockExerciseRepo.getExerciseById(
          'ex-1',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right(_exerciseFixture));

      final result = await useCase('ex-1');

      expect(result, Right(_exerciseFixture));
    });

    test('returns null when exercise not found', () async {
      when(
        () => mockExerciseRepo.getExerciseById(
          'missing',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Right(null));

      final result = await useCase('missing');

      expect(result, const Right(null));
    });

    test('propagates repository failure', () async {
      when(
        () => mockExerciseRepo.getExerciseById(
          'ex-1',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase('ex-1');

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // GetExercisesForMuscle
  // ---------------------------------------------------------------------------

  group('GetExercisesForMuscle', () {
    late GetExercisesForMuscle useCase;

    setUp(() {
      useCase = GetExercisesForMuscle(
        mockExerciseRepo,
        sourcePreferenceResolver: mockResolver,
      );
      when(
        () => mockResolver.resolveReadPreference(),
      ).thenAnswer((_) async => DataSourcePreference.localOnly);
    });

    test('returns filtered list for the given muscle group', () async {
      when(
        () => mockExerciseRepo.getExercisesForMuscle(
          'chest',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => Right([_exerciseFixture]));

      final result = await useCase('chest');

      expect(result.isRight(), isTrue);
      expect((result as Right).value, [_exerciseFixture]);
    });

    test('propagates repository failure', () async {
      when(
        () => mockExerciseRepo.getExercisesForMuscle(
          'chest',
          sourcePreference: DataSourcePreference.localOnly,
        ),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase('chest');

      expect(result, const Left(_dbFailure));
    });
  });

  // ---------------------------------------------------------------------------
  // UpdateExercise
  // ---------------------------------------------------------------------------

  group('UpdateExercise', () {
    late UpdateExercise useCase;

    setUp(() {
      useCase = UpdateExercise(
        mockExerciseRepo,
        appSessionRepository: mockSessionRepo,
        syncExerciseMuscleFactors: mockSyncFactors,
        rebuildMuscleStimulusFromWorkoutHistory: mockRebuild,
      );
    });

    test(
      'updates exercise, syncs factors, and rebuilds stimulus on success',
      () async {
        final exerciseWithOwner = _exerciseFixture.copyWith(
          ownerUserId: 'user-1',
        );
        when(
          () => mockSessionRepo.getCurrentSession(),
        ).thenAnswer((_) async => const Right(_authenticatedSession));
        when(
          () => mockExerciseRepo.updateExercise(exerciseWithOwner),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockSyncFactors(exerciseWithOwner),
        ).thenAnswer((_) async => const Right(null));
        when(
          () => mockRebuild('user-1'),
        ).thenAnswer((_) async => const Right(null));

        final result = await useCase(_exerciseFixture);

        expect(result.isRight(), isTrue);
        verify(() => mockSyncFactors(exerciseWithOwner)).called(1);
        verify(() => mockRebuild('user-1')).called(1);
      },
    );

    test('propagates repository failure without syncing', () async {
      final exerciseWithOwner = _exerciseFixture.copyWith(
        ownerUserId: 'user-1',
      );
      when(
        () => mockSessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_authenticatedSession));
      when(
        () => mockExerciseRepo.updateExercise(exerciseWithOwner),
      ).thenAnswer((_) async => const Left(_dbFailure));

      final result = await useCase(_exerciseFixture);

      expect(result, const Left(_dbFailure));
      verifyNever(() => mockSyncFactors(any()));
      verifyNever(() => mockRebuild(any()));
    });
  });
}

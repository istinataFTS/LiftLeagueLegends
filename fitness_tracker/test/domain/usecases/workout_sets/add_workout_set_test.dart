import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/config/app_sync_policy.dart';
import 'package:fitness_tracker/core/enums/auth_mode.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/repositories/workout_set_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import 'package:fitness_tracker/domain/usecases/workout_sets/add_workout_set.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockWorkoutSetRepository extends Mock implements WorkoutSetRepository {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockRebuildMuscleStimulusFromWorkoutHistory extends Mock
    implements RebuildMuscleStimulusFromWorkoutHistory {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      WorkoutSet(
        id: 'fallback-set',
        exerciseId: 'fallback-exercise',
        reps: 10,
        weight: 80,
        date: DateTime(2026),
        createdAt: DateTime(2026),
      ),
    );
  });

  late MockWorkoutSetRepository workoutSetRepository;
  late MockAppSessionRepository appSessionRepository;
  late MockRebuildMuscleStimulusFromWorkoutHistory mockRebuild;
  late AddWorkoutSet usecase;

  final baseSet = WorkoutSet(
    id: 'set-1',
    exerciseId: 'exercise-1',
    reps: 10,
    weight: 60,
    date: DateTime(2026, 3, 18),
    createdAt: DateTime(2026, 3, 18),
  );

  setUp(() {
    workoutSetRepository = MockWorkoutSetRepository();
    appSessionRepository = MockAppSessionRepository();
    mockRebuild = MockRebuildMuscleStimulusFromWorkoutHistory();

    when(
      () => appSessionRepository.syncPolicy,
    ).thenReturn(AppSyncPolicy.productionDefault);

    usecase = AddWorkoutSet(
      workoutSetRepository,
      appSessionRepository: appSessionRepository,
      rebuildMuscleStimulusFromWorkoutHistory: mockRebuild,
    );

    when(
      () => workoutSetRepository.addSet(any()),
    ).thenAnswer((_) async => const Right(null));

    when(() => mockRebuild(any())).thenAnswer((_) async => const Right(null));
  });

  test('attaches authenticated ownerUserId before repository add', () async {
    when(() => appSessionRepository.getCurrentSession()).thenAnswer(
      (_) async => Right(
        AppSession(
          authMode: AuthMode.authenticated,
          user: const AppUser(id: 'user-123', email: 'user@test.com'),
        ),
      ),
    );

    await usecase(baseSet);

    final captured =
        verify(() => workoutSetRepository.addSet(captureAny())).captured.single
            as WorkoutSet;

    expect(captured.ownerUserId, 'user-123');
  });

  test('keeps guest workout set owner unchanged', () async {
    when(
      () => appSessionRepository.getCurrentSession(),
    ).thenAnswer((_) async => const Right(AppSession.guest()));

    await usecase(baseSet);

    final captured =
        verify(() => workoutSetRepository.addSet(captureAny())).captured.single
            as WorkoutSet;

    expect(captured.ownerUserId, isNull);
  });

  test('falls back to original set when session lookup fails', () async {
    when(
      () => appSessionRepository.getCurrentSession(),
    ).thenAnswer((_) async => Left(CacheFailure('session unavailable')));

    await usecase(baseSet);

    final captured =
        verify(() => workoutSetRepository.addSet(captureAny())).captured.single
            as WorkoutSet;

    expect(captured.ownerUserId, isNull);
  });

  test('triggers full muscle stimulus rebuild after successful add', () async {
    when(() => appSessionRepository.getCurrentSession()).thenAnswer(
      (_) async => Right(
        AppSession(
          authMode: AuthMode.authenticated,
          user: const AppUser(id: 'user-123', email: 'user@test.com'),
        ),
      ),
    );

    await usecase(baseSet);

    verify(() => mockRebuild('user-123')).called(1);
  });

  test('does not trigger rebuild when repository add fails', () async {
    when(
      () => workoutSetRepository.addSet(any()),
    ).thenAnswer((_) async => const Left(DatabaseFailure('write failed')));
    when(
      () => appSessionRepository.getCurrentSession(),
    ).thenAnswer((_) async => const Right(AppSession.guest()));

    await usecase(baseSet);

    verifyNever(() => mockRebuild(any()));
  });
}

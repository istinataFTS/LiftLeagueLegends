import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_session.dart';
import 'package:fitness_tracker/domain/entities/app_user.dart';
import 'package:fitness_tracker/domain/repositories/app_session_repository.dart';
import 'package:fitness_tracker/domain/repositories/stimulus_rebuild_flag_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/run_pending_stimulus_rebuild.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStimulusRebuildFlagRepository extends Mock
    implements StimulusRebuildFlagRepository {}

class MockAppSessionRepository extends Mock implements AppSessionRepository {}

class MockRebuildMuscleStimulusFromWorkoutHistory extends Mock
    implements RebuildMuscleStimulusFromWorkoutHistory {}

const _session = AppSession(
  user: AppUser(id: 'user-1', email: 'test@example.com'),
);

void main() {
  late MockStimulusRebuildFlagRepository flagRepo;
  late MockAppSessionRepository sessionRepo;
  late MockRebuildMuscleStimulusFromWorkoutHistory rebuild;
  late RunPendingStimulusRebuild useCase;

  setUp(() {
    flagRepo = MockStimulusRebuildFlagRepository();
    sessionRepo = MockAppSessionRepository();
    rebuild = MockRebuildMuscleStimulusFromWorkoutHistory();
    useCase = RunPendingStimulusRebuild(
      flagRepository: flagRepo,
      appSessionRepository: sessionRepo,
      rebuild: rebuild,
    );
  });

  test('no-op when flag is not pending', () async {
    when(() => flagRepo.isPending()).thenAnswer((_) async => false);

    final result = await useCase();

    expect(result.isRight(), isTrue);
    verifyNever(() => sessionRepo.getCurrentSession());
    verifyNever(() => rebuild(any()));
    verifyNever(() => flagRepo.clear());
  });

  test(
    'rebuilds for the session user and clears the flag on success',
    () async {
      when(() => flagRepo.isPending()).thenAnswer((_) async => true);
      when(
        () => sessionRepo.getCurrentSession(),
      ).thenAnswer((_) async => const Right(_session));
      when(() => rebuild('user-1')).thenAnswer((_) async => const Right(null));
      when(() => flagRepo.clear()).thenAnswer((_) async {});

      final result = await useCase();

      expect(result.isRight(), isTrue);
      verify(() => rebuild('user-1')).called(1);
      verify(() => flagRepo.clear()).called(1);
    },
  );

  test('does not clear the flag when no session is available', () async {
    when(() => flagRepo.isPending()).thenAnswer((_) async => true);
    when(
      () => sessionRepo.getCurrentSession(),
    ).thenAnswer((_) async => const Left(AuthFailure('no session')));

    final result = await useCase();

    expect(result.isLeft(), isTrue);
    verifyNever(() => rebuild(any()));
    verifyNever(() => flagRepo.clear());
  });

  test('does not clear the flag when the rebuild fails', () async {
    when(() => flagRepo.isPending()).thenAnswer((_) async => true);
    when(
      () => sessionRepo.getCurrentSession(),
    ).thenAnswer((_) async => const Right(_session));
    when(
      () => rebuild('user-1'),
    ).thenAnswer((_) async => const Left(DatabaseFailure('boom')));

    final result = await useCase();

    expect(result.isLeft(), isTrue);
    verifyNever(() => flagRepo.clear());
  });
}

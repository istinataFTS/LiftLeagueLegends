import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/sync_trigger.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/core/sync/hooks/muscle_factor_heal_hook.dart';
import 'package:fitness_tracker/core/sync/post_sync_hook.dart';
import 'package:fitness_tracker/domain/usecases/muscle_factors/seed_exercise_factors.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSeedExerciseFactors extends Mock implements SeedExerciseFactors {}

void main() {
  late _MockSeedExerciseFactors seed;
  late MuscleFactorHealHook hook;

  PostSyncContext contextFor(Set<String> pulled) => PostSyncContext(
    userId: 'user-1',
    pulledFeatures: pulled,
    trigger: SyncTrigger.appLaunch,
  );

  setUp(() {
    seed = _MockSeedExerciseFactors();
    hook = MuscleFactorHealHook(seedExerciseFactors: seed);
  });

  test('declares itself as triggering on exercises pulls only', () {
    expect(hook.triggeringFeatures, equals(<String>{'exercises'}));
  });

  test('invokes the heal use case with the healing flag set', () async {
    when(
      () => seed(allowHealingWhenEmpty: true),
    ).thenAnswer((_) async => const Right(3));

    await hook.run(contextFor(const {'exercises'}));

    verify(() => seed(allowHealingWhenEmpty: true)).called(1);
  });

  test('swallows failures so the sync is not downgraded', () async {
    when(
      () => seed(allowHealingWhenEmpty: true),
    ).thenAnswer((_) async => const Left(DatabaseFailure('boom')));

    await expectLater(hook.run(contextFor(const {'exercises'})), completes);
  });

  test('is idempotent — a zero-heal result is a no-op by design', () async {
    when(
      () => seed(allowHealingWhenEmpty: true),
    ).thenAnswer((_) async => const Right(0));

    await hook.run(contextFor(const {'exercises'}));

    verify(() => seed(allowHealingWhenEmpty: true)).called(1);
  });
}

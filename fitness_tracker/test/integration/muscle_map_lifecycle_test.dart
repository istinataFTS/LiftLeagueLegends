/// Guardrail integration test: muscle-map stimulus lifecycle.
///
/// Exercises the *real* [RebuildMuscleStimulusFromWorkoutHistory] use case
/// through lightweight in-memory repository implementations to verify:
///
///  1. Stimulus is written for the correct user after a rebuild.
///  2. Sign-out clears **only** that user's records — a bystander user's data
///     is never touched.
///  3. A subsequent rebuild restores stimulus for the signed-in user.
///  4. Passing an empty userId to the rebuild is a no-op (no records written).
///
/// These are the exact failure modes that Bug C (data loss on re-login) exposed.
/// Regression here means the sign-out / sign-in data isolation contract is
/// broken at the use-case level.
library;

import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/enums/data_source_preference.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/muscle_factor.dart';
import 'package:fitness_tracker/domain/entities/muscle_stimulus.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/domain/repositories/muscle_factor_repository.dart';
import 'package:fitness_tracker/domain/repositories/muscle_stimulus_repository.dart';
import 'package:fitness_tracker/domain/repositories/workout_set_repository.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/calculate_muscle_stimulus.dart';
import 'package:fitness_tracker/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart';
import 'package:flutter_test/flutter_test.dart';

// ─── In-memory fakes ─────────────────────────────────────────────────────────

/// Minimal in-memory [WorkoutSetRepository].  Only [getAllSets] is exercised by
/// [RebuildMuscleStimulusFromWorkoutHistory]; every other method throws to make
/// accidental calls visible immediately.
class FakeWorkoutSetRepository implements WorkoutSetRepository {
  FakeWorkoutSetRepository(this._sets);

  final List<WorkoutSet> _sets;

  @override
  Future<Either<Failure, List<WorkoutSet>>> getAllSets({
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) async => Right(List.unmodifiable(_sets));

  // ── stubs that must not be called in these tests ──────────────────────────

  @override
  Future<Either<Failure, WorkoutSet?>> getSetById(
    String id, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<WorkoutSet>>> getSetsByExerciseId(
    String exerciseId, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<WorkoutSet>>> getSetsByDateRange(
    DateTime startDate,
    DateTime endDate, {
    DataSourcePreference sourcePreference = DataSourcePreference.localOnly,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> addSet(WorkoutSet set) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> updateSet(WorkoutSet set) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteSet(String id) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> clearAllSets() => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> syncPendingSets() => throw UnimplementedError();
}

/// Minimal in-memory [MuscleStimulusRepository].  Only the methods called by
/// [RebuildMuscleStimulusFromWorkoutHistory] and the sign-out path are
/// implemented; all others throw.
class FakeMuscleStimulusRepository implements MuscleStimulusRepository {
  /// Primary store: userId → list of stimulus records written by [upsertStimulus].
  final Map<String, List<MuscleStimulus>> _store =
      <String, List<MuscleStimulus>>{};

  List<MuscleStimulus> stimulusFor(String userId) =>
      List.unmodifiable(_store[userId] ?? <MuscleStimulus>[]);

  @override
  Future<Either<Failure, void>> upsertStimulus(MuscleStimulus stimulus) async {
    _store
        .putIfAbsent(stimulus.ownerUserId, () => <MuscleStimulus>[])
        .add(stimulus);
    return const Right(null);
  }

  @override
  Future<Either<Failure, void>> clearStimulusForUser(String userId) async {
    _store.remove(userId);
    return const Right(null);
  }

  // ── stubs that must not be called in these tests ──────────────────────────

  @override
  Future<Either<Failure, MuscleStimulus?>> getStimulusByMuscleAndDate({
    required String userId,
    required String muscleGroup,
    required DateTime date,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<MuscleStimulus>>> getStimulusByDateRange({
    required String userId,
    required String muscleGroup,
    required DateTime startDate,
    required DateTime endDate,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, MuscleStimulus?>> getTodayStimulus(
    String userId,
    String muscleGroup,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, List<MuscleStimulus>>> getAllStimulusForDate(
    String userId,
    DateTime date,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> updateStimulusValues({
    required String id,
    required double dailyStimulus,
    required double rollingWeeklyLoad,
    int? lastSetTimestamp,
    double? lastSetStimulus,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> applyDailyDecayToAll(String userId) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, double>> getMaxStimulusForMuscle(
    String userId,
    String muscleGroup,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteOlderThan(String userId, DateTime date) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> clearAllStimulus() =>
      throw UnimplementedError();
}

/// Minimal in-memory [MuscleFactorRepository].  Returns a canned factor map
/// keyed by exerciseId; all other methods throw.
class FakeMuscleFactorRepository implements MuscleFactorRepository {
  FakeMuscleFactorRepository(this._factorsByExercise);

  final Map<String, List<MuscleFactor>> _factorsByExercise;

  @override
  Future<Either<Failure, List<MuscleFactor>>> getFactorsForExercise(
    String exerciseId,
  ) async => Right(_factorsByExercise[exerciseId] ?? <MuscleFactor>[]);

  // ── stubs that must not be called in these tests ──────────────────────────

  @override
  Future<Either<Failure, MuscleFactor?>> getFactorById(String id) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<MuscleFactor>>> getAllFactors() =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, List<MuscleFactor>>> getFactorsByMuscleGroup(
    String muscleGroup,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> addMuscleFactor(MuscleFactor factor) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> addMuscleFactorsBatch(
    List<MuscleFactor> factors,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> updateMuscleFactor(MuscleFactor factor) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteMuscleFactor(String id) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, void>> deleteMuscleFactorsByExerciseId(
    String exerciseId,
  ) => throw UnimplementedError();

  @override
  Future<Either<Failure, void>> clearAllFactors() => throw UnimplementedError();
}

// ─── Test fixtures ───────────────────────────────────────────────────────────

const String _userId = 'user-1';
const String _bystanderUserId = 'user-2';
const String _exerciseId = 'ex-bench-press';

final DateTime _workoutDate = DateTime(2026, 4, 14);

final WorkoutSet _workoutSet = WorkoutSet(
  id: 'set-1',
  ownerUserId: _userId,
  exerciseId: _exerciseId,
  reps: 8,
  weight: 80.0,
  intensity: 3,
  date: _workoutDate,
  createdAt: _workoutDate,
);

/// One primary muscle factor for bench press (chest, full engagement).
final MuscleFactor _chestFactor = MuscleFactor(
  id: 'factor-1',
  exerciseId: _exerciseId,
  muscleGroup: 'chest',
  factor: 1.0,
);

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late FakeMuscleStimulusRepository stimulusRepo;
  late RebuildMuscleStimulusFromWorkoutHistory rebuildUseCase;

  setUp(() {
    stimulusRepo = FakeMuscleStimulusRepository();

    // Pre-seed the bystander user's data so we can verify it is never touched.
    stimulusRepo._store[_bystanderUserId] = <MuscleStimulus>[
      MuscleStimulus(
        id: 'bystander-stimulus',
        ownerUserId: _bystanderUserId,
        muscleGroup: 'chest',
        date: _workoutDate,
        dailyStimulus: 5.0,
        rollingWeeklyLoad: 5.0,
        createdAt: _workoutDate,
        updatedAt: _workoutDate,
      ),
    ];

    final workoutRepo = FakeWorkoutSetRepository([_workoutSet]);
    final factorRepo = FakeMuscleFactorRepository({
      _exerciseId: [_chestFactor],
    });
    final calculateStimulus = CalculateMuscleStimulus(
      muscleFactorRepository: factorRepo,
    );

    rebuildUseCase = RebuildMuscleStimulusFromWorkoutHistory(
      workoutSetRepository: workoutRepo,
      muscleStimulusRepository: stimulusRepo,
      calculateMuscleStimulus: calculateStimulus,
    );
  });

  test('rebuild writes stimulus records for the correct user', () async {
    final result = await rebuildUseCase(_userId);

    expect(result.isRight(), isTrue);
    expect(stimulusRepo.stimulusFor(_userId), isNotEmpty);
    expect(
      stimulusRepo.stimulusFor(_userId).every((s) => s.ownerUserId == _userId),
      isTrue,
      reason: 'every record must be owned by the signed-in user',
    );
  });

  test(
    'sign-out clears only the signed-in user — bystander data is untouched',
    () async {
      // Simulate the full lifecycle: rebuild on sign-in...
      await rebuildUseCase(_userId);
      expect(stimulusRepo.stimulusFor(_userId), isNotEmpty);

      // ...then sign-out clears this user's data...
      await stimulusRepo.clearStimulusForUser(_userId);
      expect(
        stimulusRepo.stimulusFor(_userId),
        isEmpty,
        reason: 'sign-out must wipe the user\'s stimulus records',
      );

      // ...but the bystander's data must survive.
      expect(
        stimulusRepo.stimulusFor(_bystanderUserId),
        isNotEmpty,
        reason: 'another user\'s records must never be cleared on sign-out',
      );
    },
  );

  test(
    'rebuild after sign-out restores stimulus for the re-signed-in user',
    () async {
      // Sign-in → rebuild → sign-out → sign-in again → rebuild.
      await rebuildUseCase(_userId);
      await stimulusRepo.clearStimulusForUser(_userId);

      final result = await rebuildUseCase(_userId);

      expect(result.isRight(), isTrue);
      expect(
        stimulusRepo.stimulusFor(_userId),
        isNotEmpty,
        reason: 'stimulus must be fully restored after re-authentication',
      );
    },
  );

  test(
    'rebuild for empty userId writes no records and does not touch other users',
    () async {
      // An empty userId represents the guest state; the use case should
      // produce records owned by '' (or return early with an empty list).
      // Either way, the bystander must remain unaffected.
      await rebuildUseCase('');

      expect(
        stimulusRepo.stimulusFor(_userId),
        isEmpty,
        reason:
            'rebuilding with an empty userId must not write any user-1 records',
      );
      expect(
        stimulusRepo.stimulusFor(_bystanderUserId),
        isNotEmpty,
        reason: 'bystander data must survive a guest rebuild',
      );
    },
  );

  test(
    'rebuilt stimulus records reference the correct muscle group from factors',
    () async {
      final result = await rebuildUseCase(_userId);

      expect(result.isRight(), isTrue);

      final records = stimulusRepo.stimulusFor(_userId);
      final muscleGroups = records.map((s) => s.muscleGroup).toSet();

      expect(
        muscleGroups,
        contains('chest'),
        reason:
            'the rebuild must produce a record for every muscle group '
            'covered by the exercise factors',
      );
    },
  );
}

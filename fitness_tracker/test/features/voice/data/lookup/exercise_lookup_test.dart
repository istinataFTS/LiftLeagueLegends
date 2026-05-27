import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/usecases/exercises/get_all_exercises.dart';
import 'package:fitness_tracker/features/voice/data/lookup/exercise_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGetAllExercises extends Mock implements GetAllExercises {}

Exercise _ex(String id, String name) => Exercise(
  id: id,
  name: name,
  muscleGroups: const [],
  createdAt: DateTime(2026),
);

void main() {
  late MockGetAllExercises mockUseCase;
  late ExerciseLookup lookup;

  final benchPress = _ex('ex-1', 'Bench Press');
  final squat = _ex('ex-2', 'Squat');
  final inclineBench = _ex('ex-3', 'Incline Bench Press');

  setUp(() {
    mockUseCase = MockGetAllExercises();
    lookup = ExerciseLookup(mockUseCase);
  });

  group('refreshIfStale', () {
    test('fetches exercises on first call (cache starts dirty)', () async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat]));

      await lookup.refreshIfStale();

      expect(lookup.hasCached, isTrue);
      verify(mockUseCase.call).called(1);
    });

    test('is a no-op when cache is already fresh', () async {
      when(mockUseCase.call).thenAnswer((_) async => Right([benchPress]));

      await lookup.refreshIfStale();
      await lookup.refreshIfStale(); // second call — cache is still fresh

      verify(mockUseCase.call).called(1);
    });

    test(
      'handles use case failure gracefully — cache stays empty, stays dirty',
      () async {
        when(
          mockUseCase.call,
        ).thenAnswer((_) async => Left(ServerFailure('error')));

        await lookup.refreshIfStale();

        expect(lookup.hasCached, isFalse);
      },
    );
  });

  group('invalidate + refreshIfStale', () {
    test('invalidate makes refreshIfStale reload on next call', () async {
      when(mockUseCase.call).thenAnswer((_) async => Right([benchPress]));
      await lookup.refreshIfStale(); // first load

      // Simulate library mutation: change what the repo returns
      final arnoldPress = _ex('ex-99', 'Arnold Press');
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, arnoldPress]));

      lookup.invalidate();
      await lookup.refreshIfStale(); // should reload

      expect(lookup.byName('Arnold Press'), arnoldPress);
      verify(mockUseCase.call).called(2);
    });

    test(
      'refreshIfStale is a no-op when not dirty after invalidate+reload',
      () async {
        when(mockUseCase.call).thenAnswer((_) async => Right([benchPress]));
        await lookup.refreshIfStale();
        lookup.invalidate();
        await lookup.refreshIfStale(); // reloads
        await lookup.refreshIfStale(); // no-op — cache is fresh again

        verify(mockUseCase.call).called(2);
      },
    );

    test('invalidate followed by failed reload keeps cache dirty', () async {
      when(mockUseCase.call).thenAnswer((_) async => Right([benchPress]));
      await lookup.refreshIfStale(); // initial successful load

      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Left(ServerFailure('network error')));

      lookup.invalidate();
      await lookup.refreshIfStale(); // fails — _isDirty stays true

      // Next call should try again (still dirty)
      when(mockUseCase.call).thenAnswer((_) async => Right([squat]));
      await lookup.refreshIfStale();

      expect(lookup.byName('squat'), squat);
    });
  });

  group('byName — exact match', () {
    setUp(() async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat, inclineBench]));
      await lookup.refreshIfStale();
    });

    test('finds exact name (case-insensitive)', () {
      expect(lookup.byName('bench press'), benchPress);
      expect(lookup.byName('Bench Press'), benchPress);
      expect(lookup.byName('BENCH PRESS'), benchPress);
    });

    test('finds squat exactly', () {
      expect(lookup.byName('squat'), squat);
    });
  });

  group('byName — prefix/fuzzy match', () {
    setUp(() async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat, inclineBench]));
      await lookup.refreshIfStale();
    });

    test('resolves "bench" to "Bench Press" via starts-with', () {
      expect(lookup.byName('bench'), benchPress);
    });

    test('does not match mid-word prefix ("press" alone)', () {
      expect(lookup.byName('press'), isNull);
    });

    test('returns null when no exercise matches', () {
      expect(lookup.byName('deadlift'), isNull);
    });
  });

  group('resolveId', () {
    setUp(() async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat]));
      await lookup.refreshIfStale();
    });

    test('returns exercise id for known name', () {
      expect(lookup.resolveId('bench press'), 'ex-1');
    });

    test('returns null for unknown name', () {
      expect(lookup.resolveId('deadlift'), isNull);
    });
  });

  group('nameForId', () {
    setUp(() async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat]));
      await lookup.refreshIfStale();
    });

    test('returns name for known id', () {
      expect(lookup.nameForId('ex-1'), 'Bench Press');
      expect(lookup.nameForId('ex-2'), 'Squat');
    });

    test('returns the id itself as fallback for unknown ids', () {
      expect(lookup.nameForId('unknown-id'), 'unknown-id');
    });
  });

  group('findByName (async)', () {
    test('warms cache and resolves in one call', () async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat]));

      final result = await lookup.findByName('squat');
      expect(result, squat);
    });

    test('returns null when no match after cache warm', () async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat]));

      final result = await lookup.findByName('deadlift');
      expect(result, isNull);
    });

    test('reloads after invalidate via findByName', () async {
      when(mockUseCase.call).thenAnswer((_) async => Right([benchPress]));
      await lookup.findByName('bench press');

      final arnoldPress = _ex('ex-99', 'Arnold Press');
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, arnoldPress]));

      lookup.invalidate();
      final result = await lookup.findByName('Arnold Press');
      expect(result, arnoldPress);
    });
  });
}

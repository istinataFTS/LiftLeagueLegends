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

  group('refreshIfEmpty', () {
    test('fetches exercises when cache is empty', () async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat]));

      await lookup.refreshIfEmpty();

      expect(lookup.hasCached, isTrue);
      verify(mockUseCase.call).called(1);
    });

    test('does not fetch again when cache is already populated', () async {
      when(mockUseCase.call).thenAnswer((_) async => Right([benchPress]));

      await lookup.refreshIfEmpty();
      await lookup.refreshIfEmpty(); // second call should be no-op

      verify(mockUseCase.call).called(1);
    });

    test('handles use case failure gracefully — cache stays empty', () async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Left(ServerFailure('error')));

      await lookup.refreshIfEmpty();

      expect(lookup.hasCached, isFalse);
    });
  });

  group('byName — exact match', () {
    setUp(() async {
      when(
        mockUseCase.call,
      ).thenAnswer((_) async => Right([benchPress, squat, inclineBench]));
      await lookup.refreshIfEmpty();
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
      await lookup.refreshIfEmpty();
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
      await lookup.refreshIfEmpty();
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
      await lookup.refreshIfEmpty();
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
  });
}

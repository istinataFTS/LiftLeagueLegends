import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/repositories/meal_repository.dart';
import 'package:fitness_tracker/features/voice/data/lookup/meal_lookup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockMealRepository extends Mock implements MealRepository {}

Meal _meal(String id, String name) => Meal(
  id: id,
  name: name,
  servingSizeGrams: 100,
  carbsPer100g: 20,
  proteinPer100g: 10,
  fatPer100g: 5,
  caloriesPer100g: 165,
  createdAt: DateTime(2026),
  syncMetadata: const EntitySyncMetadata(),
);

void main() {
  late MockMealRepository mockRepo;
  late MealLookup lookup;

  final chicken = _meal('m-1', 'Chicken Breast');
  final oats = _meal('m-2', 'Oats');
  final chickenSalad = _meal('m-3', 'Chicken Salad');

  setUp(() {
    mockRepo = MockMealRepository();
    lookup = MealLookup(mockRepo);
  });

  group('findByName — exact match', () {
    test('returns meal on exact match', () async {
      when(
        () => mockRepo.getMealByName('Chicken Breast'),
      ).thenAnswer((_) async => Right(chicken));

      final result = await lookup.findByName('Chicken Breast');
      expect(result, chicken);
    });

    test('returns null when repo returns null on exact lookup', () async {
      when(
        () => mockRepo.getMealByName('protein bar'),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => mockRepo.searchMealsByName('protein bar'),
      ).thenAnswer((_) async => const Right([]));

      final result = await lookup.findByName('protein bar');
      expect(result, isNull);
    });
  });

  group('findByName — prefix fallback', () {
    setUp(() {
      when(
        () => mockRepo.getMealByName(any()),
      ).thenAnswer((_) async => const Right(null));
    });

    test('returns starts-with match from search results', () async {
      when(
        () => mockRepo.searchMealsByName('chicken'),
      ).thenAnswer((_) async => Right([chicken, chickenSalad]));

      final result = await lookup.findByName('chicken');
      expect(result, chicken); // first starts-with match
    });

    test(
      'returns first search result as loose fallback when no prefix match',
      () async {
        when(
          () => mockRepo.searchMealsByName('sal'),
        ).thenAnswer((_) async => Right([chickenSalad]));

        final result = await lookup.findByName('sal');
        expect(result, chickenSalad);
      },
    );
  });

  group('findByName — error handling', () {
    test('returns null when exact lookup fails and search is empty', () async {
      when(
        () => mockRepo.getMealByName(any()),
      ).thenAnswer((_) async => Left(ServerFailure('db error')));
      when(
        () => mockRepo.searchMealsByName(any()),
      ).thenAnswer((_) async => const Right([]));

      final result = await lookup.findByName('anything');
      expect(result, isNull);
    });

    test('returns null on empty spoken name', () async {
      final result = await lookup.findByName('');
      expect(result, isNull);
      verifyNever(() => mockRepo.getMealByName(any()));
    });

    test('trims whitespace before querying', () async {
      when(
        () => mockRepo.getMealByName('oats'),
      ).thenAnswer((_) async => Right(oats));

      final result = await lookup.findByName('  oats  ');
      expect(result, oats);
    });
  });
}

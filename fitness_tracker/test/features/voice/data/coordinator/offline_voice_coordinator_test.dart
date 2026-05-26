import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:fitness_tracker/domain/entities/nutrition_log.dart';
import 'package:fitness_tracker/domain/entities/voice_chat_result.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:fitness_tracker/features/voice/data/coordinator/offline_voice_coordinator.dart';
import 'package:fitness_tracker/features/voice/data/lookup/exercise_lookup.dart';
import 'package:fitness_tracker/features/voice/data/lookup/meal_lookup.dart';
import 'package:fitness_tracker/features/voice/data/lookup/recent_entity_lookup.dart';
import 'package:fitness_tracker/features/voice/data/parser/intent_parser.dart';
import 'package:fitness_tracker/features/voice/data/parser/matchers/nutrition_matchers.dart';
import 'package:fitness_tracker/features/voice/data/parser/matchers/query_matchers.dart';
import 'package:fitness_tracker/features/voice/data/parser/matchers/workout_set_matchers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockExerciseLookup extends Mock implements ExerciseLookup {}

class MockMealLookup extends Mock implements MealLookup {}

class MockRecentEntityLookup extends Mock implements RecentEntityLookup {}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

final _benchExercise = Exercise(
  id: 'ex-bench',
  name: 'Bench Press',
  muscleGroups: ['mid-chest'],
  createdAt: DateTime(2026, 5, 1),
);

final _recentSet = WorkoutSet(
  id: 'set-1',
  exerciseId: 'ex-bench',
  reps: 10,
  weight: 80.0,
  intensity: 5,
  date: DateTime(2026, 5, 15),
  createdAt: DateTime(2026, 5, 15),
  syncMetadata: const EntitySyncMetadata(),
);

final _recentLog = NutritionLog(
  id: 'log-1',
  mealName: 'Oats',
  proteinGrams: 10,
  carbsGrams: 30,
  fatGrams: 5,
  calories: 200,
  loggedAt: DateTime(2026, 5, 15, 8),
  createdAt: DateTime(2026, 5, 15, 8),
);

Meal _fakeMeal({required String id, required String name}) => Meal(
  id: id,
  name: name,
  servingSizeGrams: 100,
  proteinPer100g: 10,
  carbsPer100g: 50,
  fatPer100g: 5,
  caloriesPer100g: 300,
  createdAt: DateTime(2026),
);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

IntentParser _buildParser() => IntentParser([
  matchDeleteWorkoutSet,
  matchEditWorkoutSet,
  matchLogWorkoutSet,
  matchDeleteNutrition,
  matchEditNutrition,
  matchLogNutrition,
  matchQueryWeeklyVolume,
  matchQueryDailyMacros,
  matchQueryRecentSets,
]);

void main() {
  late MockExerciseLookup exerciseLookup;
  late MockMealLookup mealLookup;
  late MockRecentEntityLookup recentEntityLookup;
  late OfflineVoiceCoordinator coordinator;

  setUp(() {
    exerciseLookup = MockExerciseLookup();
    mealLookup = MockMealLookup();
    recentEntityLookup = MockRecentEntityLookup();

    coordinator = OfflineVoiceCoordinator(
      parser: _buildParser(),
      exerciseLookup: exerciseLookup,
      mealLookup: mealLookup,
      recentEntityLookup: recentEntityLookup,
    );

    // Default: lookups return nothing.
    when(() => exerciseLookup.refreshIfEmpty()).thenAnswer((_) async {});
    when(() => exerciseLookup.findByName(any())).thenAnswer((_) async => null);
    when(() => mealLookup.findByName(any())).thenAnswer((_) async => null);
    when(
      () => recentEntityLookup.mostRecentSet(),
    ).thenAnswer((_) async => null);
    when(
      () => recentEntityLookup.mostRecentLog(),
    ).thenAnswer((_) async => null);
  });

  // =========================================================================
  // Log workout set
  // =========================================================================

  group('log workout set', () {
    test('returns mutation call when exercise is found', () async {
      when(
        () => exerciseLookup.findByName('bench press'),
      ).thenAnswer((_) async => _benchExercise);

      final result = await coordinator.process('log bench press 80 kg 10 reps');

      expect(result, isA<VoiceChatMutationCall>());
      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.toolName, 'logWorkoutSet');
      expect(tc.args['exerciseId'], 'ex-bench');
      expect(tc.args['reps'], 10);
      expect(tc.args['weight'], 80.0);
      expect(tc.displaySummary, contains('Bench Press'));
    });

    test('returns error text when exercise is not found', () async {
      final result = await coordinator.process('log unknown exercise 80 kg 10');

      expect(result, isA<VoiceChatTextResponse>());
      final msg = (result as VoiceChatTextResponse).message.content;
      expect(msg, AppStrings.voiceOfflineExerciseNotFound);
    });

    test('display summary includes weight unit', () async {
      when(
        () => exerciseLookup.findByName(any()),
      ).thenAnswer((_) async => _benchExercise);

      final result = await coordinator.process('log bench press 80 kg 10 reps');
      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.displaySummary, contains('kg'));
    });

    test(
      'defaults to kg when user unit is kilograms and no unit spoken',
      () async {
        when(
          () => exerciseLookup.findByName(any()),
        ).thenAnswer((_) async => _benchExercise);

        final result = await coordinator.process('log bench press 80 by 10');
        final tc = (result as VoiceChatMutationCall).toolCall;
        expect(tc.displaySummary, contains('kg'));
      },
    );
  });

  // =========================================================================
  // Edit workout set
  // =========================================================================

  group('edit workout set', () {
    test('returns mutation call when recent set exists', () async {
      when(
        () => recentEntityLookup.mostRecentSet(),
      ).thenAnswer((_) async => _recentSet);

      final result = await coordinator.process('change the weight to 90 kg');

      expect(result, isA<VoiceChatMutationCall>());
      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.toolName, 'editWorkoutSet');
      expect(tc.args['setId'], 'set-1');
      expect(tc.args['weight'], 90.0);
    });

    test('returns error text when no recent set', () async {
      final result = await coordinator.process('change the weight to 90 kg');

      expect(result, isA<VoiceChatTextResponse>());
      expect(
        (result as VoiceChatTextResponse).message.content,
        AppStrings.voiceOfflineNoRecentSet,
      );
    });

    test('patches only reps when reps-only edit', () async {
      when(
        () => recentEntityLookup.mostRecentSet(),
      ).thenAnswer((_) async => _recentSet);

      final result = await coordinator.process('update reps to 8');

      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.args.containsKey('reps'), isTrue);
      expect(tc.args['reps'], 8);
      expect(tc.args.containsKey('weight'), isFalse);
    });
  });

  // =========================================================================
  // Delete workout set
  // =========================================================================

  group('delete workout set', () {
    test('returns mutation call when recent set exists', () async {
      when(
        () => recentEntityLookup.mostRecentSet(),
      ).thenAnswer((_) async => _recentSet);

      final result = await coordinator.process('delete my last set');

      expect(result, isA<VoiceChatMutationCall>());
      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.toolName, 'deleteWorkoutSet');
      expect(tc.args['setId'], 'set-1');
    });

    test('returns error text when no recent set', () async {
      final result = await coordinator.process('delete my last set');

      expect(result, isA<VoiceChatTextResponse>());
      expect(
        (result as VoiceChatTextResponse).message.content,
        AppStrings.voiceOfflineNoRecentSet,
      );
    });
  });

  // =========================================================================
  // Log nutrition
  // =========================================================================

  group('log nutrition', () {
    test('returns mutation call with mealName and calories', () async {
      final result = await coordinator.process('log oats 300 calories');

      expect(result, isA<VoiceChatMutationCall>());
      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.toolName, 'logNutrition');
      expect(tc.args['mealName'], 'oats');
      expect(tc.args['calories'], 300.0);
    });

    test('includes mealId when meal is resolved from library', () async {
      final oatsMeal = _fakeMeal(id: 'meal-oats', name: 'Oats');
      when(
        () => mealLookup.findByName('oats'),
      ).thenAnswer((_) async => oatsMeal);

      final result = await coordinator.process('log oats 300 calories');

      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.args['mealId'], 'meal-oats');
    });

    test('proceeds without mealId when meal not in library', () async {
      final result = await coordinator.process(
        'log homemade stew 450 calories',
      );

      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.args.containsKey('mealId'), isFalse);
      expect(tc.args['mealName'], 'homemade stew');
    });

    test('includes macro fields when provided', () async {
      final result = await coordinator.process(
        'log chicken breast 200 calories 30 protein 5 fat',
      );

      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.args['proteinGrams'], 30.0);
      expect(tc.args['fatGrams'], 5.0);
    });
  });

  // =========================================================================
  // Edit nutrition
  // =========================================================================

  group('edit nutrition', () {
    test('returns editNutritionLog mutation when recent log exists', () async {
      when(
        () => recentEntityLookup.mostRecentLog(),
      ).thenAnswer((_) async => _recentLog);

      final result = await coordinator.process('change the calories to 300');

      expect(result, isA<VoiceChatMutationCall>());
      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.toolName, 'editNutritionLog');
      expect(tc.args['logId'], 'log-1');
      expect(tc.args['calories'], 300.0);
      expect(tc.args.containsKey('proteinGrams'), isFalse);
    });

    test('patches only protein when protein-only edit', () async {
      when(
        () => recentEntityLookup.mostRecentLog(),
      ).thenAnswer((_) async => _recentLog);

      final result = await coordinator.process('update protein to 40 grams');

      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.toolName, 'editNutritionLog');
      expect(tc.args['proteinGrams'], 40.0);
      expect(tc.args.containsKey('calories'), isFalse);
    });

    test('returns error text when no recent log', () async {
      final result = await coordinator.process('change the calories to 300');

      expect(result, isA<VoiceChatTextResponse>());
      expect(
        (result as VoiceChatTextResponse).message.content,
        AppStrings.voiceOfflineNoRecentLog,
      );
    });
  });

  // =========================================================================
  // Delete nutrition
  // =========================================================================

  group('delete nutrition', () {
    test('returns mutation call when recent log exists', () async {
      when(
        () => recentEntityLookup.mostRecentLog(),
      ).thenAnswer((_) async => _recentLog);

      final result = await coordinator.process('delete my last meal');

      expect(result, isA<VoiceChatMutationCall>());
      final tc = (result as VoiceChatMutationCall).toolCall;
      expect(tc.toolName, 'deleteNutritionLog');
      expect(tc.args['logId'], 'log-1');
    });

    test('returns error text when no recent log', () async {
      final result = await coordinator.process('delete my last meal');

      expect(result, isA<VoiceChatTextResponse>());
      expect(
        (result as VoiceChatTextResponse).message.content,
        AppStrings.voiceOfflineNoRecentLog,
      );
    });
  });

  // =========================================================================
  // Query intents
  // =========================================================================

  group('query intents', () {
    test('weekly volume → VoiceChatQueryCall getWeeklyVolume', () async {
      final result = await coordinator.process('what is my weekly volume');
      expect(result, isA<VoiceChatQueryCall>());
      expect((result as VoiceChatQueryCall).toolName, 'getWeeklyVolume');
    });

    test('daily macros → VoiceChatQueryCall getDailyMacros', () async {
      final result = await coordinator.process('what are my macros');
      expect(result, isA<VoiceChatQueryCall>());
      expect((result as VoiceChatQueryCall).toolName, 'getDailyMacros');
    });

    test('recent sets → VoiceChatQueryCall getRecentSets', () async {
      final result = await coordinator.process('show my recent sets');
      expect(result, isA<VoiceChatQueryCall>());
      expect((result as VoiceChatQueryCall).toolName, 'getRecentSets');
    });
  });

  // =========================================================================
  // Unrecognized
  // =========================================================================

  group('unrecognized', () {
    test('empty transcript → unrecognized text response', () async {
      final result = await coordinator.process('');
      expect(result, isA<VoiceChatTextResponse>());
      expect(
        (result as VoiceChatTextResponse).message.content,
        AppStrings.voiceOfflineUnrecognized,
      );
    });

    test('nonsense utterance → unrecognized text response', () async {
      final result = await coordinator.process('what is the meaning of life');
      expect(result, isA<VoiceChatTextResponse>());
      expect(
        (result as VoiceChatTextResponse).message.content,
        AppStrings.voiceOfflineUnrecognized,
      );
    });
  });
}

import 'package:uuid/uuid.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../../domain/entities/app_settings.dart' show WeightUnit;
import '../../../../domain/entities/voice_chat_result.dart';
import '../../../../domain/entities/voice_message.dart';
import '../../../../domain/entities/voice_tool_call.dart';
import '../grammar/units.dart';
import '../lookup/exercise_lookup.dart';
import '../lookup/meal_lookup.dart';
import '../lookup/recent_entity_lookup.dart';
import '../parser/intent_parser.dart';
import '../parser/parsed.dart';

/// Converts an offline-parsed [ParsedIntent] into a [VoiceChatResult],
/// resolving entity IDs asynchronously using the shared lookup helpers.
///
/// The returned [VoiceChatResult] is structurally identical to what
/// [VoiceSendMessage] returns online, so [VoiceBloc] handles both paths
/// with the same switch statement — no new code paths required.
class OfflineVoiceCoordinator {
  const OfflineVoiceCoordinator({
    required IntentParser parser,
    required ExerciseLookup exerciseLookup,
    required MealLookup mealLookup,
    required RecentEntityLookup recentEntityLookup,
  }) : _parser = parser,
       _exerciseLookup = exerciseLookup,
       _mealLookup = mealLookup,
       _recentEntityLookup = recentEntityLookup;

  final IntentParser _parser;
  final ExerciseLookup _exerciseLookup;
  final MealLookup _mealLookup;
  final RecentEntityLookup _recentEntityLookup;

  static const _uuid = Uuid();

  /// Parses [transcript] and returns a [VoiceChatResult] ready for VoiceBloc.
  ///
  /// [weightUnit] is used when the user did not specify a unit (e.g. "log
  /// bench 80 by 10") — the coordinator defaults to the user's preference.
  Future<VoiceChatResult> process(
    String transcript, {
    WeightUnit weightUnit = WeightUnit.kilograms,
  }) async {
    final intent = _parser.parse(transcript);
    return switch (intent) {
      ParsedLogWorkoutSet() => await _logSet(intent, weightUnit),
      ParsedEditWorkoutSet() => await _editSet(intent, weightUnit),
      ParsedDeleteWorkoutSet() => await _deleteSet(),
      ParsedLogNutrition() => await _logNutrition(intent),
      ParsedEditNutrition() => await _editNutrition(intent),
      ParsedDeleteNutrition() => await _deleteNutrition(),
      ParsedQueryWeeklyVolume() => _queryCall('getWeeklyVolume', {}),
      ParsedQueryDailyMacros() => _queryCall('getDailyMacros', {}),
      ParsedQueryRecentSets() => _queryCall('getRecentSets', {}),
      ParsedUnrecognized() => _errorResponse(
        AppStrings.voiceOfflineUnrecognized,
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Mutation handlers
  // ---------------------------------------------------------------------------

  Future<VoiceChatResult> _logSet(
    ParsedLogWorkoutSet intent,
    WeightUnit weightUnit,
  ) async {
    await _exerciseLookup.refreshIfStale();
    final exercise = await _exerciseLookup.findByName(intent.exerciseName);
    if (exercise == null) {
      return _errorResponse(AppStrings.voiceOfflineExerciseNotFound);
    }

    final unit = intent.weightUnit ?? _unitLabel(weightUnit);
    final summary =
        'Log: ${exercise.name} — ${intent.weight} $unit × ${intent.reps} reps';

    return VoiceChatMutationCall(
      toolCall: VoiceToolCall(
        id: _uuid.v4(),
        toolName: 'logWorkoutSet',
        displaySummary: summary,
        args: {
          'exerciseName': exercise.name,
          'exerciseId': exercise.id,
          'reps': intent.reps,
          'weight': intent.weight,
        },
      ),
    );
  }

  Future<VoiceChatResult> _editSet(
    ParsedEditWorkoutSet intent,
    WeightUnit weightUnit,
  ) async {
    final recent = await _recentEntityLookup.mostRecentSet();
    if (recent == null) {
      return _errorResponse(AppStrings.voiceOfflineNoRecentSet);
    }

    final newWeight = intent.weight;
    final newReps = intent.reps;
    final unit = intent.weightUnit ?? _unitLabel(weightUnit);

    final parts = <String>[];
    if (newWeight != null) parts.add('weight → $newWeight $unit');
    if (newReps != null) parts.add('reps → $newReps');
    final summary = 'Edit set: ${parts.join(', ')}';

    return VoiceChatMutationCall(
      toolCall: VoiceToolCall(
        id: _uuid.v4(),
        toolName: 'editWorkoutSet',
        displaySummary: summary,
        args: {
          'setId': recent.id,
          if (newWeight != null) 'weight': newWeight,
          if (newReps != null) 'reps': newReps,
        },
      ),
    );
  }

  Future<VoiceChatResult> _deleteSet() async {
    final recent = await _recentEntityLookup.mostRecentSet();
    if (recent == null) {
      return _errorResponse(AppStrings.voiceOfflineNoRecentSet);
    }
    return VoiceChatMutationCall(
      toolCall: VoiceToolCall(
        id: _uuid.v4(),
        toolName: 'deleteWorkoutSet',
        displaySummary: 'Delete last set',
        args: {'setId': recent.id},
      ),
    );
  }

  Future<VoiceChatResult> _logNutrition(ParsedLogNutrition intent) async {
    final meal = await _mealLookup.findByName(intent.mealName);
    final cal = intent.calories?.round() ?? 0;
    final summary = 'Log nutrition: ${intent.mealName} — $cal cal';

    return VoiceChatMutationCall(
      toolCall: VoiceToolCall(
        id: _uuid.v4(),
        toolName: 'logNutrition',
        displaySummary: summary,
        args: {
          'mealName': meal?.name ?? intent.mealName,
          if (meal != null) 'mealId': meal.id,
          if (intent.calories != null) 'calories': intent.calories,
          if (intent.proteinGrams != null) 'proteinGrams': intent.proteinGrams,
          if (intent.carbsGrams != null) 'carbsGrams': intent.carbsGrams,
          if (intent.fatGrams != null) 'fatGrams': intent.fatGrams,
        },
      ),
    );
  }

  Future<VoiceChatResult> _editNutrition(ParsedEditNutrition intent) async {
    final recent = await _recentEntityLookup.mostRecentLog();
    if (recent == null) {
      return _errorResponse(AppStrings.voiceOfflineNoRecentLog);
    }

    final parts = <String>[];
    if (intent.calories != null) {
      parts.add('calories → ${intent.calories!.round()}');
    }
    if (intent.proteinGrams != null) {
      parts.add('protein → ${intent.proteinGrams!.round()} g');
    }
    if (intent.carbsGrams != null) {
      parts.add('carbs → ${intent.carbsGrams!.round()} g');
    }
    if (intent.fatGrams != null) {
      parts.add('fat → ${intent.fatGrams!.round()} g');
    }
    final summary = 'Edit nutrition: ${parts.join(', ')}';

    return VoiceChatMutationCall(
      toolCall: VoiceToolCall(
        id: _uuid.v4(),
        toolName: 'editNutritionLog',
        displaySummary: summary,
        args: {
          'logId': recent.id,
          if (intent.calories != null) 'calories': intent.calories,
          if (intent.proteinGrams != null) 'proteinGrams': intent.proteinGrams,
          if (intent.carbsGrams != null) 'carbsGrams': intent.carbsGrams,
          if (intent.fatGrams != null) 'fatGrams': intent.fatGrams,
        },
      ),
    );
  }

  Future<VoiceChatResult> _deleteNutrition() async {
    final recent = await _recentEntityLookup.mostRecentLog();
    if (recent == null) {
      return _errorResponse(AppStrings.voiceOfflineNoRecentLog);
    }
    return VoiceChatMutationCall(
      toolCall: VoiceToolCall(
        id: _uuid.v4(),
        toolName: 'deleteNutritionLog',
        displaySummary: 'Delete last nutrition entry',
        args: {'logId': recent.id},
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Query / error helpers
  // ---------------------------------------------------------------------------

  VoiceChatResult _queryCall(String toolName, Map<String, dynamic> args) =>
      VoiceChatQueryCall(
        toolCallId: 'offline-$toolName',
        toolName: toolName,
        args: args,
      );

  VoiceChatResult _errorResponse(String message) => VoiceChatTextResponse(
    message: VoiceMessage(
      role: VoiceRole.assistant,
      content: message,
      createdAt: DateTime.now(),
    ),
  );

  static String _unitLabel(WeightUnit unit) =>
      unit == WeightUnit.pounds ? VoiceUnitGrammar.lbs : VoiceUnitGrammar.kg;
}

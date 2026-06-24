import 'package:dartz/dartz.dart';

import '../entities/app_settings.dart' show WeightUnit;
import '../entities/voice_budget.dart';
import '../entities/voice_chat_context.dart';
import '../entities/voice_chat_result.dart';
import '../entities/voice_message.dart';
import '../entities/voice_settings.dart';
import '../../core/errors/failures.dart';

abstract class VoiceRepository {
  /// Sends the user message + recent history to the `voice-chat`
  /// Edge Function and returns either a text reply, a mutation tool
  /// call requiring user confirmation, or a query tool call for
  /// local execution.
  ///
  /// [weightUnit] is required so the server's system prompt can
  /// confirm logs in the right unit. Passed explicitly because the
  /// repository must not reach into a global `AppSettings` — that
  /// would couple the voice flow to whichever bloc happens to have
  /// loaded settings first.
  Future<Either<Failure, VoiceChatResult>> chat({
    required String userMessage,
    required String sessionId,
    required List<VoiceMessage> history,
    required VoiceSettings settings,
    required WeightUnit weightUnit,
    List<RecentSetContext>? recentSets,
    List<RecentNutritionLogContext>? recentNutritionLogs,
  });

  /// Fetch the current user's daily voice budget (only `voice-chat`
  /// token cost is counted — STT/TTS are free).
  Future<Either<Failure, VoiceBudget>> getBudget();

  /// Delete all stored voice session history for the current user.
  /// Uses owner-DELETE RLS on `voice_sessions`.
  Future<Either<Failure, void>> deleteHistory();
}

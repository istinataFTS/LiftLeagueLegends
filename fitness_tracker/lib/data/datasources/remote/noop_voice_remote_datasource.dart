import 'dart:typed_data';

import '../../../core/constants/voice_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/app_settings.dart' show WeightUnit;
import '../../../domain/entities/voice_budget.dart';
import '../../../domain/entities/voice_chat_context.dart';
import '../../../domain/entities/voice_chat_result.dart';
import '../../../domain/entities/voice_message.dart';
import '../../../domain/entities/voice_settings.dart';
import 'voice_remote_datasource.dart';

/// Used when Supabase is not configured (local-only builds).
class NoopVoiceRemoteDataSource implements VoiceRemoteDataSource {
  const NoopVoiceRemoteDataSource();

  @override
  Future<VoiceChatResult> chat({
    required String userMessage,
    required String sessionId,
    required List<VoiceMessage> history,
    required VoiceSettings settings,
    required WeightUnit weightUnit,
    List<RecentSetContext>? recentSets,
    List<RecentNutritionLogContext>? recentNutritionLogs,
  }) async {
    throw const ServerFailure('Voice is not available in offline mode.');
  }

  @override
  Future<String> transcribe({
    required Uint8List audioBytes,
    required String filename,
    String? sessionId,
    String? language,
  }) async {
    throw const ServerFailure(
      'Voice transcription is not available in offline mode.',
    );
  }

  @override
  Future<VoiceBudget> getBudget() async => const VoiceBudget(
        usedUsd: 0,
        dailyCapUsd: VoiceConstants.dailyBudgetCapUsd,
      );

  @override
  Future<void> deleteHistory() async {}
}

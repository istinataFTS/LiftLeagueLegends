import 'dart:typed_data';

import '../../../domain/entities/app_settings.dart' show WeightUnit;
import '../../../domain/entities/voice_budget.dart';
import '../../../domain/entities/voice_chat_context.dart';
import '../../../domain/entities/voice_chat_result.dart';
import '../../../domain/entities/voice_message.dart';
import '../../../domain/entities/voice_settings.dart';

abstract class VoiceRemoteDataSource {
  Future<VoiceChatResult> chat({
    required String userMessage,
    required String sessionId,
    required List<VoiceMessage> history,
    required VoiceSettings settings,
    required WeightUnit weightUnit,
    List<RecentSetContext>? recentSets,
    List<RecentNutritionLogContext>? recentNutritionLogs,
  });

  /// Posts [audioBytes] to the `voice-transcribe` Edge Function and returns
  /// the recognised text. [filename] is sent in the multipart upload as the
  /// audio part's name — use the real file extension so Whisper picks the
  /// correct decoder (e.g. `utterance.m4a` for AAC, `utterance.wav` for PCM).
  Future<String> transcribe({
    required Uint8List audioBytes,
    required String filename,
    String? sessionId,
    String? language,
  });

  Future<VoiceBudget> getBudget();

  Future<void> deleteHistory();
}

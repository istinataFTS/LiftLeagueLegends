import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/date_serialization.dart';

import '../../../config/env_config.dart';
import '../../../core/constants/voice_constants.dart';
import '../../../core/errors/failures.dart';
import '../../../domain/entities/app_settings.dart' show WeightUnit;
import '../../../domain/entities/voice_budget.dart';
import '../../../domain/entities/voice_chat_context.dart';
import '../../../domain/entities/voice_chat_result.dart';
import '../../../domain/entities/voice_message.dart';
import '../../../domain/entities/voice_settings.dart';
import '../../../domain/entities/voice_tool_call.dart';
import 'supabase_client_provider.dart';
import 'voice_remote_datasource.dart';

class SupabaseVoiceRemoteDataSource implements VoiceRemoteDataSource {
  SupabaseVoiceRemoteDataSource({required this.clientProvider});

  final SupabaseClientProvider clientProvider;

  SupabaseClient get _supabase => clientProvider.client;

  /// Edge Functions base URL — constructed from the compile-time Supabase URL
  /// using the standard Supabase pattern: `$supabaseUrl/functions/v1`.
  String get _functionsBaseUrl => '${EnvConfig.supabaseUrl}/functions/v1';

  Future<String> _bearerToken() async {
    final session = _supabase.auth.currentSession;
    if (session == null) throw const ServerFailure('Not authenticated');
    return session.accessToken;
  }

  // ---------------------------------------------------------------------------
  // Chat (voice-chat)
  // ---------------------------------------------------------------------------

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
    final token = await _bearerToken();
    final uri = Uri.parse('$_functionsBaseUrl/voice-chat');

    final body = <String, dynamic>{
      'session_id': sessionId,
      'user_message': userMessage,
      'history': _serializeHistory(history),
      'context': _buildContext(
        weightUnit: weightUnit,
        recentSets: recentSets,
        recentNutritionLogs: recentNutritionLogs,
      ),
      'session_logging_enabled': settings.sessionLoggingEnabled,
    };

    final http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: <String, String>{
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(VoiceConstants.voiceChatHttpTimeout);
    } on TimeoutException {
      throw const ServerFailure(
        'TIMEOUT: Voice service did not respond in time',
      );
    }

    if (response.statusCode != 200) {
      _throwFromErrorBody(response.body, response.statusCode);
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    return parseResult(json);
  }

  // ---------------------------------------------------------------------------
  // Transcribe (voice-transcribe — Whisper)
  // ---------------------------------------------------------------------------

  @override
  Future<String> transcribe({
    required Uint8List audioBytes,
    required String filename,
    String? sessionId,
    String? language,
  }) async {
    final token = await _bearerToken();
    final uri = Uri.parse('$_functionsBaseUrl/voice-transcribe');

    final request = http.MultipartRequest('POST', uri)
      ..headers['Authorization'] = 'Bearer $token'
      ..files.add(
        http.MultipartFile.fromBytes('file', audioBytes, filename: filename),
      );
    if (sessionId != null && sessionId.isNotEmpty) {
      request.fields['session_id'] = sessionId;
    }
    if (language != null && language.isNotEmpty) {
      request.fields['language'] = language;
    }

    final http.StreamedResponse streamed;
    try {
      streamed = await request.send().timeout(
        VoiceConstants.voiceTranscribeHttpTimeout,
      );
    } on TimeoutException {
      throw const ServerFailure(
        'TIMEOUT: Voice transcription did not respond in time',
      );
    }

    final body = await streamed.stream.bytesToString();
    if (streamed.statusCode != 200) {
      _throwFromErrorBody(body, streamed.statusCode);
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    final transcript = json['transcript'] as String? ?? '';
    return transcript;
  }

  // ---------------------------------------------------------------------------
  // Budget
  // ---------------------------------------------------------------------------

  @override
  Future<VoiceBudget> getBudget() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const ServerFailure('Not authenticated');

    final now = DateTime.now().toUtc();
    final startOfDay = DateTime.utc(now.year, now.month, now.day);

    final result = await _supabase
        .from('voice_usage_log')
        .select('cost_usd')
        .eq('user_id', userId)
        .gte('created_at', startOfDay.toStorageIso());

    final rows = result as List<dynamic>;
    final usedUsd = rows.fold<double>(
      0.0,
      (sum, row) =>
          sum + ((row as Map<String, dynamic>)['cost_usd'] as num).toDouble(),
    );

    return VoiceBudget(
      usedUsd: usedUsd,
      dailyCapUsd: VoiceConstants.dailyBudgetCapUsd,
    );
  }

  // ---------------------------------------------------------------------------
  // Delete history
  // ---------------------------------------------------------------------------

  @override
  Future<void> deleteHistory() async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw const ServerFailure('Not authenticated');

    await _supabase.from('voice_sessions').delete().eq('user_id', userId);
  }

  // ---------------------------------------------------------------------------
  // Context builder
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _buildContext({
    required WeightUnit weightUnit,
    List<RecentSetContext>? recentSets,
    List<RecentNutritionLogContext>? recentNutritionLogs,
  }) {
    final now = DateTime.now();
    final currentDate = _formatDate(now);

    return <String, dynamic>{
      'currentDate': currentDate,
      'weightUnit': _weightUnitCode(weightUnit),
      'recentSets':
          recentSets
              ?.map(
                (s) => <String, dynamic>{
                  'setId': s.setId,
                  'exerciseName': s.exerciseName,
                  'weight': s.weight,
                  'reps': s.reps,
                  'intensity': s.intensity,
                  'date': _formatDate(s.date),
                },
              )
              .toList() ??
          <dynamic>[],
      'recentNutritionLogs':
          recentNutritionLogs
              ?.map(
                (l) => <String, dynamic>{
                  'logId': l.logId,
                  'mealName': l.mealName,
                  'calories': l.calories,
                  'date': _formatDate(l.date),
                },
              )
              .toList() ??
          <dynamic>[],
    };
  }

  // ---------------------------------------------------------------------------
  // Result parser
  // ---------------------------------------------------------------------------

  /// Parses the JSON payload from `voice-chat` into a typed [VoiceChatResult].
  /// Exposed as `@visibleForTesting` static so the parse logic can be unit-
  /// tested without spinning up an HTTP server (mirrors the `shouldTranscribe`
  /// pattern from [WhisperVoiceSttService]).
  @visibleForTesting
  static VoiceChatResult parseResult(Map<String, dynamic> json) {
    final kind = json['kind'] as String?;

    if (kind == 'tool_call') {
      final tc =
          json['tool_call'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final toolName = tc['name'] as String? ?? '';
      final toolCallId = tc['id'] as String? ?? '';
      final args =
          (tc['arguments'] as Map<String, dynamic>?) ?? <String, dynamic>{};

      // clarify → spoken question that KEEPS the conversation alive (re-listen)
      if (toolName == 'clarify') {
        final raw = args['question'];
        final question = raw is String ? raw : raw?.toString() ?? '';
        return VoiceChatClarifyResponse(
          message: VoiceMessage(
            role: VoiceRole.assistant,
            content: question,
            createdAt: DateTime.now(),
          ),
        );
      }

      // Query tools → client executes locally, no confirmation card
      const queryTools = <String>{
        'getWeeklyVolume',
        'getDailyMacros',
        'getRecentSets',
      };
      if (queryTools.contains(toolName)) {
        return VoiceChatQueryCall(
          toolCallId: toolCallId,
          toolName: toolName,
          args: args,
        );
      }

      // Mutation tools → show confirmation card
      final displaySummary = _buildDisplaySummary(toolName, args);
      return VoiceChatMutationCall(
        toolCall: VoiceToolCall(
          id: toolCallId,
          toolName: toolName,
          displaySummary: displaySummary,
          args: args,
        ),
      );
    }

    // Plain text message
    return VoiceChatTextResponse(
      message: VoiceMessage(
        role: VoiceRole.assistant,
        content: json['content'] as String? ?? json['message'] as String? ?? '',
        createdAt: DateTime.now(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Display summary builder
  // ---------------------------------------------------------------------------

  /// Builds the human-readable summary shown on [VoiceConfirmationCard].
  /// Built from LLM-provided args only — never issues a DB read.
  /// Falls back to the tool name if args are incomplete (defensive).
  static String _buildDisplaySummary(
    String toolName,
    Map<String, dynamic> args,
  ) {
    switch (toolName) {
      case 'logWorkoutSet':
        final exercise = args['exerciseName'] as String? ?? 'Exercise';
        final weight = args['weight'] as num? ?? 0;
        final reps = args['reps'] as num? ?? 0;
        return 'Log: $exercise — $weight × $reps reps';

      case 'editWorkoutSet':
        final exercise = args['exerciseName'] as String? ?? 'set';
        final parts = <String>[];
        if (args['reps'] != null) parts.add('reps: ${args['reps']}');
        if (args['weight'] != null) parts.add('weight: ${args['weight']}');
        if (args['intensity'] != null)
          parts.add('intensity: ${args['intensity']}');
        final changes = parts.isEmpty ? 'no changes' : parts.join(', ');
        return 'Edit: $exercise ($changes)';

      case 'deleteWorkoutSet':
        final exercise = args['exerciseName'] as String? ?? 'set';
        return 'Delete: $exercise set';

      case 'logNutrition':
        final meal = args['mealName'] as String? ?? 'Meal';
        final cals = args['calories'] as num?;
        final grams = args['gramsConsumed'] as num?;
        if (grams != null) return 'Log: $meal — ${grams}g';
        if (cals != null) return 'Log: $meal — $cals kcal';
        return 'Log: $meal';

      case 'editNutritionLog':
        final meal = args['mealName'] as String? ?? 'nutrition log';
        return 'Edit: $meal';

      case 'deleteNutritionLog':
        final meal = args['mealName'] as String? ?? 'nutrition log';
        return 'Delete: $meal';

      default:
        return toolName;
    }
  }

  // ---------------------------------------------------------------------------
  // History serializer
  // ---------------------------------------------------------------------------

  List<Map<String, String>> _serializeHistory(List<VoiceMessage> history) {
    return history
        .map(
          (m) => <String, String>{
            'role': m.role == VoiceRole.user ? 'user' : 'assistant',
            'content': m.content,
          },
        )
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatDate(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';

  /// Maps the in-app [WeightUnit] enum to the short code the Edge
  /// Function's system prompt expects. This is the **only** place in
  /// `lib/` where 'kg' / 'lb' literals are allowed — every other layer
  /// uses the typed enum.
  String _weightUnitCode(WeightUnit unit) {
    switch (unit) {
      case WeightUnit.kilograms:
        return 'kg';
      case WeightUnit.pounds:
        return 'lb';
    }
  }

  /// Builds a [ServerFailure] from a non-2xx Edge Function response.
  ///
  /// The shape of an error body from `_shared/errors.ts` is
  /// `{ "code": "<ErrorCode>", "message": "<human-readable>" }`. We encode
  /// the code, the HTTP status, and the message into the failure's message
  /// using the pipe-delimited form `"CODE|status|message"` so that the
  /// Whisper STT classifier can map it to a typed [VoiceSttErrorKind]
  /// without re-implementing the HTTP layer. The legacy `error` field is
  /// kept as a fallback for older function builds that haven't been
  /// redeployed yet.
  Never _throwFromErrorBody(String body, int statusCode) {
    String message = 'Voice service error ($statusCode)';
    String? code;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final extractedMessage = json['message'] ?? json['error'];
      if (extractedMessage is String && extractedMessage.isNotEmpty) {
        message = extractedMessage;
      }
      final extractedCode = json['code'];
      if (extractedCode is String && extractedCode.isNotEmpty) {
        code = extractedCode;
      }
    } catch (_) {
      // Body is not JSON — keep the default message.
    }
    final encoded = '${code ?? 'HTTP_$statusCode'}|$statusCode|$message';
    throw ServerFailure(encoded);
  }
}

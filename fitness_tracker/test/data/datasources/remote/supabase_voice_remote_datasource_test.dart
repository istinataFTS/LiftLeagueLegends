import 'package:fitness_tracker/data/datasources/remote/supabase_voice_remote_datasource.dart';
import 'package:fitness_tracker/domain/entities/voice_chat_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseVoiceRemoteDataSource.parseResult', () {
    Map<String, dynamic> _toolCall(String name, Map<String, dynamic> args) => {
      'kind': 'tool_call',
      'tool_call': {'id': 'call-1', 'name': name, 'arguments': args},
    };

    test('clarify tool_call → VoiceChatClarifyResponse with question text', () {
      final result = SupabaseVoiceRemoteDataSource.parseResult(
        _toolCall('clarify', {'question': 'How many reps?'}),
      );

      expect(result, isA<VoiceChatClarifyResponse>());
      final clarify = result as VoiceChatClarifyResponse;
      expect(clarify.message.content, 'How many reps?');
    });

    test('clarify tool_call → NOT a VoiceChatTextResponse', () {
      final result = SupabaseVoiceRemoteDataSource.parseResult(
        _toolCall('clarify', {'question': 'Which exercise?'}),
      );

      expect(result, isNot(isA<VoiceChatTextResponse>()));
    });

    test('plain message → VoiceChatTextResponse', () {
      final result = SupabaseVoiceRemoteDataSource.parseResult({
        'kind': 'message',
        'content': 'Done!',
      });

      expect(result, isA<VoiceChatTextResponse>());
      final text = result as VoiceChatTextResponse;
      expect(text.message.content, 'Done!');
    });

    test('query tool_call → VoiceChatQueryCall', () {
      final result = SupabaseVoiceRemoteDataSource.parseResult(
        _toolCall('getWeeklyVolume', {'muscleGroup': 'chest'}),
      );

      expect(result, isA<VoiceChatQueryCall>());
    });

    test('mutation tool_call → VoiceChatMutationCall', () {
      final result = SupabaseVoiceRemoteDataSource.parseResult(
        _toolCall('logWorkoutSet', {
          'exerciseName': 'Bench Press',
          'weight': 80,
          'reps': 8,
        }),
      );

      expect(result, isA<VoiceChatMutationCall>());
    });

    test('clarify with empty question falls back to empty string', () {
      final result = SupabaseVoiceRemoteDataSource.parseResult(
        _toolCall('clarify', <String, dynamic>{}),
      );

      expect(result, isA<VoiceChatClarifyResponse>());
      final clarify = result as VoiceChatClarifyResponse;
      expect(clarify.message.content, '');
    });

    test('clarify with non-string question coerces via toString()', () {
      final result = SupabaseVoiceRemoteDataSource.parseResult(
        _toolCall('clarify', {'question': 42}),
      );

      expect(result, isA<VoiceChatClarifyResponse>());
      final clarify = result as VoiceChatClarifyResponse;
      expect(clarify.message.content, '42');
    });
  });
}

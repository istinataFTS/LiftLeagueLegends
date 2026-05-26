import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/voice_chat_result.dart';
import 'package:fitness_tracker/domain/entities/voice_message.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/repositories/voice_repository.dart';
import 'package:fitness_tracker/domain/usecases/voice/send_voice_message.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockVoiceRepository extends Mock implements VoiceRepository {}

void main() {
  late MockVoiceRepository repo;
  late SendVoiceMessage useCase;

  setUpAll(() {
    registerFallbackValue(const VoiceSettings.defaults());
    registerFallbackValue(WeightUnit.kilograms);
    registerFallbackValue(<VoiceMessage>[]);
  });

  setUp(() {
    repo = MockVoiceRepository();
    useCase = SendVoiceMessage(repo);
  });

  group('SendVoiceMessage', () {
    final assistantMsg = VoiceMessage(
      role: VoiceRole.assistant,
      content: 'Got it!',
      createdAt: DateTime(2026),
    );
    final assistantResult = VoiceChatTextResponse(message: assistantMsg);

    test('delegates to repository.chat with correct parameters', () async {
      when(
        () => repo.chat(
          userMessage: 'bench press',
          sessionId: 'sid-1',
          history: const <VoiceMessage>[],
          settings: const VoiceSettings.defaults(),
          weightUnit: WeightUnit.kilograms,
        ),
      ).thenAnswer((_) async => Right(assistantResult));

      final result = await useCase(
        userMessage: 'bench press',
        sessionId: 'sid-1',
        history: const <VoiceMessage>[],
        settings: const VoiceSettings.defaults(),
        weightUnit: WeightUnit.kilograms,
      );

      expect(result, Right<Failure, VoiceChatResult>(assistantResult));
    });

    test('passes weightUnit through to repository', () async {
      when(
        () => repo.chat(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: WeightUnit.pounds,
        ),
      ).thenAnswer((_) async => Right(assistantResult));

      await useCase(
        userMessage: 'log 200lb squat',
        sessionId: 'sid-2',
        history: const <VoiceMessage>[],
        settings: const VoiceSettings.defaults(),
        weightUnit: WeightUnit.pounds,
      );

      verify(
        () => repo.chat(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: WeightUnit.pounds,
        ),
      ).called(1);
    });

    test('propagates Left(failure) unchanged', () async {
      when(
        () => repo.chat(
          userMessage: any(named: 'userMessage'),
          sessionId: any(named: 'sessionId'),
          history: any(named: 'history'),
          settings: any(named: 'settings'),
          weightUnit: any(named: 'weightUnit'),
        ),
      ).thenAnswer((_) async => const Left(ServerFailure('rate limited')));

      final result = await useCase(
        userMessage: 'test',
        sessionId: 'sid',
        history: const <VoiceMessage>[],
        settings: const VoiceSettings.defaults(),
        weightUnit: WeightUnit.kilograms,
      );

      expect(result.isLeft(), isTrue);
    });
  });
}

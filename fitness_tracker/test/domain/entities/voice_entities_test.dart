import 'package:fitness_tracker/domain/entities/voice_budget.dart';
import 'package:fitness_tracker/domain/entities/voice_message.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('VoiceBudget', () {
    test('remainingUsd is capped at 0 when overspent', () {
      const budget = VoiceBudget(usedUsd: 1.5, dailyCapUsd: 1.0);
      expect(budget.remainingUsd, 0.0);
    });

    test('usedFraction returns correct ratio', () {
      const budget = VoiceBudget(usedUsd: 0.5, dailyCapUsd: 1.0);
      expect(budget.usedFraction, 0.5);
    });

    test('isExhausted is true when remainingUsd is 0', () {
      const budget = VoiceBudget(usedUsd: 1.0, dailyCapUsd: 1.0);
      expect(budget.isExhausted, isTrue);
    });

    test('isExhausted is false when budget has remaining amount', () {
      const budget = VoiceBudget(usedUsd: 0.3, dailyCapUsd: 1.0);
      expect(budget.isExhausted, isFalse);
    });

    test('usedFraction is 0 when dailyCapUsd is 0', () {
      const budget = VoiceBudget(usedUsd: 0.0, dailyCapUsd: 0.0);
      expect(budget.usedFraction, 0.0);
    });

    test('equality holds for same values', () {
      const a = VoiceBudget(usedUsd: 0.2, dailyCapUsd: 1.0);
      const b = VoiceBudget(usedUsd: 0.2, dailyCapUsd: 1.0);
      expect(a, b);
    });
  });

  group('VoiceMessage', () {
    test('user message has correct role', () {
      final msg = VoiceMessage(
        role: VoiceRole.user,
        content: 'bench press',
        createdAt: DateTime(2026),
      );
      expect(msg.role, VoiceRole.user);
      expect(msg.content, 'bench press');
    });

    test('assistant message has correct role', () {
      final msg = VoiceMessage(
        role: VoiceRole.assistant,
        content: 'Got it!',
        createdAt: DateTime(2026),
      );
      expect(msg.role, VoiceRole.assistant);
    });

    test('equality holds for same values', () {
      final t = DateTime(2026);
      final a = VoiceMessage(role: VoiceRole.user, content: 'hi', createdAt: t);
      final b = VoiceMessage(role: VoiceRole.user, content: 'hi', createdAt: t);
      expect(a, b);
    });
  });

  group('VoiceSettings', () {
    test('defaults match master spec §3.6', () {
      const s = VoiceSettings.defaults();
      expect(s.wakeWordPreset, WakeWordPreset.samoLevski);
      expect(s.sessionLoggingEnabled, isFalse);
      expect(s.workoutModeAutoEnable, isFalse);
      expect(s.ttsVolume, 1.0);
      expect(s.ttsSpeechRate, 1.0);
      expect(s.wakeWordArmedInForeground, isTrue);
    });

    test('copyWith overrides only specified fields', () {
      const original = VoiceSettings.defaults();
      final updated = original.copyWith(ttsSpeechRate: 1.5);
      expect(updated.ttsSpeechRate, 1.5);
      // Every other field stays at the default.
      expect(updated.wakeWordPreset, WakeWordPreset.samoLevski);
      expect(updated.sessionLoggingEnabled, isFalse);
      expect(updated.ttsVolume, 1.0);
      expect(updated.wakeWordArmedInForeground, isTrue);
    });

    test('equality is by value across all six fields', () {
      const a = VoiceSettings();
      const b = VoiceSettings();
      expect(a, b);
      final c = a.copyWith(workoutModeAutoEnable: true);
      expect(c, isNot(a));
    });

    test('WakeWordPreset display names match master spec', () {
      expect(WakeWordPreset.samoLevski.displayName, 'Hey Samo Levski');
      expect(WakeWordPreset.trainer.displayName, 'Hey Trainer');
      expect(WakeWordPreset.thomas.displayName, 'Hey Thomas');
    });

    test('WakeWordPreset acceptedPhrases include bare and Hey variants', () {
      expect(WakeWordPreset.samoLevski.acceptedPhrases, {
        'SAMO LEVSKI',
        'HEY SAMO LEVSKI',
      });
      expect(WakeWordPreset.trainer.acceptedPhrases, {
        'TRAINER',
        'HEY TRAINER',
      });
      expect(WakeWordPreset.thomas.acceptedPhrases, {'THOMAS', 'HEY THOMAS'});
    });
  });
}

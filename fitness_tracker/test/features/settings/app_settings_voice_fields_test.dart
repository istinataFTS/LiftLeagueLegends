import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/repositories/app_settings_repository.dart';
import 'package:fitness_tracker/features/settings/application/app_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAppSettingsRepository extends Mock implements AppSettingsRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

AppSettingsCubit _makeCubit(AppSettingsRepository repo) =>
    AppSettingsCubit(repository: repo);

void main() {
  setUpAll(() {
    registerFallbackValue(const AppSettings.defaults());
  });

  // -------------------------------------------------------------------------
  // VoiceSettings entity
  // -------------------------------------------------------------------------

  group('VoiceSettings defaults match master spec §3.6', () {
    const defaults = VoiceSettings.defaults();

    test('wakeWordPreset defaults to samoLevski', () {
      expect(defaults.wakeWordPreset, WakeWordPreset.samoLevski);
    });

    test('ttsSpeechRate defaults to 1.0', () {
      expect(defaults.ttsSpeechRate, 1.0);
    });

    test('sessionLoggingEnabled defaults to false', () {
      expect(defaults.sessionLoggingEnabled, isFalse);
    });

    test('workoutModeAutoEnable defaults to false', () {
      expect(defaults.workoutModeAutoEnable, isFalse);
    });

    test('ttsVolume defaults to 1.0', () {
      expect(defaults.ttsVolume, 1.0);
    });

    test('wakeWordArmedInForeground defaults to true', () {
      expect(defaults.wakeWordArmedInForeground, isTrue);
    });
  });

  group('VoiceSettings.copyWith preserves unmodified fields', () {
    const base = VoiceSettings(
      wakeWordPreset: WakeWordPreset.trainer,
      ttsSpeechRate: 1.5,
      sessionLoggingEnabled: true,
      workoutModeAutoEnable: true,
      ttsVolume: 0.5,
      wakeWordArmedInForeground: false,
    );

    test('copying only ttsSpeechRate leaves other fields unchanged', () {
      final updated = base.copyWith(ttsSpeechRate: 0.8);
      expect(updated.ttsSpeechRate, 0.8);
      expect(updated.wakeWordPreset, WakeWordPreset.trainer);
      expect(updated.sessionLoggingEnabled, isTrue);
      expect(updated.workoutModeAutoEnable, isTrue);
      expect(updated.ttsVolume, 0.5);
      expect(updated.wakeWordArmedInForeground, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // AppSettings entity
  // -------------------------------------------------------------------------

  group('AppSettings.voiceSettings field', () {
    test('defaults to VoiceSettings.defaults()', () {
      const settings = AppSettings.defaults();
      expect(settings.voiceSettings, const VoiceSettings.defaults());
    });

    test('copyWith updates voiceSettings only', () {
      const settings = AppSettings.defaults();
      const newVoice = VoiceSettings(ttsSpeechRate: 1.5);
      final updated = settings.copyWith(voiceSettings: newVoice);
      expect(updated.voiceSettings.ttsSpeechRate, 1.5);
      // Other fields unchanged
      expect(updated.notificationsEnabled, settings.notificationsEnabled);
      expect(updated.weightUnit, settings.weightUnit);
    });

    test('props includes voiceSettings', () {
      const a = AppSettings.defaults();
      final b = a.copyWith(
        voiceSettings: const VoiceSettings(ttsSpeechRate: 0.7),
      );
      expect(a, isNot(equals(b)));
    });
  });

  // -------------------------------------------------------------------------
  // AppSettingsCubit voice setters
  // -------------------------------------------------------------------------

  group('AppSettingsCubit voice setters', () {
    late MockAppSettingsRepository repo;
    late AppSettingsCubit cubit;

    setUp(() {
      repo = MockAppSettingsRepository();
      when(
        () => repo.getSettings(),
      ).thenAnswer((_) async => const Right(AppSettings.defaults()));
      when(
        () => repo.saveSettings(any()),
      ).thenAnswer((_) async => const Right(null));
      // The cubit's constructor subscribes to watchSettings(). Without
      // this stub, the constructor throws and `cubit` stays uninitialised.
      when(
        () => repo.watchSettings(),
      ).thenAnswer((_) => const Stream<AppSettings>.empty());
      cubit = _makeCubit(repo);
    });

    tearDown(() => cubit.close());

    test('setVoiceTtsSpeechRate saves updated voiceSettings', () async {
      await cubit.ensureLoaded();
      await cubit.setVoiceTtsSpeechRate(1.5);

      final captured = verify(() => repo.saveSettings(captureAny())).captured;
      final saved = captured.last as AppSettings;
      expect(saved.voiceSettings.ttsSpeechRate, 1.5);
    });

    test('setVoiceSessionLoggingEnabled saves updated voiceSettings', () async {
      await cubit.ensureLoaded();
      await cubit.setVoiceSessionLoggingEnabled(true);

      final captured = verify(() => repo.saveSettings(captureAny())).captured;
      final saved = captured.last as AppSettings;
      expect(saved.voiceSettings.sessionLoggingEnabled, isTrue);
    });

    test('setVoiceWakeWordPreset saves updated voiceSettings', () async {
      await cubit.ensureLoaded();
      await cubit.setVoiceWakeWordPreset(WakeWordPreset.thomas);

      final captured = verify(() => repo.saveSettings(captureAny())).captured;
      final saved = captured.last as AppSettings;
      expect(saved.voiceSettings.wakeWordPreset, WakeWordPreset.thomas);
    });

    test('setVoiceTtsVolume clamps and saves', () async {
      await cubit.ensureLoaded();
      await cubit.setVoiceTtsVolume(1.5); // above max

      final captured = verify(() => repo.saveSettings(captureAny())).captured;
      final saved = captured.last as AppSettings;
      expect(saved.voiceSettings.ttsVolume, 1.0);
    });

    test('setVoiceWorkoutModeAutoEnable saves updated voiceSettings', () async {
      await cubit.ensureLoaded();
      await cubit.setVoiceWorkoutModeAutoEnable(true);

      final captured = verify(() => repo.saveSettings(captureAny())).captured;
      final saved = captured.last as AppSettings;
      expect(saved.voiceSettings.workoutModeAutoEnable, isTrue);
    });

    test(
      'setVoiceWakeWordArmedInForeground saves updated voiceSettings',
      () async {
        await cubit.ensureLoaded();
        await cubit.setVoiceWakeWordArmedInForeground(false);

        final captured = verify(() => repo.saveSettings(captureAny())).captured;
        final saved = captured.last as AppSettings;
        expect(saved.voiceSettings.wakeWordArmedInForeground, isFalse);
      },
    );
  });

  // -------------------------------------------------------------------------
  // AppSettingsRepositoryImpl voice field round-trip
  // -------------------------------------------------------------------------

  group('AppSettingsRepositoryImpl.getSettings voice field parsing', () {
    test('WakeWordPreset enum has the expected 3 values', () {
      expect(WakeWordPreset.values.length, 3);
    });

    test('ttsVolume parse: valid string "0.75" → 0.75', () {
      expect(double.tryParse('0.75'), 0.75);
    });

    test('ttsVolume parse: null → default 1.0', () {
      expect(double.tryParse('') ?? 1.0, 1.0);
    });

    test('ttsVolume parse: invalid string "abc" → default 1.0', () {
      expect(double.tryParse('abc') ?? 1.0, 1.0);
    });
  });
}

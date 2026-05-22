import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/repositories/app_settings_repository.dart';
import 'package:fitness_tracker/domain/usecases/voice/delete_voice_history.dart';
import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class MockAppSettingsRepository extends Mock implements AppSettingsRepository {}

class MockDeleteVoiceHistory extends Mock implements DeleteVoiceHistory {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Stubs a repository whose `getSettings` returns [settings], whose
/// `saveSettings` always succeeds, and whose `watchSettings` returns the
/// stream produced by [controller] (or an empty stream if omitted).
MockAppSettingsRepository _stubRepo({
  AppSettings settings = const AppSettings.defaults(),
  StreamController<AppSettings>? controller,
}) {
  final repo = MockAppSettingsRepository();
  when(() => repo.getSettings()).thenAnswer((_) async => Right(settings));
  when(
    () => repo.saveSettings(any()),
  ).thenAnswer((_) async => const Right(null));
  when(
    () => repo.watchSettings(),
  ).thenAnswer((_) => controller?.stream ?? const Stream<AppSettings>.empty());
  return repo;
}

void main() {
  setUpAll(() {
    registerFallbackValue(const AppSettings.defaults());
  });

  group('VoiceSettingsCubit', () {
    late MockDeleteVoiceHistory deleteVoiceHistory;

    setUp(() {
      deleteVoiceHistory = MockDeleteVoiceHistory();
      when(
        () => deleteVoiceHistory(),
      ).thenAnswer((_) async => const Right(null));
    });

    test(
      'initial state is VoiceSettings.defaults before the bootstrap read',
      () {
        final repo = _stubRepo();
        final cubit = VoiceSettingsCubit(
          repository: repo,
          deleteVoiceHistory: deleteVoiceHistory,
        );

        // Bootstrap is unawaited; the constructor returns synchronously
        // before the read completes.
        expect(cubit.state, const VoiceSettings.defaults());

        cubit.close();
      },
    );

    test(
      'bootstrap _init populates state from getSettings on construction',
      () async {
        const customVoice = VoiceSettings(
          wakeWordPreset: WakeWordPreset.trainer,
          ttsVolume: 0.7,
        );
        const settings = AppSettings(
          notificationsEnabled: true,
          weekStartDay: WeekStartDay.monday,
          weightUnit: WeightUnit.kilograms,
          voiceSettings: customVoice,
        );

        final repo = _stubRepo(settings: settings);
        final cubit = VoiceSettingsCubit(
          repository: repo,
          deleteVoiceHistory: deleteVoiceHistory,
        );

        // Let _init() complete.
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.wakeWordPreset, WakeWordPreset.trainer);
        expect(cubit.state.ttsVolume, 0.7);

        await cubit.close();
      },
    );

    test(
      'emits new voice state when watchSettings publishes a change',
      () async {
        final controller = StreamController<AppSettings>.broadcast();
        final repo = _stubRepo(controller: controller);
        final cubit = VoiceSettingsCubit(
          repository: repo,
          deleteVoiceHistory: deleteVoiceHistory,
        );
        await Future<void>.delayed(Duration.zero);

        const customVoice = VoiceSettings(
          wakeWordPreset: WakeWordPreset.thomas,
          ttsVolume: 0.42,
        );
        controller.add(
          const AppSettings(
            notificationsEnabled: true,
            weekStartDay: WeekStartDay.monday,
            weightUnit: WeightUnit.kilograms,
            voiceSettings: customVoice,
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(cubit.state.wakeWordPreset, WakeWordPreset.thomas);
        expect(cubit.state.ttsVolume, 0.42);

        await cubit.close();
        await controller.close();
      },
    );

    test(
      'state does NOT change when non-voice AppSettings field changes',
      () async {
        final controller = StreamController<AppSettings>.broadcast();
        final repo = _stubRepo(controller: controller);
        final cubit = VoiceSettingsCubit(
          repository: repo,
          deleteVoiceHistory: deleteVoiceHistory,
        );
        await Future<void>.delayed(Duration.zero);

        final stateBefore = cubit.state;
        final emitted = <VoiceSettings>[];
        final sub = cubit.stream.listen(emitted.add);

        // Same voiceSettings, different weightUnit — distinct() upstream
        // filters this and the cubit does not re-emit.
        controller.add(
          const AppSettings(
            notificationsEnabled: true,
            weekStartDay: WeekStartDay.monday,
            weightUnit: WeightUnit.pounds,
            voiceSettings: VoiceSettings.defaults(),
          ),
        );
        await Future<void>.delayed(Duration.zero);

        expect(emitted, isEmpty);
        expect(cubit.state, equals(stateBefore));

        await sub.cancel();
        await cubit.close();
        await controller.close();
      },
    );

    test(
      'setWakeWordPreset reads current settings then saves the mutation',
      () async {
        const initialSettings = AppSettings(
          notificationsEnabled: false,
          weekStartDay: WeekStartDay.sunday,
          weightUnit: WeightUnit.pounds,
        );
        final repo = _stubRepo(settings: initialSettings);
        final cubit = VoiceSettingsCubit(
          repository: repo,
          deleteVoiceHistory: deleteVoiceHistory,
        );
        await Future<void>.delayed(Duration.zero);

        final ok = await cubit.setWakeWordPreset(WakeWordPreset.trainer);

        expect(ok, isTrue);
        final captured = verify(() => repo.saveSettings(captureAny())).captured;
        final saved = captured.last as AppSettings;
        expect(saved.voiceSettings.wakeWordPreset, WakeWordPreset.trainer);
        // Preserves other fields untouched.
        expect(saved.notificationsEnabled, isFalse);
        expect(saved.weekStartDay, WeekStartDay.sunday);
        expect(saved.weightUnit, WeightUnit.pounds);

        await cubit.close();
      },
    );

    test('setTtsVolume preserves other voice fields', () async {
      const initial = VoiceSettings(
        wakeWordPreset: WakeWordPreset.trainer,
        ttsVolume: 0.1,
        ttsSpeechRate: 0.6,
      );
      const initialSettings = AppSettings(
        notificationsEnabled: true,
        weekStartDay: WeekStartDay.monday,
        weightUnit: WeightUnit.kilograms,
        voiceSettings: initial,
      );
      final repo = _stubRepo(settings: initialSettings);
      final cubit = VoiceSettingsCubit(
        repository: repo,
        deleteVoiceHistory: deleteVoiceHistory,
      );
      await Future<void>.delayed(Duration.zero);

      await cubit.setTtsVolume(0.85);

      final captured = verify(() => repo.saveSettings(captureAny())).captured;
      final saved = captured.last as AppSettings;
      expect(saved.voiceSettings.ttsVolume, 0.85);
      expect(saved.voiceSettings.ttsSpeechRate, 0.6);
      expect(saved.voiceSettings.wakeWordPreset, WakeWordPreset.trainer);

      await cubit.close();
    });

    test('setter returns false when repository.getSettings fails', () async {
      final repo = MockAppSettingsRepository();
      when(
        () => repo.getSettings(),
      ).thenAnswer((_) async => const Left(CacheFailure('read error')));
      when(
        () => repo.saveSettings(any()),
      ).thenAnswer((_) async => const Right(null));
      when(
        () => repo.watchSettings(),
      ).thenAnswer((_) => const Stream<AppSettings>.empty());

      final cubit = VoiceSettingsCubit(
        repository: repo,
        deleteVoiceHistory: deleteVoiceHistory,
      );
      await Future<void>.delayed(Duration.zero);

      final ok = await cubit.setTtsVolume(0.5);

      expect(ok, isFalse);
      verifyNever(() => repo.saveSettings(any()));

      await cubit.close();
    });

    test('setter returns false when repository.saveSettings fails', () async {
      final repo = MockAppSettingsRepository();
      when(
        () => repo.getSettings(),
      ).thenAnswer((_) async => const Right(AppSettings.defaults()));
      when(
        () => repo.saveSettings(any()),
      ).thenAnswer((_) async => const Left(CacheFailure('write error')));
      when(
        () => repo.watchSettings(),
      ).thenAnswer((_) => const Stream<AppSettings>.empty());

      final cubit = VoiceSettingsCubit(
        repository: repo,
        deleteVoiceHistory: deleteVoiceHistory,
      );
      await Future<void>.delayed(Duration.zero);

      final ok = await cubit.setTtsVolume(0.5);

      expect(ok, isFalse);
      verify(() => repo.saveSettings(any())).called(1);

      await cubit.close();
    });

    test(
      'previewTtsVolume emits local state without writing to disk',
      () async {
        final repo = _stubRepo();
        final cubit = VoiceSettingsCubit(
          repository: repo,
          deleteVoiceHistory: deleteVoiceHistory,
        );
        await Future<void>.delayed(Duration.zero);

        cubit.previewTtsVolume(0.33);

        expect(cubit.state.ttsVolume, 0.33);
        verifyNever(() => repo.saveSettings(any()));

        await cubit.close();
      },
    );

    test(
      'previewTtsSpeechRate emits local state without writing to disk',
      () async {
        final repo = _stubRepo();
        final cubit = VoiceSettingsCubit(
          repository: repo,
          deleteVoiceHistory: deleteVoiceHistory,
        );
        await Future<void>.delayed(Duration.zero);

        cubit.previewTtsSpeechRate(1.5);

        expect(cubit.state.ttsSpeechRate, 1.5);
        verifyNever(() => repo.saveSettings(any()));

        await cubit.close();
      },
    );

    test('clearHistory delegates to DeleteVoiceHistory use case', () async {
      final repo = _stubRepo();
      final cubit = VoiceSettingsCubit(
        repository: repo,
        deleteVoiceHistory: deleteVoiceHistory,
      );

      final ok = await cubit.clearHistory();

      expect(ok, isTrue);
      verify(() => deleteVoiceHistory()).called(1);

      await cubit.close();
    });

    test(
      'close() cancels the subscription without double-cancel error',
      () async {
        final controller = StreamController<AppSettings>.broadcast();
        final repo = _stubRepo(controller: controller);
        final cubit = VoiceSettingsCubit(
          repository: repo,
          deleteVoiceHistory: deleteVoiceHistory,
        );

        await cubit.close();
        // Closing the controller after the subscription is cancelled must
        // not surface an error.
        await controller.close();
      },
    );
  });
}

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:fitness_tracker/core/errors/failures.dart';
import 'package:fitness_tracker/domain/entities/app_settings.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/repositories/app_settings_repository.dart';
import 'package:fitness_tracker/domain/repositories/voice_repository.dart';
import 'package:fitness_tracker/domain/usecases/voice/delete_voice_history.dart';
import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockAppSettingsRepository extends Mock implements AppSettingsRepository {}

class MockVoiceRepository extends Mock implements VoiceRepository {}

void main() {
  late MockAppSettingsRepository repository;
  late VoiceSettingsCubit cubit;

  const _persistedSettings = AppSettings(
    notificationsEnabled: true,
    weekStartDay: WeekStartDay.monday,
    weightUnit: WeightUnit.kilograms,
    voiceSettings: VoiceSettings(wakeWordPreset: WakeWordPreset.trainer),
  );

  setUp(() {
    repository = MockAppSettingsRepository();
    when(
      () => repository.watchSettings(),
    ).thenAnswer((_) => const Stream<AppSettings>.empty());
  });

  tearDown(() async {
    await cubit.close();
  });

  VoiceSettingsCubit _makeCubit() {
    final voiceRepo = MockVoiceRepository();
    return VoiceSettingsCubit(
      repository: repository,
      deleteVoiceHistory: DeleteVoiceHistory(voiceRepo),
    );
  }

  test('initial state is VoiceSettings.defaults() before ready completes', () {
    when(
      () => repository.getSettings(),
    ).thenAnswer((_) async => const Right(_persistedSettings));
    cubit = _makeCubit();

    expect(cubit.state, const VoiceSettings.defaults());
  });

  test('ready completes after the initial repository read', () async {
    when(
      () => repository.getSettings(),
    ).thenAnswer((_) async => const Right(_persistedSettings));
    cubit = _makeCubit();

    await cubit.ready;

    verify(() => repository.getSettings()).called(1);
  });

  test('state reflects persisted preset after await ready', () async {
    when(
      () => repository.getSettings(),
    ).thenAnswer((_) async => const Right(_persistedSettings));
    cubit = _makeCubit();

    await cubit.ready;

    expect(cubit.state.wakeWordPreset, WakeWordPreset.trainer);
  });

  test(
    'ready still completes and state keeps defaults on repository failure',
    () async {
      when(() => repository.getSettings()).thenAnswer(
        (_) async => const Left(CacheFailure('settings unavailable')),
      );
      cubit = _makeCubit();

      await cubit.ready;

      expect(cubit.state, const VoiceSettings.defaults());
    },
  );
}

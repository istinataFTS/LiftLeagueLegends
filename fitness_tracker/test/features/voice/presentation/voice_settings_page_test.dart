import 'package:bloc_test/bloc_test.dart';
import 'package:fitness_tracker/core/constants/app_strings.dart';
import 'package:fitness_tracker/domain/entities/voice_settings.dart';
import 'package:fitness_tracker/domain/services/voice_credential_service.dart';
import 'package:fitness_tracker/domain/services/voice_tts_service.dart';
import 'package:fitness_tracker/features/voice/application/picovoice_key_cubit.dart';
import 'package:fitness_tracker/features/voice/application/voice_settings_cubit.dart';
import 'package:fitness_tracker/features/voice/presentation/voice_settings_page.dart';
import 'package:fitness_tracker/features/voice/presentation/voice_settings_page_keys.dart';
import 'package:fitness_tracker/injection/injection_container.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Fakes & mocks
// ---------------------------------------------------------------------------

class MockVoiceSettingsCubit extends MockCubit<VoiceSettings>
    implements VoiceSettingsCubit {}

/// Minimal in-memory [VoiceCredentialService] for tests that need to render
/// the Picovoice key section but do not care about secure-storage behavior.
/// Reports "no key configured" by default; tests that want the configured
/// state can pass `hasKey: true`.
class FakeVoiceCredentialService implements VoiceCredentialService {
  FakeVoiceCredentialService({String? initialKey}) : _key = initialKey;

  String? _key;

  @override
  Future<String?> getPicovoiceAccessKey() async => _key;

  @override
  Future<void> setPicovoiceAccessKey(String key) async {
    _key = key.trim();
  }

  @override
  Future<void> clearPicovoiceAccessKey() async {
    _key = null;
  }

  @override
  Future<bool> hasPicovoiceAccessKey() async =>
      _key != null && _key!.isNotEmpty;
}

class FakeVoiceTtsService implements VoiceTtsService {
  @override
  Future<void> initialize({
    double volume = 1.0,
    double speechRate = 1.0,
  }) async {}

  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> dispose() async {}
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Widget _wrap(VoiceSettingsCubit cubit) {
  return MaterialApp(
    home: BlocProvider<VoiceSettingsCubit>.value(
      value: cubit,
      child: const VoiceSettingsPage(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late MockVoiceSettingsCubit cubit;

  setUpAll(() {
    // Register a fake TTS service so the audio preview callback in
    // _WakeWordPicker._preview() can call sl<VoiceTtsService>() without
    // throwing during tests. Audio playback is a no-op in tests.
    if (!sl.isRegistered<VoiceTtsService>()) {
      sl.registerSingleton<VoiceTtsService>(FakeVoiceTtsService());
    }
    // Register a fake credential service + the real PicovoiceKeyCubit
    // factory so the page's `BlocProvider<PicovoiceKeyCubit>` can resolve
    // a cubit via `sl<PicovoiceKeyCubit>()`. The fake reports "no key" by
    // default — the section renders the "needs setup" tile, which these
    // tests do not assert on but must not crash either.
    if (!sl.isRegistered<VoiceCredentialService>()) {
      sl.registerSingleton<VoiceCredentialService>(
        FakeVoiceCredentialService(),
      );
    }
    if (!sl.isRegistered<PicovoiceKeyCubit>()) {
      sl.registerFactory<PicovoiceKeyCubit>(
        () => PicovoiceKeyCubit(credentials: sl<VoiceCredentialService>()),
      );
    }
  });

  tearDownAll(() async {
    if (sl.isRegistered<VoiceTtsService>()) {
      await sl.unregister<VoiceTtsService>();
    }
    if (sl.isRegistered<PicovoiceKeyCubit>()) {
      await sl.unregister<PicovoiceKeyCubit>();
    }
    if (sl.isRegistered<VoiceCredentialService>()) {
      await sl.unregister<VoiceCredentialService>();
    }
  });

  setUp(() {
    cubit = MockVoiceSettingsCubit();
    when(() => cubit.state).thenReturn(const VoiceSettings.defaults());
    when(() => cubit.clearHistory()).thenAnswer((_) async => true);
    whenListen(
      cubit,
      Stream<VoiceSettings>.empty(),
      initialState: const VoiceSettings.defaults(),
    );
  });

  group('VoiceSettingsPage', () {
    group('rendering', () {
      testWidgets('shows page title', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        expect(find.text(AppStrings.voiceSettingsPageTitle), findsOneWidget);
      });

      testWidgets('shows page scaffold with correct key', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        expect(find.byKey(VoiceSettingsPageKeys.pageKey), findsOneWidget);
      });

      testWidgets('shows all three wake-word preset options', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        await tester.pump();
        expect(
          find.byKey(VoiceSettingsPageKeys.wakeWordSamoLevskiKey),
          findsOneWidget,
        );
        expect(
          find.byKey(VoiceSettingsPageKeys.wakeWordTrainerKey),
          findsOneWidget,
        );
        expect(
          find.byKey(VoiceSettingsPageKeys.wakeWordThomasKey),
          findsOneWidget,
        );
      });

      testWidgets('shows wake-word armed toggle', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        expect(
          find.byKey(VoiceSettingsPageKeys.wakeWordArmedToggleKey),
          findsOneWidget,
        );
      });

      testWidgets('shows session-logging toggle', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        expect(
          find.byKey(VoiceSettingsPageKeys.sessionLoggingToggleKey),
          findsOneWidget,
        );
      });

      testWidgets('shows TTS volume slider', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        await tester.scrollUntilVisible(
          find.byKey(VoiceSettingsPageKeys.ttsVolumeSliderKey),
          100,
        );
        expect(
          find.byKey(VoiceSettingsPageKeys.ttsVolumeSliderKey),
          findsOneWidget,
        );
      });

      testWidgets('shows TTS speech rate slider', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        await tester.scrollUntilVisible(
          find.byKey(VoiceSettingsPageKeys.ttsSpeechRateSliderKey),
          100,
        );
        expect(
          find.byKey(VoiceSettingsPageKeys.ttsSpeechRateSliderKey),
          findsOneWidget,
        );
      });

      testWidgets('shows delete history button', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        await tester.scrollUntilVisible(
          find.byKey(VoiceSettingsPageKeys.deleteHistoryButtonKey),
          100,
        );
        expect(
          find.byKey(VoiceSettingsPageKeys.deleteHistoryButtonKey),
          findsOneWidget,
        );
      });
    });

    group('session-logging toggle', () {
      testWidgets('reflects default OFF state', (tester) async {
        await tester.pumpWidget(_wrap(cubit));

        final toggle = tester.widget<SwitchListTile>(
          find.byKey(VoiceSettingsPageKeys.sessionLoggingToggleKey),
        );
        // Default is false per spec §3.6
        expect(toggle.value, isFalse);
      });

      testWidgets('reflects ON state when settings say so', (tester) async {
        when(() => cubit.state).thenReturn(
          const VoiceSettings.defaults().copyWith(sessionLoggingEnabled: true),
        );
        whenListen(
          cubit,
          Stream<VoiceSettings>.empty(),
          initialState: const VoiceSettings.defaults().copyWith(
            sessionLoggingEnabled: true,
          ),
        );

        await tester.pumpWidget(_wrap(cubit));

        final toggle = tester.widget<SwitchListTile>(
          find.byKey(VoiceSettingsPageKeys.sessionLoggingToggleKey),
        );
        expect(toggle.value, isTrue);
      });

      testWidgets('calls setSessionLoggingEnabled on tap', (tester) async {
        when(
          () => cubit.setSessionLoggingEnabled(any()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(_wrap(cubit));
        await tester.tap(
          find.byKey(VoiceSettingsPageKeys.sessionLoggingToggleKey),
        );

        verify(() => cubit.setSessionLoggingEnabled(true)).called(1);
      });
    });

    group('wake-word armed toggle', () {
      testWidgets('reflects default ON state', (tester) async {
        await tester.pumpWidget(_wrap(cubit));

        final toggle = tester.widget<SwitchListTile>(
          find.byKey(VoiceSettingsPageKeys.wakeWordArmedToggleKey),
        );
        // Default is true per spec §3.6
        expect(toggle.value, isTrue);
      });

      testWidgets('calls setWakeWordArmedInForeground on tap', (tester) async {
        when(
          () => cubit.setWakeWordArmedInForeground(any()),
        ).thenAnswer((_) async => true);

        await tester.pumpWidget(_wrap(cubit));
        await tester.tap(
          find.byKey(VoiceSettingsPageKeys.wakeWordArmedToggleKey),
        );

        verify(() => cubit.setWakeWordArmedInForeground(false)).called(1);
      });
    });

    group('delete history', () {
      testWidgets('calls clearHistory on confirm', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        await tester.scrollUntilVisible(
          find.byKey(VoiceSettingsPageKeys.deleteHistoryButtonKey),
          100,
        );
        await tester.tap(
          find.byKey(VoiceSettingsPageKeys.deleteHistoryButtonKey),
        );
        await tester.pumpAndSettle();

        // Tap the "Delete" confirmation button in the dialog.
        await tester.tap(find.text(AppStrings.voiceDeleteHistoryConfirmButton));
        await tester.pumpAndSettle();

        verify(() => cubit.clearHistory()).called(1);
      });

      testWidgets('shows success snackbar after deletion', (tester) async {
        await tester.pumpWidget(_wrap(cubit));
        await tester.scrollUntilVisible(
          find.byKey(VoiceSettingsPageKeys.deleteHistoryButtonKey),
          100,
        );
        await tester.tap(
          find.byKey(VoiceSettingsPageKeys.deleteHistoryButtonKey),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(AppStrings.voiceDeleteHistoryConfirmButton));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.voiceDeleteHistorySuccess), findsOneWidget);
      });
    });

    // -----------------------------------------------------------------------
    // Picovoice access key section
    //
    // These tests scope the credential service per-test so each can choose
    // whether to start with a key configured. The base setUpAll registers a
    // default fake; here we unregister/replace it before the test runs.
    // -----------------------------------------------------------------------

    group('Picovoice key section', () {
      Future<void> useCredentialService(
        FakeVoiceCredentialService service,
      ) async {
        if (sl.isRegistered<VoiceCredentialService>()) {
          await sl.unregister<VoiceCredentialService>();
        }
        sl.registerSingleton<VoiceCredentialService>(service);
      }

      tearDown(() async {
        // Restore the default empty fake so the next test starts clean.
        if (sl.isRegistered<VoiceCredentialService>()) {
          await sl.unregister<VoiceCredentialService>();
        }
        sl.registerSingleton<VoiceCredentialService>(
          FakeVoiceCredentialService(),
        );
      });

      testWidgets(
        'renders the missing-key tile when no key is configured',
        (tester) async {
          await useCredentialService(FakeVoiceCredentialService());
          await tester.pumpWidget(_wrap(cubit));
          await tester.pumpAndSettle();

          expect(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeyTileKey),
            findsOneWidget,
          );
          expect(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeySetUpButtonKey),
            findsOneWidget,
          );
          expect(
            find.text(AppStrings.voicePicovoiceKeyMissingTitle),
            findsOneWidget,
          );
        },
      );

      testWidgets(
        'renders the configured tile when a key is present',
        (tester) async {
          await useCredentialService(
            FakeVoiceCredentialService(initialKey: 'existing-key'),
          );
          await tester.pumpWidget(_wrap(cubit));
          await tester.pumpAndSettle();

          expect(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeyTileKey),
            findsOneWidget,
          );
          expect(
            find.text(AppStrings.voicePicovoiceKeyPresentTitle),
            findsOneWidget,
          );
          // The "Set up key" CTA only appears in the missing state.
          expect(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeySetUpButtonKey),
            findsNothing,
          );
        },
      );

      testWidgets(
        'tapping "Set up key" opens the entry dialog with a hidden field',
        (tester) async {
          await useCredentialService(FakeVoiceCredentialService());
          await tester.pumpWidget(_wrap(cubit));
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeySetUpButtonKey),
          );
          await tester.pumpAndSettle();

          expect(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeyDialogKey),
            findsOneWidget,
          );
          expect(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeyTextFieldKey),
            findsOneWidget,
          );

          // The TextField is obscured to keep the secret out of shoulder
          // surfers' line of sight — verify the obscureText property.
          final TextField field = tester.widget(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeyTextFieldKey),
          );
          expect(field.obscureText, isTrue);
        },
      );

      testWidgets(
        'entering a key and tapping Save persists it through the service',
        (tester) async {
          final service = FakeVoiceCredentialService();
          await useCredentialService(service);
          await tester.pumpWidget(_wrap(cubit));
          await tester.pumpAndSettle();

          await tester.tap(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeySetUpButtonKey),
          );
          await tester.pumpAndSettle();

          await tester.enterText(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeyTextFieldKey),
            '  fresh-key  ',
          );
          await tester.tap(
            find.byKey(VoiceSettingsPageKeys.picovoiceKeyDialogSaveKey),
          );
          await tester.pumpAndSettle();

          expect(await service.hasPicovoiceAccessKey(), isTrue);
          expect(await service.getPicovoiceAccessKey(), 'fresh-key');
          expect(
            find.text(AppStrings.voicePicovoiceKeySaveSuccess),
            findsOneWidget,
          );
        },
      );
    });
  });
}

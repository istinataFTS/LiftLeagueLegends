import 'package:fitness_tracker/domain/services/voice_permission_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// ---------------------------------------------------------------------------
// Minimal mock of the abstract interface — used to verify delegation contract
// ---------------------------------------------------------------------------

class MockVoicePermissionService extends Mock
    implements VoicePermissionService {}

void main() {
  group('VoicePermissionStatus', () {
    test('enum has exactly 3 values', () {
      expect(VoicePermissionStatus.values.length, 3);
    });

    test('contains granted, denied, deniedPermanently', () {
      expect(
        VoicePermissionStatus.values,
        containsAll([
          VoicePermissionStatus.granted,
          VoicePermissionStatus.denied,
          VoicePermissionStatus.deniedPermanently,
        ]),
      );
    });
  });

  group('VoicePermissionService contract (mock)', () {
    late MockVoicePermissionService service;

    setUp(() {
      service = MockVoicePermissionService();
    });

    test('checkMicrophonePermission returns granted', () async {
      when(
        () => service.checkMicrophonePermission(),
      ).thenAnswer((_) async => VoicePermissionStatus.granted);

      final result = await service.checkMicrophonePermission();
      expect(result, VoicePermissionStatus.granted);
    });

    test('checkMicrophonePermission returns denied', () async {
      when(
        () => service.checkMicrophonePermission(),
      ).thenAnswer((_) async => VoicePermissionStatus.denied);

      final result = await service.checkMicrophonePermission();
      expect(result, VoicePermissionStatus.denied);
    });

    test('checkMicrophonePermission returns deniedPermanently', () async {
      when(
        () => service.checkMicrophonePermission(),
      ).thenAnswer((_) async => VoicePermissionStatus.deniedPermanently);

      final result = await service.checkMicrophonePermission();
      expect(result, VoicePermissionStatus.deniedPermanently);
    });

    test('requestMicrophonePermission returns granted', () async {
      when(
        () => service.requestMicrophonePermission(),
      ).thenAnswer((_) async => VoicePermissionStatus.granted);

      final result = await service.requestMicrophonePermission();
      expect(result, VoicePermissionStatus.granted);
    });

    test('requestMicrophonePermission returns deniedPermanently', () async {
      when(
        () => service.requestMicrophonePermission(),
      ).thenAnswer((_) async => VoicePermissionStatus.deniedPermanently);

      final result = await service.requestMicrophonePermission();
      expect(result, VoicePermissionStatus.deniedPermanently);
    });

    test('openAppSettings delegates and returns bool', () async {
      when(() => service.openAppSettings()).thenAnswer((_) async => true);

      final result = await service.openAppSettings();
      expect(result, isTrue);
      verify(() => service.openAppSettings()).called(1);
    });
  });
}

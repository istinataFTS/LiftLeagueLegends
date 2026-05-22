import 'package:permission_handler/permission_handler.dart' as ph;

import '../../../../domain/services/voice_permission_service.dart';

class PermissionHandlerVoicePermissionService
    implements VoicePermissionService {
  const PermissionHandlerVoicePermissionService();

  @override
  Future<VoicePermissionStatus> checkMicrophonePermission() async {
    final status = await ph.Permission.microphone.status;
    return _map(status);
  }

  @override
  Future<VoicePermissionStatus> requestMicrophonePermission() async {
    final status = await ph.Permission.microphone.request();
    return _map(status);
  }

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();

  VoicePermissionStatus _map(ph.PermissionStatus status) {
    return switch (status) {
      // iOS "limited" mic permission is sufficient — map to granted.
      ph.PermissionStatus.granted ||
      ph.PermissionStatus.limited => VoicePermissionStatus.granted,
      ph.PermissionStatus.permanentlyDenied ||
      ph.PermissionStatus.restricted => VoicePermissionStatus.deniedPermanently,
      _ => VoicePermissionStatus.denied,
    };
  }
}

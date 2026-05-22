enum VoicePermissionStatus { granted, denied, deniedPermanently }

abstract interface class VoicePermissionService {
  /// Current mic permission status — does NOT prompt the user.
  Future<VoicePermissionStatus> checkMicrophonePermission();

  /// Requests mic permission. Shows the system dialog if status is [denied].
  /// Returns [deniedPermanently] if the user selected "Don't ask again".
  Future<VoicePermissionStatus> requestMicrophonePermission();

  /// Opens the app's system-settings page for manual grant.
  Future<bool> openAppSettings();
}

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../domain/services/voice_credential_service.dart';

class SecureStorageVoiceCredentialService implements VoiceCredentialService {
  SecureStorageVoiceCredentialService(this._storage);

  final FlutterSecureStorage _storage;
  // sync: true — events are delivered immediately inside add(), not on the
  // next microtask. This is correct for a change-notification channel whose
  // listeners (VoiceFab) only schedule more work, never block.
  final _keyChangedController = StreamController<void>.broadcast(sync: true);

  // Single canonical key. Never expose outside this class.
  static const _kPicovoiceKey = 'voice.picovoice_access_key';

  // ── VoiceCredentialService interface ────────────────────────────────────────

  @override
  Stream<void> get onPicovoiceKeyChanged => _keyChangedController.stream;

  @override
  Future<String?> getPicovoiceAccessKey() => _storage.read(key: _kPicovoiceKey);

  @override
  Future<void> setPicovoiceAccessKey(String key) async {
    if (key.trim().isEmpty) {
      throw ArgumentError('Picovoice key must not be empty');
    }
    await _storage.write(key: _kPicovoiceKey, value: key.trim());
    _keyChangedController.add(null);
  }

  @override
  Future<void> clearPicovoiceAccessKey() async {
    await _storage.delete(key: _kPicovoiceKey);
    _keyChangedController.add(null);
  }

  @override
  Future<bool> hasPicovoiceAccessKey() async {
    final key = await getPicovoiceAccessKey();
    return key != null && key.isNotEmpty;
  }

  @override
  Future<void> dispose() => _keyChangedController.close();
}

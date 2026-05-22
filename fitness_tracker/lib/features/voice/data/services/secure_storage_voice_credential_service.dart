import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../../domain/services/voice_credential_service.dart';

class SecureStorageVoiceCredentialService implements VoiceCredentialService {
  const SecureStorageVoiceCredentialService(this._storage);

  final FlutterSecureStorage _storage;

  // Single canonical key. Never expose outside this class.
  static const _kPicovoiceKey = 'voice.picovoice_access_key';

  @override
  Future<String?> getPicovoiceAccessKey() =>
      _storage.read(key: _kPicovoiceKey);

  @override
  Future<void> setPicovoiceAccessKey(String key) {
    if (key.trim().isEmpty) {
      throw ArgumentError('Picovoice key must not be empty');
    }
    return _storage.write(key: _kPicovoiceKey, value: key.trim());
  }

  @override
  Future<void> clearPicovoiceAccessKey() =>
      _storage.delete(key: _kPicovoiceKey);

  @override
  Future<bool> hasPicovoiceAccessKey() async {
    final key = await getPicovoiceAccessKey();
    return key != null && key.isNotEmpty;
  }
}

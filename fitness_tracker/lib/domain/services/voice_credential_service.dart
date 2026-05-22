abstract interface class VoiceCredentialService {
  /// Retrieves the Picovoice access key. Returns null if not configured.
  Future<String?> getPicovoiceAccessKey();

  /// Stores the Picovoice access key in secure storage.
  /// Throws [ArgumentError] if [key] is empty or whitespace-only.
  Future<void> setPicovoiceAccessKey(String key);

  /// Removes the Picovoice access key from secure storage.
  Future<void> clearPicovoiceAccessKey();

  /// Whether a non-empty Picovoice access key is currently configured.
  Future<bool> hasPicovoiceAccessKey();
}

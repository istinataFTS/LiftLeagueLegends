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

  /// Emits a void event every time the key is written or cleared via this
  /// service instance. Listeners (e.g. [VoiceFab]) subscribe to this stream
  /// so they can react when the bootstrap seeder populates the key on first
  /// launch without requiring a widget rebuild.
  Stream<void> get onPicovoiceKeyChanged;

  /// Releases internal resources (closes the change-notification stream).
  /// Called by the DI container's `dispose` hook on unregister.
  Future<void> dispose();
}

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/logging/app_logger.dart';
import '../../../domain/services/voice_credential_service.dart';

/// Immutable state for [PicovoiceKeyCubit].
///
/// The cubit deliberately exposes only a boolean `hasKey` flag, never the
/// key string itself — the secret stays inside [VoiceCredentialService] and
/// is read by the wake-word engine on demand.
class PicovoiceKeyState extends Equatable {
  const PicovoiceKeyState({
    required this.hasKey,
    required this.isLoading,
    required this.isSaving,
    this.errorMessage,
  });

  const PicovoiceKeyState.initial()
    : hasKey = false,
      isLoading = true,
      isSaving = false,
      errorMessage = null;

  /// Whether a non-empty Picovoice access key is currently stored.
  final bool hasKey;

  /// True while the initial load from secure storage is in flight.
  final bool isLoading;

  /// True while a save or clear operation is in flight.
  final bool isSaving;

  /// Non-null if the last save / clear / load failed. Surfaces in the UI;
  /// cleared on the next successful operation.
  final String? errorMessage;

  PicovoiceKeyState copyWith({
    bool? hasKey,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return PicovoiceKeyState(
      hasKey: hasKey ?? this.hasKey,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [hasKey, isLoading, isSaving, errorMessage];
}

/// Application cubit for the Picovoice access-key setup surface.
///
/// **Why a cubit and not a bloc:** the operations are direct
/// load / save / clear with no event-driven branching and no one-shot
/// side-effects. A cubit keeps the surface small and the tests narrow.
///
/// **Why no `String` key in state:** the access key is a per-device secret.
/// Keeping it out of the cubit state means it never accidentally lands in
/// a `toString()`, a `print(state)`, or a state-diff log. The UI only ever
/// needs to know *whether* one is configured, not *what* it is — the
/// wake-word engine reads it straight from [VoiceCredentialService] when
/// it needs to.
///
/// **Lifecycle:** registered as `registerFactory` so each settings page
/// instance gets a fresh cubit, and disposed when the page pops.
class PicovoiceKeyCubit extends Cubit<PicovoiceKeyState> {
  PicovoiceKeyCubit({required VoiceCredentialService credentials})
    : _credentials = credentials,
      super(const PicovoiceKeyState.initial());

  final VoiceCredentialService _credentials;

  /// Hydrate state from secure storage. Safe to call multiple times — the
  /// settings page calls it once on `initState`.
  Future<void> load() async {
    if (!isClosed) emit(state.copyWith(isLoading: true, clearError: true));
    try {
      final present = await _credentials.hasPicovoiceAccessKey();
      if (isClosed) return;
      emit(state.copyWith(hasKey: present, isLoading: false));
    } catch (e, st) {
      AppLogger.warning(
        'PicovoiceKeyCubit: failed to read access-key presence from storage',
        error: e,
        stackTrace: st,
        category: 'voice',
      );
      if (isClosed) return;
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Could not read voice key from secure storage.',
        ),
      );
    }
  }

  /// Save [key] to secure storage. Whitespace is trimmed by the underlying
  /// service. Returns `true` on success, `false` on failure (the error is
  /// also surfaced via [PicovoiceKeyState.errorMessage]).
  Future<bool> save(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) {
      emit(
        state.copyWith(errorMessage: 'Voice key cannot be empty.'),
      );
      return false;
    }
    if (!isClosed) emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _credentials.setPicovoiceAccessKey(trimmed);
      if (isClosed) return true;
      emit(state.copyWith(hasKey: true, isSaving: false));
      return true;
    } catch (e, st) {
      AppLogger.warning(
        'PicovoiceKeyCubit: failed to write access key to storage',
        error: e,
        stackTrace: st,
        category: 'voice',
      );
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Could not save voice key to secure storage.',
        ),
      );
      return false;
    }
  }

  /// Remove the stored access key. Returns `true` on success.
  Future<bool> clear() async {
    if (!isClosed) emit(state.copyWith(isSaving: true, clearError: true));
    try {
      await _credentials.clearPicovoiceAccessKey();
      if (isClosed) return true;
      emit(state.copyWith(hasKey: false, isSaving: false));
      return true;
    } catch (e, st) {
      AppLogger.warning(
        'PicovoiceKeyCubit: failed to clear access key from storage',
        error: e,
        stackTrace: st,
        category: 'voice',
      );
      if (isClosed) return false;
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Could not remove voice key from secure storage.',
        ),
      );
      return false;
    }
  }
}

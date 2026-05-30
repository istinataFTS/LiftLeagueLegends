import 'dart:async';

/// Outcome of a voice-dispatched mutation, awaited by [VoiceBloc] via a
/// [Completer] threaded through each [VoiceMutationCommand].
///
/// [VoiceCommandRouter] produces this value after observing the target BLoC's
/// success or failure effect. [VoiceBloc._dispatchMutationTool] awaits it
/// (with a finite timeout) before speaking a response, so the user hears an
/// accurate outcome rather than a phantom success.
sealed class VoiceMutationOutcome {
  const VoiceMutationOutcome();
}

/// The mutation was acknowledged as persisted by the target BLoC.
final class VoiceMutationSuccess extends VoiceMutationOutcome {
  const VoiceMutationSuccess();
}

/// The target BLoC emitted a failure effect (e.g. SQLite error, session race).
/// [reason] is for telemetry; the spoken reply uses [AppStrings.voiceSpokenToolFailed].
final class VoiceMutationFailure extends VoiceMutationOutcome {
  const VoiceMutationFailure(this.reason);

  final String reason;
}

/// [VoiceCommandRouter] did not complete the [Completer] within
/// [VoiceConstants.mutationDispatchTimeout]. Control returns to [VoiceBloc]
/// so the voice overlay does not stay in the processing state indefinitely.
final class VoiceMutationTimeout extends VoiceMutationOutcome {
  const VoiceMutationTimeout();
}

abstract class HistoryUiEffect {
  const HistoryUiEffect();
}

class HistorySuccessEffect extends HistoryUiEffect {
  final String message;

  const HistorySuccessEffect(this.message);
}

/// Emitted alongside [HistoryError] state when a mutation fails.
/// [VoiceCommandRouter] listens for this to complete the in-flight mutation
/// completer with a failure outcome so [VoiceBloc] can speak an error reply.
class HistoryMutationFailedEffect extends HistoryUiEffect {
  const HistoryMutationFailedEffect(this.message);

  final String message;
}

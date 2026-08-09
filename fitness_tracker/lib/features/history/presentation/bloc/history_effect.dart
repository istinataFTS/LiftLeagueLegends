abstract class HistoryUiEffect {
  const HistoryUiEffect();
}

class HistorySuccessEffect extends HistoryUiEffect {
  final String message;

  const HistorySuccessEffect(this.message);
}

/// Emitted alongside [HistoryError] state when a mutation fails.
/// Emitted when a history mutation fails, so the UI can surface the error
/// separately from the state channel.
class HistoryMutationFailedEffect extends HistoryUiEffect {
  const HistoryMutationFailedEffect(this.message);

  final String message;
}

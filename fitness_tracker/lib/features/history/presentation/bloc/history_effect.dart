abstract class HistoryUiEffect {
  const HistoryUiEffect();
}

class HistorySuccessEffect extends HistoryUiEffect {
  final String message;

  const HistorySuccessEffect(this.message);
}

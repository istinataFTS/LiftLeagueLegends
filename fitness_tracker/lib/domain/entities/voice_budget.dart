import 'package:equatable/equatable.dart';

class VoiceBudget extends Equatable {
  const VoiceBudget({required this.usedUsd, required this.dailyCapUsd});

  final double usedUsd;
  final double dailyCapUsd;

  double get remainingUsd => (dailyCapUsd - usedUsd).clamp(0.0, dailyCapUsd);
  double get usedFraction =>
      dailyCapUsd > 0 ? (usedUsd / dailyCapUsd).clamp(0.0, 1.0) : 0.0;
  bool get isExhausted => remainingUsd <= 0;

  @override
  List<Object?> get props => <Object?>[usedUsd, dailyCapUsd];
}

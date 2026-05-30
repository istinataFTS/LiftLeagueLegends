import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/nutrition_log.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/nutrition_log_repository.dart';

class UpdateNutritionLog {
  final NutritionLogRepository repository;
  final AppSessionRepository appSessionRepository;

  const UpdateNutritionLog(
    this.repository, {
    required this.appSessionRepository,
  });

  Future<Either<Failure, void>> call(NutritionLog log) async {
    final sessionResult = await appSessionRepository.getCurrentSession();

    return sessionResult.fold((failure) => Left(failure), (session) {
      final userId = session.user.id;
      final preparedLog = log.ownerUserId == userId
          ? log
          : log.copyWith(ownerUserId: userId);
      return repository.updateLog(preparedLog);
    });
  }
}

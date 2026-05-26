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

    final preparedLog = sessionResult.fold((_) => log, (session) {
      if (!session.isAuthenticated || session.user == null) {
        return log;
      }

      if (log.ownerUserId == session.user!.id) {
        return log;
      }

      return log.copyWith(ownerUserId: session.user!.id);
    });

    return repository.updateLog(preparedLog);
  }
}

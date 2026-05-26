import 'package:dartz/dartz.dart';

import '../../../core/errors/failures.dart';
import '../../entities/nutrition_log.dart';
import '../../repositories/app_session_repository.dart';
import '../../repositories/nutrition_log_repository.dart';

class AddNutritionLog {
  final NutritionLogRepository repository;
  final AppSessionRepository appSessionRepository;

  const AddNutritionLog(this.repository, {required this.appSessionRepository});

  Future<Either<Failure, void>> call(NutritionLog log) async {
    final sessionResult = await appSessionRepository.getCurrentSession();

    final preparedLog = sessionResult.fold((_) => log, (session) {
      if (!session.isAuthenticated || session.user == null) {
        return log;
      }

      return log.copyWith(ownerUserId: session.user!.id);
    });

    return repository.addLog(preparedLog);
  }
}

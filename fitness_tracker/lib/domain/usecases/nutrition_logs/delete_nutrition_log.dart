import 'package:dartz/dartz.dart';
import '../../../core/errors/failures.dart';
import '../../repositories/nutrition_log_repository.dart';

class DeleteNutritionLog {
  final NutritionLogRepository repository;

  const DeleteNutritionLog(this.repository);

  Future<Either<Failure, void>> call(String id) {
    return repository.deleteLog(id);
  }
}

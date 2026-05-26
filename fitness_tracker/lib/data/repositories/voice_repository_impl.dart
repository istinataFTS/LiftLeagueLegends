import 'package:dartz/dartz.dart';

import '../../core/errors/failures.dart';
import '../../domain/entities/app_settings.dart' show WeightUnit;
import '../../domain/entities/voice_budget.dart';
import '../../domain/entities/voice_chat_context.dart';
import '../../domain/entities/voice_chat_result.dart';
import '../../domain/entities/voice_message.dart';
import '../../domain/entities/voice_settings.dart';
import '../../domain/repositories/voice_repository.dart';
import '../datasources/remote/voice_remote_datasource.dart';

class VoiceRepositoryImpl implements VoiceRepository {
  const VoiceRepositoryImpl({required this.remoteDataSource});

  final VoiceRemoteDataSource remoteDataSource;

  @override
  Future<Either<Failure, VoiceChatResult>> chat({
    required String userMessage,
    required String sessionId,
    required List<VoiceMessage> history,
    required VoiceSettings settings,
    required WeightUnit weightUnit,
    List<RecentSetContext>? recentSets,
    List<RecentNutritionLogContext>? recentNutritionLogs,
  }) => _guard(
    () => remoteDataSource.chat(
      userMessage: userMessage,
      sessionId: sessionId,
      history: history,
      settings: settings,
      weightUnit: weightUnit,
      recentSets: recentSets,
      recentNutritionLogs: recentNutritionLogs,
    ),
  );

  @override
  Future<Either<Failure, VoiceBudget>> getBudget() =>
      _guard(() => remoteDataSource.getBudget());

  @override
  Future<Either<Failure, void>> deleteHistory() =>
      _guard(() => remoteDataSource.deleteHistory());

  Future<Either<Failure, T>> _guard<T>(Future<T> Function() action) async {
    try {
      final result = await action();
      return Right(result);
    } on Failure catch (f) {
      return Left(f);
    } catch (e) {
      return Left(ServerFailure(e.toString()));
    }
  }
}

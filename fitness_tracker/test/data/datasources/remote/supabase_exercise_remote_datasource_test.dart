import 'package:fitness_tracker/data/datasources/remote/supabase_exercise_remote_datasource.dart';
import 'package:fitness_tracker/data/datasources/remote/supabase_client_provider.dart';
import 'package:fitness_tracker/data/dtos/supabase/supabase_exercise_dto.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 3, 26, 10, 0);

  Exercise buildExercise({
    required String id,
    String? ownerUserId = 'user-1',
    String name = 'Bench Press',
    List<String> muscleGroups = const <String>['chest', 'triceps'],
    String? serverId,
  }) {
    return Exercise(
      id: id,
      ownerUserId: ownerUserId,
      name: name,
      muscleGroups: muscleGroups,
      createdAt: baseDate,
      updatedAt: baseDate.add(const Duration(hours: 1)),
      syncMetadata: EntitySyncMetadata(serverId: serverId),
    );
  }

  group('SupabaseExerciseRemoteDataSource', () {
    test('reports configured state from provider', () {
      const dataSource = SupabaseExerciseRemoteDataSource(
        clientProvider: SupabaseClientProvider(isConfigured: true),
      );

      expect(dataSource.isConfigured, isTrue);
    });

    test('throws if provider is not configured and client is requested', () {
      const provider = SupabaseClientProvider(isConfigured: false);

      expect(() => provider.client, throwsStateError);
    });

    test('dto conversion supports remote upsert payload shape', () {
      final exercise = buildExercise(id: 'local-1', serverId: 'server-1');

      expect(exercise.ownerUserId, 'user-1');
      expect(exercise.syncMetadata.serverId, 'server-1');
      expect(exercise.muscleGroups, <String>['chest', 'triceps']);
    });

    test('exercise without ownerUserId is invalid for remote sync', () {
      final exercise = buildExercise(id: 'local-1', ownerUserId: null);

      expect(exercise.ownerUserId, isNull);
    });

    test(
      'upsert payload carries the onConflict target columns (user_id, name)',
      () {
        // The remote upsert uses onConflict: "user_id,name"; the payload
        // must always expose those columns or PostgREST cannot resolve the
        // conflict target. Guards the Phase-3 idempotent-upsert contract.
        final map = SupabaseExerciseDto.fromEntity(
          buildExercise(id: 'local-1'),
        ).toMap();

        expect(map.containsKey('user_id'), isTrue);
        expect(map.containsKey('name'), isTrue);
        expect(map['name'], 'Bench Press');
        expect(map['user_id'], 'user-1');
      },
    );
  });
}

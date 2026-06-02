import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/dtos/supabase/supabase_exercise_dto.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:fitness_tracker/domain/entities/exercise.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 3, 26, 10, 0);

  Exercise buildExercise({
    required String id,
    String? ownerUserId,
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

  group('SupabaseExerciseDto.fromEntity', () {
    test('maps user-owned exercise to supabase payload', () {
      final exercise = buildExercise(
        id: 'local-1',
        ownerUserId: 'user-1',
        serverId: 'server-1',
      );

      final dto = SupabaseExerciseDto.fromEntity(exercise);

      expect(dto.id, 'server-1');
      expect(dto.userId, 'user-1');
      expect(dto.name, 'Bench Press');
      expect(dto.muscleGroups, <String>['chest', 'triceps']);
      expect(dto.createdAt, baseDate);
      expect(dto.updatedAt, baseDate.add(const Duration(hours: 1)));
    });

    test('falls back to local id when server id is missing', () {
      final exercise = buildExercise(id: 'local-1', ownerUserId: 'user-1');

      final dto = SupabaseExerciseDto.fromEntity(exercise);

      expect(dto.id, 'local-1');
    });

    test('throws when ownerUserId is missing', () {
      final exercise = buildExercise(id: 'local-1');

      expect(
        () => SupabaseExerciseDto.fromEntity(exercise),
        throwsArgumentError,
      );
    });
  });

  group('SupabaseExerciseDto mapping', () {
    test('round-trips from map to entity with synced metadata', () {
      final dto = SupabaseExerciseDto.fromMap(<String, dynamic>{
        'id': 'server-1',
        'user_id': 'user-1',
        'name': 'Bench Press',
        'muscle_groups': <String>['chest', 'triceps'],
        'created_at': baseDate.toIso8601String(),
        'updated_at': baseDate.add(const Duration(hours: 1)).toIso8601String(),
      });

      final entity = dto.toEntity(
        localId: 'local-1',
        syncMetadata: dto.toSyncedMetadata(),
      );

      expect(entity.id, 'local-1');
      expect(entity.ownerUserId, 'user-1');
      expect(entity.name, 'Bench Press');
      expect(entity.muscleGroups, <String>['chest', 'triceps']);
      expect(entity.syncMetadata.serverId, 'server-1');
      expect(entity.syncMetadata.status, SyncStatus.synced);
      expect(
        entity.syncMetadata.lastSyncedAt,
        baseDate.add(const Duration(hours: 1)),
      );
    });

    test('serializes to expected supabase map', () {
      final dto = SupabaseExerciseDto(
        id: 'server-1',
        userId: 'user-1',
        name: 'Bench Press',
        muscleGroups: <String>['chest', 'triceps'],
        createdAt: DateTime(2026, 3, 26, 10, 0),
        updatedAt: DateTime(2026, 3, 26, 11, 0),
      );

      final map = dto.toMap();
      expect(map['id'], 'server-1');
      expect(map['user_id'], 'user-1');
      expect(map['name'], 'Bench Press');
      expect(map['muscle_groups'], <String>['chest', 'triceps']);
      expect((map['created_at'] as String).endsWith('Z'), isTrue);
      expect((map['updated_at'] as String).endsWith('Z'), isTrue);
    });
  });
}

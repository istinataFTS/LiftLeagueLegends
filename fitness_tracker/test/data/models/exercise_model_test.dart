import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/models/exercise_model.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 6, 2, 10, 30, 0);

  ExerciseModel buildModel({
    String id = 'ex-1',
    DateTime? createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    final d = createdAt ?? baseDate;
    return ExerciseModel(
      id: id,
      ownerUserId: 'user-1',
      name: 'Bench Press',
      muscleGroups: const ['chest'],
      createdAt: d,
      updatedAt: updatedAt ?? d,
      syncMetadata: syncMetadata,
    );
  }

  group('ExerciseModel.toMap', () {
    test('createdAt is Z-suffixed', () {
      final map = buildModel().toMap();
      expect(
        (map[DatabaseTables.exerciseCreatedAt] as String).endsWith('Z'),
        isTrue,
      );
    });

    test('updatedAt is Z-suffixed', () {
      final map = buildModel().toMap();
      expect(
        (map[DatabaseTables.exerciseUpdatedAt] as String).endsWith('Z'),
        isTrue,
      );
    });

    test('lastSyncedAt is Z-suffixed when present', () {
      final syncedAt = DateTime(2026, 6, 2, 11, 0);
      final model = buildModel(
        syncMetadata: EntitySyncMetadata(
          serverId: 'srv-1',
          status: SyncStatus.synced,
          lastSyncedAt: syncedAt,
        ),
      );
      final map = model.toMap();
      expect(
        (map[DatabaseTables.exerciseLastSyncedAt] as String).endsWith('Z'),
        isTrue,
      );
    });

    test('lastSyncedAt is null when absent', () {
      final map = buildModel().toMap();
      expect(map[DatabaseTables.exerciseLastSyncedAt], isNull);
    });
  });

  group('ExerciseModel.fromMap round-trip', () {
    test('createdAt round-trips to same instant and is local', () {
      final model = buildModel();
      final roundTripped = ExerciseModel.fromMap(model.toMap());
      expect(roundTripped.createdAt.isAtSameMomentAs(model.createdAt), isTrue);
      expect(roundTripped.createdAt.isUtc, isFalse);
    });

    test('updatedAt round-trips to same instant and is local', () {
      final model = buildModel(
        updatedAt: baseDate.add(const Duration(hours: 1)),
      );
      final roundTripped = ExerciseModel.fromMap(model.toMap());
      expect(roundTripped.updatedAt.isAtSameMomentAs(model.updatedAt), isTrue);
      expect(roundTripped.updatedAt.isUtc, isFalse);
    });

    test('Z-suffix stored createdAt parses to correct local instant', () {
      final utcInstant = DateTime.utc(2026, 6, 2, 7, 30);
      final map = buildModel(createdAt: utcInstant.toLocal()).toMap();
      map[DatabaseTables.exerciseCreatedAt] = '2026-06-02T07:30:00.000Z';
      final parsed = ExerciseModel.fromMap(map);
      expect(parsed.createdAt.isAtSameMomentAs(utcInstant), isTrue);
      expect(parsed.createdAt.isUtc, isFalse);
    });
  });

  group('ExerciseModel.toJson / fromJson', () {
    test('toJson createdAt is Z-suffixed', () {
      final json = buildModel().toJson();
      expect((json['createdAt'] as String).endsWith('Z'), isTrue);
    });

    test('fromJson createdAt round-trips to same instant and is local', () {
      final model = buildModel();
      final roundTripped = ExerciseModel.fromJson(model.toJson());
      expect(roundTripped.createdAt.isAtSameMomentAs(model.createdAt), isTrue);
      expect(roundTripped.createdAt.isUtc, isFalse);
    });
  });
}

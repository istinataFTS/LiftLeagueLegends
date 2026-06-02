import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/enums/sync_status.dart';
import 'package:fitness_tracker/data/models/workout_set_model.dart';
import 'package:fitness_tracker/domain/entities/entity_sync_metadata.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime baseDate = DateTime(2026, 6, 2, 10, 30, 0);

  WorkoutSetModel buildModel({
    String id = 'set-1',
    DateTime? date,
    DateTime? createdAt,
    DateTime? updatedAt,
    EntitySyncMetadata syncMetadata = const EntitySyncMetadata(),
  }) {
    final d = date ?? baseDate;
    return WorkoutSetModel(
      id: id,
      ownerUserId: 'user-1',
      exerciseId: 'bench',
      reps: 10,
      weight: 80.0,
      date: d,
      createdAt: createdAt ?? d,
      updatedAt: updatedAt ?? d,
      syncMetadata: syncMetadata,
    );
  }

  group('WorkoutSetModel.toMap', () {
    test('date field is Z-suffixed', () {
      final model = buildModel();
      final map = model.toMap();
      expect((map[DatabaseTables.setDate] as String).endsWith('Z'), isTrue);
    });

    test('createdAt field is Z-suffixed', () {
      final model = buildModel();
      final map = model.toMap();
      expect(
        (map[DatabaseTables.setCreatedAt] as String).endsWith('Z'),
        isTrue,
      );
    });

    test('updatedAt field is Z-suffixed', () {
      final model = buildModel();
      final map = model.toMap();
      expect(
        (map[DatabaseTables.setUpdatedAt] as String).endsWith('Z'),
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
        (map[DatabaseTables.setLastSyncedAt] as String).endsWith('Z'),
        isTrue,
      );
    });

    test('lastSyncedAt is null when absent', () {
      final model = buildModel();
      final map = model.toMap();
      expect(map[DatabaseTables.setLastSyncedAt], isNull);
    });
  });

  group('WorkoutSetModel.fromMap round-trip', () {
    test('date round-trips to same instant and is local', () {
      final model = buildModel();
      final roundTripped = WorkoutSetModel.fromMap(model.toMap());
      expect(roundTripped.date.isAtSameMomentAs(model.date), isTrue);
      expect(roundTripped.date.isUtc, isFalse);
    });

    test('createdAt round-trips to same instant and is local', () {
      final model = buildModel();
      final roundTripped = WorkoutSetModel.fromMap(model.toMap());
      expect(roundTripped.createdAt.isAtSameMomentAs(model.createdAt), isTrue);
      expect(roundTripped.createdAt.isUtc, isFalse);
    });

    test('updatedAt round-trips to same instant and is local', () {
      final model = buildModel(
        updatedAt: baseDate.add(const Duration(hours: 1)),
      );
      final roundTripped = WorkoutSetModel.fromMap(model.toMap());
      expect(roundTripped.updatedAt.isAtSameMomentAs(model.updatedAt), isTrue);
      expect(roundTripped.updatedAt.isUtc, isFalse);
    });

    test('Z-suffix stored date parses to correct local instant', () {
      final utcInstant = DateTime.utc(2026, 6, 2, 7, 30);
      final map = buildModel(date: utcInstant.toLocal()).toMap();
      // Replace the stored date with an explicit Z string (as if pulled from Supabase).
      map[DatabaseTables.setDate] = '2026-06-02T07:30:00.000Z';
      final parsed = WorkoutSetModel.fromMap(map);
      expect(parsed.date.isAtSameMomentAs(utcInstant), isTrue);
      expect(parsed.date.isUtc, isFalse);
    });
  });

  group('WorkoutSetModel.toJson / fromJson', () {
    test('toJson date is Z-suffixed', () {
      final model = buildModel();
      final json = model.toJson();
      expect((json['date'] as String).endsWith('Z'), isTrue);
    });

    test('fromJson date round-trips to same instant and is local', () {
      final model = buildModel();
      final roundTripped = WorkoutSetModel.fromJson(model.toJson());
      expect(roundTripped.date.isAtSameMomentAs(model.date), isTrue);
      expect(roundTripped.date.isUtc, isFalse);
    });
  });
}

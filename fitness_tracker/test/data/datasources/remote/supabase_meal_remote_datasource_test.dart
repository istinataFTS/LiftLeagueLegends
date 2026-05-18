import 'package:fitness_tracker/data/datasources/remote/supabase_client_provider.dart';
import 'package:fitness_tracker/data/datasources/remote/supabase_meal_remote_datasource.dart';
import 'package:fitness_tracker/data/dtos/supabase/supabase_meal_dto.dart';
import 'package:fitness_tracker/domain/entities/meal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Meal buildMeal({String? ownerUserId = 'user-1'}) => Meal(
    id: 'local-1',
    ownerUserId: ownerUserId,
    name: 'Chicken Breast',
    servingSizeGrams: 100,
    carbsPer100g: 0,
    proteinPer100g: 31,
    fatPer100g: 3.6,
    caloriesPer100g: 156.4,
    createdAt: DateTime(2026, 3, 26, 10),
  );

  group('SupabaseMealRemoteDataSource', () {
    test('reports configured state from provider', () {
      const dataSource = SupabaseMealRemoteDataSource(
        clientProvider: SupabaseClientProvider(isConfigured: true),
      );

      expect(dataSource.isConfigured, isTrue);
    });

    test(
      'upsert payload carries the onConflict target columns (user_id, name)',
      () {
        // The remote upsert uses onConflict: "user_id,name"; the payload
        // must expose those columns. Guards the Phase-3 idempotent-upsert
        // contract for meals (mirrors the exercises guard).
        final map = SupabaseMealDto.fromEntity(buildMeal()).toMap();

        expect(map.containsKey('user_id'), isTrue);
        expect(map.containsKey('name'), isTrue);
        expect(map['name'], 'Chicken Breast');
        expect(map['user_id'], 'user-1');
      },
    );
  });
}

/// Integration regression test: profile data isolation.
///
/// Reproduces the exact multi-profile scenario that exposed the three
/// data-isolation bugs (Phases 1–5):
///
///   Bug 2 — Sign-out destroyed ALL profiles' local rows (unscoped DELETE).
///   Bug 3 — Guest read queries were unscoped (no owner_user_id filter).
///
/// Scenario:
///   1. [guest]   logs workout sets and meals.
///   2. [user-a]  signs in and logs their own sets / meals.
///   3. Assert    user-a reads see only user-a rows; guest rows untouched.
///   4. [user-a]  signs out  → owner-scoped clears remove user-a rows only.
///   5. Assert    guest rows are still intact after user-a's sign-out.
///   6. [user-b]  signs in — reads return nothing (no user-b rows in DB).
///   7. Assert    user-b cannot see guest data or user-a's (already wiped) data.
///
/// The test wires real datasource implementations against an in-memory
/// sqflite database with the production schema, so every SQL path exercised
/// here is identical to the production path.
library;

import 'package:fitness_tracker/core/constants/database_tables.dart';
import 'package:fitness_tracker/core/session/current_user_id_resolver.dart';
import 'package:fitness_tracker/data/datasources/local/meal_local_datasource_impl.dart';
import 'package:fitness_tracker/data/datasources/local/nutrition_log_local_datasource_impl.dart';
import 'package:fitness_tracker/data/datasources/local/workout_set_local_datasource_impl.dart';
import 'package:fitness_tracker/data/models/meal_model.dart';
import 'package:fitness_tracker/data/models/nutrition_log_model.dart';
import 'package:fitness_tracker/domain/entities/workout_set.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'support/in_memory_db_harness.dart';

// ─── Test doubles ────────────────────────────────────────────────────────────

class MockCurrentUserIdResolver extends Mock implements CurrentUserIdResolver {}

// ─── Fixtures ────────────────────────────────────────────────────────────────

const String _guestId = ''; // ''
const String _userAId = 'user-a';
const String _userBId = 'user-b';

final DateTime _date = DateTime(2026, 4, 20, 10);

WorkoutSet _buildSet({required String id, required String ownerId}) =>
    WorkoutSet(
      id: id,
      ownerUserId: ownerId,
      exerciseId: 'bench-press',
      reps: 8,
      weight: 80.0,
      intensity: 7,
      date: _date,
      createdAt: _date,
    );

MealModel _buildMeal({
  required String id,
  required String ownerId,
  required String name,
}) => MealModel(
  id: id,
  ownerUserId: ownerId,
  name: name,
  servingSizeGrams: 100,
  carbsPer100g: 30,
  proteinPer100g: 20,
  fatPer100g: 10,
  caloriesPer100g: 290,
  createdAt: _date,
  updatedAt: _date,
);

NutritionLogModel _buildLog({required String id, required String ownerId}) =>
    NutritionLogModel(
      id: id,
      ownerUserId: ownerId,
      mealName: 'Direct log',
      proteinGrams: 25,
      carbsGrams: 40,
      fatGrams: 10,
      calories: 350,
      loggedAt: _date,
      createdAt: _date,
      updatedAt: _date,
    );

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  late InMemoryDbHarness dbHarness;

  late MockCurrentUserIdResolver resolver;

  late WorkoutSetLocalDataSourceImpl setDs;
  late NutritionLogLocalDataSourceImpl logDs;
  late MealLocalDataSourceImpl mealDs;

  setUp(() async {
    dbHarness = await InMemoryDbHarness.open();

    resolver = MockCurrentUserIdResolver();

    setDs = WorkoutSetLocalDataSourceImpl(
      databaseHelper: dbHarness.helper,
      currentUserIdResolver: resolver,
    );

    logDs = NutritionLogLocalDataSourceImpl(
      databaseHelper: dbHarness.helper,
      currentUserIdResolver: resolver,
    );

    mealDs = MealLocalDataSourceImpl(
      databaseHelper: dbHarness.helper,
      currentUserIdResolver: resolver,
    );
  });

  tearDown(() async {
    await dbHarness.close();
  });

  /// Configures the resolver mock to the given identity.
  ///
  /// Pass [''] (`''`) to simulate a guest session.
  void switchIdentity(String userId) {
    when(() => resolver.resolve()).thenAnswer((_) async => userId);
  }

  test(
    'guest rows are invisible to user-a; '
    'user-a rows are invisible to guest (Phase 3 — owner-scoped reads)',
    () async {
      // ── Step 1: guest logs data ──────────────────────────────────────────
      switchIdentity(_guestId);

      await setDs.addSet(_buildSet(id: 'guest-set', ownerId: _guestId));
      await mealDs.insertMeal(
        _buildMeal(id: 'guest-meal', ownerId: _guestId, name: 'Guest Oats'),
      );

      // ── Step 2: user-a signs in and logs their own data ──────────────────
      switchIdentity(_userAId);

      await setDs.addSet(_buildSet(id: 'a-set', ownerId: _userAId));
      await mealDs.insertMeal(
        _buildMeal(id: 'a-meal', ownerId: _userAId, name: 'User A Chicken'),
      );

      // ── Step 3: user-a reads see only user-a data ────────────────────────
      final aSets = await setDs.getAllSets();
      expect(
        aSets.map((s) => s.id),
        equals(<String>['a-set']),
        reason: 'user-a must not see guest sets',
      );

      final aMeals = await mealDs.getAllMeals();
      expect(
        aMeals.map((m) => m.id),
        equals(<String>['a-meal']),
        reason: 'user-a must not see guest meals',
      );

      // ── Step 4: switch back to guest — guest reads see only guest data ───
      switchIdentity(_guestId);

      final guestSets = await setDs.getAllSets();
      expect(
        guestSets.map((s) => s.id),
        equals(<String>['guest-set']),
        reason: 'guest must not see user-a sets',
      );

      final guestMeals = await mealDs.getAllMeals();
      expect(
        guestMeals.map((m) => m.id),
        equals(<String>['guest-meal']),
        reason: 'guest must not see user-a meals',
      );
    },
  );

  test('sign-out of user-a removes only user-a rows; '
      'guest rows survive intact (Phase 2 — owner-scoped clears)', () async {
    // ── Seed all three owners ────────────────────────────────────────────
    await setDs.addSet(_buildSet(id: 'guest-set', ownerId: _guestId));
    await setDs.addSet(_buildSet(id: 'a-set', ownerId: _userAId));
    await setDs.addSet(_buildSet(id: 'b-set', ownerId: _userBId));

    await logDs.insertLog(_buildLog(id: 'guest-log', ownerId: _guestId));
    await logDs.insertLog(_buildLog(id: 'a-log', ownerId: _userAId));
    await logDs.insertLog(_buildLog(id: 'b-log', ownerId: _userBId));

    await mealDs.insertMeal(
      _buildMeal(id: 'guest-meal', ownerId: _guestId, name: 'Guest Oats'),
    );
    await mealDs.insertMeal(
      _buildMeal(id: 'a-meal', ownerId: _userAId, name: 'User A Chicken'),
    );
    await mealDs.insertMeal(
      _buildMeal(id: 'b-meal', ownerId: _userBId, name: 'User B Rice'),
    );

    // ── Simulate user-a sign-out: owner-scoped clears ────────────────────
    await setDs.clearSetsForOwner(_userAId);
    await logDs.clearLogsForOwner(_userAId);
    await mealDs.clearMealsForOwner(_userAId);

    // ── Inspect raw DB — no resolver needed ──────────────────────────────
    final db = dbHarness.database;

    final setRows = await db.query(DatabaseTables.workoutSets);
    final setIds = setRows
        .map((r) => r[DatabaseTables.setId] as String)
        .toSet();
    expect(
      setIds,
      equals(<String>{'guest-set', 'b-set'}),
      reason: 'only user-a sets must be removed; guest and user-b survive',
    );

    final logRows = await db.query(DatabaseTables.nutritionLogs);
    final logIds = logRows
        .map((r) => r[DatabaseTables.nutritionLogId] as String)
        .toSet();
    expect(
      logIds,
      equals(<String>{'guest-log', 'b-log'}),
      reason: 'only user-a logs must be removed; guest and user-b survive',
    );

    final mealRows = await db.query(DatabaseTables.meals);
    final mealIds = mealRows
        .map((r) => r[DatabaseTables.mealId] as String)
        .toSet();
    expect(
      mealIds,
      equals(<String>{'guest-meal', 'b-meal'}),
      reason: 'only user-a meals must be removed; guest and user-b survive',
    );
  });

  test(
    'full multi-profile lifecycle: '
    'guest → sign in A → sign out A → sign in B — no cross-owner bleed',
    () async {
      // ── Phase 1: guest logs sets and a meal ──────────────────────────────
      switchIdentity(_guestId);

      await setDs.addSet(_buildSet(id: 'guest-set-1', ownerId: _guestId));
      await setDs.addSet(_buildSet(id: 'guest-set-2', ownerId: _guestId));
      await mealDs.insertMeal(
        _buildMeal(id: 'guest-meal', ownerId: _guestId, name: 'Porridge'),
      );

      // ── Phase 2: user-a signs in and logs data ───────────────────────────
      switchIdentity(_userAId);

      await setDs.addSet(_buildSet(id: 'a-set-1', ownerId: _userAId));
      await setDs.addSet(_buildSet(id: 'a-set-2', ownerId: _userAId));
      await mealDs.insertMeal(
        _buildMeal(id: 'a-meal', ownerId: _userAId, name: 'A Chicken'),
      );
      await logDs.insertLog(_buildLog(id: 'a-log', ownerId: _userAId));

      // user-a reads see only user-a data.
      final aSets = await setDs.getAllSets();
      expect(
        aSets.map((s) => s.id).toSet(),
        equals(<String>{'a-set-1', 'a-set-2'}),
        reason: 'user-a must not see guest sets (Phase 3)',
      );

      // guest rows are still in the DB and still owned by guest.
      final db = dbHarness.database;
      final rawSetsBeforeSignOut = await db.query(
        DatabaseTables.workoutSets,
        where: '${DatabaseTables.ownerUserId} = ?',
        whereArgs: <Object?>[_guestId],
      );
      expect(
        rawSetsBeforeSignOut,
        hasLength(2),
        reason:
            'guest sets must not be adopted or deleted during user-a session (Phase 1)',
      );

      // ── Phase 3: user-a signs out — scoped clears ────────────────────────
      await setDs.clearSetsForOwner(_userAId);
      await logDs.clearLogsForOwner(_userAId);
      await mealDs.clearMealsForOwner(_userAId);

      // user-a's rows are gone.
      final rawSetsAfterSignOut = await db.query(
        DatabaseTables.workoutSets,
        where: '${DatabaseTables.ownerUserId} = ?',
        whereArgs: <Object?>[_userAId],
      );
      expect(
        rawSetsAfterSignOut,
        isEmpty,
        reason: 'user-a sets must be wiped on sign-out (Phase 2)',
      );

      // guest rows are INTACT — this was the reported data-loss bug.
      final rawGuestSetsAfterSignOut = await db.query(
        DatabaseTables.workoutSets,
        where: '${DatabaseTables.ownerUserId} = ?',
        whereArgs: <Object?>[_guestId],
      );
      expect(
        rawGuestSetsAfterSignOut,
        hasLength(2),
        reason: 'guest sets must survive user-a sign-out (Phase 2)',
      );

      // ── Phase 4: user-b signs in — clean slate ───────────────────────────
      switchIdentity(_userBId);

      final bSets = await setDs.getAllSets();
      expect(
        bSets,
        isEmpty,
        reason: 'user-b must see no sets (nothing seeded for user-b)',
      );

      final bMeals = await mealDs.getAllMeals();
      expect(
        bMeals,
        isEmpty,
        reason: 'user-b must see no meals (guest + user-a both scoped out)',
      );

      // Guest rows are still in the DB for whenever the guest session resumes.
      switchIdentity(_guestId);

      final guestSetsAfterAll = await setDs.getAllSets();
      expect(
        guestSetsAfterAll.map((s) => s.id).toSet(),
        equals(<String>{'guest-set-1', 'guest-set-2'}),
        reason: 'guest reads must return the original guest sets at any point',
      );
    },
  );
}

# Playbook — Add a user-scoped local datasource

- **Task:** Add a new user-scoped local SQLite datasource to an existing feature
- **When to use:** When a feature needs to persist per-user rows in the local SQLite database
- **Estimated steps:** 6
- **Last verified:** 2026-05-30
- **Canonical references:** [[datasource]], [[injection_module]]
- **Touches:** data, di, test
- **Related playbooks:** [add-feature](add-feature.md), [add-migration](add-migration.md)

---

## 0. Preconditions

- Read `.claude/reference/datasource.md` end-to-end before starting. It explains `whereOwned(...)`, `resolveOwnerId()`, and `requireAuthenticatedOwnerId()`.
- The feature directory `lib/features/<name>/` already exists.
- If a new table is required, complete `add-migration.md` first and confirm the table is created in `onCreate` / `onUpgrade`.
- `dart run tool/check_conventions.dart` passes before you touch anything.

---

## Steps

### 1. Decide whether the datasource is user-scoped or global

- [ ] Ask: does every row in this table belong to exactly one user? If yes → user-scoped. If no (e.g. a global config table) → see the exemption list in `lib/data/datasources/local/user_scoped_local_datasource.dart`.
- [ ] If exempt, add the new file to the `_exemptFiles` set in `tool/convention_rules/user_scoped_datasource.dart` and update the base-class doc-comment exemption list. Then stop — this playbook covers user-scoped only.

### 2. Create the datasource interface and implementation files

- [ ] Create `lib/data/datasources/local/<feature>_local_datasource.dart` — the abstract interface. List every method that the repository will call.
- [ ] Create `lib/data/datasources/local/<feature>_local_datasource_impl.dart` — the concrete class. Mirror the shape of `lib/data/datasources/local/workout_set_local_datasource_impl.dart:12`.
- [ ] `<FeatureLocalDataSourceImpl>` must `extend UserScopedLocalDatasource` (`lib/data/datasources/local/user_scoped_local_datasource.dart:35`). No constructor call to `super` is needed; the base class provides the resolver via its constructor argument (`currentUserIdResolver`).

### 3. Implement all user-scoped query methods

- [ ] Every `db.query`, `db.update`, `db.delete` call that filters by owner **must** use `whereOwned(...)` (`lib/data/datasources/local/user_scoped_local_datasource.dart`). Never interpolate `ownerId` into the SQL string literal.
- [ ] Call `await ownerId()` (`lib/data/datasources/local/user_scoped_local_datasource.dart`) to obtain the current authenticated owner ID. It throws `MissingUserContextException` if no user is in context — **there is no guest mode**, so no empty-string guard is needed.
- [ ] Insert methods must stamp the row with the `ownerId` column value obtained from `ownerId()`.

### 4. Add auth protection to sync operations

- [ ] List every method that reads from or writes to Supabase (push, pull, prepareMigration). Each calls `ownerId()` which already throws `MissingUserContextException` if no user is present — no separate auth guard is required beyond calling `ownerId()` first.

### 5. Register the datasource in the feature's DI module

- [ ] In `lib/injection/modules/register_<feature>_module.dart`, add `sl.registerLazySingleton<FeatureLocalDataSource>(() => FeatureLocalDataSourceImpl(currentUserIdResolver: sl()))`. Mirror `.claude/reference/injection_module.md`.
- [ ] Datasources are **always** `registerLazySingleton`, never `registerFactory`.
- [ ] Verify no duplicate registration. See KNOWN_ISSUES.md [#duplicate-di-registration-causes-silent-bugs](../../KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs).

### 6. Write the auth-only test and the base-class behaviour test

- [ ] Add a test file at `test/data/datasources/local/<feature>_local_datasource_impl_test.dart`.
- [ ] Test 1 (auth-only): call each method that calls `ownerId()` without a signed-in user and assert `MissingUserContextException` is thrown. Mirror the pattern from the v22 migration test.
- [ ] Test 2 (base-class): confirm `ownerId()` returns the real user ID in authenticated mode and throws `MissingUserContextException` when no user is in context.
- [ ] Run `flutter test test/data/datasources/local/<feature>_local_datasource_impl_test.dart` before moving on.

---

## Verification

Run the following from `fitness_tracker/` and confirm each passes before opening a PR:

```sh
dart format --output=none --set-exit-if-changed $(git diff --name-only origin/main -- '*.dart')
flutter analyze
dart run tool/check_conventions.dart
flutter test
```

---

## Pitfalls

- **Forget to extend `UserScopedLocalDatasource`** — CI will fail the `user-scoped-datasource` convention rule immediately. Never skip the base class.
- **Interpolate `ownerId` into a SQL string** — CI will fail the `sql-userid-interpolation` rule. Always use `whereOwned(...)` or `whereArgs`.
- **Register the datasource as a BLoC factory** — datasources are singletons. Registering as `registerFactory` creates one instance per page, each with its own database connection handle.
- **Duplicate DI registration** — see [KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs](../../KNOWN_ISSUES.md#duplicate-di-registration-causes-silent-bugs).
- **Add an empty-string guard around `ownerId()`** — there is no guest mode; `ownerId()` either returns an authenticated uid or throws. An `if (id.isEmpty) return []` check masks a session-resolution bug rather than handling it.

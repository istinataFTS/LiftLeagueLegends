# Canonical example — User-scoped local datasource

- **Pattern:** User-scoped local datasource
- **Canonical file:** `lib/data/datasources/local/workout_set_local_datasource_impl.dart`
- **Locked by:** PR `#56`, commit `6171671` — Adoption 02 migrated this datasource to extend `UserScopedLocalDatasource`, making it the first full exerciser of every base-class method
- **Last verified:** 2026-05-30
- **Related references:** [[repository]], [[injection_module]]
- **Companion playbook:** _(to be added by Adoption 05: `.claude/skills/add-feature.md`)_
- **Embodied conventions:**
  - Every user-scoped local datasource extends `UserScopedLocalDatasource` — see CLAUDE.md "User-scoped local datasources"
  - `whereOwned(...)` is the only sanctioned way to build an owner-filtered `WHERE` clause — see `lib/data/datasources/local/user_scoped_local_datasource.dart`
  - `ownerId()` obtains the current authenticated owner ID — it throws `MissingUserContextException` if no user is in context; **there is no guest mode**
  - Bulk replacement uses a single SQLite transaction + batch to keep the write atomic — see CLAUDE.md "Local database"
  - All public methods wrap in `try/catch` and rethrow as `CacheDatabaseException` — see CLAUDE.md "Error handling"
  - Datasource interface (`WorkoutSetLocalDataSource`) lives in a separate file; the impl is a distinct file — no "god file" with both

---

## Why this is the canonical

`WorkoutSetLocalDataSourceImpl` is the canonical datasource example because it is the *only* datasource in the codebase that exercises every method on `UserScopedLocalDatasource`: `resolveOwnerId()` for standard queries, `requireAuthenticatedOwnerId(operation:)` for the initial-sync prepare path, and `whereOwned(...)` with and without the `extra:` predicate. It was explicitly hardened by Adoption 02 (PR `#56`) to demonstrate all three usage modes in a single class, making it the reference point for every datasource added afterward.

It also showcases the two-tier read model that is standard in this codebase: `_getVisibleSets()` / `_getVisibleSetById()` for UI reads (owner-scoped, pending-delete filtered), and `_getStoredSets()` / `_getStoredSetById()` for sync reads (unscoped, all rows). Understanding why the unscoped variants exist — and when to use each — is the main thing a copier needs to internalise.

**There is no guest mode.** Every datasource operates only on authenticated user data. The convention checker enforces that every concrete local datasource extends `UserScopedLocalDatasource`, with three documented exemptions (see the base class doc comment). `ownerId()` either returns an authenticated user ID or throws — callers do not need a "missing user" branch.

---

## Walkthrough

### Class declaration and constructor (lines 12–24)

`workout_set_local_datasource_impl.dart:12-13` — The `extends UserScopedLocalDatasource` clause is load-bearing. The `implements WorkoutSetLocalDataSource` clause enforces the interface contract. Both must appear; neither alone is sufficient.

`workout_set_local_datasource_impl.dart:21-24` — The constructor passes `databaseHelper` and `currentUserIdResolver` via `super(...)`, not re-declaring them as fields. This is the correct shape: the base class owns the fields; the subclass provides values. Do not re-declare `databaseHelper` or `currentUserIdResolver` as local fields.

`workout_set_local_datasource_impl.dart:14-19` — `LocalRemoteMerge` is a static field because it is stateless and shared across all instances. Declare merge helpers and other stateless utilities as `static final` rather than as instance fields or local variables.

### Standard owner-filtered query — `whereOwned(...)` with `extra:` (lines 47–68)

`workout_set_local_datasource_impl.dart:47-68` — `getSetsByExerciseId` is the canonical example of a query with two filters: an entity-specific predicate (`exercise_id = ?`) and the standard pending-delete exclusion, both composed via the `extra:` / `extraArgs:` parameters of `whereOwned(...)`. The owner filter is always the *last* predicate because `whereOwned` appends `owner_user_id = ?` after the `extra` clause. Do not write inline `WHERE` strings that include `owner_user_id`; always delegate to `whereOwned`.

### Obtaining the owner id — `ownerId()` (lines 182–198)

`workout_set_local_datasource_impl.dart:182-185` — `prepareForInitialCloudMigration` calls `await ownerId()` as its first action. Since guest mode was removed, `ownerId()` is the single method for obtaining the current owner — it returns the authenticated user ID or throws `MissingUserContextException` if the session cannot be resolved. The distinction between "guest-safe" reads (old `resolveOwnerId()`) and "auth-only" writes (old `requireAuthenticatedOwnerId()`) no longer exists: every datasource call runs above the sign-in gate and may safely call `ownerId()` without a guest fallback check.

### Internal visible-reads pattern (lines 364–406)

`workout_set_local_datasource_impl.dart:364-382` — `_getVisibleSets()` is the private helper used by every public read method that targets the UI. Note the sequence: resolve owner → get db handle → build filter via `whereOwned` → query. This three-step sequence is always the same. Extract it into a private helper rather than repeating it in each public method.

`workout_set_local_datasource_impl.dart:384-406` — `_getVisibleSetById` shows the single-item variant: the entity's primary key is part of `extra:`, not a separate `WHERE` clause. Never write `where: '${DatabaseTables.setId} = ? AND owner_user_id = ?'` inline — compose via `whereOwned`.

### Internal storage-reads (unscoped) and when to use them (lines 408–433)

`workout_set_local_datasource_impl.dart:408-433` — `_getStoredSets()` and `_getStoredSetById()` are intentionally *unscoped* — they query the raw table without owner or sync-status filters. These exist because sync operations (`mergeRemoteSets`, `prepareForInitialCloudMigration`) must see all rows including pending-deletes and rows belonging to the signed-out session. **Never use these from a public method** that services UI reads — they would expose cross-user data. The naming convention (`_getStored*` vs `_getVisible*`) is the signal: "stored" = raw table, "visible" = owner-scoped, pending-delete excluded.

### Atomic bulk replacement with transaction + batch (lines 435–452)

`workout_set_local_datasource_impl.dart:435-452` — `_replaceStoredSets` wraps the delete + batch-insert in a single `db.transaction(...)`. This is required: if the app is killed between the delete and the re-insert, the local database would be empty. Always use a transaction for operations that combine a DELETE with subsequent INSERTs. `batch.commit(noResult: true)` skips per-row result parsing for write performance.

---

## Before you copy this

- [ ] **Extend, do not compose.** Your new datasource must `extends UserScopedLocalDatasource`, not hold it as a field. Composition bypasses the `@protected` access control on `resolveOwnerId()` and `whereOwned(...)`.
- [ ] **Pass `super.databaseHelper` and `super.currentUserIdResolver` in the constructor.** Do not redeclare them as your own fields.
- [ ] **Every public read method that targets the UI must use `whereOwned(...)`.** No inline `owner_user_id = ?` strings in public methods.
- [ ] **Call `await ownerId()` at the top of any method that needs the current user.** It throws `MissingUserContextException` if no user is in context — do not add an empty-string guard around it.
- [ ] **Wrap all public methods in `try/catch` and rethrow as `CacheDatabaseException`.** No raw exceptions escape the datasource layer.
- [ ] **Name your internal helpers `_getVisible*` for UI reads and `_getStored*` for raw/sync reads.** This naming convention is the only signal of which kind of scope applies.
- [ ] **Use `db.transaction(...)` + `batch.commit(noResult: true)` for any bulk delete+insert.** Never delete and then insert outside a transaction.
- [ ] **Register the new datasource in the matching `register_*_module.dart` as `registerLazySingleton<Interface>`.** See [[injection_module]].
- [ ] **If your datasource does NOT scope by user (e.g. a global catalog table), it must be added to the exemption list in `user_scoped_local_datasource.dart`'s doc comment** rather than silently omitting `extends UserScopedLocalDatasource`.

---

## If you change the pattern

If the canonical shape changes — for example, the `UserScopedLocalDatasource` API gains a new method, the error type changes, or the naming convention evolves — update this file in the same PR and update the companion playbook in `.claude/skills/`. Adoption 04 will verify that the canonical file path still exists and that the class still extends `UserScopedLocalDatasource`; a shape change that the CI check cannot detect must be manually reflected here.

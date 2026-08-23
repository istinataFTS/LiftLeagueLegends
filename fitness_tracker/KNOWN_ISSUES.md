# KNOWN_ISSUES.md

A structured log of real, recurring traps in this codebase's stack. When you hit a gotcha that cost more than 15 minutes to debug, add it here before opening the PR that fixes it. The entry is part of the fix.

This file covers *repo-specific* quirks only — things that are not obvious from the Flutter/Dart/Supabase docs alone. General Flutter behaviour belongs in external docs or in code comments.

---

## How to add an entry

Copy the template below, fill in every field, and append it under the correct section. Do not omit fields — a stub entry is worse than no entry.

```
### <short-kebab-case-title>

- **Severity:** Critical | High | Medium | Low
- **Status:** Active | Mitigated | Resolved-but-monitor
- **First observed:** YYYY-MM-DD
- **Last verified:** YYYY-MM-DD
- **Area:** sync | db | di | ci | platform | other

**Symptom**

One short paragraph describing what the developer or app sees when this trap fires.

**Root cause**

One short paragraph explaining why it happens. Be specific — name the file, the API, the constraint.

**Workaround / fix**

Numbered steps or a short paragraph. State what to do and what *not* to do.

**References**

- `path/to/file.dart:LINE` — what to look at
- Commit `<7-char-sha>` — when it was fixed/observed
- PR `#NN` — discussion
- External link if any
```

### Style guide

- Third person, present tense: "The datasource does X" not "I found that X".
- File paths in backticks: `` `lib/path/to/file.dart:LINE` ``.
- Constants by symbolic name, not literal value: `` `AppConstants.maxSetsPerExercise` `` not `"10"`. Exception: entries describing a historical change may quote the old value.
- Commit SHAs: 7-character short form (e.g. `` `1f72e9b` ``).
- `Last verified` is the date the entry was last confirmed still accurate. Bump it at every adoption boundary (adoption 02 through 06 each start with a 5-minute pass through this file).

### Severity definitions

| Level | Meaning |
|---|---|
| **Critical** | Data loss, production outage, or cross-user data leakage. |
| **High** | User-visible incorrectness or persistent state corruption. |
| **Medium** | Developer-visible only, or recoverable by the user without data loss. |
| **Low** | Cosmetic, UX preference, or local tooling friction. |

---

## Table of contents

### Sync
1. [guest-data-must-not-adopt-on-sign-in](#guest-data-must-not-adopt-on-sign-in)
2. [sign-out-must-scope-data-clear-to-signing-out-owner](#sign-out-must-scope-data-clear-to-signing-out-owner)
3. [pending-delete-queue-must-clear-on-sign-out](#pending-delete-queue-must-clear-on-sign-out)
4. [per-entity-sync-failures-need-underlying-cause-logged](#per-entity-sync-failures-need-underlying-cause-logged)
5. [muscle-map-needs-rebuild-after-background-sync](#muscle-map-needs-rebuild-after-background-sync)
6. [pre-auth-write-through-must-skip-remote-push](#pre-auth-write-through-must-skip-remote-push)
7. [timestamps-must-round-trip-as-utc-not-naive-local](#timestamps-must-round-trip-as-utc-not-naive-local)

### Database

1. [sqflite-version-15-rejects-incompatible-legacy-databases](#sqflite-version-15-rejects-incompatible-legacy-databases)
2. [conflict-algorithm-replace-needed-for-deterministic-default-ids](#conflict-algorithm-replace-needed-for-deterministic-default-ids)
3. [pull-before-push-for-sign-in-sync](#pull-before-push-for-sign-in-sync)
4. [default-catalog-ids-must-be-owner-scoped](#default-catalog-ids-must-be-owner-scoped)
5. [guest-catalog-pk-collision-blocks-initial-sign-in](#guest-catalog-pk-collision-blocks-initial-sign-in)
6. [migration-add-column-must-be-idempotent](#migration-add-column-must-be-idempotent)
7. [muscle-taxonomy-vocabulary-split-hid-fatigue](#muscle-taxonomy-vocabulary-split-hid-fatigue)

### Dependency Injection

1. [blocs-must-be-factories-repositories-singletons](#blocs-must-be-factories-repositories-singletons)
2. [duplicate-di-registration-causes-silent-bugs](#duplicate-di-registration-causes-silent-bugs)
3. [fire-and-forget-futures-in-startup-cause-race-conditions](#fire-and-forget-futures-in-startup-cause-race-conditions)
4. [widget-state-must-not-field-capture-factory-blocs-or-cubits](#widget-state-must-not-field-capture-factory-blocs-or-cubits)

### CI & Local Tooling

1. [crlf-line-endings-cause-false-positive-dart-format-locally](#crlf-line-endings-cause-false-positive-dart-format-locally)
2. [flutter-analyze-info-issues-do-not-fail-ci](#flutter-analyze-info-issues-do-not-fail-ci)
3. [main-branch-is-pr-only-direct-push-blocked](#main-branch-is-pr-only-direct-push-blocked)
4. [convention-checker-regexes-must-have-multiline-test-fixtures](#convention-checker-regexes-must-have-multiline-test-fixtures)

### Platform

1. [dart-define-is-build-time-not-runtime](#dart-define-is-build-time-not-runtime)
2. [supabase-disabled-by-default](#supabase-disabled-by-default)

### Other

1. [history-renders-orphaned-sets-not-hides-them](#history-renders-orphaned-sets-not-hides-them)
2. [cross-feature-presentation-imports-are-architectural-cycles](#cross-feature-presentation-imports-are-architectural-cycles)
3. [empty-state-columns-need-scrollable-centering](#empty-state-columns-need-scrollable-centering)
4. [muscle-stimulus-repository-userid-parameter-silently-dropped](#muscle-stimulus-repository-userid-parameter-silently-dropped)
5. [history-calendar-dot-disagrees-with-day-detail-for-orphan-sets](#history-calendar-dot-disagrees-with-day-detail-for-orphan-sets)
6. [signin-does-not-navigate-until-restart](#signin-does-not-navigate-until-restart)
7. [auth-gate-must-not-flash-signin-before-session-resolves](#auth-gate-must-not-flash-signin-before-session-resolves)
8. [muscle-stimulus-rebuild-dst-day-iteration](#muscle-stimulus-rebuild-dst-day-iteration)
9. [full-width-elevated-button-crashes-inside-a-row](#full-width-elevated-button-crashes-inside-a-row)
10. [body-overlays-are-registered-to-the-base-arts-ink-box](#body-overlays-are-registered-to-the-base-arts-ink-box)

---

## Sync

### guest-data-must-not-adopt-on-sign-in

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-19
- **Last verified:** 2026-05-23
- **Area:** sync

**Symptom**

On initial sign-in, guest workout and nutrition data was being adopted (merged) into the newly authenticated account, causing the new account to contain data that did not belong to it.

**Root cause**

The initial sign-in sync path did not distinguish between guest data that should be migrated and guest data that should be discarded. The correct behaviour is: guest data is *not* adopted. The authenticated user starts from their server-side data only. The prepare → push → pull sequence runs purely to migrate any pre-existing server rows into the local database.

**Workaround / fix**

The fix is in place. Do not reintroduce adoption logic on the sign-in path. The sync ordering (prepare → push → pull) must respect FK dependencies: exercises → meals → workout_sets → nutrition_logs.

**References**

- `lib/core/session/session_sync_service_impl.dart` — sync ordering and sign-in path
- Commit `1f72e9b` — fix: stop guest data adoption on initial sign-in

---

### sign-out-must-scope-data-clear-to-signing-out-owner

- **Severity:** Critical
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-19
- **Last verified:** 2026-05-23
- **Area:** sync

**Symptom**

Signing out cleared *all* local data regardless of owner. On the next sign-in (or if a second user signed in on the same device), rows belonging to other users were gone or corrupted.

**Root cause**

The sign-out data-clear called an unscoped DELETE across all tables. Every datasource must filter deletes by `ownerUserId` equal to the user who is signing out.

**Workaround / fix**

The scoped clear is in place. Any future datasource that participates in sign-out cleanup must accept the signing-out user's ID and scope its DELETE accordingly. Never call an unscoped DELETE as part of sign-out.

**References**

- `lib/core/session/session_sync_service_impl.dart` — sign-out clear orchestration
- Commit `f10edd0` — fix: scope sign-out data clear to the signing-out owner
- PR `#50`, PR `#51` — discussion and merge

---

### pending-delete-queue-must-clear-on-sign-out

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-19
- **Last verified:** 2026-05-23
- **Area:** sync

**Symptom**

Pending remote deletions queued for user A were still present after sign-out. When user B signed in, those deletions ran against user B's server-side data.

**Root cause**

The pending-delete queue was not included in the sign-out cleanup. It holds row-level delete operations keyed by entity ID but not by owner, so a queue left over from a previous session is indistinguishable from the new user's queue.

**Workaround / fix**

The clear is in place. Any sign-out flow must flush the pending-delete queue for the signing-out user before the session is destroyed.

**References**

- `lib/data/datasources/local/pending_sync_delete_local_datasource_impl.dart` — queue storage
- Commit `7d69c72` — fix: clear pending-delete queue on sign-out; register CurrentUserIdResolver

---

### per-entity-sync-failures-need-underlying-cause-logged

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-17
- **Last verified:** 2026-05-23
- **Area:** sync

**Symptom**

Sync failures reported as generic `SyncFailure` with no detail. Debugging required attaching a debugger to identify the real database or network error underneath.

**Root cause**

Exception catch blocks in the sync layer re-wrapped exceptions as `SyncFailure` without preserving the original message or stack trace.

**Workaround / fix**

Always include the underlying exception's `toString()` in the failure message when wrapping. `RepositoryGuard.run()` does this automatically for repository-layer calls; sync-specific catch blocks must do it explicitly.

**References**

- Commit `533a565` — fix(sync): log underlying cause of per-entity sync failures

---

### muscle-map-needs-rebuild-after-background-sync

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-17
- **Last verified:** 2026-05-23
- **Area:** sync

**Symptom**

After a background sync completed, the muscle-stimulus map shown in the UI reflected pre-sync data until the user manually navigated away and back.

**Root cause**

`MuscleStimulusRebuildHook` was being triggered on UI demand rather than as a post-sync side effect. Background sync has no UI trigger, so the rebuild never ran.

**Workaround / fix**

`MuscleStimulusRebuildHook` is registered as a post-sync hook in `SyncOrchestrator` and runs automatically after every sync cycle. `MuscleFactorHealHook` runs first to ensure exercise factors are present. Do not move these hooks back to on-demand execution.

**References**

- `lib/core/sync/` — post-sync hook registration
- Commit `3d68873` — fix(sync): instant muscle-map updates after background sync

---

### pre-auth-write-through-must-skip-remote-push

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-23
- **Last verified:** 2026-05-23
- **Area:** sync

**Symptom**

Boot-time default-catalog seeding (`AppDataSeeder.seedIfEnabled` → `SeedMeals` / `SeedExercises` → `RepositoryImpl.addX`) emitted one `AuthSyncException: unauthenticated: <entity> remote access requires an authenticated user` warning *with full stack trace* per default row — ~100 lines of red on every cold start, drowning out genuinely actionable sync failures.

**Root cause**

Guest-owned writes already land in the local store with `SyncStatus.localOnly` via `guestAwareAddedSyncMetadata` / `guestAwareUpdatedSyncMetadata`. But `BaseEntitySyncCoordinator.persistAdded` / `persistUpdated` only gated the remote push on `isRemoteSyncEnabled` — they ignored the metadata. So every seeded guest row was pushed to Supabase anyway, the remote DTO's `user_id` check rejected it, and the exception was logged as a normal sync failure even though it is by design.

**Workaround / fix**

`persistAdded` / `persistUpdated` now consult `_shouldAttemptRemotePush(localEntity)`, which returns `false` when the just-built local metadata is `SyncStatus.localOnly`. Any new sync coordinator subclass automatically inherits this — there's nothing to remember as long as guest-owned writes go through `guestAwareAddedSyncMetadata`. Do **not** push `localOnly` rows out of band; the post-sign-in `InitialCloudMigrationCoordinator` drains anything that legitimately needs an upload.

**References**

- `lib/data/sync/base_entity_sync_coordinator.dart:108` — `_shouldAttemptRemotePush`
- `test/data/sync/base_entity_sync_coordinator_test.dart` — `localOnly write-through guard` group

---

### timestamps-must-round-trip-as-utc-not-naive-local

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-02
- **Last verified:** 2026-06-02
- **Area:** sync

**Symptom**

A workout set or nutrition log created moments ago is missing from "recent" reads
(weekly volume, the home dashboard) even though it persisted and shows correctly in
History. The gap is roughly the device's UTC offset — in UTC+3 the newest entry is
invisible for ~3 hours after it is logged. Near midnight an entry can also display
under the wrong calendar day.

**Root cause**

Entity timestamps (`WorkoutSet.date`, `NutritionLog.loggedAt`, every `createdAt` /
`updatedAt`) are created with `DateTime.now()` — a *local* DateTime — and were
serialized with a bare `.toIso8601String()`, which for a local DateTime omits the
offset (e.g. `2026-06-02T01:52:00.000`). Supabase `timestamptz` reads an offset-less
string as UTC, so the stored instant is shifted forward by the local offset; on
pull-back `DateTime.parse` yields that shifted instant. The authenticated
`remoteThenLocal` read path filters in memory with `!date.isAfter(DateTime.now())`
(`workout_set_repository_impl.dart`, `nutrition_log_repository_impl.dart`), so a
freshly-logged row reads as "in the future" and is dropped. The same offset corrupted
the `fetchSince('updated_at', …)` cursor and the local SQLite string range bounds.

**Workaround / fix**

1. Normalize at the serialization boundary only — entity DateTimes stay *local* in
   memory. Write every timestamp with `DateSerialization.toStorageIso()`
   (`lib/core/utils/date_serialization.dart`); parse with `parseStorageDate(...)`.
2. Compute day boundaries from local calendar components, then `.toStorageIso()` the
   bound, preserving "the user's day" against UTC-stored values.
3. Do NOT change the in-memory repository filters or any presentation code — under
   this strategy entity dates stay local and those comparisons are already correct.
4. No schema migration: only the string format inside existing columns changes.
   Already-shifted test rows were reset once post-fix (fix-forward).

**References**

- `lib/core/utils/date_serialization.dart` — the boundary helper
- `lib/data/models/workout_set_model.dart`, `lib/data/dtos/supabase/supabase_workout_set_dto.dart`
- `lib/data/repositories/workout_set_repository_impl.dart:126-130` — the filter that surfaced it
- PR `#NN` — fix

---

## Database

### sqflite-version-15-rejects-incompatible-legacy-databases

- **Severity:** High
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
- **Area:** db

**Symptom**

A device upgrading from a legacy schema version encounters a hard rejection rather than a migration. The app fails to open the database.

**Root cause**

Version 15 introduced a policy change: rather than attempting a destructive migration on an incompatible legacy schema, the migration path now rejects the database entirely. This prevents silent data loss but surfaces as a hard error for users with very old app versions.

**Workaround / fix**

All migrations from version 15 onward must be strictly additive (add columns, add tables, never drop or rename). The current schema version is tracked in `EnvConfig.databaseVersion`. When writing a new migration, increment that constant and add an additive-only upgrade step.

**References**

- `lib/config/env_config.dart` — `EnvConfig.databaseVersion`
- `lib/data/datasources/local/database_helper.dart` — migration dispatcher
- `CLAUDE.md` — "Version upgrades are additive; version 15+ rejects incompatible legacy databases"

---

### conflict-algorithm-replace-needed-for-deterministic-default-ids

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-18
- **Last verified:** 2026-05-23
- **Area:** db

**Symptom**

Re-seeding default exercises or meals (e.g. after a fresh install or a test reset) fails with a unique-constraint violation because the deterministic IDs already exist in the table.

**Root cause**

Default exercises and meals use deterministic IDs (introduced in PR `#49`) so that every device generates the same primary key for the same catalog entry. On re-seed, a plain INSERT hits an existing row and aborts.

**Workaround / fix**

Use `ConflictAlgorithm.replace` (sqflite) when inserting default catalog entries. The seeder already does this; any new seeding code must do the same.

**References**

- `lib/data/datasources/local/` — `ConflictAlgorithm.replace` in catalog insert paths
- Commit `e23c185` — fix(catalog): deterministic default exercise/meal identity + v21 migration
- PR `#49` — Fix/stable exercise meal identity

---

### pull-before-push-for-sign-in-sync

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-18
- **Last verified:** 2026-05-23
- **Area:** db

**Symptom**

On initial sign-in, locally generated guest-ID rows overwrote the server's canonical rows for the same entities, producing duplicate or corrupted records visible after the next pull.

**Root cause**

The original sign-in sync pushed local rows first, then pulled from the server. If the server already had a canonical version of an entity (e.g. a default exercise with a deterministic ID), the push overwrote it with the guest-local version before the pull could surface the conflict.

**Workaround / fix**

The sign-in sync path now pulls before pushing for any entity that may already exist on the server. Do not revert the ordering. The sequence is: prepare → (pull to surface conflicts) → push (idempotent upserts only).

**References**

- `lib/core/session/session_sync_service_impl.dart` — sign-in sync ordering
- Commit `4de6f8d` — fix(sync): idempotent upsert, pull-before-push, non-fatal sign-in
- PR `#49` — Fix/stable exercise meal identity

---

### default-catalog-ids-must-be-owner-scoped

- **Severity:** Critical
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-23
- **Last verified:** 2026-05-23
- **Area:** db

**Symptom**

Newly signed-in users opened the app to a completely empty Library (Exercises and Meals tabs both showed "No exercises yet" / "No meals yet"), even though the boot-time seeder logged a successful seed and `AccountCatalogProvisionHook` claimed to provision the new account's catalog. The Log → Exercise tab consequently showed "No exercises available — Go to Library to create exercises first".

**Root cause**

Default catalog rows used a name-only deterministic id: `DeterministicCatalogId.fromName('Bench Press')` produced the same UUIDv5 regardless of owner. The boot-time seed runs while the app is still in guest mode and writes 53 rows owned by `''` at those deterministic ids. When the user later signs in, the post-sync `AccountCatalogProvisionHook` calls `SeedMeals(ownerUserId: <new-user>)` which tries to insert rows at the *same* ids with the new owner — and `meal_local_datasource_impl.insertMeal` (correctly) uses `ConflictAlgorithm.abort` to avoid cascade-deleting linked `nutrition_logs`. Every insert aborted. `SeedMeals` swallowed each per-row failure and the hook logged a single innocuous "Failed to seed any meals", leaving the new user with no catalog.

**Workaround / fix**

`DeterministicCatalogId.forOwner(name:, ownerUserId:)` scopes the id by `'$owner|$canonicalName'`. Guest (`''` or `null`) collapses to the legacy name-only formula so existing on-disk guest rows remain addressable. Both `SeedMeals` and `SeedExercises` now use `forOwner` with the resolved owner. Any future default-catalog seeder MUST do the same — call `DeterministicCatalogId.forOwner`, never `.fromName` directly, when an owner is known. Tests under `test/domain/usecases/{exercises,meals}/` include a regression covering the guest-seeded-then-user-signs-in coexistence path.

**References**

- `lib/core/utils/deterministic_catalog_id.dart:59` — `forOwner` derivation
- `lib/domain/usecases/exercises/seed_exercises.dart`, `lib/domain/usecases/meals/seed_meals.dart` — call sites
- `lib/core/sync/hooks/account_catalog_provision_hook.dart` — post-sign-in provisioning that this unblocks
- `test/core/utils/deterministic_catalog_id_test.dart` — coexistence guarantees pinned

---

### guest-catalog-pk-collision-blocks-initial-sign-in

- **Severity:** Critical
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-28
- **Last verified:** 2026-05-30
- **Area:** db

**Symptom**

On the affected device, the initial cloud migration logs `[ERROR][sync] Initial cloud migration step failed (continuing): exercises` followed by `CacheDatabaseException: Failed to insert exercise "Bulgarian Split Squat" (owner: <uid>): DatabaseException(UNIQUE constraint failed: exercises.id …)`. The exercises step of the initial cloud migration aborts mid-loop, so subsequent default rows the user owns on the server (in this case "Bench Press") are never pulled. `session.requires_initial_cloud_migration` stays `true` indefinitely, blocking every later sync trigger. User-visible effects: the Library is missing the two affected defaults, the History view shows previously-logged sets labelled "Unknown exercise", and the History calendar may fail to render activity dots for affected days.

**Root cause**

The local `exercises` table has `PRIMARY KEY (id)` — ids are globally unique within the table regardless of `owner_user_id`. Boot-time guest catalog seeding uses `DeterministicCatalogId.forOwner(ownerUserId: '', name: …)`, which collapses to a name-only UUIDv5 formula in the empty-owner branch (kept for back-compat with pre-owner-scoping installs). The user's Supabase rows for "Bench Press" and "Bulgarian Split Squat" were generated by an older version of the catalog-id formula that also did not mix the owner into the id — so those server-side ids are byte-identical to today's guest-flavoured ids. At boot the app seeds the guest catalog locally at those ids; later, after sign-in, `InitialCloudMigrationCoordinator` pulls the matching server rows and `BaseEntitySyncCoordinator.persistRemotePulledRow` (`lib/data/sync/base_entity_sync_coordinator.dart:339`) issues an unconditional INSERT for any id that doesn't already exist under the *authenticated owner's* `getLocalById` lookup. The owner-scoped existence check passes (no row at that id owned by the user), but the global PK collides with the pre-existing guest row, raising `UNIQUE constraint failed`. The exercises step catches and skips, leaving the migration flag asserted forever.

**Workaround / fix**

Documented fix: see [`guest-removal-and-migration-unstick-plan.md`](C:\Users\User\Desktop\ForLiftLeaguLegends\guest-removal-and-migration-unstick-plan.md) for the seven-commit plan. The fix removes guest mode entirely (v22 destructive migration purges guest-owned rows + the `catalog_init_*` empty-suffix flags; the code paths that handle guest sessions are deleted; `DeterministicCatalogId.forOwner` rejects empty owners; `AccountCatalogProvisionHook` gains a name-based self-heal pass to seed any defaults the user is still missing after the migration).

Diagnostic-only manual workaround (local DB, never push remotely): delete the two colliding guest-owned rows by id (`DELETE FROM exercises WHERE owner_user_id = '' AND id IN ('5de79a89-…', '<bench-press-guest-id>')`). The next sync will then successfully pull the user-owned rows. Do NOT use this on a device with valuable guest data — the proper fix is the planned migration.

**References**

- `lib/core/utils/deterministic_catalog_id.dart` — `forOwner` empty-owner collapse to name-only formula
- `lib/data/datasources/local/exercise_local_datasource.dart` — owner-scoped `getLocalById` check that misses cross-owner PK collisions
- `lib/data/sync/base_entity_sync_coordinator.dart:339` — `persistRemotePulledRow` unconditional INSERT after the owner-scoped check
- `lib/core/sync/hooks/account_catalog_provision_hook.dart` — post-sign-in provisioning bypassed when `catalog_init_<entity>_<uid>` is absent but `hasExistingData` short-circuits
- [`guest-removal-and-migration-unstick-plan.md`](C:\Users\User\Desktop\ForLiftLeaguLegends\guest-removal-and-migration-unstick-plan.md) — full implementation plan
- Related: [`default-catalog-ids-must-be-owner-scoped`](#default-catalog-ids-must-be-owner-scoped) — the earlier owner-scoping fix that introduced the empty-owner back-compat branch this entry's root cause depends on

**Resolution**

Removed guest mode entirely across commits 2–6 of PR series #79–#86. The v22 database migration (`lib/data/datasources/local/database_helper.dart`) purges all guest-owned rows from the five user-scoped tables and removes the empty-suffix catalog-init flags from `app_metadata`. The code paths that handled guest sessions — `AppSession.guest()`, `kGuestUserId`, `guestAwareAddedSyncMetadata`, `DeterministicCatalogId`'s empty-owner branch, `startGuestSession()`, and the boot-time guest catalog seed — are deleted. `AccountCatalogProvisionHook` gained a name-based self-heal pass that seeds any default exercises or meals the user is missing, gated by the absence of the per-user `catalog_init_<entity>_<uid>` flag. The collision is no longer possible because the guest catalog is never seeded. See [`guest-removal-and-migration-unstick-plan.md`](C:\Users\User\Desktop\ForLiftLeaguLegends\guest-removal-and-migration-unstick-plan.md) for the full seven-commit plan.

---

### migration-add-column-must-be-idempotent

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-29
- **Last verified:** 2026-05-29
- **Area:** db

**Symptom**

Chained `_onUpgrade` from an early version (e.g. v2) through a later one (e.g. v6 or v7) throws `SqliteException: duplicate column name: <name>` partway through the cascade. Per-version migration tests don't surface this because each only exercises one branch in isolation — the bug only shows when several branches run consecutively on the same database.

**Root cause**

When a column was added to a table in migration `v<N>` via `ALTER TABLE ... ADD COLUMN`, later versions often retrofitted the column into the earlier `CREATE TABLE IF NOT EXISTS` block (so fresh installs at the latest version don't need to run the ALTER). The retrofit makes sense for fresh installs but introduces a hidden invariant: any chained upgrade that runs both the (now-fat) CREATE and the (still-present) ALTER hits the column twice. Specific instances in this repo: v4 `CREATE TABLE nutrition_logs` declared `meal_name`, but v6 ALTER also tried to add it; v4 `CREATE TABLE meals` declared `serving_size_grams`, but v7 ALTER also tried to add it.

**Workaround / fix**

Every `ALTER TABLE ... ADD COLUMN` in `_onUpgrade` must be wrapped in an existence check. Use the shared `_addColumnIfMissing` helper (`lib/data/datasources/local/database_helper.dart`) or the nullable-text-only `_addNullableTextColumnIfMissing`. Do NOT issue a raw `db.execute('ALTER TABLE ... ADD COLUMN ...')` for any column that also appears in any earlier `CREATE TABLE` block. The `database_helper_migration_replay_test.dart` runs the full v2 → current cascade on a single in-memory DB and will catch any new instance of this trap.

**References**

- `lib/data/datasources/local/database_helper.dart` — `_addColumnIfMissing` helper, v6/v7 idempotent branches
- `test/data/datasources/local/database_helper_migration_replay_test.dart` — end-to-end cascade test
- Found by: the very first run of the replay test on 2026-05-29

---

### muscle-taxonomy-vocabulary-split-hid-fatigue

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-17
- **Last verified:** 2026-06-18
- **Area:** db

**Symptom**

Muscles selected on custom or hand-edited exercises never accumulate fatigue and never light up on the body map, even after many logged sets. Editing a seeded exercise (e.g. Bench Press) and re-saving it also resets all its fatigue to zero going forward. Volume and fatigue for bodyweight exercises (weight == 0) similarly read as zero regardless of reps.

**Root cause**

Two vocabulary mismatches existed in parallel:

1. **Taxonomy split.** `exercise_muscle_factors.muscle_group` was written by two separate vocabularies that were never reconciled. The edit dialog and custom-exercise path wrote *simple* keys (`chest`, `shoulder`, `traps`, `hamstring`, `lower back`, `neck`). The seeded data and body-map overlay used *granular* keys (`upper-chest`, `mid-chest`, `lower-chest`, `front-delts`, `side-delts`, `upper-traps`, etc.). The fatigue read path iterated only granular keys, so any row carrying a simple key was silently skipped — `fatigueGain` was computed correctly but never read back. `SyncExerciseMuscleFactors._isKnownMuscle` accepted both vocabularies without canonicalising, so the divergence was invisible at write time.

2. **Zero-weight formula.** `StimulusCalculationRules.fatigueGain` (`lib/domain/entities/stimulus_calculation_rules.dart`) computed `gain = (weight * reps) * intensityMult * factor / NORM`. Any set with `weight == 0` (bodyweight exercise) produced exactly zero gain, so bodyweight work never contributed to fatigue or volume regardless of reps or muscle activation.

**Workaround / fix**

v26 migration (`lib/data/datasources/local/database_helper.dart`) canonicalises all existing `exercise_muscle_factors.muscle_group` and `exercises.muscle_groups` rows to the 18-key canonical taxonomy via `canonicalizeMuscleKey` (`lib/core/constants/legacy_muscle_group_map.dart`), collapses duplicate rows per `(exercise_id, canonical_key)` with MAX factor, and clears `muscle_stimulus` for a full rebuild. All write paths — the edit dialog chip list, `SyncExerciseMuscleFactors`, and seed data — now use only the 18 canonical keys. The canonical-key invariant: every value in `exercise_muscle_factors.muscle_group` and `muscle_stimulus.muscle_group` must be a member of `MuscleStimulus.allMuscleGroups` (18 keys). For bodyweight sets, `effectiveLoad = weight + bodyweightRepLoad` (25 kg constant in `MuscleStimulus.bodyweightRepLoad`) is substituted consistently in both `fatigueGain` and `dailyVolume`; a v27 logic migration triggers a one-time rebuild so the new formula applies to past sets.

**References**

- `lib/core/constants/legacy_muscle_group_map.dart` — `legacyToCanonical` map and `canonicalizeMuscleKey` helper
- `lib/core/constants/muscle_stimulus_constants.dart` — 18 canonical keys and `bodyweightRepLoad` constant
- `lib/data/datasources/local/database_helper.dart` — v26 taxonomy migration, v27 rebuild trigger
- `lib/domain/entities/stimulus_calculation_rules.dart` — `fatigueGain` and `dailyVolume` with `effectiveLoad`
- `test/data/datasources/local/database_helper_v26_migration_test.dart` — taxonomy migration coverage
- `test/core/constants/legacy_muscle_group_map_test.dart` — full key-coverage and idempotency tests
- PR `#180` — A1: canonical constants + legacy map
- PR `#181` — A2: taxonomy cutover + v26 migration
- PR `#182` — A3: bodyweight fatigue fix + v27 rebuild trigger

---

## Dependency Injection

### blocs-must-be-factories-repositories-singletons

- **Severity:** High
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
- **Area:** di

**Symptom**

A BLoC registered as `registerLazySingleton` carries state from a previous page visit into the next, producing stale UI or duplicate events. A repository registered as `registerFactory` is re-constructed on every use-case call, breaking caching and causing multiple database connections.

**Root cause**

BLoCs have per-page lifecycle; they must be created fresh for each page and disposed when the page is popped. Repositories and use cases are stateless coordinators; they are safe and efficient as singletons.

**Workaround / fix**

Register all BLoCs and Cubits with `registerFactory`. Register all repositories, use cases, and datasources with `registerLazySingleton`. Check every `register_*_module.dart` file when adding new wiring.

**References**

- `lib/injection/` — all `register_*_module.dart` files
- `CLAUDE.md` — "BLoCs and Cubits are registered as factories (new instance per page)"

---

### duplicate-di-registration-causes-silent-bugs

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
- **Area:** di

**Symptom**

A class behaves unexpectedly because an old registration is in effect instead of the current one. The second `registerLazySingleton` call silently shadows the first with no error.

**Root cause**

`get_it` does not throw on duplicate registration by default. The last call for a given type wins, but in module-based DI the ordering is not obvious and may change as modules are added.

**Workaround / fix**

Before registering a type that might already be registered (e.g. a shared service used across modules), guard with `if (!locator.isRegistered<T>())`. Remove any registration that was duplicated unintentionally rather than adding a guard everywhere.

**References**

- `lib/injection/modules/` — registration modules
- Commit `336ad27` — fix: remove duplicate DI registration, redundant singleton, and fire-and-forget futures

---

### fire-and-forget-futures-in-startup-cause-race-conditions

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
- **Area:** di

**Symptom**

Intermittent test failures during DI bootstrap: a service appears registered but its async initialisation has not completed, leading to null-state reads shortly after app start.

**Root cause**

Startup code called async initialisation methods without awaiting them. In production the timing was usually safe; in tests the shorter execution window exposed the race.

**Workaround / fix**

All async work performed during DI bootstrap must be awaited before the bootstrap function returns. Do not fire-and-forget futures in `injection_container.dart` or any `register_*_module.dart`.

**References**

- `lib/injection/injection_container.dart` — bootstrap entry point
- Commit `336ad27` — fix: remove duplicate DI registration, redundant singleton, and fire-and-forget futures

---

### widget-state-must-not-field-capture-factory-blocs-or-cubits

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-21
- **Last verified:** 2026-05-23
- **Area:** di

**Symptom**

A widget appears to update settings or dispatch events through a Cubit/BLoC, yet other parts of the app holding the "same" Cubit/BLoC do not react. State seems coherent in isolated tests but silently desyncs in the running app, or two confirmation cards/snackbars appear after one tap.

**Root cause**

A `State<…>` subclass field-captures a factory-registered BLoC or Cubit from `sl<>()` (typically in `initState` or as a `late final` field). `get_it.registerFactory` returns a **new instance** on every call, so the field-captured instance is different from whatever `BlocProvider` higher in the widget tree provides. Any state the field instance emits is invisible to consumers reading via `context.read`/`context.watch`. This was the root cause of an original silent-dispatch bug fixed in PR `#58`, where a screen-level BLoC field-captured its target BLoCs and silently dropped events meant for them, and of a `BottomNavigation` instance-multiplication bug fixed in a later cleanup PR, where a settings-flavoured Cubit was field-captured from `sl<>()` alongside three other concurrent `BlocProvider` sites.

**Workaround / fix**

Never declare a BLoC or Cubit as a widget-state field (`final XxxBloc _x;`, `late final XxxCubit _x;`). Read it lazily inside `build`/`didChangeDependencies` via `context.read<XxxBloc>()` or `context.watch<XxxCubit>()`. If the widget genuinely needs a constructor-injected BLoC (e.g. for test injection), declare the parameter on the `StatefulWidget` itself, not on the `State<…>` subclass. The `widget-state-bloc-field` convention rule enforces this default-deny; legitimate exceptions waive with `// convention-checker:allow=widget-state-bloc-field reason=<at-least-10-character-prose>`.

**References**

- `tool/convention_rules/widget_state_bloc_field.dart` — the rule
- `test/tool/widget_state_bloc_field_test.dart` — multi-line test fixtures
- Historical: the DI module that originally registered the field-captured Cubit belonged to a feature deleted in a later cleanup — the motivating registration no longer exists in the codebase
- The PR that added this rule also removed the `BottomNavigation` field capture it was written to catch

---

## CI & Local Tooling

### crlf-line-endings-cause-false-positive-dart-format-locally

- **Severity:** Low
- **Status:** Active
- **First observed:** 2026-05-20
- **Last verified:** 2026-05-23
- **Area:** ci

**Symptom**

Running `dart format --set-exit-if-changed lib test` on Windows flags every file as "changed" even when CI (Ubuntu) reports everything correctly formatted.

**Root cause**

`git config core.autocrlf=true` (Windows default) stores files with CRLF line endings locally. The `dart format` tool normalises to LF, so every file appears to differ from its on-disk version. Ubuntu CI checks out with LF endings and sees no difference.

**Workaround / fix**

To verify real formatting issues, run format only against the diff: `dart format --output=none --set-exit-if-changed $(git diff --name-only HEAD -- '*.dart')`. Do not run format over the entire `lib test` tree when diagnosing local failures — the CRLF noise will obscure real issues.

**References**

- `CLAUDE.md` — `dart format lib test` command note
- This entry is a meta-confirmation: it was first observed while verifying formatting for this very PR.

---

### flutter-analyze-info-issues-do-not-fail-ci

- **Severity:** Low
- **Status:** Active
- **First observed:** 2026-05-20
- **Last verified:** 2026-05-23
- **Area:** ci

**Symptom**

`flutter analyze` exits zero even though the output contains info-level notices. CI passes. A developer spends time chasing info items expecting them to block the build.

**Root cause**

The CI pipeline treats only `warning` and `error` severity items as failures. Info-level notices are intentionally allowed; the codebase carries some of them by design.

**Workaround / fix**

Do not invest time eliminating info-level analyzer notices unless they are promoted to warnings or errors in `analysis_options.yaml`. If a notice is genuinely problematic, promote it in the options file so CI enforces it.

**References**

- `analysis_options.yaml` — severity configuration

---

### main-branch-is-pr-only-direct-push-blocked

- **Severity:** Low
- **Status:** Active
- **First observed:** 2026-05-20
- **Last verified:** 2026-05-23
- **Area:** ci

**Symptom**

`git push origin main` is rejected with a branch protection error. The push completes locally but the remote refuses it.

**Root cause**

A repository rule on `main` requires all changes to land via a reviewed, approved PR. Direct pushes are blocked at the remote regardless of local permissions.

**Workaround / fix**

Always push to a feature or fix branch and open a PR. The branch naming convention is: `chore/`, `feat/`, `fix/`, `refactor/`, `docs/`, `ci/` followed by a short description. Merge via the GitHub UI after approval.

**References**

- Repository branch protection rules (GitHub Settings → Branches)

---

### convention-checker-regexes-must-have-multiline-test-fixtures

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-21
- **Last verified:** 2026-05-23
- **Area:** ci

**Symptom**

A convention-checker rule passes its unit tests but silently fails to detect a real violation in the live codebase. The developer is unaware the rule is broken because green tests imply green enforcement.

**Root cause**

The rule's regex was tested only against single-line fixtures. The dart-formatter routinely wraps long lines, and patterns like `registerLazySingleton(\n  () => XxxBloc(` span two lines. A per-line regex iteration cannot match across the line break.

**Workaround / fix**

Every convention rule's regex must be tested against at least one multi-line fixture in `test/tool/<rule-id>_test.dart`. Whenever possible, scan whole-file content rather than per-line iteration, and recover the 1-based line number from each match's byte offset via `'\n'.allMatches(content.substring(0, match.start)).length + 1`. Reference implementations: `KnownIssuesSchemaRule`, `StateFreshnessChecker._classDeclarationRegex`.

**References**

- `tool/convention_rules/bloc_factory_registration.dart` — the rule that was fixed
- Commit `ab2c46e` — fix(ci): convention-checker detects multi-line BLoC singletons

---

## Platform

### dart-define-is-build-time-not-runtime

- **Severity:** Medium
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
- **Area:** platform

**Symptom**

A `--dart-define` value is changed and the app is restarted (hot restart or cold restart) but the app still uses the old value.

**Root cause**

`EnvConfig` reads `--dart-define` flags at compile time via `const String.fromEnvironment(...)`. The values are baked into the binary at build time. Restarting the app does not re-read them; a full rebuild is required.

**Workaround / fix**

After changing any `--dart-define` value, run a full `flutter run` (not hot restart/reload). When running from an IDE, use the run configuration's environment variable panel — not a runtime override.

**References**

- `lib/config/env_config.dart` — `EnvConfig` compile-time constants
- `CLAUDE.md` — Flutter compile-time config section

---

### supabase-disabled-by-default

- **Severity:** Low
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
- **Area:** platform

**Symptom**

The app runs, exercises and meals load from local SQLite, but sync never triggers. No error is shown — the app silently operates in offline-only mode.

**Root cause**

`ENABLE_SUPABASE=false` is the compile-time default. Without `--dart-define=ENABLE_SUPABASE=true` (plus `SUPABASE_URL` and `SUPABASE_ANON_KEY`), the Supabase client is never initialised and sync never starts.

**Workaround / fix**

To run with a real Supabase backend, pass all three `--dart-define` flags on `flutter run`. See `CLAUDE.md` for the full command. The `.env.local` file in `supabase/` holds the correct values for the local stack.

**References**

- `lib/config/env_config.dart` — `EnvConfig.enableSupabase`
- `CLAUDE.md` — Flutter compile-time config section

---

## Other

### history-renders-orphaned-sets-not-hides-them

- **Severity:** Low
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
- **Area:** other

**Symptom**

A workout set whose exercise has been deleted still appears in the history view with a fallback label. A developer hides these rows to "clean up" the UI and introduces a regression.

**Root cause**

Hiding orphaned sets was determined to be worse than showing them with a fallback label — it causes silent data gaps in the user's history. The intentional behaviour is to render all sets and use a placeholder label for the deleted exercise.

**Workaround / fix**

Do not add a filter that hides sets with a missing exercise reference. The fallback label path in `history_day_content.dart` is intentional. If the display is confusing, improve the fallback label — do not hide the set.

**References**

- `lib/features/history/presentation/widgets/history_day_content.dart`
- Commit `3b52f0d` — fix(history): render orphaned sets instead of hiding them

---

### cross-feature-presentation-imports-are-architectural-cycles

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-21
- **Last verified:** 2026-05-23
- **Area:** other

**Symptom**

A presentation file under `lib/features/<F1>/presentation/` imports a page or widget from `lib/features/<F2>/presentation/` (or worse, from `lib/features/<F2>/application/` or `data/`). The build compiles; tests pass; but the feature dependency graph silently grows cycles. Removing or renaming any one feature breaks an unrelated feature in a non-local way. Before the rule existed, three offenders were found this way: `settings_page.dart` imported presentation code from two other features, `profile_page.dart` imported from three, and `home_page.dart` imported from one.

**Root cause**

Flutter's default navigation pattern — `Navigator.push(context, MaterialPageRoute(builder: (_) => SomePage()))` — requires the caller to import the destination page class directly. Done from inside another feature, that import couples the two features at compile time and creates a cycle the moment the destination ever needs anything from the source. The `presentation-layer-data-import` convention rule blocks `presentation → data`, but until the foundation PR there was no rule blocking `presentation → presentation` across feature boundaries.

**Workaround / fix**

Use a named-route registry. All page classes are imported once in `lib/app/routes/app_router.dart` (the only file granted an exception to the rule); every other navigation site uses `Navigator.pushNamed(context, AppRoutes.foo)` with a route constant from `lib/app/routes/app_routes.dart`. The `cross-feature-presentation-import` convention rule enforces the default-deny. Legitimate exceptions waive with `// convention-checker:allow=cross-feature-presentation-import reason=<at-least-10-character-prose>`.

**References**

- `tool/convention_rules/cross_feature_presentation_import.dart` — the rule
- `test/tool/cross_feature_presentation_import_test.dart` — multi-line test fixtures
- `lib/app/routes/app_routes.dart` — route constants
- `lib/app/routes/app_router.dart` — `onGenerateRoute` registry
- The PR that added this rule also added the route registry and migrated the three offending files to it

---

### empty-state-columns-need-scrollable-centering

- **Severity:** Low
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-23
- **Last verified:** 2026-05-23
- **Area:** other

**Symptom**

`BOTTOM OVERFLOWED BY <N> PIXELS` debug stripe on the Library Exercises (and Meals) tab whenever the catalog is empty, on phones with a tight viewport — the empty-state column plus the sticky "Add Exercise" CTA plus the bottom nav inset exceed available height.

**Root cause**

The empty-state pattern was `Center > Padding(40) > Column(MainAxisAlignment.center, children: [icon, headline, description, CTA])`. `Center` provides no scrolling fallback. When the surrounding `Column`'s `Expanded` shrinks below the empty state's intrinsic height (sticky bottom CTA, smaller screens, in-call status bar), the column overflows and Flutter renders the yellow/black stripe. The same shape repeats across `library/presentation/widgets/{exercises_tab,meals_tab}.dart` and `log/presentation/widgets/log_exercise_tab.dart`.

**Workaround / fix**

Replace the `Center > Padding > Column` shape with `LayoutBuilder > SingleChildScrollView > ConstrainedBox(minHeight: constraints.maxHeight - 80) > IntrinsicHeight > Column(MainAxisAlignment.center)`. This centers when the empty state fits and degrades to scrolling when it does not. Applied to both Library tabs; apply the same pattern to any new empty-state widget that lives above a sticky CTA.

**References**

- `lib/features/library/presentation/widgets/exercises_tab.dart` — `_buildEmptyState`
- `lib/features/library/presentation/widgets/meals_tab.dart` — `_buildEmptyState`

---

### muscle-stimulus-repository-userid-parameter-silently-dropped

- **Severity:** Low
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-28
- **Last verified:** 2026-05-30
- **Area:** other

**Symptom**

Six methods on `MuscleStimulusRepository` accept a `userId` parameter that is never forwarded to the datasource. Callers believe they are being explicit about which user's data they want; in practice the datasource always resolves the owner from the active session via `UserScopedLocalDatasource.ownerId()`. Today this is benign — there is only ever one authenticated user — but the lying signature is a latent footgun: any future caller wanting to query a different user's data will receive the wrong rows without an error.

**Root cause**

The repository was authored while the guest/auth layer was being unwound. The `userId` parameter was retained "for safety" during that refactor but was never wired through to the datasource. After guest removal (Plan 1, PRs #79–#86), no caller path will ever pass a user ID that differs from the session owner, making the parameter purely misleading.

**Workaround / fix**

No user-visible workaround is needed; current behaviour matches caller intent. The fix (planned in `plan-2-post-guest-removal-cleanups.md` Commit 2) drops the `userId` parameter from every method where it is unused. The two methods that genuinely pass it to the datasource (`clearStimulusForUser`, `applyDailyDecayToAll`) retain it.

**References**

- `lib/data/repositories/muscle_stimulus_repository_impl.dart:18,32,48,58,97,104,114` — methods with the unused parameter
- `lib/domain/repositories/muscle_stimulus_repository.dart` — interface to be cleaned up
- `plan-2-post-guest-removal-cleanups.md` — full implementation plan (Commit 2)

**Resolution**

Repository interface no longer accepts a `userId` argument on read methods where it was dropped silently. The two methods that genuinely use the argument (`clearStimulusForUser`, `applyDailyDecayToAll`) keep it — wait, `applyDailyDecayToAll` was also dropped since the datasource resolves the owner from the session. Only `clearStimulusForUser` retains `userId`. See Commit 2 of `plan-2-post-guest-removal-cleanups.md`.

---

### history-calendar-dot-disagrees-with-day-detail-for-orphan-sets

- **Severity:** Low
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-28
- **Last verified:** 2026-05-31
- **Area:** other

**Symptom**

A day that contains only workout sets whose `exerciseId` no longer resolves to a library row shows no activity dot on the History calendar. Tapping the same day opens the day-detail bottom sheet, which renders every set with the label "Unknown exercise". The two surfaces apply different orphan-filtering policies, so the calendar silently understates activity for days containing exclusively orphaned sets.

**Root cause**

`HistoryActivityAggregator._countResolvableSets` filtered out sets whose `exerciseId` was absent from `resolvableExerciseIds`, which was derived from the current exercise library. The day-detail bottom sheet applied no such filter — it rendered every set regardless of whether the exercise still exists. The docstring rationale ("a dot promises data the user can't actually open") was contradicted by the actual day-detail behaviour: the user could open the day and see all sets, just with a degraded label.

**Workaround / fix**

No user-visible workaround needed post Plan 1 (no orphaned sets on device). Fixed in Commit 4 of `plan-2-post-guest-removal-cleanups.md`.

**References**

- `lib/features/history/presentation/helpers/history_activity_aggregator.dart` — `_countSets` (replaced filtered version)
- `lib/features/history/presentation/history_page.dart` — aggregator call site
- `plan-2-post-guest-removal-cleanups.md` — full implementation plan (Commit 4)

**Resolution**

`HistoryActivityAggregator` no longer accepts a `resolvableExerciseIds` parameter. The private `_countResolvableSets` method is replaced with `_countSets`, which counts every set unconditionally. The `BlocBuilder<ExerciseBloc>` wrapper in `HistoryPage` (whose sole purpose was computing the id-set for the filter) is removed. The calendar now shows a dot for every day that has sets, regardless of whether the exercises still resolve — matching the day-detail bottom sheet's policy of rendering orphans as "Unknown exercise". See Commit 4 of `plan-2-post-guest-removal-cleanups.md`.

---

### signin-does-not-navigate-until-restart

- **Severity:** Critical
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-31
- **Last verified:** 2026-06-01
- **Area:** other

**Symptom**

A successful sign-in (logs show `Session established successfully`) leaves the user on the sign-in screen; the app only opens to the home screen after a manual restart. Affects all three authenticated entry points: sign-in, sign-up (no-email-confirmation branch), and OTP verification.

**Root cause**

`AuthGate` (`lib/app/auth_gate.dart`) swaps screens purely on `ProfileCubit.state.session != null`. The live-auth flow — `SignInCubit` → `AuthSessionService` → `SessionSyncService.establishAuthenticatedSession()` → `AppSessionRepository.startAuthenticatedSession()` — persists the session successfully, but nothing notifies `ProfileCubit`. `ProfileCubit.state.session` is only populated by `_loadProfile()`, which runs once at cold start (`lib/app/app.dart:60`) and from within the already-authenticated tree. `SignInCubit` (`lib/features/auth/application/sign_in_cubit.dart`) and `ProfileCubit` (`lib/features/profile/application/profile_cubit.dart`) are fully decoupled — there is no bridge. So after a live sign-in, `session` stays `null` in `ProfileCubit`, the gate's selector never changes, and the sign-in screen stays up. A restart re-runs `loadProfile()`, finds the persisted session, and the gate finally swaps.

**Workaround / fix**

End-user workaround: restart the app after signing in — the session is already persisted and the app will open normally on relaunch. Developer fix: see `issue-1-signin-navigation-fix-plan.md` (reactive `onSessionEstablished` stream on `SessionSyncService`; `ProfileCubit` subscribes and reloads via `loadProfile()`).

**References**

- `lib/app/auth_gate.dart` — gate that keys off `ProfileCubit.state.session`
- `lib/features/auth/application/sign_in_cubit.dart` — live-auth path that never touches `ProfileCubit`
- `lib/features/profile/application/profile_cubit.dart` — `session` only loaded at cold start
- `issue-1-signin-navigation-fix-plan.md` — full implementation plan

**Resolution**

`ProfileCubit` now subscribes to `SessionSyncService.onSessionEstablished` (emitted on the completed establish path only — never skipped/failed) in its constructor and reloads via the existing `loadProfile()`, so `AuthGate` swaps from the sign-in screen to the app on live sign-in/up/OTP without a restart. The subscription is cancelled in `close()`. No auth-page or `AuthGate` changes were required. See `issue-1-signin-navigation-fix-plan.md`.

---

### auth-gate-must-not-flash-signin-before-session-resolves

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-02
- **Last verified:** 2026-06-02
- **Area:** other

**Symptom**

On launching while already signed in, the sign-in page is visible for roughly one second before the app swaps to Home.

**Root cause**

`AuthGate` (`lib/app/auth_gate.dart`) selected its child off `state.session != null` only. `ProfileState.initial()` has `session: null, hasLoaded: false`; `loadProfile()` resolves the persisted session asynchronously (it awaits `getCurrentSession()` and a Supabase `auth.refreshSession`). During that window the gate could not distinguish "session not resolved yet" from "signed out", so it rendered `SignInPage` and then swapped to the authenticated child once the session arrived.

**Workaround / fix**

Derive a three-way status from `ProfileState`: `hasLoaded == false` → a neutral `AuthLoadingView` splash; `hasLoaded && session != null` → the authenticated child; `hasLoaded && session == null` → `SignInPage`. `loadProfile()` sets `hasLoaded: true` in both its success and failure branches, so the splash always resolves and never hangs. Do not reset `hasLoaded` on resume — the splash must only appear at cold start.

**References**

- `lib/app/auth_gate.dart`, `lib/app/auth_loading_view.dart`
- `lib/features/profile/application/profile_cubit.dart:287-318` — `hasLoaded` set in both branches
- `test/app/auth_gate_test.dart` — resolving + cold-start regression tests
- PR `#107` — fix

---

### muscle-stimulus-rebuild-dst-day-iteration

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-03
- **Last verified:** 2026-06-03
- **Area:** other

**Symptom**

After a workout history spanning a daylight-saving spring-forward, the 2D muscle model (Fatigue/Month/All-time) stops reflecting newly logged sets. All-time shows only the oldest (pre-DST) set; Month and Fatigue show nothing for recent sets. Deleting the oldest pre-DST set restores correct behaviour for every newer set.

**Root cause**

`RebuildMuscleStimulusFromWorkoutHistory._buildRecords` keyed its per-day aggregation maps by local-midnight `DateTime` but stepped the day loop with `day.add(const Duration(days: 1))` — a fixed 24 h of elapsed time. Across the EU spring-forward (clocks jump 03:00→04:00, e.g. late March in `Europe/Sofia`) a calendar day is only 23 h long. So the loop variable drifts to 01:00 for every subsequent day, while the map keys are exact local midnights. `dailyStimulusByDate[day]` and `lastSetByDate[day]` both miss, and each post-transition day's stimulus is written as 0 with no `last_set_timestamp`.

**Workaround / fix**

Step the loop with calendar-component arithmetic (`CalendarDay.nextDay`), which constructs `DateTime(y, m, d + 1)` and always re-normalises to local midnight. Use `CalendarDay.calendarDaysBetween` (UTC-normalised) for any day-gap math. Never iterate or measure calendar days with `Duration(days: N)` in production code.

**References**

- `lib/core/utils/calendar_day.dart` — DST-safe helper (introduced by this fix)
- `lib/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history.dart` — loop step changed to `CalendarDay.nextDay`
- `test/core/utils/calendar_day_test.dart` — helper contract tests
- `test/domain/usecases/muscle_stimulus/rebuild_muscle_stimulus_from_workout_history_test.dart` — rebuild invariant tests

---

### full-width-elevated-button-crashes-inside-a-row

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-08-21
- **Last verified:** 2026-08-21
- **Area:** other

**Symptom**

A dialog or panel throws `BoxConstraints forces an infinite width` during `performLayout` the instant it is built, and the feature behind it looks broken rather than buggy — History's `Edit Set` dialog appeared to have no edit function at all, because the only way in produced a layout assertion instead of a dialog. Deleting a set from the same row worked, which made the fault read as "edit is missing" rather than "edit crashes".

**Root cause**

`LiftTheme`'s `elevatedButtonTheme` sets `minimumSize: const Size.fromHeight(52)`, and `Size.fromHeight` yields `Size(double.infinity, 52)` — every `ElevatedButton` in the app asks for infinite width by design, so CTAs fill their container. A `Row` hands its non-flex children unbounded width, so the button's own `ConstrainedBox` gets `w=Infinity` with nothing to clamp it and the assertion fires. `AlertDialog.actions` is safe because `OverflowBar` bounds its children; a bare `Row` is not.

**Workaround / fix**

1. Wrap every `ElevatedButton` (and `OutlinedButton`, which carries `Size.fromHeight(48)`) in `Expanded` or `Flexible` when it sits in a `Row`.
2. Do not "fix" this by overriding `minimumSize` at the call site — the full-width minimum is the intended CTA shape and overriding it per-button re-introduces the inconsistent button widths the restyle removed.
3. Widget tests catch this only if they actually open the surface. A test that asserts a control exists does not exercise the dialog behind it.

**References**

- `lib/core/themes/lift_theme.dart` — `elevatedButtonTheme` / `outlinedButtonTheme` `minimumSize`
- `lib/features/history/presentation/widgets/edit_set_dialog.dart` — the actions row, now `Expanded`
- `test/features/history/presentation/widgets/history_day_content_test.dart` — "the edit control opens the edit dialog", the regression test

### body-overlays-are-registered-to-the-base-arts-ink-box

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-08-23
- **Last verified:** 2026-08-23
- **Area:** other

**Symptom**

Home's 2D muscle map highlights the wrong muscle. The back view is the one that shows it: a lats highlight paints across the trapezius and rhomboid rows, the upper-trap highlight lands on the neck, and every torso overlay sits roughly a tenth of the figure's height above the region it names. The arms look correct, which makes the fault read as a bad muscle-to-asset mapping in `HomeViewDataMapper` rather than as an asset-registration problem.

**Root cause**

Every raster under `assets/images/body/` shares a 440x956 canvas, and each overlay is drawn to register against one specific base image's *ink box* — not against the canvas. `BackLook.png` inked at (57,182)-(397,849) when the 14 `back_*.png` overlays were authored. Commit `2aaca8a` redrew it to (47,194)-(387,848) so the two faces would register against each other, and moved only the base: every overlay was then 10px right and 12px high of the art it labels, with a 2% height mismatch on top. Nothing in Dart, in the analyzer, or in the widget tests can see this — the mapper is correct, the assets load, and the layers composite exactly where they were told to.

**Workaround / fix**

1. Treat the base image's opaque bounds as a contract. Moving or rescaling `FrontLook.png` or `BackLook.png` means applying the same affine transform to every overlay for that face in the same commit.
2. Verify by compositing, not by eye on a phone. Stack each overlay over its base in a distinct colour and check every polygon lands on an art region — an overlay that is 10px out still looks plausible at phone scale.
3. `BodyVisualWidget` crops both faces to one shared ink rect (`_figureInk`), so the two bounds must also stay within a pixel or two of each other or the flip shifts the model.

**References**

- `lib/features/home/presentation/widgets/body_visual_widget.dart` — `_canvas` and `_figureInk`, the crop the bounds feed
- `lib/features/home/presentation/mappers/home_view_data_mapper.dart` — `_backBodyAssetMap`, correct throughout
- Commit `2aaca8a` — moved the base without the overlays

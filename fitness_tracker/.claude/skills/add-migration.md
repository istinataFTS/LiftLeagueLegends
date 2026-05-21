# Playbook — Add a SQLite schema migration

- **Task:** Add a new SQLite schema migration (new table, new column, or schema change)
- **When to use:** When a feature needs a new table or column in the local SQLite database
- **Estimated steps:** 6
- **Last verified:** 2026-05-21
- **Canonical references:**
- **Touches:** data
- **Related playbooks:** [add-datasource](add-datasource.md), [add-feature](add-feature.md)

---

## 0. Preconditions

- Read KNOWN_ISSUES.md entries for the `db` area before starting. Anchor: [#sqflite-version-15-rejects-incompatible-legacy-databases](../../KNOWN_ISSUES.md#sqflite-version-15-rejects-incompatible-legacy-databases).
- `dart run tool/check_conventions.dart` passes before you touch anything.
- Confirm the current `databaseVersion` value: `lib/config/env_config.dart:83`.

---

## Steps

### 1. Read the relevant KNOWN_ISSUES entries

- [ ] Read [#sqflite-version-15-rejects-incompatible-legacy-databases](../../KNOWN_ISSUES.md#sqflite-version-15-rejects-incompatible-legacy-databases). Understand the additive-only constraint and the version-15+ reject behaviour.
- [ ] Read [#conflict-algorithm-replace-needed-for-deterministic-default-ids](../../KNOWN_ISSUES.md#conflict-algorithm-replace-needed-for-deterministic-default-ids). If your new table has a deterministic default-id pattern, you need `ConflictAlgorithm.replace` on insert.

### 2. Bump `EnvConfig.databaseVersion`

- [ ] In `lib/config/env_config.dart:83`, increment `databaseVersion` by exactly **1**. Never skip versions, never decrement.
- [ ] Add a one-line inline doc comment describing what changed at this version. Example: `// v20: added nutrition_goal table`.

### 3. Add the migration branch in `_onUpgrade`

- [ ] In `lib/data/datasources/local/database_helper.dart`, find the `_onUpgrade` method (line 204) and add a new `if (oldVersion < N)` branch for your version number `N`.
- [ ] Migrations are **additive only**: `CREATE TABLE`, `ALTER TABLE ADD COLUMN`, `CREATE INDEX`. Never `DROP TABLE`, `DROP COLUMN`, or `ALTER COLUMN` in a migration branch. Destructive changes require a fresh install path only.
- [ ] If adding a new table, also add the `CREATE TABLE` statement to `createSchema` (the `onCreate` handler) so fresh installs include it.
- [ ] Test the branch with a real `sqflite` database in a migration test — do not rely on mocks.

### 4. Document the version bump inline

- [ ] The new `if (oldVersion < N)` block must begin with a short comment: `// v<N>: <one-line description of change>`.
- [ ] Add the same note to `EnvConfig.databaseVersion`'s inline comment block if it maintains a version history log.

### 5. Add a migration test

- [ ] Add or extend the migration test file (look for `test/data/datasources/local/database_helper_migration_test.dart` or equivalent).
- [ ] Write a test that: opens a database at version N-1, runs the upgrade to version N, then asserts the new table/column exists with `db.rawQuery("PRAGMA table_info(<table>)")` or equivalent.
- [ ] Run `flutter test test/data/datasources/local/` before moving on.

### 6. Apply the 15-minute rule

- [ ] If you spent more than 15 minutes debugging this migration (sqflite version handling, CRLF edge cases, column types), add an entry to `KNOWN_ISSUES.md` before opening the PR. The entry is part of the fix.

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

- **Non-additive migration** — `ALTER TABLE DROP COLUMN` and `DROP TABLE` crash or corrupt data on users with the old schema. Additive only. See [KNOWN_ISSUES.md#sqflite-version-15-rejects-incompatible-legacy-databases](../../KNOWN_ISSUES.md#sqflite-version-15-rejects-incompatible-legacy-databases).
- **Skipping a version number** — sqflite calls `onUpgrade` with `oldVersion` and `newVersion`. Skipping a version means migrations for that number never run on users who were on the skipped version.
- **Forget to add the table to `createSchema`** — fresh-install users skip `_onUpgrade` entirely. The table must exist in `onCreate` too.
- **Deterministic default ID with insert conflict** — if you use a content-hash or deterministic ID, use `ConflictAlgorithm.replace` on insert. See [KNOWN_ISSUES.md#conflict-algorithm-replace-needed-for-deterministic-default-ids](../../KNOWN_ISSUES.md#conflict-algorithm-replace-needed-for-deterministic-default-ids).

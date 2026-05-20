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
- **Area:** sync | voice | db | di | ci | platform | other

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
- Constants by symbolic name, not literal value: `` `VoiceConstants.sttListenTimeout` `` not `"10 seconds"`. Exception: entries describing a historical change may quote the old value.
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

### Voice
6. [voice-stt-hard-cap-is-10-seconds](#voice-stt-hard-cap-is-10-seconds)
7. [voice-edge-function-must-have-30s-http-timeout](#voice-edge-function-must-have-30s-http-timeout)
8. [voice-daily-cost-cap-is-server-side-only](#voice-daily-cost-cap-is-server-side-only)
9. [voice-fab-is-disabled-not-hidden-for-guests](#voice-fab-is-disabled-not-hidden-for-guests)

### Database
10. [sqflite-version-15-rejects-incompatible-legacy-databases](#sqflite-version-15-rejects-incompatible-legacy-databases)
11. [conflict-algorithm-replace-needed-for-deterministic-default-ids](#conflict-algorithm-replace-needed-for-deterministic-default-ids)
12. [pull-before-push-for-sign-in-sync](#pull-before-push-for-sign-in-sync)

### Dependency Injection
13. [blocs-must-be-factories-repositories-singletons](#blocs-must-be-factories-repositories-singletons)
14. [duplicate-di-registration-causes-silent-bugs](#duplicate-di-registration-causes-silent-bugs)
15. [fire-and-forget-futures-in-startup-cause-race-conditions](#fire-and-forget-futures-in-startup-cause-race-conditions)

### CI & Local Tooling
16. [crlf-line-endings-cause-false-positive-dart-format-locally](#crlf-line-endings-cause-false-positive-dart-format-locally)
17. [flutter-analyze-info-issues-do-not-fail-ci](#flutter-analyze-info-issues-do-not-fail-ci)
18. [main-branch-is-pr-only-direct-push-blocked](#main-branch-is-pr-only-direct-push-blocked)

### Platform
19. [dart-define-is-build-time-not-runtime](#dart-define-is-build-time-not-runtime)
20. [supabase-disabled-by-default](#supabase-disabled-by-default)

### Other
21. [history-renders-orphaned-sets-not-hides-them](#history-renders-orphaned-sets-not-hides-them)
22. [voice-slider-persists-on-every-drag-tick](#voice-slider-persists-on-every-drag-tick)

---

## Sync

### guest-data-must-not-adopt-on-sign-in

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-19
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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

## Voice

### voice-stt-hard-cap-is-10-seconds

- **Severity:** Medium
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-20
- **Area:** voice

**Symptom**

If `VoiceConstants.sttListenTimeout` is raised above 10 seconds, per-utterance cost assumptions break and the voice budget may be exceeded sooner than modelled.

**Root cause**

The STT listen cap is a spec-mandated constraint, not an arbitrary default. The budget model assumes utterances are bounded at 10 seconds. Raising the cap does not change what OpenAI charges for audio that runs longer.

**Workaround / fix**

Do not raise `VoiceConstants.sttListenTimeout`. If a future spec revision changes the cap, update the constant and re-validate the budget model before deploying.

**References**

- `lib/core/constants/voice_constants.dart` — `VoiceConstants.sttListenTimeout`
- Commit `cb8cb29` — fix(voice): align STT listen timeout to spec-mandated 10 seconds

---

### voice-edge-function-must-have-30s-http-timeout

- **Severity:** High
- **Status:** Mitigated
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-20
- **Area:** voice

**Symptom**

Without a client-side HTTP timeout on the `voice-chat` edge function call, a slow or hung OpenAI response leaves the user staring at an indefinite spinner with no recovery path.

**Root cause**

The Supabase Functions HTTP client does not apply a default timeout. OpenAI calls can take several seconds and occasionally hang on poor connections.

**Workaround / fix**

`VoiceConstants.voiceChatHttpTimeout` sets the client-side deadline. Do not remove it or replace it with an unbounded timeout. If the call exceeds the timeout, the voice flow surfaces a `ServerFailure` and the user can retry.

**References**

- `lib/core/constants/voice_constants.dart` — `VoiceConstants.voiceChatHttpTimeout`
- `lib/features/voice/data/remote/supabase_voice_remote_datasource.dart` — timeout applied at call site
- Commit `e205027` — fix: add 30-second HTTP timeout to voice-chat Edge Function call

---

### voice-daily-cost-cap-is-server-side-only

- **Severity:** Critical
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-20
- **Area:** voice

**Symptom**

If the daily budget cap is enforced only on the client, a modified client or a direct API call can bypass it entirely, leading to unbounded spend against the OpenAI API key.

**Root cause**

Client-side enforcement is not trustworthy for monetary limits. The cap must be checked by the edge function before every OpenAI call, using server-side state.

**Workaround / fix**

The cap (`VoiceConstants.dailyBudgetCapUsd` on the Flutter side; `dailyCapUsd` parameter in `supabase/functions/_shared/budget.ts`) is enforced exclusively in the edge function. Do not move the enforcement to the Flutter client. All LLM calls, including failures, must log to `voice_usage_log` with `cost_usd=0` for failures so the server-side accounting remains complete.

**References**

- `lib/core/constants/voice_constants.dart` — `VoiceConstants.dailyBudgetCapUsd` (UI display only)
- `supabase/functions/_shared/budget.ts` — server-side budget gate
- `supabase/functions/_shared/usage.ts` — `voice_usage_log` insert

---

### voice-fab-is-disabled-not-hidden-for-guests

- **Severity:** Low
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-20
- **Area:** voice

**Symptom**

A guest user sees the voice FAB but it is non-interactive. This is intentional — removing it appears as a regression.

**Root cause**

UX decision: the FAB is visible with a sign-in CTA so that guests understand the feature exists. Hiding it would suppress discoverability.

**Workaround / fix**

Leave the FAB visible and disabled for guests. The sign-in CTA is the intended interaction. If you add a condition that hides the FAB for unauthenticated users, that is a regression.

**References**

- `CLAUDE.md` — "Guest users cannot use voice (FAB is visible-but-disabled with a sign-in CTA)"

---

## Database

### sqflite-version-15-rejects-incompatible-legacy-databases

- **Severity:** High
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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

## Dependency Injection

### blocs-must-be-factories-repositories-singletons

- **Severity:** High
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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

## CI & Local Tooling

### crlf-line-endings-cause-false-positive-dart-format-locally

- **Severity:** Low
- **Status:** Active
- **First observed:** 2026-05-20
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
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

## Platform

### dart-define-is-build-time-not-runtime

- **Severity:** Medium
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-20
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
- **Last verified:** 2026-05-20
- **Area:** platform

**Symptom**

The app runs, exercises and meals load from local SQLite, but sync never triggers and voice returns a `ServerFailure` on every call. No error is shown — the app silently operates in offline-only mode.

**Root cause**

`ENABLE_SUPABASE=false` is the compile-time default. Without `--dart-define=ENABLE_SUPABASE=true` (plus `SUPABASE_URL` and `SUPABASE_ANON_KEY`), the Supabase client is never initialised and the voice remote datasource falls back to `NoopVoiceRemoteDataSource`.

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
- **Last verified:** 2026-05-20
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

### voice-slider-persists-on-every-drag-tick

- **Severity:** Low
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-20
- **Area:** other

**Symptom**

Adding a debounce to the voice settings slider so it only persists on drag-release causes the final value to be lost if the user releases quickly and then navigates away.

**Root cause**

The settings page persists slider values on every `onChanged` callback (every drag tick), not only on `onChangeEnd`. This was tried with debouncing; the debounce interval caused dropped values when the user released and immediately back-navigated.

**Workaround / fix**

Leave the `onChanged` handler writing to persistent storage on every tick. The performance cost is negligible for a settings slider. Do not add debouncing.

**References**

- `lib/features/voice/presentation/voice_settings_page.dart` — slider `onChanged` handler
- `lib/features/voice/application/voice_settings_cubit.dart` — persistence logic
- Commit `9f8edcf` — feat: wire Delete History button and fix slider persistence on every drag tick

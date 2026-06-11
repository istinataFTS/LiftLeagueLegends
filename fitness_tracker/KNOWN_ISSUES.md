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
6. [pre-auth-write-through-must-skip-remote-push](#pre-auth-write-through-must-skip-remote-push)
7. [timestamps-must-round-trip-as-utc-not-naive-local](#timestamps-must-round-trip-as-utc-not-naive-local)

### Voice
1. [voice-stt-hard-cap-bounds-per-utterance-cost](#voice-stt-hard-cap-bounds-per-utterance-cost)
2. [voice-edge-function-must-have-30s-http-timeout](#voice-edge-function-must-have-30s-http-timeout)
3. [voice-daily-cost-cap-is-server-side-only](#voice-daily-cost-cap-is-server-side-only)
4. [voice-fab-is-disabled-not-hidden-for-guests](#voice-fab-is-disabled-not-hidden-for-guests)
5. [voice-stt-no-match-is-not-an-error](#voice-stt-no-match-is-not-an-error)
6. [voice-wake-word-requires-picovoice-key-in-secure-storage](#voice-wake-word-requires-picovoice-key-in-secure-storage)
7. [voice-stt-samsung-no-match-terminates-recogniser](#voice-stt-samsung-no-match-terminates-recogniser)
8. [voice-picovoice-key-must-ship-via-dart-define](#voice-picovoice-key-must-ship-via-dart-define)
9. [voice-context-keys-must-be-camelcase](#voice-context-keys-must-be-camelcase)
10. [voice-openai-api-key-must-be-supabase-secret](#voice-openai-api-key-must-be-supabase-secret)
11. [voice-mic-permission-must-be-requested-before-overlay](#voice-mic-permission-must-be-requested-before-overlay)
12. [voice-whisper-is-the-default-stt-backend](#voice-whisper-is-the-default-stt-backend)
13. [voice-transcribe-must-deploy-with-openai-secret-and-cors](#voice-transcribe-must-deploy-with-openai-secret-and-cors)
14. [voice-phantom-success-spoken-before-persistence-completes](#voice-phantom-success-spoken-before-persistence-completes)
15. [voice-overlay-and-shell-use-different-voicebloc-instances](#voice-overlay-and-shell-use-different-voicebloc-instances)
16. [voice-bot-must-never-surface-internal-ids](#voice-bot-must-never-surface-internal-ids)
17. [voice-wake-word-engine-must-serialize-and-retry-mic-acquire](#voice-wake-word-engine-must-serialize-and-retry-mic-acquire)
18. [voice-bot-must-log-duplicate-sets](#voice-bot-must-log-duplicate-sets)
19. [voice-confirmation-cancel-leaves-bot-unresponsive](#voice-confirmation-cancel-leaves-bot-unresponsive)
20. [voice-whisper-hallucinates-on-silent-audio](#voice-whisper-hallucinates-on-silent-audio)
21. [voice-wake-word-keyword-miss-rate](#voice-wake-word-keyword-miss-rate)
22. [voice-wake-word-engine-stops-when-overlay-opens](#voice-wake-word-engine-stops-when-overlay-opens)
23. [headphone-tap-to-wake-unreliable-on-airpods-and-when-another-app-holds-media-focus](#headphone-tap-to-wake-unreliable-on-airpods-and-when-another-app-holds-media-focus)
24. [voice-edge-functions-bare-import-specifiers-fail-to-boot](#voice-edge-functions-bare-import-specifiers-fail-to-boot)
25. [voice-confirmation-card-buttons-must-cancel-the-open-listen](#voice-confirmation-card-buttons-must-cancel-the-open-listen)
26. [voice-clarify-questions-must-be-coerced-to-the-clarify-tool](#voice-clarify-questions-must-be-coerced-to-the-clarify-tool)
27. [voice-must-resolve-exercise-before-presenting-a-confirmation-card](#voice-must-resolve-exercise-before-presenting-a-confirmation-card)
28. [voice-day-scoped-queries-need-explicit-date-resolution](#voice-day-scoped-queries-need-explicit-date-resolution)
29. [voice-day-scoped-query-falls-back-to-last-referenced-date](#voice-day-scoped-query-falls-back-to-last-referenced-date)
30. [voice-spoken-confirm-must-tolerate-stt-punctuation-and-filler](#voice-spoken-confirm-must-tolerate-stt-punctuation-and-filler)
31. [voice-recent-nutrition-context-was-today-only](#voice-recent-nutrition-context-was-today-only)
32. [voice-day-scoped-query-tools-omitted-from-must-call-rule](#voice-day-scoped-query-tools-omitted-from-must-call-rule)
33. [voice-nutrition-query-spoke-calories-without-macros](#voice-nutrition-query-spoke-calories-without-macros)
34. [voice-most-recent-nutrition-had-no-cross-day-query-tool](#voice-most-recent-nutrition-had-no-cross-day-query-tool)
35. [voice-logged-meal-macros-are-retrievable-not-advice](#voice-logged-meal-macros-are-retrievable-not-advice)
36. [voice-recent-nutrition-tool-was-misclassified-as-mutation-on-client](#voice-recent-nutrition-tool-was-misclassified-as-mutation-on-client)

### Database
11. [sqflite-version-15-rejects-incompatible-legacy-databases](#sqflite-version-15-rejects-incompatible-legacy-databases)
12. [conflict-algorithm-replace-needed-for-deterministic-default-ids](#conflict-algorithm-replace-needed-for-deterministic-default-ids)
13. [pull-before-push-for-sign-in-sync](#pull-before-push-for-sign-in-sync)
14. [default-catalog-ids-must-be-owner-scoped](#default-catalog-ids-must-be-owner-scoped)
15. [guest-catalog-pk-collision-blocks-initial-sign-in](#guest-catalog-pk-collision-blocks-initial-sign-in)
16. [migration-add-column-must-be-idempotent](#migration-add-column-must-be-idempotent)

### Dependency Injection
15. [blocs-must-be-factories-repositories-singletons](#blocs-must-be-factories-repositories-singletons)
16. [duplicate-di-registration-causes-silent-bugs](#duplicate-di-registration-causes-silent-bugs)
17. [fire-and-forget-futures-in-startup-cause-race-conditions](#fire-and-forget-futures-in-startup-cause-race-conditions)
18. [widget-state-must-not-field-capture-factory-blocs-or-cubits](#widget-state-must-not-field-capture-factory-blocs-or-cubits)

### CI & Local Tooling
19. [crlf-line-endings-cause-false-positive-dart-format-locally](#crlf-line-endings-cause-false-positive-dart-format-locally)
20. [flutter-analyze-info-issues-do-not-fail-ci](#flutter-analyze-info-issues-do-not-fail-ci)
21. [main-branch-is-pr-only-direct-push-blocked](#main-branch-is-pr-only-direct-push-blocked)
22. [convention-checker-regexes-must-have-multiline-test-fixtures](#convention-checker-regexes-must-have-multiline-test-fixtures)

### Platform
23. [dart-define-is-build-time-not-runtime](#dart-define-is-build-time-not-runtime)
24. [supabase-disabled-by-default](#supabase-disabled-by-default)

### Other
25. [history-renders-orphaned-sets-not-hides-them](#history-renders-orphaned-sets-not-hides-them)
26. [voice-slider-persists-on-every-drag-tick](#voice-slider-persists-on-every-drag-tick)
27. [cross-feature-presentation-imports-are-architectural-cycles](#cross-feature-presentation-imports-are-architectural-cycles)
28. [empty-state-columns-need-scrollable-centering](#empty-state-columns-need-scrollable-centering)
29. [muscle-stimulus-repository-userid-parameter-silently-dropped](#muscle-stimulus-repository-userid-parameter-silently-dropped)
30. [history-calendar-dot-disagrees-with-day-detail-for-orphan-sets](#history-calendar-dot-disagrees-with-day-detail-for-orphan-sets)
31. [signin-does-not-navigate-until-restart](#signin-does-not-navigate-until-restart)
32. [auth-gate-must-not-flash-signin-before-session-resolves](#auth-gate-must-not-flash-signin-before-session-resolves)
33. [muscle-stimulus-rebuild-dst-day-iteration](#muscle-stimulus-rebuild-dst-day-iteration)

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
(the voice bot's "what are my latest sets", weekly volume, the home dashboard) even
though it persisted and shows correctly in History. The gap is roughly the device's
UTC offset — in UTC+3 the newest entry is invisible for ~3 hours after it is logged.
Near midnight an entry can also display under the wrong calendar day, and voice
edit/delete of a just-logged item fails with "not found".

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

## Voice

### voice-stt-hard-cap-bounds-per-utterance-cost

- **Severity:** Medium
- **Status:** Active
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
- **Area:** voice

**Symptom**

If `VoiceConstants.sttListenTimeout` is raised without revalidating the budget model, per-utterance audio assumptions break and the daily voice budget may be exceeded sooner than modelled.

**Root cause**

The STT listen cap is a hard upper bound on per-utterance audio duration. The daily-budget model assumes utterances are bounded at this constant. Raising the cap does not change what the LLM is charged for the resulting transcript length, but it does widen the worst-case audio window. The constant was 10 s originally; in the voice-foundation PR it was raised to 15 s to accommodate multi-field edit utterances (e.g. "change carbs to 60, fat to 15"), with the budget model re-checked at the new bound.

**Workaround / fix**

Do not raise `VoiceConstants.sttListenTimeout` without re-validating the daily budget model against the new bound. The current value is 15 s; if a future spec revision changes the cap again, update the constant, the doc comment in `voice_constants.dart`, the budget model, and the `CLAUDE.md` voice-bot section in the same PR.

**References**

- `lib/core/constants/voice_constants.dart` — `VoiceConstants.sttListenTimeout`
- Commit `cb8cb29` — fix(voice): align STT listen timeout to spec-mandated 10 seconds (superseded by the foundation PR)
- Voice-foundation PR — raised the cap to 15 s and updated this entry

---

### voice-edge-function-must-have-30s-http-timeout

- **Severity:** High
- **Status:** Mitigated
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
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
- **Last verified:** 2026-05-23
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
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-30
- **Area:** voice

**Symptom**

A guest user sees the voice FAB but it is non-interactive. This was intentional — removing it appeared as a regression.

**Root cause**

UX decision (now superseded): the FAB was visible with a sign-in CTA so that guests understood the feature existed. Guest mode was removed in the guest-removal plan (PRs #79–#86); the app now requires sign-in before use. The FAB is always enabled for authenticated users and the sign-in gate prevents any unauthenticated access.

**Workaround / fix**

No action needed. Guest mode was removed entirely. The FAB is active for all app users (all of whom are authenticated). See [`guest-catalog-pk-collision-blocks-initial-sign-in`](#guest-catalog-pk-collision-blocks-initial-sign-in) for the full guest-removal context.

**References**

- PR `#80` — feat(auth): gate the app behind sign-in for unauthenticated users
- PR `#84` — refactor(session): remove guest concept from domain and data layers

---

### voice-stt-no-match-is-not-an-error

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-23
- **Last verified:** 2026-05-23
- **Area:** voice

**Symptom**

User taps the voice FAB or fires the wake word; the overlay shows "Listening…" for 2-3 seconds, then silently reverts to idle without ever displaying a partial transcript. No error surface appears. Logs show `SpeechToTextVoiceSttService error: error_no_match (permanent: true)` repeated once per attempt.

**Root cause**

Android `SpeechRecognizer` (and the Samsung variant especially) emits `ERROR_NO_MATCH` and `ERROR_SPEECH_TIMEOUT` as normal "I heard nothing recognisable" signals — frequently during recogniser warm-up, before the user has finished speaking. The previous implementation in `SpeechToTextVoiceSttService._onError` treated *every* plugin error as fatal: it added a `VoiceSttException` to the controller and closed it. Combined with `SpeechListenOptions(cancelOnError: true)` on the plugin and `cancelOnError: true` on the bloc's stream subscription, the first transient `error_no_match` tore the session down before any partial result could appear.

**Workaround / fix**

The `noSpeech` kind is now classified as a graceful end-of-stream, not an error. `SpeechToTextVoiceSttService._onError` checks `isGracefulSilence(kind)` and closes the controller via `_closeController()` — no error event is added. The bloc's existing `onDone → VoiceListenEnded` path then reverts the UI to idle the same way a natural pause does. `cancelOnError` on the plugin listen is also removed so the only shutdown path is the explicit `_closeController()` in `_onError`. The classifier (`classifyErrorCode` / `isGracefulSilence`) is a pure static helper marked `@visibleForTesting` so the contract has unit-test coverage in `speech_to_text_voice_stt_service_test.dart`. Do **not** re-promote `noSpeech` back into an `onError` event — the rule is encoded in the `VoiceSttService.listen` doc comment in the domain layer.

**References**

- `lib/features/voice/data/services/speech_to_text_voice_stt_service.dart` — `_onError`, `classifyErrorCode`, `isGracefulSilence`
- `lib/domain/services/voice_stt_service.dart` — `listen` error-vs-end-of-speech contract
- `test/features/voice/services/speech_to_text_voice_stt_service_test.dart` — graceful-silence regression tests

---

### voice-stt-samsung-no-match-terminates-recogniser

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-23
- **Last verified:** 2026-05-25
- **Area:** voice

**Symptom**

Mic shuts off silently 3–5 seconds after the overlay opens. The user hears nothing (no error message, no TTS), the overlay reverts to idle, and the bot never processes the utterance. Logs show `SpeechToTextVoiceSttService: closing gracefully` with no transcript, even though the user spoke.

**Root cause**

Android `SpeechRecognizer.onError(ERROR_NO_MATCH)` is a **terminal** callback — once it fires, the recogniser engine has stopped completely. The previous fix (treating `no_match` as graceful end-of-stream and closing the controller) was half-correct: it removed the error UI but still ended the session before any partial could be promoted. On Samsung devices, `error_no_match` fires aggressively during recogniser warm-up (~2–3 s) and again at the first post-speech silence, so the old 2 s `sttSilenceTimeout` caused near-instant termination even after the user finished speaking.

**Workaround / fix**

The STT service now implements a continuous-listening session model:

1. **On `error_no_match` with a non-empty partial** — the latest partial transcript is promoted to a synthetic final result (Claude-voice-style auto-finalise on silence) and the stream closes normally. `VoiceBloc` follows the existing `isFinal: true` path: `listening → transcribing → thinking → VoiceSendMessage`.
2. **On `error_no_match` with no partial yet** — the underlying `SpeechRecognizer` is silently restarted up to `VoiceConstants.sttMaxNoMatchRestarts` times (covers the Samsung warm-up quirk). The user sees uninterrupted "Listening…".
3. **On `status='done'` with an un-finalised partial** — same promotion as (1), handles Samsung's quirk of ending cleanly via `pauseFor` without tagging the last `onResult` as final.
4. `sttSilenceTimeout` raised from 2 s to 3 s; `sttListenTimeout` raised from 15 s to 20 s; `sttMaxNoMatchRestarts = 2` added.
5. `ListenMode.dictation` replaces the default `confirmation` mode — designed for longer, pause-tolerant utterances.

Do **not** revert to the old approach of closing the session on `error_no_match` — the recogniser is terminal and cannot recover on its own.

**References**

- `lib/features/voice/data/services/speech_to_text_voice_stt_service.dart` — `_ListenSession`, `_onError`, `_onStatus`, `promoteOnSilence`, `shouldRestartOnNoMatch`
- `lib/core/constants/voice_constants.dart` — `sttSilenceTimeout`, `sttListenTimeout`, `sttMaxNoMatchRestarts`
- `lib/domain/services/voice_stt_service.dart` — updated `listen()` contract doc
- `test/features/voice/services/speech_to_text_voice_stt_service_test.dart` — promotion and restart regression tests
- `test/features/voice/application/voice_bloc_test.dart` — silence-promotion bloc regression test

---

### voice-wake-word-requires-picovoice-key-in-secure-storage

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-23
- **Last verified:** 2026-06-06
- **Area:** voice

**Symptom**

Wake-word detection never activates on a fresh install. The VoiceFab logged `VoiceWakeWordException(VoiceWakeWordErrorKind.noAccessKey, Picovoice access key not configured.)` on every app launch and resume, and the user had no visible cue that they needed to act.

**Root cause**

The Picovoice Porcupine access key was a per-device secret that lived exclusively in `flutter_secure_storage` (key `voice.picovoice_access_key`). `PorcupineVoiceWakeWordService.start()` threw `VoiceWakeWordErrorKind.noAccessKey` when no value was present.

**Workaround / fix**

Resolved: Picovoice/Porcupine removed. Wake word now uses `SherpaOnnxVoiceWakeWordService` (offline, no credentials, Apache-2.0). No access key, no secure-storage machinery, no `VoiceCredentialService`. The `noAccessKey` error kind no longer exists. See PR that merged `chore/remove-picovoice`.

**References**

- `lib/features/voice/data/services/sherpa_onnx_voice_wake_word_service.dart` — replacement engine
- `lib/injection/modules/register_voice_module.dart` — `SherpaOnnxVoiceWakeWordService` registration

---

### voice-picovoice-key-must-ship-via-dart-define

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-25
- **Last verified:** 2026-06-06
- **Area:** voice

**Symptom**

Wake-word engine never started on a fresh install or CI build. `PorcupineVoiceWakeWordService.start()` threw `VoiceWakeWordErrorKind.noAccessKey` because `flutter_secure_storage` had no Picovoice key.

**Root cause**

The Picovoice Porcupine access key was a per-app-registration credential that could not be committed to version control. Every fresh install was missing the key because there was no automatic seeding path until `AppBootstrapper._seedPicovoiceKeyFromEnvIfNeeded` was introduced.

**Workaround / fix**

Resolved: Picovoice/Porcupine removed entirely. Wake word now uses `SherpaOnnxVoiceWakeWordService` (offline, Apache-2.0, no access key, no dart-define, no secure-storage seeding). The `PICOVOICE_ACCESS_KEY` dart-define and the `VoiceCredentialService` / `AppBootstrapper` seeder are gone. `dart_defines.json` / `dart_defines.example.json` no longer contain this key. No developer action required on fresh clones.

**References**

- `lib/features/voice/data/services/sherpa_onnx_voice_wake_word_service.dart` — replacement engine
- `assets/wake_words/kws/` — bundled KWS model assets (sherpa-onnx-kws-zipformer-gigaspeech int8)
- `dart_defines.example.json` — `PICOVOICE_ACCESS_KEY` row removed

---

### voice-context-keys-must-be-camelcase

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-25
- **Last verified:** 2026-05-25
- **Area:** voice

**Symptom**

The LLM always received default/empty context regardless of actual user data — today's date was correct but `recentSets` and `recentNutritionLogs` were always empty arrays, and `weightUnit` was always `kg` even for `lbs` users. Context was silently dropped with no error.

**Root cause**

`_buildContext()` in `supabase_voice_remote_datasource.dart` sent snake_case keys (`current_date`, `weight_unit`, `recent_sets`, `recent_nutrition_logs`, `set_id`, `exercise_name`, `log_id`, `meal_name`) but the TypeScript Edge Function (`supabase/functions/voice-chat/index.ts`) reads camelCase properties (`ctx.currentDate`, `ctx.weightUnit`, `ctx.recentSets`, `ctx.recentNutritionLogs`). Unmatched keys are `undefined` in JavaScript and the type guards `isRecentSet` / `isRecentNutritionLog` silently rejected every entry, so the LLM always saw empty lists.

**Workaround / fix**

All keys in `_buildContext()` must be camelCase to match the TypeScript interface. The fix changed every snake_case key to camelCase. If the Edge Function TypeScript interface is ever refactored, the Dart datasource must be updated in the same PR — the two are a coupled contract.

**References**

- `lib/data/datasources/remote/supabase_voice_remote_datasource.dart` — `_buildContext()`
- `supabase/functions/voice-chat/index.ts` — `isRecentSet`, `isRecentNutritionLog` type guards

---

### voice-openai-api-key-must-be-supabase-secret

- **Severity:** Critical
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-25
- **Last verified:** 2026-05-25
- **Area:** voice

**Symptom**

Every voice chat call returned a generic "Something went wrong" TTS readback. The Edge Function responded with HTTP 502 and no further detail was surfaced to the client.

**Root cause**

`supabase/functions/_shared/openai.ts` — `getApiKey()` throws `VoiceError(OPENAI_UNAVAILABLE, 502)` when the `OPENAI_API_KEY` environment variable is absent. The key was never set as a Supabase function secret, so every call from the deployed function failed at the key-retrieval step before reaching OpenAI.

**Workaround / fix**

Run `supabase secrets set OPENAI_API_KEY=<key>` from the Supabase CLI to provision the secret in the target Supabase project. The key is a server-side secret only — it must never appear in Flutter client code or in the repository. Verify the secret is set before deploying the Edge Function to any new environment.

**References**

- `supabase/functions/_shared/openai.ts` — `getApiKey()`
- `supabase/functions/voice-chat/index.ts` — entry point that calls `getApiKey()`
- `CLAUDE.md` — "`OPENAI_API_KEY` lives exclusively as a Supabase function secret"

---

### voice-mic-permission-must-be-requested-before-overlay

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-25
- **Last verified:** 2026-05-25
- **Area:** voice

**Symptom**

The microphone permission dialog appeared mid-session — during STT initialisation inside `VoiceBloc._onListenRequested` — rather than before the overlay opened. On some Android devices this caused STT to fail silently on first use: the permission grant was asynchronous and the recogniser had already been asked to start without the permission being granted yet.

**Root cause**

`VoicePermissionService` was implemented (`PermissionHandlerVoicePermissionService`) but never registered in the DI container and never called before the overlay was pushed. STT's `speech_to_text` plugin triggers the OS permission dialog internally when `initialize()` is called, which happens inside the BLoC after the overlay is already visible.

**Workaround / fix**

`VoicePermissionService` is now registered as `registerLazySingleton` in `register_voice_module.dart`. `VoiceFab._openOverlay()` performs an explicit `checkMicrophonePermission` → `requestMicrophonePermission` sequence before pushing the overlay route. If permission is permanently denied, a SnackBar with an "Open Settings" action is shown and the overlay is not opened. Do not move the permission check inside the BLoC or overlay — it must happen before the overlay route is pushed.

**References**

- `lib/domain/services/voice_permission_service.dart` — `VoicePermissionService` interface
- `lib/features/voice/data/services/permission_handler_voice_permission_service.dart` — implementation
- `lib/features/voice/presentation/widgets/voice_fab.dart` — `_openOverlay()`
- `lib/injection/modules/register_voice_module.dart` — `VoicePermissionService` registration

---

### voice-whisper-is-the-default-stt-backend

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-26
- **Last verified:** 2026-05-26
- **Area:** voice

**Symptom**

Voice utterances are now uploaded to OpenAI Whisper (server-side) rather than recognised on-device. A developer who expects the old on-device flow (no network call, no per-utterance cost) may be surprised by the new latency profile (~500ms-1s upload + transcription) and the per-utterance line items in `voice_usage_log`.

**Root cause**

Android `SpeechRecognizer` (especially the Samsung variant) mishears gym jargon — `bench press` → `walk me lunch press`, `RPE` → `R&P`, etc. — even with the per-platform vocabulary nudges available to it. Whisper with the `WHISPER_VOCABULARY_PROMPT` gym/nutrition prompt recognises these terms reliably. The trade-off was accepted in the voice-whisper-stt PR.

**Workaround / fix**

`NetworkAwareVoiceSttService` is the registered `VoiceSttService` implementation. It delegates each `listen()` call to `WhisperVoiceSttService` when `NetworkStatusService.isNetworkAvailable()` returns `true`, and falls back to `SpeechToTextVoiceSttService` when offline (or when the connectivity check itself throws). The routing decision is made **once per session** — a connectivity change mid-utterance does **not** swap backends. Do not bypass the composite by registering one of the underlying backends directly; the composite is the only entry point that respects the offline fallback contract.

Per-utterance cost: ~$0.001-0.002 against the $0.50/day budget (caps at ~250 utterances/day). Whisper bills audio rounded up to the nearest second; the daily budget gate enforced in `voice-transcribe/index.ts` shares the same `voice_usage_log` table and `dailyCapUsd` as `voice-chat`.

**References**

- `lib/features/voice/data/services/network_aware_voice_stt_service.dart` — composite routing
- `lib/features/voice/data/services/whisper_voice_stt_service.dart` — record + upload + emit
- `supabase/functions/voice-transcribe/index.ts` — server entry
- `supabase/functions/_shared/whisper.ts` — Whisper API wrapper + `WHISPER_VOCABULARY_PROMPT`
- `lib/injection/modules/register_voice_module.dart` — composite registration

---

### voice-transcribe-must-deploy-with-openai-secret-and-cors

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-26
- **Last verified:** 2026-05-26
- **Area:** voice

**Symptom**

After the Whisper migration ships, every voice utterance fails with `ServerFailure: Voice transcription is not available in offline mode.` or with a 502 from the function. The Flutter logs show the new error path firing on every tap.

**Root cause**

The `voice-transcribe` Edge Function is a **new** function — Supabase does not auto-deploy it. Until it is deployed via the Supabase CLI or the `Supabase Deploy` GitHub Action, the function URL returns 404 and the Flutter client surfaces the failure as a generic ServerFailure. Additionally, the function shares the `OPENAI_API_KEY` secret with `voice-chat` — if the secret is set for `voice-chat` only (older deployments) the new function still inherits it because Supabase secrets are project-scoped, but a fresh project without the secret will 502.

**Workaround / fix**

1. Deploy: trigger the `Supabase Deploy` GitHub Action with target `functions` (or run `supabase functions deploy voice-transcribe` locally with the project linked). The same workflow already deploys `voice-chat`; the new function lands alongside it.
2. Verify the secret: `supabase secrets list` must show `OPENAI_API_KEY`. If absent, set with `supabase secrets set OPENAI_API_KEY=<key>`.
3. CORS headers are shared via `supabase/functions/_shared/cors.ts` — both functions return the same preflight response; no per-function CORS work is required.

**References**

- `supabase/functions/voice-transcribe/index.ts` — entry
- `supabase/functions/_shared/cors.ts` — shared CORS preflight
- `.github/workflows/supabase-deploy.yml` — manual deploy workflow

---

### voice-phantom-success-spoken-before-persistence-completes

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-27
- **Last verified:** 2026-06-01
- **Area:** voice

**Symptom**

User logs a set via voice; the bot replies "Set logged" within ~200 ms; the actual `WorkoutBloc.add(AddWorkoutSetEvent)` dispatch may still be pending or may fail silently. If the persistence step fails (transient SQLite error, `MissingUserContextException` from a session race, etc.), the user is misled — no row lands, but they were told everything is fine. The local recent-sets cache also carries the phantom row until the next app restart, so subsequent voice-context payloads to the LLM "see" a set that was never written to disk.

**Root cause**

`VoiceBloc._dispatchMutationTool` (`lib/features/voice/application/voice_bloc.dart:960`) emits `VoiceAddWorkoutSetCommand` as a fire-and-forget effect and **immediately returns** the success string. There is no round-trip wait for the target BLoC's outcome. `_cachedWorkoutSets` is mutated synchronously in the same branch, compounding the deception: the cache is updated regardless of whether the underlying write succeeds.

**Workaround / fix**

Diagnostic workaround: open the History tab after every voice log to confirm the row appears. The fix (planned in `plan-2-post-guest-removal-cleanups.md` Commit 3) makes `VoiceBloc._dispatchMutationTool` await a `Completer<VoiceMutationOutcome>` completed by `VoiceCommandRouter` only after the target BLoC emits a success or failure effect. Cache mutation moves into the success branch only.

**References**

- `lib/features/voice/application/voice_bloc.dart` — `_dispatchMutationTool` round-trip dispatch
- `lib/app/voice/voice_command_router.dart` — dispatch bridge and completer outcome bridge
- `plan-2-post-guest-removal-cleanups.md` — full implementation plan (Commit 3)

**Resolution**

`VoiceBloc` now awaits a `VoiceMutationOutcome` via a `Completer` round-trip through `VoiceCommandRouter` and the target BLoC's effects. `VoiceCommandRouter` subscribes to `WorkoutBloc.effects`, `NutritionLogBloc.effects`, and `HistoryBloc.effects`, completing the completer when a success or failure effect arrives. Cache mutation (`_cachedWorkoutSets` / `_cachedNutritionLogs`) occurs only on `VoiceMutationSuccess`. A 5-second timeout returns `voiceSpokenMutationTimedOut` if the target BLoC stalls. Concurrent dispatches are serialised via a FIFO queue (max 5). See Commit 3 of `plan-2-post-guest-removal-cleanups.md`. The round-trip added in Plan 2 only actually dispatches once the overlay and router share one `VoiceBloc` — see [`voice-overlay-and-shell-use-different-voicebloc-instances`](#voice-overlay-and-shell-use-different-voicebloc-instances).

---

### voice-overlay-and-shell-use-different-voicebloc-instances

- **Severity:** Critical
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-31
- **Last verified:** 2026-06-01
- **Area:** voice

**Symptom**

Confirming a voice mutation (log/edit/delete workout set or nutrition log) makes the bot say `voiceSpokenMutationTimedOut` after ~5 seconds and nothing persists — not in History, not in the muscle model. Affects all six voice mutations: logWorkoutSet, editWorkoutSet, deleteWorkoutSet, logNutrition, editNutritionLog, deleteNutritionLog.

**Root cause**

`VoiceBloc` is registered as a factory, so every `sl<VoiceBloc>()` call returns a new object. Two separate providers exist: `VoiceOverlayPage` (`lib/features/voice/presentation/voice_overlay_page.dart:48`) creates its own instance and runs the entire overlay UI — including the confirmation card → `VoiceConfirmationAccepted` → `_dispatchMutationTool` → `emitEffect(VoiceAddWorkoutSetCommand(...))` — on that instance. Meanwhile, `VoiceCommandRouter` (`lib/app/voice/voice_command_router.dart:83`) subscribes to the separate shell instance provided by `AuthSessionShell` (`lib/app/auth_session_shell.dart:78`). Because the two are different objects, the overlay's emitted `VoiceMutationCommand` goes into its own effects stream, which the router never listens to. The dispatch never reaches `WorkoutBloc`/`HistoryBloc`/`NutritionLogBloc`, the `Completer<VoiceMutationOutcome>` is never completed, and `_dispatchMutationTool` times out after `VoiceConstants.mutationDispatchTimeout` (5 s). This dual-instance split was also the true underlying cause of the earlier phantom-success symptom — see [`voice-phantom-success-spoken-before-persistence-completes`](#voice-phantom-success-spoken-before-persistence-completes).

**Workaround / fix**

No user workaround; voice logging is entirely unusable until fixed. Fix: mount `VoiceCommandRouter` inside `VoiceOverlayPage`, below its `BlocProvider<VoiceBloc>`, so the router observes the same instance the overlay uses. It still reaches `WorkoutBloc`/`HistoryBloc`/`NutritionLogBloc` via the auth-session shell (pushed routes are descendants of its `MultiBlocProvider`). Then remove the now-dead shell-level `BlocProvider<VoiceBloc>` and `VoiceCommandRouter` wrapper from `AuthSessionShell`. See `issue-2-voice-dual-voicebloc-fix-plan.md`.

**References**

- `lib/features/voice/presentation/voice_overlay_page.dart:48` — overlay creates its own `VoiceBloc` instance
- `lib/app/auth_session_shell.dart:78` — shell provides a separate `VoiceBloc` instance
- `lib/app/voice/voice_command_router.dart:83` — router listens to the shell instance, never the overlay's
- `issue-2-voice-dual-voicebloc-fix-plan.md` — full fix plan
- See also: [`voice-phantom-success-spoken-before-persistence-completes`](#voice-phantom-success-spoken-before-persistence-completes)

**Resolution**

Mounted `VoiceCommandRouter` inside `VoiceOverlayPage` below its `BlocProvider<VoiceBloc>`, so the router observes the same `VoiceBloc` the overlay uses; the round-trip now dispatches and persists. The dead shell-level `VoiceBloc`/router were removed in the follow-up refactor. See `issue-2-voice-dual-voicebloc-fix-plan.md`.

---

### voice-bot-must-never-surface-internal-ids

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-02
- **Last verified:** 2026-06-02
- **Area:** voice

**Symptom**

When asked about logged data (e.g. "what are my latest workout sets"), the voice bot sometimes reads/writes raw database identifiers — `1. Skull Crushers … [id: a74cfe8b-…]` — back to the user. Intermittent: clean when the bot routes through the `getRecentSets` query tool, leaky when it answers in its own prose.

**Root cause**

`SYSTEM_PROMPT_TEMPLATE` (`supabase/functions/voice-chat/index.ts`) deliberately renders recent sets/logs with `[id: …]` so the model can fill `setId`/`logId` on edit/delete tool calls, but never forbids surfacing them, and only softly routes data questions through query tools. When the model answers a data question as prose it parrots the context lines verbatim, ids included. The ids are per-user RLS-scoped row UUIDs, not credentials, so this is data-hygiene/UX incorrectness, not a credential leak.

**Workaround / fix**

1. Prompt rule: ids are internal-only, never spoken/written; data questions MUST be answered via a query tool. Keep ids in the context — the model needs them for tool calls.
2. Defense-in-depth: `sanitizeAssistantText()` strips `[id: …]` and bare UUIDs from assistant *message* text before it is returned or stored. Tool calls are unaffected (the client builds an id-free readback from structured args).

**References**

- `supabase/functions/voice-chat/index.ts` — `SYSTEM_PROMPT_TEMPLATE`, `sanitizeAssistantText`
- `supabase/functions/voice-chat/index.test.ts` — sanitizer tests
- PR `#NN` — fix

---

### voice-bot-must-log-duplicate-sets

- **Severity:** Critical
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-06
- **Last verified:** 2026-06-06
- **Area:** voice

**Symptom**

The bot refuses to log a workout set or nutrition entry that is identical to an existing one (same exercise, weight, reps, intensity, or meal/macros). Instead of logging, it says "You have already logged this — would you like to edit that entry instead?" Even when the user insists, no entry is created.

**Root cause**

No dedup logic exists in the code: `VoiceBloc._buildWorkoutSet` always mints a fresh `Uuid().v4()` and never compares against existing rows; `_shared/tools.ts` `logWorkoutSet` has no uniqueness clause; the persistence layer accepts duplicate rows without error. The refusal is purely model-invented behaviour: `SYSTEM_PROMPT_TEMPLATE` injects the user's recent sets via `{{recent_sets}}`, and `gpt-4o-mini` "helpfully" decided to refuse and redirect — returning prose instead of a `logWorkoutSet` tool call — because the prompt contained no statement that duplicates are explicitly allowed.

**Workaround / fix**

Add an explicit allow-duplicates rule to `SYSTEM_PROMPT_TEMPLATE` in the "Tool usage rules:" block: "Duplicates are always allowed … The recent sets/logs context is for resolving edit/delete targets ONLY — it is NOT a uniqueness constraint." Do **not** add any dedup or uniqueness logic anywhere in the client or server — duplicates are a valid user requirement. After merging, the `voice-chat` Edge Function must be redeployed (`Supabase Deploy` GitHub Action, target `functions`) for the prompt change to take effect.

**References**

- `supabase/functions/voice-chat/index.ts` — `SYSTEM_PROMPT_TEMPLATE`, "Tool usage rules:" block
- `supabase/functions/_shared/tools.ts:9` — `logWorkoutSet.description` (no uniqueness constraint)
- `lib/features/voice/application/voice_bloc.dart:1272` — `_buildWorkoutSet` always mints a fresh UUID

---

### voice-wake-word-engine-must-serialize-and-retry-mic-acquire

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-06
- **Last verified:** 2026-06-06
- **Area:** voice

**Symptom**

Wake word stops responding after a voice turn (wake word → STT → TTS → overlay closed). Recovered only by changing the preset in Settings. Intermittent; "after a couple of tries it worked."

**Root cause**

Two compounding bugs. (1) `start()` and `stop()` were unserialised: the dedup guard `if (_running && _activePreset == preset) return` was checked before either call settled `_running`, so two concurrent callers (e.g. `VoiceFab.initState` and the `BlocListener` firing close together) both passed the guard, both opened an `AudioRecorder` stream, and the second assignment orphaned the first recorder — leaving the engine "running" with a dead subscription. Device log showed the `started for preset` line twice back-to-back. (2) Re-arm on overlay close called `start()` immediately after the Whisper STT recorder released the mic; on Android the OS may not have freed the `AudioRecord` yet, causing `startStream` to throw. The FAB's `.catchError` logged and gave up with no retry, leaving the engine permanently off until the user changed the preset (which triggered a fresh `start()`).

**Workaround / fix**

Serialise via a single-slot op queue (`_opChain` + `_enqueue<T>`) inside `SherpaOnnxVoiceWakeWordService` so `start()`, `stop()`, and `dispose()` never interleave. `dispose()` is a terminal enqueued op that closes the stream controllers inside the queue. Retry mic acquisition up to `VoiceConstants.wakeWordMicAcquireMaxAttempts` times with `VoiceConstants.wakeWordMicAcquireRetryDelay` backoff before surfacing `audioError`. Do **not** add retries or serialisation in `VoiceFab` — the service owns this contract.

**References**

- `lib/features/voice/data/services/sherpa_onnx_voice_wake_word_service.dart` — `_opChain`, `_enqueue`, `_doStart` retry loop
- `lib/features/voice/presentation/widgets/voice_fab.dart:104` — `_startWakeWordIfArmed` (unchanged; service handles retries)
- `lib/core/constants/voice_constants.dart` — `wakeWordMicAcquireMaxAttempts`, `wakeWordMicAcquireRetryDelay`

---

### voice-confirmation-cancel-leaves-bot-unresponsive

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-07
- **Last verified:** 2026-06-07
- **Area:** voice

**Symptom**

Tapping Cancel on the confirmation card leaves the bot unreachable — the in-overlay mic button does nothing and the wake word does not work — until the overlay is closed and reopened.

**Root cause**

`_onConfirmationCancelled` cleared the pending card but never reset `status`, leaving it at `VoiceStatus.awaitingConfirmation`. The overlay mic tap is gated `status == idle`, so it became a no-op; the wake engine is off while the overlay is open. The accept path resets to idle; cancel did not.

**Workaround / fix**

`_onConfirmationCancelled` now emits `status: VoiceStatus.idle` (with `clearPendingConfirmation` + `clearTranscript`), mirroring the accept path. Re-engaging via the mic tap works again. (Full wake-word-while-overlay-open is addressed by the Plan 2 wake-engine-at-idle change.)

**References**

- `lib/features/voice/application/voice_bloc.dart` — `_onConfirmationCancelled`
- `lib/features/voice/presentation/voice_overlay_page.dart:237` — mic-tap `status == idle` gate
- `test/features/voice/application/voice_bloc_test.dart` — `VoiceConfirmationCancelled` group

---

### voice-whisper-hallucinates-on-silent-audio

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-07
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

Waking the bot and immediately tapping Stop (or any near-silent recording) sends a phantom user message such as "For more information visit www.FEMA.gov", which the LLM then answers. The user never spoke. Also recurs after a bot question while the user stays silent — the post-#143 re-listen path re-opens the mic and ambient room noise crosses the client amplitude gate.

**Root cause**

Two-layer failure, fixed in two stages.

1. (Client, fixed 2026-06-07.) `WhisperVoiceSttService` uploaded any non-empty recording — the only gate was `bytes.isEmpty`. A sub-second silence clip is a non-empty ~7 KB m4a, so it was uploaded.
2. (Server gap exposed 2026-06-10 by the post-#143 re-listen loop.) After bot questions, the client re-opens the mic; ambient room noise above the −45 dBFS gate (`whisper_voice_stt_service.dart`) sets `_voiceDetected=true` and the clip is uploaded anyway. Whisper then hallucinates a fluent stock phrase on the noise, and the server passed `.text` straight through with no confidence gate.

**Workaround / fix**

Defense in depth — both layers now exist:

1. **Client amplitude gate** — `_voiceDetected` (set when any amplitude sample crosses the voice threshold) gates the upload via `WhisperVoiceSttService.shouldTranscribe(voiceDetected:, byteCount:)`. Silence-only clips emit `VoiceSttErrorKind.noSpeech` without uploading. Do not gate on `_lastVoiceAt` — it is nulled by `_teardownTimersAndSubscription()` before the gate runs.
2. **Server confidence gate** — `_shared/whisper.ts` calls the pure exported helper `gateHallucinatedTranscript(json)` on every Whisper response. When `max(segments[].no_speech_prob) >= 0.6` **AND** `min(segments[].avg_logprob) <= -1.0`, the helper returns `""`. Empty text falls through the client's existing `text.isEmpty` branch (reprompt-once-then-idle). Both bounds must trip together so real speech (incl. one-word `"Confirm."` with no_speech_prob ≈ 0.05, avg_logprob ≈ -0.4) is never silenced. The gate only fires when `segments` is present in the response — a missing/empty array passes raw text through unchanged. Audio duration is still billed because Whisper processed the clip. Field names (`segments[].no_speech_prob`, `segments[].avg_logprob`) were verified against the OpenAI audio API reference before the helper was written. Requires a `Supabase Deploy` (functions target) on the self-hosted VPS for the server gate to take effect.

**References**

- `lib/features/voice/data/services/whisper_voice_stt_service.dart` — `_voiceDetected`, `shouldTranscribe`, `_stopAndTranscribe`
- `test/features/voice/services/whisper_voice_stt_service_test.dart` — `shouldTranscribe` group
- `supabase/functions/_shared/whisper.ts` — `gateHallucinatedTranscript`, `NO_SPEECH_PROB_MAX`, `AVG_LOGPROB_MIN`
- `supabase/functions/_shared/whisper.test.ts` — `gateHallucinatedTranscript` group + `transcribeAudio` end-to-end gate test
- `supabase/functions/voice-transcribe/index.test.ts` — silence-hallucination end-to-end test
- PR `#150` — fix: gate Whisper output on no_speech_prob/avg_logprob confidence

---

### voice-wake-word-keyword-miss-rate

- **Severity:** Medium
- **Status:** Active
- **First observed:** 2026-06-07
- **Last verified:** 2026-06-11
- **Area:** voice

**Symptom**

With the engine correctly armed and the mic streaming a clear signal, the sherpa-onnx KWS frequently fails to spot a short wake phrase ("Thomas", "Trainer") — often needing several repetitions, occasionally missing entirely. Confirmed on-device: two consecutive "Thomas" attempts produced no detection; the third matched. On 2026-06-11, the trainer preset measured ~1/10 hit rate on a fresh device session.

**Root cause**

Short keywords (2–3 BPE tokens) provide little acoustic evidence for streaming KWS. The engine, mic, and audio pipeline are healthy — this is recognition sensitivity, not a lifecycle or mic bug.

**Workaround / fix**

`keywordsThreshold` lowered 0.25 → `VoiceConstants.wakeWordKeywordsThreshold` (0.20) and `keywordsScore` raised 1.0 → `VoiceConstants.wakeWordKeywordsScore` (1.5). Both are now in `VoiceConstants` and wired through `buildKeywordSpotterConfig`. The longer "Samo Levski" preset is the most reliable and is recommended for users who miss wake-word fires frequently. Values may need further on-device tuning; watch for false positives if the threshold is lowered further. Status stays Active because tuning is empirical and ongoing.

On 2026-06-11 all three phrases were prefixed with "Hey" (now 5+ BPE tokens after re-tokenization against `tool/wake_words/bpe.model`: `▁HE Y ▁SA MO ▁LE V S K I`, `▁HE Y ▁TRA IN ER`, `▁HE Y ▁TH OM AS`). The short two (trainer, thomas) additionally carry a per-keyword `:2.0` boost suffix in `assets/wake_words/kws/keywords.txt` to compensate for fewer tokens. The global `keywordsScore` (1.5) and `keywordsThreshold` (0.20) remain unchanged. Settings labels and `WakeWordPreset.wakePhrase` / `displayName` were updated accordingly (`HEY SAMO LEVSKI` / `HEY TRAINER` / `HEY THOMAS`). Status stays Active — on-device verification of the new hit rate is pending.

A second root cause was identified 2026-06-11: `VoiceSettingsCubit` starts at `VoiceSettings.defaults()` (preset `samoLevski`) and hydrates async via `_init()`. `VoiceFab.initState` called `_startWakeWordIfArmed` immediately — before hydration — arming the wrong preset and triggering a second native init when hydration landed and the cubit emitted the persisted preset. Fixed by exposing `VoiceSettingsCubit.ready` (the `_init()` future) and gating `_startWakeWordIfArmed` on `await cubit.ready` before reading `cubit.state`. This eliminates the wrong-preset window at boot and halves the native engine inits per session.

On-device verification 2026-06-11 (SM-S908B) showed the "Hey"-only lines made the regression worse, not better: the trainer preset measured **0/10** (down from ~1/10). The keyword path now requires the engine to decode `▁HE Y` before the preset tokens are reachable; if "Hey" is not decoded (accent, mic, a pause after "Hey,") the whole keyword can never fire. The fix arms **two keyword lines per preset** — the bare phrase and the "Hey"-prefixed variant — in `assets/wake_words/kws/keywords.txt` (six lines total, `:2.0` boost on the shorter bare/Hey trainer and thomas lines). `tokenizedLineForPreset` became `tokenizedLinesForPreset`, returning the two-line block for the active preset. `WakeWordPreset.acceptedPhrases` was added next to `wakePhrase` so detection matches either de-tokenized variant (`{'TRAINER', 'HEY TRAINER'}`, etc.); `_onAudioFrame` now compares against that set. To close a long-standing blind spot, a keyword that fires but matches no accepted phrase is now logged at `info` (`keyword "<kw>" ignored`) instead of being dropped silently — the only on-device signal for diagnosing phrase-contract or preset mismatches. Status stays **Active**: this is empirical tuning, and on-device verification of the new dual-phrase hit rate is pending. Do not claim solved.

**References**

- `lib/core/constants/voice_constants.dart` — `wakeWordKeywordsThreshold`, `wakeWordKeywordsScore`
- `lib/features/voice/data/services/sherpa_onnx_voice_wake_word_service.dart` — `buildKeywordSpotterConfig`
- `test/features/voice/services/sherpa_onnx_voice_wake_word_service_test.dart` — `buildKeywordSpotterConfig` group
- `lib/features/voice/application/voice_settings_cubit.dart:43` — `super(VoiceSettings.defaults())` initial state (samoLevski)
- `lib/features/voice/application/voice_settings_cubit.dart:59` — `late final Future<void> ready` getter
- `lib/features/voice/application/voice_settings_cubit.dart:65` — `_init()` hydration method
- `lib/domain/entities/voice_settings.dart:48` — `VoiceSettings.defaults()` (samoLevski preset)
- `lib/features/voice/presentation/widgets/voice_fab.dart:59` — `initState` (arms wake word on mount)
- `lib/features/voice/presentation/widgets/voice_fab.dart:115` — `_startWakeWordIfArmed` (now awaits `cubit.ready`)
- `assets/wake_words/kws/keywords.txt` — six lines, bare + "Hey" variant per preset
- `lib/features/voice/data/services/pcm_utils.dart` — `tokenizedLinesForPreset` (two-line block per preset)
- `lib/domain/entities/voice_settings.dart` — `WakeWordPreset.acceptedPhrases` (bare + Hey per preset)
- `lib/features/voice/data/services/sherpa_onnx_voice_wake_word_service.dart` — `_onAudioFrame` (matches `acceptedPhrases`; logs ignored firings)

---

### voice-wake-word-engine-stops-when-overlay-opens

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-07
- **Last verified:** 2026-06-08
- **Area:** voice

**Symptom**

With the voice overlay open and the bot at idle, saying the wake word did nothing. The bot could only be re-triggered by tapping the in-overlay mic button. The overlay had to be closed and reopened for the wake word to work again.

**Root cause**

`VoiceFab._openOverlay` stopped the wake engine before pushing the overlay (required for the mic handoff — both the wake recorder and the STT recorder use the `record` plugin and cannot simultaneously hold the mic on Android). The engine was only re-armed on overlay close, so it was off for the entire overlay session. The overlay's `_subscribeToWakeWord` subscription was wired correctly but never received events because the engine was not running.

**Workaround / fix**

Gate the wake engine on voice status rather than overlay visibility. A `BlocListener<VoiceBloc, VoiceState>` added to `_VoiceOverlayView.build` (Plan 2 commit 6) starts the engine when status transitions to `idle` and stops it when status leaves `idle`. A `postFrameCallback` in `_VoiceOverlayViewState.initState` handles the initial idle state (the FAB stops the engine before the overlay opens; the BlocListener only fires on transitions, not on first build). The FAB's pre-open stop and post-close re-arm are unchanged — the two owners do not overlap: FAB manages the engine while the overlay is closed, the BlocListener manages it while the overlay is open. Mic handoff between the wake recorder and the STT recorder continues to be bridged by `wakeWordMicAcquireMaxAttempts` / `wakeWordMicAcquireRetryDelay`.

**References**

- `lib/features/voice/presentation/voice_overlay_page.dart` — `_armWakeEngineForOverlay`, `BlocListener` in `_VoiceOverlayView.build`
- `lib/features/voice/presentation/widgets/voice_fab.dart:157` — `_openOverlay` (unchanged; mic handoff stop stays)
- `lib/core/constants/voice_constants.dart` — `wakeWordMicAcquireMaxAttempts`, `wakeWordMicAcquireRetryDelay`
- `test/features/voice/presentation/voice_overlay_page_test.dart` — wake engine lifecycle group
- redesign-overview.md §8; Plan 2 §2.2, commit 6

---

### headphone-tap-to-wake-unreliable-on-airpods-and-when-another-app-holds-media-focus

- **Severity:** Low
- **Status:** Mitigated
- **First observed:** 2026-06-08
- **Last verified:** 2026-06-08
- **Area:** voice

**Symptom**

A single headphone tap sometimes does not wake the bot — notably with AirPods on Android, or when a music app is the active media-button target.

**Root cause**

Android routes media buttons to the app holding the active MediaSession / audio focus; Apple does not expose AirPods tap gestures as standard media buttons off-iOS.

**Workaround / fix**

Keep the app's MediaSession active while the wake word is armed in the foreground (Plan 3). Wake-word remains the reliable fallback. No background service or silent audio is used to force the route (battery/policy cost).

**References**

- `redesign-plan-3-headphone-tap-to-wake.md §0` — known limitations
- `redesign-overview.md §12` — plan sequencing

---

### voice-edge-functions-bare-import-specifiers-fail-to-boot

- **Severity:** Critical
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

Every voice call fails. The app says "Something went wrong, please try again!" and `WhisperVoiceSttService` logs `ServerFailure(HTTP_500|500|Voice service error (500))`. The Edge Function returns HTTP 500 with a body that is not the standard `{code, message}` error JSON, so the client falls back to its default message.

**Root cause**

The self-hosted edge-runtime router (`supabase/docker/volumes/functions/main/index.ts` on the VPS) creates each worker with `importMapPath: null` — it does **not** load the `deno.json` import map, and the deploy never copied `deno.json` to the functions volume anyway. A bare specifier like `import ... from "@supabase/supabase-js"` therefore cannot be resolved at runtime: the worker fails with `worker boot error: ... Relative import path "@supabase/supabase-js" not prefixed with / or ./ or ../`, and the router's catch block returns `500 {msg: ...}`. Because the body uses `msg` rather than `code`/`message`, `SupabaseVoiceRemoteDataSource._throwFromErrorBody` keeps its default text. This affects every function importing `_shared/auth.ts` (`voice-chat` and `voice-transcribe`).

**Workaround / fix**

1. Do **not** rely on `deno.json`'s import map at runtime on the self-hosted stack — the router does not load it.
2. Route all third-party imports through `_shared/deps.ts`, which re-exports them with fully-qualified `npm:`/`jsr:` specifiers (e.g. `npm:@supabase/supabase-js@2`). Fully-qualified specifiers resolve without an import map, so the worker boots regardless of router config, and the version is pinned in one place.
3. Keep `deno.json` only for local dev/test conveniences (`@std/*`); do not add runtime third-party deps to it.
4. Verify on the server after deploy: `docker logs --tail 80 supabase-edge-functions` must show clean `serving the request with ...` lines and **no** `worker boot error`.

**References**

- `supabase/functions/_shared/deps.ts` — the dependency module
- `supabase/functions/_shared/auth.ts:1`, `utils.ts:1` — value import of `createClient`
- `lib/data/datasources/remote/supabase_voice_remote_datasource.dart:402` — `_throwFromErrorBody` default-message fallback
- `supabase/docker/volumes/functions/main/index.ts` (server only) — `importMapPath = null`

---

### voice-confirmation-card-buttons-must-cancel-the-open-listen

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

After tapping Cancel (or Yes) on the confirmation card, a phantom user turn appears — e.g. "For more information visit www.ottobock.com" — and the bot replies as if the user spoke it. The phrase was never said.

**Root cause**

The mutation readback re-opens the mic (`_speakThenListen`) so the user can confirm by voice. The spoken-confirm path cancels `_sttSubscription` on its final transcript, but the card *button* handlers did not: `_onConfirmationAccepted` and `_onConfirmationCancelled` cleared `pendingConfirmation` and returned to idle without tearing down the open listen. The readback mic stayed open; its final transcript still arrived at `_onTranscriptReceived` with `pendingConfirmation == null`, so it skipped the confirm-classify block and was processed as a fresh turn. The transcript itself is a Whisper near-silence hallucination (see [voice-whisper-hallucinates-on-silent-audio](#voice-whisper-hallucinates-on-silent-audio)).

**Workaround / fix**

Both button handlers now tear down the live listen before any state change: `_sttSubscription?.cancel(); _sttSubscription = null;` (fire-and-forget, matching the existing `_onTranscriptReceived`/`_onListenEnded` idiom — do **not** `await`, it hangs under `fakeAsync`) plus reset of `_awaitingUserReply`, `_repromptedThisTurn`, `_consecutiveRelistens`. Defense in depth: `_onTranscriptReceived` and `_onTranscriptFailed` now drop any event that arrives when `state.status != VoiceStatus.listening` (the only open-mic state). This does not change the spoken-confirm path, which legitimately runs while `status == listening`. The near-silence hallucination itself is an inherent Whisper limit ([voice-whisper-hallucinates-on-silent-audio](#voice-whisper-hallucinates-on-silent-audio)); this fix makes its consequence harmless. Related: [voice-confirmation-cancel-leaves-bot-unresponsive](#voice-confirmation-cancel-leaves-bot-unresponsive).

**References**

- `lib/features/voice/application/voice_bloc.dart` — `_onConfirmationAccepted`, `_onConfirmationCancelled`, `_onTranscriptReceived`, `_onTranscriptFailed`
- `test/features/voice/application/voice_bloc_test.dart` — `confirmation buttons end the listen` group
- PR `#142`

---

### voice-clarify-questions-must-be-coerced-to-the-clarify-tool

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

The bot asks a clarifying question ("What weight did you use?") but the microphone does not re-open — the question is spoken and the conversation ends, forcing the user to tap to answer.

**Root cause**

The clarify question only keeps the mic open when the model routes it through the `clarify` tool: the client re-listens for `tool_call` + `clarify` (`supabase_voice_remote_datasource.dart:251`), while a plain `message` becomes a final `kind:"message"` response → `voice_bloc` speaks then goes idle. The system prompt instructs the model to use the `clarify` tool for any question, but `completeChat` sends `tool_choice:"auto"` with no enforcement (`openai.ts:133-134`), so the model still returns questions as prose in the field. Prompt-only enforcement was already attempted (PR `#129`) and still fails.

**Workaround / fix**

Server-side coercion. `coerceQuestionToClarify` (`voice-chat/index.ts`) inspects the guard-resolved assistant content: a reply with no tool call whose trimmed text ends in `?` is re-tagged into a `clarify` tool call (`{name:"clarify", arguments:{question}}`). The text is run through `sanitizeAssistantText` first (and the `?`-tail is tested on the sanitized text) — a tool call bypasses the response-shaping sanitize that a `kind:"message"` reply gets, so this preserves [voice-bot-must-never-surface-internal-ids](#voice-bot-must-never-surface-internal-ids). `handleChat` applies it after `applyAssistantGuard` and before billing/response shaping, so the existing tool_call branches log the session turn and return `kind:"tool_call"` — the client re-listens with no client change. The `GUARD_CORRECTIVE_MESSAGE` ends in "request." (not "?") so it is never coerced; it remains a statement (DECISION: do not re-open the mic on the corrective). The prompt rule (`index.ts:64-65`) is kept as belt-and-suspenders. **Backend change — takes effect only after a manual `Supabase Deploy` (functions target).** Related: [voice-confirmation-cancel-leaves-bot-unresponsive](#voice-confirmation-cancel-leaves-bot-unresponsive).

**References**

- `supabase/functions/voice-chat/index.ts` — `coerceQuestionToClarify`, `handleChat`
- `supabase/functions/voice-chat/index.test.ts` — `coerceQuestionToClarify` tests
- `supabase/functions/_shared/openai.ts:133-134` — `tool_choice:"auto"`, no enforcement
- `lib/data/datasources/remote/supabase_voice_remote_datasource.dart:251` — client re-listens on `clarify`

---

### voice-must-resolve-exercise-before-presenting-a-confirmation-card

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

A workout-log confirmation card reads "Log: unknown — 70 kg × 12 reps". Tapping "Yes" logs nothing — the set is silently dropped and no error is spoken.

**Root cause**

The model loses the exercise name across a prose clarify turn and emits `logWorkoutSet` with the literal placeholder `exerciseName: "unknown"`. `_buildReadback` prints the name verbatim, so the card shows "unknown" (`voice_bloc.dart`). On accept, `_buildWorkoutSet` resolves `"unknown"` through `ExerciseLookup.resolveId`, which returns null (no matching exercise), so the builder returns null and the mutation is dropped (`voice_bloc.dart` — the `if (set == null)` branch speaks `voiceSpokenExerciseNotFound`, but only after a doomed card was presented and confirmed). Because the model emits a real placeholder string rather than omitting the field, `strict`/`required` schema enforcement would not catch it.

**Workaround / fix**

Resolve-or-clarify before the card. In `_dispatchVoiceResult`'s `VoiceChatMutationCall` branch, for `logWorkoutSet` only, mirror `_buildWorkoutSet`'s resolution (`exerciseId ?? _resolveExerciseIdFromCache(exerciseName)`); if it resolves to null, do NOT set `pendingConfirmation` — speak `AppStrings.voiceClarifyWhichExercise` ("Which exercise was that?") and re-open the mic via `_speakThenListen`, then `return`. `editWorkoutSet`/`deleteWorkoutSet` are NOT gated: they resolve their target by `setId` from recent context and their readback derives the display name from that id, never from `args['exerciseName']`. `_resolveExerciseIdFromCache` refreshes the lookup if stale, so the gate is safe even on a cold cache. Client-only — no deploy required. Related: [voice-clarify-questions-must-be-coerced-to-the-clarify-tool](#voice-clarify-questions-must-be-coerced-to-the-clarify-tool), [voice-whisper-hallucinates-on-silent-audio](#voice-whisper-hallucinates-on-silent-audio).

**References**

- `lib/features/voice/application/voice_bloc.dart` — `_dispatchVoiceResult` `logWorkoutSet` resolution gate; `_buildWorkoutSet`, `_resolveExerciseIdFromCache`
- `lib/core/constants/app_strings.dart` — `voiceClarifyWhichExercise`
- `lib/features/voice/data/lookup/exercise_lookup.dart:48` — `resolveId` returns null for unknown names
- `test/features/voice/application/voice_bloc_test.dart` — logWorkoutSet group: unresolvable → clarify+re-listen; resolvable → card

---

### voice-day-scoped-queries-need-explicit-date-resolution

- **Severity:** Medium
- **Status:** Mitigated
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

"Tell me the nutrition I logged this day" returns "I don't have any recorded nutrition" even though data for that day exists. The model resolves a different (usually earlier) day correctly when the user names it explicitly ("the 8th of June"), but fails on anaphoric references ("this day", "that day", "then").

**Root cause**

`getDailyNutritionLog`, `getWorkoutForDay`, and `getDailyMacros` all default their `date` parameter to today when the model omits it (`voice_bloc.dart` — `_parseIsoDate(args['date']) ?? DateTime.now()`). The model is not instructed explicitly to resolve relative/anaphoric date references to an ISO string before calling these tools; when it fails to do so, the call silently queries today instead of the intended day. DB proof: `nutrition_logs` contained `Chicken Breast | 312.8 | 2026-06-08` for the affected user, but the bot queried 2026-06-10 (today), which had no logs.

**Workaround / fix**

Two-layer fix. Prompt half (this entry): append a `**Dates.**` rule to `SYSTEM_PROMPT_TEMPLATE` (`supabase/functions/voice-chat/index.ts`) instructing the model to resolve all relative/anaphoric day references to `yyyy-MM-dd` before calling the three day-scoped tools, and never to assume "today" when the user pointed at a different day. Sharpen the `date` parameter descriptions in `tools.ts` to reinforce the same rule at the schema level. **Requires a `Supabase Deploy` (functions target) to take effect** — prompt changes are not active until the edge function is redeployed. The deterministic client backstop (Commit 5 — last-referenced-date carry in `VoiceBloc`) is decision-gated and documented separately.

**References**

- `supabase/functions/voice-chat/index.ts` — `SYSTEM_PROMPT_TEMPLATE` date rule
- `supabase/functions/_shared/tools.ts` — `getDailyNutritionLog`, `getDailyMacros`, `getWorkoutForDay` date parameter descriptions
- `lib/features/voice/application/voice_bloc.dart` — `_queryDailyNutritionLog:1691`, `_queryWorkoutForDay:1708`, `_queryDailyMacros:1670` — client-side `DateTime.now()` default (backstop for Commit 5)
- `supabase/functions/voice-chat/index.test.ts` — `buildSystemPrompt: contains explicit date-resolution rule`
- `supabase/functions/_shared/tools.test.ts` — `tools: day-scoped query tools instruct model to resolve dates explicitly`

---

### voice-day-scoped-query-falls-back-to-last-referenced-date

- **Severity:** Medium
- **Status:** Mitigated
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

After the user names a day ("what did I train on the 8th") and then asks a follow-up that refers to it anaphorically ("and what did I eat that day"), the second query returns "nothing logged" — even though data for the 8th exists — because the model omitted the `date` argument on the anaphoric turn and the client defaulted to today.

**Root cause**

The prompt-side fix ([voice-day-scoped-queries-need-explicit-date-resolution](#voice-day-scoped-queries-need-explicit-date-resolution)) instructs the model to resolve anaphoric dates to an explicit `yyyy-MM-dd`, but `tool_choice` is `auto` with no `strict` enforcement, so the model can still omit `date`. When it does, `_queryDailyNutritionLog`, `_queryWorkoutForDay`, and `_queryDailyMacros` all fell back to `DateTime.now()`, querying the wrong day.

**Workaround / fix**

Deterministic client backstop in `VoiceBloc`. `_lastReferencedDate` records the last day a day-scoped query resolved to from an explicit (parseable) `date` argument. `_resolveQueryDate(args)` centralises the resolution for all three day-scoped query tools: when `date` is present and parseable it is used AND remembered; when `date` is absent or unparseable it falls back to `_lastReferencedDate`, else to **start-of-day today** (`DateTime(now.year, now.month, now.day)`, NOT raw `DateTime.now()` — `_queryWorkoutForDay` uses the value directly as `startDate`, so a time component would exclude earlier-in-day sets; the parsed-ISO path is already midnight). The carry persists for the whole conversation (per maintainer decision — NOT one-shot) and is reset to null in **every conversation-rotation handler** — `_onSessionStarted`, `_onConversationCleared`, and `_onHistoryDelete` (each mints a new `sessionId`) — so a stale day can never leak into a freshly cleared conversation (a fresh `VoiceBloc` is also created per overlay, so cross-conversation leakage is doubly guarded). **Residual risk:** if the user later means "today" but the model omits `date` on that turn too, the client reuses the last referenced day instead of today. The Commit-4 prompt makes the model emit an explicit `date` for "today", which overrides the carry (only an *absent* date falls back); deploy the functions target for that mitigation to be active. Client-only — no deploy required for this commit.

**References**

- `lib/features/voice/application/voice_bloc.dart` — `_lastReferencedDate` field; `_resolveQueryDate` (start-of-day fallback); `_queryDailyMacros`, `_queryDailyNutritionLog`, `_queryWorkoutForDay`; reset in `_onSessionStarted`, `_onConversationCleared`, `_onHistoryDelete`
- `test/features/voice/application/voice_bloc_test.dart` — `day-scoped date carry` group: carry reuses the prior day; lone query uses start-of-day today; clearing the conversation drops the carried day
- Related prompt half: [voice-day-scoped-queries-need-explicit-date-resolution](#voice-day-scoped-queries-need-explicit-date-resolution)

---

### voice-spoken-confirm-must-tolerate-stt-punctuation-and-filler

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

Saying "Confirm" (or "I confirm") while a confirmation card is showing causes the bot to re-ask the question and then log a completely different exercise. Device logcat proves the pattern: `transcription received (8 chars)` = `"Confirm."`, `transcription received (10 chars)` = `"I confirm."`. The correct exercise (e.g. bench press) disappears and a hallucinated one (e.g. Bulgarian Split Squat) appears on the card instead.

**Root cause**

`VoiceReplyClassifier.classify` matched against the raw transcript using anchored regexes (`^confirm$`). Whisper returns transcripts with a capital first letter and a trailing period, so `"Confirm."` fails `^confirm$` on the trailing `.` and `"I confirm."` fails on the `I ` prefix AND the `.`. Both fall through to `VoiceReplyKind.correction`, which routes to the LLM. `_onSendMessage` clears the pending confirmation before the LLM call, so the bench-press card is gone. The LLM receives a bare `"Confirm"` with truncated history, loses context, and re-emits `logWorkoutSet` with a hallucinated exercise name.

**Workaround / fix**

`VoiceReplyClassifier.classify` now normalises the input before matching: `transcript.toLowerCase().trim().replaceAll(_edgePunct, '')`, where `_edgePunct = RegExp(r'^[\s\p{P}]+|[\s\p{P}]+$', unicode: true)` strips leading and trailing Unicode whitespace and punctuation. The anchored regexes (`^…$`) are applied to the normalised string, so `"Confirm."` → `"confirm"` and `"I confirm."` → `"i confirm"` both hit their respective alternation. The alternations were also widened to cover common spoken forms (`i confirm`, `please confirm`, `okay`, `ok`, `correct`, `that's right`, `thats right`, `sure`; cancel: `no thanks`, `nope`, `forget it`). Anchoring is preserved — `"yes but make it 8"` still falls through to correction. Do **not** weaken the anchor (`^…$`) or remove the normalisation without re-running the full classifier test suite.

**References**

- `lib/features/voice/application/voice_reply_classifier.dart` — `_edgePunct`; widened `_confirm`/`_cancel`; normalised `classify()`
- `test/features/voice/application/voice_reply_classifier_test.dart` — new "Whisper normalisation" group; updated cancel list; regression anchoring tests
- PR `#147` — fix: punctuation/filler-tolerant confirm classifier
- Related: [voice-must-resolve-exercise-before-presenting-a-confirmation-card](#voice-must-resolve-exercise-before-presenting-a-confirmation-card)

---

### voice-recent-nutrition-context-was-today-only

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

Asking "what nutrition did I log on the 8th?" (or any day other than today) causes the bot to answer "You haven't logged any nutrition entries yet" even though food was logged via the app screens. Workout history from the same day is visible and queryable normally.

**Root cause**

`_warmRecentCaches` in `VoiceBloc` built the two LLM context slots asymmetrically: `{{recent_sets}}` used a 7-day sliding window (`_getSetsByDateRange`, last 7 days) while `{{recent_nutrition_logs}}` used today-only (`_getLogsForDate(DateTime.now())`). On any day where nutrition was logged earlier in the week but nothing was logged today, `{{recent_nutrition_logs}}` was empty. The LLM saw recent workouts and zero nutrition, concluded the user had no nutrition history, and free-texted that answer instead of calling `getDailyNutritionLog`.

**Workaround / fix**

`_warmRecentCaches` now uses `_getLogsByDateRange(startDate: now − 7 days, endDate: now)` for the nutrition cache, matching the sets window exactly. `GetLogsByDateRange` was already `registerLazySingleton` in the meals module and is wired into `VoiceBloc` as a new required constructor param `getLogsByDateRange`. `_getLogsForDate` is retained for the `_queryDailyNutritionLog` tool path, which still queries a specific date on demand. The `editNutritionLog` tool-dispatch test was updated to stub `getLogsByDateRange` (not `getLogsForDate`) for cache warming, since that path now populates `_cachedNutritionLogs`. Client-only — no deploy required.

**References**

- `lib/features/voice/application/voice_bloc.dart` — `_warmRecentCaches`: `_getLogsByDateRange` replaces `_getLogsForDate`; `_getLogsByDateRange` field and constructor param
- `lib/injection/modules/register_voice_module.dart` — `getLogsByDateRange: sl<GetLogsByDateRange>()` wired into VoiceBloc factory
- `test/features/voice/application/voice_bloc_test.dart` — `MockGetLogsByDateRange`; `_defaultGetLogsByDateRange`; new "recentNutritionLogs is non-empty" and "empty range" tests; `editNutritionLog` test updated to stub `getLogsByDateRange`
- PR `#148` — fix: widen recent-nutrition context window to 7 days

---

### voice-day-scoped-query-tools-omitted-from-must-call-rule

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-10
- **Last verified:** 2026-06-10
- **Area:** voice

**Symptom**

After the recent-nutrition window was widened to 7 days (see `[[voice-recent-nutrition-context-was-today-only]]`), the model still sometimes answers day-specific questions ("what did I eat on the 8th?", "what did I train on Monday?") with free-text prose — "You haven't logged anything" or a summary invented from the recent context — instead of calling `getDailyNutritionLog` / `getWorkoutForDay` / `getTrainingDays`.

**Root cause**

The "Answer data questions only through a query tool" block in the system prompt (`voice-chat/index.ts`) enumerated only three tools: `getRecentSets`, `getWeeklyVolume`, `getDailyMacros`. The three day-scoped query tools (`getDailyNutritionLog`, `getWorkoutForDay`, `getTrainingDays`) were absent from that rule and from the parallel tool-usage bullet. The model treated the recent-sets/-logs context slots as the authoritative record for day-specific questions because nothing told it otherwise, and no rule forced a tool call for those queries. A second gap: nothing stated that the recent context is a truncated hint — the model could legitimately infer "the context is exhaustive; therefore nothing was logged."

**Workaround / fix**

Added all six query tools to the must-call rule and the tool-usage bullet. Added an explicit statement: "The recent sets/logs above are a **truncated hint** (a few recent rows), **not** the user's full history. NEVER conclude that something was not logged, or answer any 'what did I log / eat / lift on <day>' question, from that list. You MUST call the matching query tool and let the client speak the result." Requires a `Supabase Deploy` (functions target) to take effect on the self-hosted VPS (manual rsync of `_shared` + `voice-chat` to the docker volume, then `docker restart supabase-edge-functions`).

**References**

- `supabase/functions/voice-chat/index.ts` — "Answer data questions only through a query tool" block and tool-usage query rule
- PR `#149` — fix: force query tool for day-scoped data; frame recent context as hint

---

### voice-nutrition-query-spoke-calories-without-macros

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-11
- **Last verified:** 2026-06-11
- **Area:** voice

**Symptom**

Voice bot spoke only meal name and calories for `getDailyNutritionLog` results (e.g. "You logged: Chicken Breast, 313 calories."). A follow-up macro question ("how many protein?") was refused with "I only handle logging and your own stats." — even though macros were stored on the entity.

**Root cause**

Two layers. **A (client):** `_queryDailyNutritionLog` in `voice_bloc.dart` formatted each row as `'${l.mealName}, ${l.calories.round()} calories'`, discarding `proteinGrams`, `carbsGrams`, and `fatGrams`. With no macros in the spoken output or conversation history, the model had no data to answer a follow-up. **B (prompt):** The system prompt's nutrition-recommendation refusal rule had no carve-out for macros of meals the user already logged, so the model classified "how many protein does it contain?" as generic dietary advice and refused. See `[[voice-logged-meal-macros-are-retrievable-not-advice]]` (Commit 4) for the prompt fix.

**Workaround / fix**

Extracted a `_nutritionLineFor(NutritionLog l)` helper that voices all three macros including zeros (e.g. "0g carbs"). `_queryDailyNutritionLog` now delegates to this helper. With macros present in the spoken output and history, macro follow-ups are answered from context — the refusal trigger disappears without requiring the prompt carve-out. The helper is reused by `_queryRecentNutrition` (Commit 3, see `[[voice-most-recent-nutrition-had-no-cross-day-query-tool]]`). Client-only fix; no Supabase deploy required.

**References**

- `lib/features/voice/application/voice_bloc.dart` — `_nutritionLineFor`, `_queryDailyNutritionLog`
- `lib/domain/entities/nutrition_log.dart:11-13` — `proteinGrams`, `carbsGrams`, `fatGrams`
- `[[voice-logged-meal-macros-are-retrievable-not-advice]]` — prompt carve-out (Commit 4)
- `[[voice-most-recent-nutrition-had-no-cross-day-query-tool]]` — cross-day query tool (Commit 3)

---

### voice-most-recent-nutrition-had-no-cross-day-query-tool

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-11
- **Last verified:** 2026-06-11
- **Area:** voice

**Symptom**

"Tell me my latest worked nutritions" / "what's my most recent nutrition" → "Nothing has been logged for that day yet." The same session correctly answered "show me my recent sets" — exercise queries had a cross-day path, nutrition did not.

**Root cause**

The exercises path has `getRecentSets` → client `_queryRecentSets` over a 30-day window. The only nutrition query tools were `getDailyNutritionLog` and `getDailyMacros`, both single-day, both resolving through `_resolveQueryDate` (defaulting to today / last-referenced day). When the user asked for "latest / most recent nutrition," the model's only nutrition option was `getDailyNutritionLog` — which resolved to today, found nothing, and spoke `voiceQueryNothingLogged`.

**Workaround / fix**

Added a `getRecentNutrition` tool mirroring `getRecentSets`: server `ToolDefinition` next to `getRecentSets`, added to `TOOL_REGISTRY` and `QUERY_TOOLS`, enumerated in both query-tool prompt blocks in `voice-chat/index.ts`. Client handler `_queryRecentNutrition` calls `_getLogsByDateRange` over a 30-day window (the datasource orders newest-first via `nutritionLogCreatedAt DESC`, so `.take(limit)` keeps the most recent), reuses `_nutritionLineFor` from `[[voice-nutrition-query-spoke-calories-without-macros]]` so macros are voiced for the recent path too. Default `limit` 5. Three new AppStrings (`voiceQueryRecentNutritionUnavailable`, `voiceQueryNoRecentNutrition`, `voiceQueryRecentNutritionResult`). Requires a `Supabase Deploy` (functions target) for the server changes to take effect on the self-hosted VPS (manual rsync of `_shared` + `voice-chat` to the docker volume, then `docker restart supabase-edge-functions`).

**References**

- `supabase/functions/_shared/tools.ts` — `getRecentNutrition`, `TOOL_REGISTRY`, `QUERY_TOOLS`
- `supabase/functions/voice-chat/index.ts` — must-call query-tool block + tool-usage bullet
- `lib/features/voice/application/voice_bloc.dart` — `_executeQueryTool` dispatch + `_queryRecentNutrition`
- `lib/core/constants/app_strings.dart` — three new recent-nutrition strings
- `[[voice-nutrition-query-spoke-calories-without-macros]]` — shared `_nutritionLineFor` formatter

---

### voice-logged-meal-macros-are-retrievable-not-advice

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-11
- **Last verified:** 2026-06-11
- **Area:** voice

**Symptom**

A follow-up question about macros of a meal the user had already logged ("how many protein does it contain?") was refused with "I only handle logging and your own stats." — even though the macros were available and had been spoken by the client (after Commit 1).

**Root cause**

The system prompt's nutrition-recommendation refusal rule ("You MUST refuse… nutrition recommendations") had no carve-out distinguishing *generic dietary advice* from *retrieval of the user's own logged data*. With no carve-out, the model classified "how many protein in my logged meal?" as generic dietary advice and refused. The `getDailyNutritionLog`, `getRecentNutrition`, and `getDailyMacros` tools can retrieve this data, but the model did not attempt them.

**Workaround / fix**

Added a narrowly-scoped carve-out sentence immediately after the example refusal in `SYSTEM_PROMPT_TEMPLATE` (`voice-chat/index.ts`): reporting macros/calories/contents of a meal the user already logged is retrieving their own data, NOT a nutrition recommendation — answer via the nutrition query tools. Generic nutrition facts and dietary advice for foods the user did not log remain refused. Belt-and-suspenders alongside Commit 1's `_nutritionLineFor`, which seeds macros into conversation history so follow-up questions are often answerable from context without a tool call. Requires a `Supabase Deploy` (functions target) for the server-side prompt change to take effect on the self-hosted VPS (manual rsync of `_shared` + `voice-chat` to the docker volume, then `docker restart supabase-edge-functions`). Deploy shared with Commit 3 (`[[voice-most-recent-nutrition-had-no-cross-day-query-tool]]`).

**References**

- `supabase/functions/voice-chat/index.ts` — `SYSTEM_PROMPT_TEMPLATE` refusal rule carve-out
- `[[voice-nutrition-query-spoke-calories-without-macros]]` — Commit 1, client-side macro formatter
- `[[voice-most-recent-nutrition-had-no-cross-day-query-tool]]` — Commit 3, shared deploy

---

### voice-recent-nutrition-tool-was-misclassified-as-mutation-on-client

- **Severity:** High
- **Status:** Resolved-but-monitor
- **First observed:** 2026-06-11
- **Last verified:** 2026-06-11
- **Area:** voice

**Symptom**

"What's my most recent nutrition?" → spoken "I can't do that yet." with no assistant bubble in the transcript. The backend demonstrably called `getRecentNutrition` correctly; the failure was entirely on the client side.

**Root cause**

`SupabaseVoiceRemoteDataSource.parseResult` classifies tool calls using a hardcoded `queryTools` set. PR #153 added `getRecentNutrition` to the server `TOOL_REGISTRY`, the prompt, and the `VoiceBloc._executeQueryTool` dispatch case — but not to this client-side set. The tool fell through to `VoiceChatMutationCall`, then hit the `_knownMutationTools` fail-closed gate (which also does not list it), and spoke `voiceSpokenUnsupportedAction`. The `_queryRecentNutrition` handler was reachable dead code for the lifetime of #153.

**Workaround / fix**

Added `'getRecentNutrition'` to the `queryTools` set in `parseResult`. Added a table-driven test iterating all seven query-tool names and asserting each parses to `VoiceChatQueryCall` — this test IS the cross-layer contract; a future omission will fail CI immediately. No backend change, no deploy required.

**References**

- `lib/data/datasources/remote/supabase_voice_remote_datasource.dart` — `queryTools` set in `parseResult`
- `test/data/datasources/remote/supabase_voice_remote_datasource_test.dart` — seven-tool contract test
- `lib/features/voice/application/voice_bloc.dart:1686` — `_executeQueryTool` dispatch (was already correct)
- `[[voice-most-recent-nutrition-had-no-cross-day-query-tool]]` — #153 that shipped the tool server-side

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

A `State<…>` subclass field-captures a factory-registered BLoC or Cubit from `sl<>()` (typically in `initState` or as a `late final` field). `get_it.registerFactory` returns a **new instance** on every call, so the field-captured instance is different from whatever `BlocProvider` higher in the widget tree provides. Any state the field instance emits is invisible to consumers reading via `context.read`/`context.watch`. This was the root cause of the original silent-dispatch bug fixed in PR `#58` (`VoiceBloc` field-captured target BLoCs) and of the `BottomNavigation` instance multiplication fixed in the voice-foundation PR (`VoiceSettingsCubit` field-captured from `sl<>()` alongside three other concurrent `BlocProvider` sites).

**Workaround / fix**

Never declare a BLoC or Cubit as a widget-state field (`final XxxBloc _x;`, `late final XxxCubit _x;`). Read it lazily inside `build`/`didChangeDependencies` via `context.read<XxxBloc>()` or `context.watch<XxxCubit>()`. If the widget genuinely needs a constructor-injected BLoC (e.g. for test injection), declare the parameter on the `StatefulWidget` itself, not on the `State<…>` subclass. The `widget-state-bloc-field` convention rule enforces this default-deny; legitimate exceptions waive with `// convention-checker:allow=widget-state-bloc-field reason=<at-least-10-character-prose>`.

**References**

- `tool/convention_rules/widget_state_bloc_field.dart` — the rule
- `test/tool/widget_state_bloc_field_test.dart` — multi-line test fixtures
- `lib/injection/modules/register_voice_module.dart` — `VoiceSettingsCubit` factory registration
- Voice-foundation PR — added the rule; removed the `BottomNavigation` field capture

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

### voice-slider-persists-on-every-drag-tick

- **Severity:** Low
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-14
- **Last verified:** 2026-05-23
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

---

### cross-feature-presentation-imports-are-architectural-cycles

- **Severity:** Medium
- **Status:** Resolved-but-monitor
- **First observed:** 2026-05-21
- **Last verified:** 2026-05-23
- **Area:** other

**Symptom**

A presentation file under `lib/features/<F1>/presentation/` imports a page or widget from `lib/features/<F2>/presentation/` (or worse, from `lib/features/<F2>/application/` or `data/`). The build compiles; tests pass; but the feature dependency graph silently grows cycles. Removing or renaming any one feature breaks an unrelated feature in a non-local way. Pre-foundation-PR, three offenders existed: `settings_page.dart` → profile/voice, `profile_page.dart` → auth/settings/voice, `home_page.dart` → profile.

**Root cause**

Flutter's default navigation pattern — `Navigator.push(context, MaterialPageRoute(builder: (_) => SomePage()))` — requires the caller to import the destination page class directly. Done from inside another feature, that import couples the two features at compile time and creates a cycle the moment the destination ever needs anything from the source. The `presentation-layer-data-import` convention rule blocks `presentation → data`, but until the foundation PR there was no rule blocking `presentation → presentation` across feature boundaries.

**Workaround / fix**

Use a named-route registry. All page classes are imported once in `lib/app/routes/app_router.dart` (the only file granted an exception to the rule); every other navigation site uses `Navigator.pushNamed(context, AppRoutes.foo)` with a route constant from `lib/app/routes/app_routes.dart`. The `cross-feature-presentation-import` convention rule enforces the default-deny. Legitimate exceptions waive with `// convention-checker:allow=cross-feature-presentation-import reason=<at-least-10-character-prose>`.

**References**

- `tool/convention_rules/cross_feature_presentation_import.dart` — the rule
- `test/tool/cross_feature_presentation_import_test.dart` — multi-line test fixtures
- `lib/app/routes/app_routes.dart` — route constants
- `lib/app/routes/app_router.dart` — `onGenerateRoute` registry
- Voice-foundation PR — added the rule, the registry, and migrated the three offenders

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

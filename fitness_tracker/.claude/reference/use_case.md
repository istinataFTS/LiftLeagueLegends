# Canonical example — Use case

- **Pattern:** Use case
- **Canonical file:** `lib/domain/usecases/workout_sets/add_workout_set.dart`
- **Locked by:** commit `5042902` — fatigue fix that last touched the use-case chain; class shape has been stable since
- **Last verified:** 2026-05-21
- **Related references:** [[repository]], [[bloc]], [[injection_module]]
- **Companion playbook:** _(to be added by Adoption 05: `.claude/skills/add-use-case.md`)_
- **Embodied conventions:**
  - A use case is pure domain: no Flutter imports, no `sqflite`, no Supabase — see CLAUDE.md "Flutter app — Clean Architecture"
  - The single public entry point is `call(Params)`, making the use case callable as a function — standard `flutter_bloc`-friendly contract
  - Returns `Either<Failure, T>` — never throws — see CLAUDE.md "Error handling"
  - The constructor is `const` — use cases are stateless
  - Side effects that must happen after a successful write (e.g. stimulus rebuild) are chained inside `call`, not delegated to the BLoC — keeps the BLoC ignorant of invariants it should not need to know

---

## Why this is the canonical

`AddWorkoutSet` is a representative use case because it shows the full pattern including session resolution and a post-write side effect — the two things a developer is most likely to need when adding a new write use case. A simpler use case (like `DeleteWorkoutSet` or `GetWeeklySets`) is easier to read but teaches less. A new contributor who understands `AddWorkoutSet` can trivially write any simpler use case; the reverse is not always true.

Note: not every use case needs session resolution. If a use case only reads or if the owner ID is already embedded in the entity, skip the session fold. The principle is: do the minimum domain work required; never reach into the DI container or call platform APIs.

---

## Walkthrough

### Class declaration and fields (lines 9–13)

`add_workout_set.dart:9-13` — Three `final` fields: the repository (primary data dependency) and two cross-cutting collaborators (`AppSessionRepository` for auth context, `RebuildMuscleStimulusFromWorkoutHistory` for the post-write side effect). Use cases can depend on other use cases — the muscle-stimulus rebuild is itself a use case. This is fine; the dependency graph stays within the domain layer.

### `const` constructor (lines 15–19)

`add_workout_set.dart:15-19` — The positional parameter is the repository; collaborators are named. This is the conventional shape: the primary data repository is positional (mirrors the repository interface it uses), extras are named. The constructor is `const` because use cases hold only references — they have no mutable state.

### `call()` — session resolution pattern (lines 21–37)

`add_workout_set.dart:21-37` — `AppSessionRepository.getCurrentSession()` returns `Either<Failure, AppSession>`. The use case folds on it twice: once to extract the `userId` for downstream side effects, and once to produce a `preparedSet` with the correct `ownerUserId`. The fold's left branch returns the original value (no owner means guest; the write still proceeds). This is the canonical way to read session state from the domain layer — never inject `CurrentUserIdResolver` directly into a use case; that belongs at the datasource layer.

### `call()` — write and chained side effect (lines 39–48)

`add_workout_set.dart:39-48` — `repository.addSet(preparedSet)` returns `Either<Failure, void>`. The fold on its result either propagates the failure or chains the side effect. The side effect (`rebuildMuscleStimulusFromWorkoutHistory`) is also a use case and also returns `Either<Failure, void>`. Returning its result directly means the caller sees a failure if the rebuild fails — consistent with the principle that the caller is responsible for handling domain errors.

The comment on line 43 explains *why* a full rebuild rather than an incremental update is used. Always leave an explanatory comment when a non-obvious choice was made; the BLoC and future maintainers need this context.

---

## Before you copy this

- [ ] **No Flutter or platform imports.** `lib/domain/` must not import from `lib/features/`, `lib/data/`, or any Flutter SDK widget. Only `dart:core`, `dartz`, and other domain-layer types.
- [ ] **`call()` is the only public method** (or `call(Params)` if you need typed params). Use cases are callable objects — one responsibility, one entry point.
- [ ] **Return `Either<Failure, T>`.** Never throw from a use case; wrap all exceptions at the repository layer below.
- [ ] **Make the constructor `const`** unless you genuinely need non-const initialisation. Use cases are stateless.
- [ ] **Chain side effects inside `call()`, not in the BLoC.** If the write invariant requires a follow-up operation (e.g. rebuilding derived data), do it here. The BLoC should not know about domain invariants.
- [ ] **Do not inject `CurrentUserIdResolver` into a use case.** Session-aware reads belong at the datasource layer (`resolveOwnerId()`). If you need the user ID in a use case, read it from `AppSessionRepository` the same way this use case does.
- [ ] **Register as `registerLazySingleton` in the DI module.** See [[injection_module]] and KNOWN_ISSUES.md `blocs-must-be-factories-repositories-singletons`.

---

## If you change the pattern

If the use-case contract changes — for example, session resolution moves to a shared base class, or `Either` is replaced — update this file in the same PR and update the companion playbook in `.claude/skills/`.

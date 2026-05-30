# Canonical example — Repository implementation

- **Pattern:** Repository implementation
- **Canonical file:** `lib/data/repositories/workout_set_repository_impl.dart`
- **Locked by:** commit `810bcbe` — offline-resilience fix that introduced `_tryRemoteFetch` and hardened all four `DataSourcePreference` paths
- **Last verified:** 2026-05-30
- **Related references:** [[datasource]], [[use_case]], [[injection_module]]
- **Companion playbook:** _(to be added by Adoption 05: `.claude/skills/add-feature.md`)_
- **Embodied conventions:**
  - Every repository method returns `Either<Failure, T>` and every call body is wrapped in `RepositoryGuard.run(() async { ... })` — see CLAUDE.md "Error handling"
  - Remote failures on read paths are caught and logged, never propagated — see KNOWN_ISSUES.md `per-entity-sync-failures-need-underlying-cause-logged`
  - Write paths delegate to a `SyncCoordinator`, never to the local datasource directly — see CLAUDE.md "Data / sync architecture"
  - `DataSourcePreference` makes the offline-first strategy explicit at every call site; callers pick a strategy, not a datasource
  - The repository is registered as `registerLazySingleton<Interface>` — see KNOWN_ISSUES.md `blocs-must-be-factories-repositories-singletons`
  - The constructor is `const` — repositories are stateless; any mutable state belongs in a datasource or a sync coordinator

---

## Why this is the canonical

`WorkoutSetRepositoryImpl` is the canonical repository example because it demonstrates every read strategy in `DataSourcePreference` in a single, small file (250 lines), and it was the first repository hardened with the `_tryRemoteFetch` offline-resilience pattern (commit `810bcbe`). It also illustrates the clean separation of concerns between the repository (decides *what* data to return and from where) and the sync coordinator (decides *how* to persist writes and queue sync operations). All write methods are three-line delegates to the coordinator — there is no sync logic embedded in the repository itself.

The inclusion of `_tryRemoteFetch` as a `static` helper that catches specific remote exception types and logs warnings — instead of propagating them — is the pattern that allows the app to stay usable offline without every call site needing its own catch block.

---

## Walkthrough

### Constructor and dependencies (lines 15–31)

`workout_set_repository_impl.dart:15-31` — Three injected dependencies: `localDataSource`, `remoteDataSource`, `syncCoordinator`. Each is `final` and injected via the constructor; no `get_it` lookups inside the impl. The constructor is marked `const` because the repository holds no mutable state — everything is delegated to its dependencies. Use `const` on your constructor unless the repository genuinely needs non-const initialization.

`workout_set_repository_impl.dart:20-25` — `LocalRemoteMerge` is a `static final` field, not an instance field, because it is stateless. See the same pattern in the canonical datasource.

### The `RepositoryGuard.run` wrapper (lines 34–40, 43–96)

`workout_set_repository_impl.dart:34-40` — Every public method returns the result of `RepositoryGuard.run(() async { ... })` directly. There is no `try/catch` in the repository; `RepositoryGuard.run` handles all exceptions and maps them to `Failure` subtypes via `RepositoryErrorMapper`. Never wrap with `try/catch` instead — it would bypass the error-mapping logic and potentially leak raw exceptions.

`workout_set_repository_impl.dart:43-45` — Notice that `getSetById` also wraps in `RepositoryGuard.run`. No method is exempt. Even single-line delegates go through the guard because a datasource exception from `localDataSource.getSetById(id)` must still be caught and mapped.

### `DataSourcePreference` switch pattern (lines 43–96)

`workout_set_repository_impl.dart:43-96` — `getSetById` is the most complete example of the `DataSourcePreference` switch. Four cases:
- `localOnly` — query local, never touch remote.
- `remoteOnly` — check `remoteDataSource.isConfigured` before calling, return `null` if not configured.
- `localThenRemote` — return local if present, fallback to remote and upsert if local misses.
- `remoteThenLocal` — fetch both, merge with `LocalRemoteMerge.chooseWinner`, persist the winner.

The `remoteDataSource.isConfigured` guard must appear before every remote call. Calling an unconfigured remote datasource does not crash (the noop impl returns empty results) but is wasteful and hides misconfiguration bugs.

### Write path delegation to `SyncCoordinator` (lines 134–159)

`workout_set_repository_impl.dart:134-159` — `addSet`, `updateSet`, `deleteSet`, and `syncPendingSets` each contain a single line inside `RepositoryGuard.run`. The repository does not touch the local datasource for writes; that is the sync coordinator's job. This separation keeps the repository from accumulating sync logic and keeps the sync coordinator independently testable. If your repository writes directly to `localDataSource` for a mutable operation, that is a code smell — route it through a sync coordinator.

### `_readAllSets` internal helper (lines 168–219)

`workout_set_repository_impl.dart:168-219` — Multiple public list-read methods (`getAllSets`, `getSetsByExerciseId`, `getSetsByDateRange`) delegate to `_readAllSets`. Extracting the four-case switch into a private method prevents the switch from being repeated and ensures all read methods respect the same data-source strategy logic. Name your equivalent helper `_readAll<Entity>` to follow the convention.

### `_tryRemoteFetch` — offline-resilient remote reads (lines 221–249)

`workout_set_repository_impl.dart:221-249` — This `static` helper catches three specific remote exception types (`AuthSyncException`, `NetworkSyncException`, `RemoteSyncException`), logs a warning at the `'<feature>_repository'` category, and returns `null`. The caller treats `null` as "remote unavailable; use local cache." Non-remote exceptions (e.g. a local database failure) are *not* caught here and propagate up through `RepositoryGuard.run` as real errors.

Key points:
1. It is `static` — it needs no instance state.
2. It accepts a `Future<List<T>> Function()` rather than the result directly — it wraps the invocation, not the value.
3. The `context` string names the call site (`'getAllSets(localThenRemote)'`) so logs are traceable without stack parsing.
4. It never logs at `error` level for transient network failures — that would trigger alerting for expected offline scenarios.

---

## Before you copy this

- [ ] **Every method returns `Either<Failure, T>` via `RepositoryGuard.run`.** No raw `Future<T>` return types. No `try/catch` inside the repository.
- [ ] **Write operations go to the sync coordinator, not the local datasource.** If you find yourself calling `localDataSource.addX(...)` directly for a user-initiated write, introduce a sync coordinator.
- [ ] **Guard every remote call with `remoteDataSource.isConfigured`.** The app runs offline-first; an unconfigured remote must be a silent no-op on read paths.
- [ ] **Extract the `DataSourcePreference` switch into a private `_readAll*` helper** when two or more public methods share the same four-case logic.
- [ ] **Use `_tryRemoteFetch` (or an equivalent) for reads that have a local fallback.** Never let a `NetworkSyncException` or `AuthSyncException` escape a read path as a `Failure` — that turns a connectivity blip into a visible error screen.
- [ ] **Make the constructor `const`** unless you genuinely need non-const initialization. Repositories are stateless coordinators.
- [ ] **Register as `registerLazySingleton<InterfaceType>` in the DI module**, not `registerFactory`. See [[injection_module]] and KNOWN_ISSUES.md `blocs-must-be-factories-repositories-singletons`.
- [ ] **The interface belongs in `lib/domain/repositories/`.** The impl belongs in `lib/data/repositories/`. Keep them separate — the domain layer must never import from `lib/data/`.

---

## If you change the pattern

If the canonical shape changes — for example, `RepositoryGuard.run` gains a new parameter, `DataSourcePreference` gains a new case, or the sync-coordinator separation pattern changes — update this file in the same PR and update the companion playbook in `.claude/skills/`. Notify in the PR description so reviewers can check for non-obvious call-site impacts across other repositories.

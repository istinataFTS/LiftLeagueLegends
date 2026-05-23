# Canonical example — Injection module

- **Pattern:** Feature DI module (`register_*_module.dart`)
- **Canonical file:** `lib/injection/modules/register_workout_module.dart`
- **Locked by:** commit `c0a2c7f`, PR `#58` — fixed `WorkoutBloc` from `registerLazySingleton` to `registerFactory`, putting the module in the correct canonical shape
- **Last verified:** 2026-05-23
- **Related references:** [[datasource]], [[repository]], [[use_case]], [[bloc]]
- **Companion playbook:** _(to be added by Adoption 05: `.claude/skills/add-feature.md`)_
- **Embodied conventions:**
  - BLoCs and Cubits use `registerFactory`; everything else uses `registerLazySingleton` — see KNOWN_ISSUES.md `blocs-must-be-factories-repositories-singletons` and CLAUDE.md "State management"
  - Repository and datasource registrations are typed: `registerLazySingleton<Interface>(() => Impl(...))` — callers resolve the interface, not the concrete type
  - The local datasource receives `currentUserIdResolver: sl()` (never `appSessionRepository: sl()`) — see CLAUDE.md "User-scoped local datasources"
  - Remote datasource selection is runtime-gated via `RemoteSyncRuntimePolicy` — the module never reads `EnvConfig` directly
  - A sync coordinator owns the write path; it is wired up separately from the repository — see [[repository]]
  - No async work, no side effects inside the module function — `registerLazySingleton` factories are lazy by definition

---

## Why this is the canonical

`register_workout_module.dart` is the canonical module because it wires up the fullest stack in the codebase: local datasource, remote datasource (with env-gate), sync coordinator, repository, six use cases, and the BLoC. Every registration pattern used anywhere in the app appears at least once in this file. After PR `#58` it also correctly demonstrates `registerFactory` for the BLoC, closing the last convention gap.

**One important exception to be aware of:** `AppSettingsCubit` in `register_settings_module.dart` is intentionally registered as `registerLazySingleton` because its state must be shared across the Settings page and `VoiceSettingsCubit`. This is the only BLoC/Cubit in the codebase exempt from the factory rule. Every other BLoC and Cubit must use `registerFactory`.

### Cubits that mirror persistent settings subscribe to a repository stream, never to another cubit

When two cubits hold overlapping slices of the same persisted state — e.g. `AppSettingsCubit` owns the full `AppSettings` and `VoiceSettingsCubit` mirrors the `voiceSettings` slice — the dependent cubit must subscribe to the **owning repository's** `Stream<T>`, not to the other cubit's state stream. The canonical example is `VoiceSettingsCubit`: it depends on `AppSettingsRepository.watchSettings()` and emits when the broadcast stream replays a fresh value. It does **not** import `AppSettingsCubit`.

Why: a cross-cubit subscription creates a cross-feature application-layer import and forces both cubits into the same lifecycle assumptions (or, worse, requires a singleton to keep them coherent). A repository-stream subscription keeps the dependency arrow pointing into the domain layer, lets either cubit be a `registerFactory`, and removes the need for one cubit to know the other exists. If you see a cubit constructor that takes another cubit, refactor it to take the repository (and have the repository expose a `Stream<T>` with behaviour-subject semantics — replay the last cached value on subscribe, then emit again after each successful write).

The convention rule `cross-feature-presentation-import` does not catch application-layer cross-cubit imports today. Treat this rule as informal until/unless it gets enforced; for now, it is a review-time check.

---

## Walkthrough

### BLoC registration — `registerFactory` (lines 23–30)

`register_workout_module.dart:23-30` — `WorkoutBloc` is the only registration in this file that uses `registerFactory`. No type argument is needed because `WorkoutBloc` has no interface; the BLoC is resolved by its concrete type. The three use-case dependencies (`sl()`) resolve lazily from the singletons registered later in the same function — `get_it` resolves registrations at call time, not at registration time, so order within the function does not matter.

### Use-case registrations — `registerLazySingleton` (lines 32–65)

`register_workout_module.dart:32-65` — Each use case is `registerLazySingleton` with no type argument (the concrete class is also the type). Note that several use cases (`AddWorkoutSet`, `DeleteWorkoutSet`, `UpdateWorkoutSet`) share the same two cross-cutting dependencies — `appSessionRepository: sl()` and `rebuildMuscleStimulusFromWorkoutHistory: sl()`. These are wired once in the relevant module; each use case simply receives them. Never reach outside the module's feature boundary to wire a dependency that belongs to a different feature — cross-feature dependencies are resolved through `sl()` from a module that owns the registration.

### Repository registration — typed interface (lines 67–73)

`register_workout_module.dart:67-73` — `registerLazySingleton<WorkoutSetRepository>(() => WorkoutSetRepositoryImpl(...))`. The type argument `<WorkoutSetRepository>` is the domain interface; the factory creates the data-layer impl. All call sites that request `sl<WorkoutSetRepository>()` receive the impl without knowing its concrete type. This is the correct pattern for every repository — always register the interface, never the impl.

### Sync coordinator and local datasource — typed interface (lines 75–88)

`register_workout_module.dart:75-88` — `WorkoutSetSyncCoordinator` and `WorkoutSetLocalDataSource` follow the same typed-interface pattern. Note line 85–87: the local datasource impl receives `databaseHelper: sl()` and `currentUserIdResolver: sl()` — these are the two `super` parameters required by `UserScopedLocalDatasource`. Never pass `appSessionRepository: sl()` to a local datasource; Adoption 02 replaced that pattern with the base class resolver.

### Remote datasource — runtime env gate (lines 90–98)

`register_workout_module.dart:90-98` — The remote datasource is selected at registration time using `sl<RemoteSyncRuntimePolicy>().isRemoteSyncConfigured`. If Supabase is not configured (`ENABLE_SUPABASE=false`), the noop impl is registered. This is the canonical env-gate pattern: the module reads the policy object, not `EnvConfig` directly. Never call `EnvConfig.enableSupabase` inside a module — that would bypass the policy abstraction and make the module untestable in isolation.

---

## Before you copy this

- [ ] **BLoC/Cubit → `registerFactory`. Everything else → `registerLazySingleton`.** There is one intentional exception: `AppSettingsCubit` is a singleton. Every other BLoC you register must be a factory.
- [ ] **Type-annotate every repository and datasource registration**: `registerLazySingleton<InterfaceType>(() => ImplType(...))`. Callers depend on the interface, not the impl.
- [ ] **Pass `currentUserIdResolver: sl()` to every user-scoped local datasource impl**, not `appSessionRepository: sl()`. See [[datasource]] and CLAUDE.md "User-scoped local datasources".
- [ ] **Use `RemoteSyncRuntimePolicy` for the remote datasource env gate**, not `EnvConfig` directly.
- [ ] **Do not call `await` or perform side effects inside the module function.** `registerLazySingleton` factories are evaluated lazily; async work in the registration factory will cause unpredictable initialisation order. If async initialisation is needed, await it in `injection_container.dart` before calling module registration functions — see KNOWN_ISSUES.md `fire-and-forget-futures-in-startup-cause-race-conditions`.
- [ ] **Guard cross-module shared registrations with `if (!sl.isRegistered<T>())`** if the same type is registered in more than one module path. See KNOWN_ISSUES.md `duplicate-di-registration-causes-silent-bugs`.
- [ ] **The module function receives `GetIt sl` as a parameter** — do not call `GetIt.instance` or `locator` inside the module. The parameter is the canonical handle.

---

## If you change the pattern

If the DI wiring contract changes — for example, `registerFactory` is replaced by a scoped lifetime, or the env-gate policy API changes — update this file in the same PR and update the companion playbook in `.claude/skills/add-feature.md`.

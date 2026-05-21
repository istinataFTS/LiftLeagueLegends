# Canonical example — BLoC

- **Pattern:** BLoC (Business Logic Component)
- **Canonical file:** `lib/features/log/application/workout_bloc.dart`
- **Locked by:** commit `5042902` — last substantial shape change; `BlocEffectsMixin` wiring and the `_loadWeeklySetsData` helper were both in place at this commit
- **Last verified:** 2026-05-21
- **Related references:** [[use_case]], [[bloc_test]], [[injection_module]]
- **Companion playbook:** _(to be added by Adoption 05: `.claude/skills/add-bloc-effect.md`)_
- **Embodied conventions:**
  - BLoCs are registered as `registerFactory` — one fresh instance per page, disposed on pop — see KNOWN_ISSUES.md `blocs-must-be-factories-repositories-singletons` and CLAUDE.md "State management"
  - One-shot side effects (snackbars, navigation) are emitted via `BlocEffectsMixin`, never via `BuildContext` inside the BLoC — see CLAUDE.md "State management"
  - Events, states, effects, and the BLoC class all live in the same file for small-to-medium features
  - All state and event classes extend `Equatable` and declare `props` — required for `bloc_test` value assertions
  - Event handlers are private methods (`_onEventName`) registered in the constructor; no inline lambdas in `on<>()`
  - Load vs refresh share a private helper; the difference is only whether `WorkoutLoading` is emitted first

---

## Why this is the canonical

`WorkoutBloc` is the canonical BLoC because it demonstrates three things that every feature BLoC must eventually handle: a plain data-load path, a write path with a downstream side effect (muscle stimulus), and a one-shot UI notification via `BlocEffectsMixin`. Together they exercise the full `flutter_bloc` + effects contract used across the codebase. At 190 lines it is also small enough to read without losing context, yet representative enough to generalise from.

---

## Walkthrough

### Events (lines 12–35)

`workout_bloc.dart:12-35` — All events `extend Equatable` and declare `props`. `WorkoutEvent` is the sealed base; concrete events are defined in the same file. The `const` constructors on leaf events are important — `bloc_test`'s `act` and `expect` comparisons rely on value equality. An event without `const` or with a missing `props` entry will produce hard-to-diagnose test failures where identical-looking events are not equal.

### States (lines 36–64)

`workout_bloc.dart:36-64` — Same shape as events. `WorkoutState` is the sealed base. Every state with a payload (`WorkoutLoaded`, `WorkoutError`) declares that payload in `props`. `WorkoutInitial` and `WorkoutLoading` carry no payload and use the default empty `props` from the base class. Do not add fields to a state and forget to add them to `props` — the state change will appear correct but `bloc_test` `expect` assertions will fail silently.

### Effect types (lines 65–84)

`workout_bloc.dart:65-84` — Effects are plain Dart classes, not `Equatable`. They are one-shot: emitted once, consumed once, not stored in the state. `WorkoutUiEffect` is the sealed base; `WorkoutLoggedEffect` carries the snackbar message and the set of affected muscle names. Effects must never replace state — they are for fire-and-forget UI signals (snackbars, navigation, toasts) that have no meaning after they are consumed.

### Class declaration and constructor (lines 86–102)

`workout_bloc.dart:86-102` — `WorkoutBloc extends Bloc<WorkoutEvent, WorkoutState> with BlocEffectsMixin<WorkoutState, WorkoutUiEffect>`. The `with BlocEffectsMixin` clause is the entire effects wiring — it gives the class `emitEffect(effect)` and exposes `bloc.effects` as a `Stream`. The constructor registers each event type with a private handler via `on<EventType>(_handler)`. Never pass a lambda directly to `on<>` — extract a method so the handler is named and independently testable.

### Write handler with effect (lines 104–154)

`workout_bloc.dart:104-154` — `_onAddWorkoutSet` is the canonical write-path handler. Sequence:
1. `emit(WorkoutLoading())` — optimistic loading state.
2. Await the use case; fold on the result.
3. On failure: `emit(WorkoutError(failure.message))` — done, no effect.
4. On success: compute UI-display data (muscle groups), reload the list via `_loadWeeklySetsData`, then `emitEffect(WorkoutLoggedEffect(...))`.

The effect is emitted **after** the state update (line 143 before 145), so the widget has already re-rendered with fresh data before the snackbar appears. Reversing this order can cause a flash of stale data behind the snackbar.

`workout_bloc.dart:127-136` — Note the non-fatal muscle-stimulus calculation: a `calculateMuscleStimulus` failure yields an empty list and logs a warning; it does not fail the whole handler. Distinguish between errors that must abort the flow (write failure) and errors that are tolerable degradations (display enrichment failure).

### Load vs refresh pattern (lines 156–168)

`workout_bloc.dart:156-168` — `_onLoadWeeklySets` calls the helper with `showLoading: true`; `_onRefreshWeeklySets` calls it without. This is the correct distinction: an initial load shows a spinner (the user has nothing to see yet); a refresh does not (the user can see the previous data while new data loads). Both share identical data-fetching logic — they differ only in UX.

### Shared data-load helper (lines 170–187)

`workout_bloc.dart:170-187` — `_loadWeeklySetsData` is the private method both load and refresh handlers call. Extract any async data-fetch sequence used by more than one handler into a private helper. This prevents subtle divergences between code paths and makes the individual handlers trivial to read.

`workout_bloc.dart:183` — `_cachedWeeklySets = sets` stores the last-seen list for the `cachedWeeklySets` getter (line 189). The cache is updated inside the BLoC, not inside a state subclass. This is intentional: the cache is a transient implementation detail that helps UI layers avoid rebuilds when sets do not change; it is not part of the state contract.

---

## Before you copy this

- [ ] **Register as `registerFactory`, not `registerLazySingleton`.** See [[injection_module]] and KNOWN_ISSUES.md `blocs-must-be-factories-repositories-singletons`.
- [ ] **Every event and state must extend `Equatable` and declare all payload fields in `props`.** Omitting a field from `props` silently breaks test equality assertions.
- [ ] **Effects are not states.** An effect is a fire-and-forget UI signal. If you need to persist information across rebuilds, it belongs in the state.
- [ ] **`emitEffect(...)` after `emit(newState)`.** The widget should re-render with fresh state before the side effect (snackbar, navigation) fires.
- [ ] **Register each event with `on<EventType>(_privateMethod)` in the constructor.** No inline lambdas — named handlers are independently testable and readable.
- [ ] **Distinguish fatal from tolerable errors.** A write failure aborts and emits `WorkoutError`. A display-enrichment failure (like muscle stimulus) logs a warning and degrades gracefully — it does not abort the whole handler.
- [ ] **Extract shared async sequences into private helpers** (`_loadWeeklySetsData`). If two handlers fetch the same data, one copy is the rule.
- [ ] **`BlocEffectsMixin` closes the stream controller in `close()`.** Do not add a manual `@override Future<void> close()` unless you need to dispose additional resources — the mixin handles it.

---

## If you change the pattern

If the effects contract changes — for example, `BlocEffectsMixin` is replaced, the Equatable requirement is dropped, or the load/refresh split moves to a different mechanism — update this file in the same PR and update the companion playbook in `.claude/skills/add-bloc-effect.md`.

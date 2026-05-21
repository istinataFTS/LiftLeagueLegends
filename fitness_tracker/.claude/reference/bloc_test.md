# Canonical example — BLoC test

- **Pattern:** BLoC unit test (`bloc_test` package)
- **Canonical file:** `test/features/log/application/workout_bloc_test.dart`
- **Locked by:** commit `5042902` — last shape change; `BlocEffectsMixin` effect assertion and `cachedWeeklySets` verify both in place at this commit
- **Last verified:** 2026-05-21
- **Related references:** [[bloc]], [[widget_test]]
- **Companion playbook:** _(to be added by Adoption 05: `.claude/skills/add-feature.md`)_
- **Embodied conventions:**
  - Use `mocktail` for mocks (`class MockX extends Mock implements X {}`) — the codebase does not use `mockito`
  - `setUp` creates fresh mocks and a fresh BLoC; `tearDown` closes the BLoC — never share BLoC instances across tests
  - `blocTest` is the only way to test state sequences — do not use raw `expectLater` / `bloc.stream` for state assertions
  - Effect assertions capture `bloc.effects.first` **before** the `act` lambda fires — capturing after is a race condition
  - `verify` callbacks inside `blocTest` run after the state sequence is confirmed — use them for post-act side-effect checks

---

## Why this is the canonical

`workout_bloc_test.dart` is the canonical BLoC test because it covers all three test scenarios a feature BLoC test must address: a plain read path (load weekly sets), a write path with a success effect (add set + `WorkoutLoggedEffect`), and a failure path (error state). The effect assertion pattern in the "add set succeeds" test (lines 110–128) is the subtlest part of testing a `BlocEffectsMixin` BLoC — capturing the future before `act` fires — and having a worked example prevents the race-condition trap.

---

## Walkthrough

### Mock declarations (lines 13–18)

`workout_bloc_test.dart:13-18` — Each dependency is mocked with a one-line class: `class MockX extends Mock implements X {}`. No setup in the class body. `mocktail` resolves method stubs lazily via `when(() => mock.method()).thenAnswer(...)` inside each test. Keep mock classes at the top of the file, before `main`.

### `setUp` / `tearDown` (lines 41–55)

`workout_bloc_test.dart:41-51` — `setUp` creates a fresh mock and a fresh `WorkoutBloc` for every test. Never reuse a BLoC instance across tests — `bloc_test`'s `build:` callback creates its own copy, but the `bloc` variable in `setUp` is used by tests that need to read the BLoC's public fields (like `cachedWeeklySets`) after the test runs.

`workout_bloc_test.dart:53-55` — `tearDown` calls `await bloc.close()`. `BlocEffectsMixin` stores a `StreamController`; not closing it causes "Stream was already listened to" failures in subsequent tests. Always `close()` in `tearDown`.

### Minimal `blocTest` — read path (lines 60–75)

`workout_bloc_test.dart:60-75` — The minimum shape for a `blocTest`:
- `build:` — stubs mocks and returns the BLoC under test.
- `act:` — dispatches one event via `bloc.add(...)`.
- `expect:` — the exact sequence of states emitted. `isA<WorkoutLoading>()` is used instead of `WorkoutLoading()` where the state carries no payload worth asserting.
- `verify:` — runs after the state sequence; here it checks `bloc.cachedWeeklySets`.

The `build:` callback receives the BLoC returned by the `blocTest` machinery; the `bloc` variable in `setUp` and the argument to `build:` are different instances. Use the `build:` argument for `act` and `expect`; use the `setUp` `bloc` only when you need post-test field access that `verify:` cannot provide.

### Failure path (lines 77–90)

`workout_bloc_test.dart:77-90` — Failure tests are structurally identical to success tests. Stub the mock to return a `Left(Failure(...))`, then assert the error state. No `verify:` needed when there is nothing to check beyond the emitted states.

### Effect assertion — capturing before `act` (lines 92–128)

`workout_bloc_test.dart:110-128` — This is the critical pattern for `BlocEffectsMixin` tests:

```
_addSetEffectFuture = bloc.effects.first;   // captured BEFORE act fires
```

`bloc.effects` is a broadcast stream. `effects.first` returns a `Future<Effect>` that resolves when the first effect is emitted. If you capture `.first` *after* `act` fires the event, the emission may have already passed and the future will never resolve — causing the test to hang. Capture it before `act`, then `await` it inside `verify:`.

`workout_bloc_test.dart:119-128` — The `verify:` callback is `async` because it awaits the effect future. `bloc_test` supports async `verify:` callbacks. Assert the effect type with `isA<>()` before casting to access its fields — do not cast blindly.

### `verifyNever` — asserting something did not happen (lines 143–146)

`workout_bloc_test.dart:143-146` — In the failure path test, `verifyNever(() => mockGetWeeklySets())` asserts that the reload was not attempted after a write failure. Use `verifyNever` for negative assertions — do not rely on absence of state emissions alone, because a silent no-op and an intentionally skipped call look identical from the state sequence.

---

## Before you copy this

- [ ] **Use `mocktail`, not `mockito`.** `extends Mock implements X` with no `@GenerateMocks` or `build_runner` step.
- [ ] **Create a fresh BLoC in `setUp`; close it in `tearDown`.** Never share a BLoC instance between tests.
- [ ] **Capture `bloc.effects.first` inside `build:`, before `act:` fires.** Capturing it after is a race condition that causes tests to hang.
- [ ] **Make the `verify:` callback `async` when it awaits an effect future.** `bloc_test` supports this; there is no need for workarounds.
- [ ] **Use `isA<StateType>()` for states with no payload you care about** (e.g. `WorkoutLoading`). Use concrete instances (`WorkoutLoaded(sets)`) for states where payload equality matters.
- [ ] **Add a `verifyNever` assertion for any code path that must NOT be called on failure.** State-sequence tests alone do not prove a handler short-circuited correctly.
- [ ] **Every `blocTest` must have a `build:` that returns the BLoC.** Do not return `bloc` from `setUp` — `blocTest` creates its own managed lifecycle for the returned instance.

---

## If you change the pattern

If the BLoC testing conventions change — for example, `bloc_test` is replaced, `BlocEffectsMixin` changes its stream API, or `mocktail` is swapped for a different mock library — update this file in the same PR and update the companion playbook in `.claude/skills/`.

# Playbook — Add a new event, state, or effect to an existing BLoC

- **Task:** Add a new event, state, or one-shot UI effect to an existing BLoC
- **When to use:** When an existing BLoC needs to handle a new user action, emit a new state shape, or fire a one-shot UI signal (snackbar, navigation)
- **Estimated steps:** 5
- **Last verified:** 2026-05-31
- **Canonical references:** [[bloc]], [[bloc_test]], [[widget_test]]
- **Touches:** application, presentation, test
- **Related playbooks:** [add-use-case](add-use-case.md), [add-feature](add-feature.md)

---

## 0. Preconditions

- Read `.claude/reference/bloc.md` end-to-end before starting. Pay attention to the `BlocEffectsMixin` section — it explains when an effect is appropriate versus a new state.
- Read `.claude/reference/bloc_test.md` to understand effect-channel assertions.
- `dart run tool/check_conventions.dart` passes before you touch anything.

---

## Steps

### 1. Add the new event class

- [ ] In the BLoC file, add a new concrete class that extends the sealed `<Feature>Event` base class. Mirror the event shape from `.claude/reference/bloc.md`.
- [ ] Declare all payload fields as `final`. Implement `Equatable` and add every field to `props`. An empty or incomplete `props` list will cause silent test failures — `bloc_test` comparisons rely on value equality. See `.claude/reference/bloc.md` walkthrough (lines 12–35) for the pattern.
- [ ] Use `const` constructors on leaf event classes.

### 2. Add the new state class (only if the event mutates persistent UI state)

- [ ] If the new event produces a new durable UI state, add a concrete class extending the sealed `<Feature>State` base. Same `Equatable` + `props` rules as events.
- [ ] If the event is purely a "trigger" that emits a one-shot signal and then returns to the prior state (e.g. "log set" emits a snackbar then stays loaded), **skip this step** — handle it via an effect in step 3.

### 3. Add the new effect class (only if the event produces a one-shot UI signal)

- [ ] Add a concrete class extending the sealed `<Feature>UiEffect` base. Effects are plain Dart classes — they do **not** extend `Equatable` and are **not** stored in state.
- [ ] Effect rule: emit once, consume once, forget. If the UI needs to re-display the same information after a re-render, it belongs in state, not an effect.
- [ ] See `.claude/reference/bloc.md` walkthrough (lines 65–84) for the effect-types shape.
- [ ] **If the new effect is part of a cross-BLoC round-trip dispatch** (one BLoC dispatches a mutation command and another BLoC needs to report the outcome back), thread a `Completer<Outcome>` through the command effect. The originating BLoC owns the completer and `await`s it with a finite timeout; a router or mediator widget completes it after the target BLoC emits its outcome effect. Add both a success effect and a `*MutationFailedEffect` to the target BLoC so the router has a failure channel separate from the state channel. See `.claude/reference/bloc.md` "Cross-BLoC round-trip via Completer-bearing effect" for the full pattern, and `voice_command_router.dart` + `voice_bloc.dart` `_dispatchMutationTool` as the canonical example.

### 4. Register the event handler and implement it

- [ ] In the BLoC constructor, add `on<NewEvent>(_onNewEvent);`.
- [ ] Implement the private `_onNewEvent(NewEvent event, Emitter<FeatureState> emit)` method. Never use an inline lambda in `on<>()` — always delegate to a private method.
- [ ] If the handler calls a use case, inject the use case in the BLoC constructor. Do not call a repository directly from a BLoC.
- [ ] Emit state changes with `emit(NewState(...))`. Fire effects with `effectController.add(NewEffect(...))`.

### 5. Extend tests to cover the new event

- [ ] In the BLoC test file, add a `blocTest<FeatureBloC, FeatureState>(...)` case that exercises the new event. Mirror `.claude/reference/bloc_test.md`.
- [ ] If the handler emits an effect, assert it: `verify(() => effectListener(NewEffect(...))).called(1)` or `await bloc.effects.first`. See `.claude/reference/bloc_test.md` for the effect-assertion pattern.
- [ ] If the new event changes the UI, add or extend a widget test. Mirror `.claude/reference/widget_test.md`.
- [ ] Run `flutter test test/features/<feature>/` before moving on.

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

- **Missing `props` on event or state** — `bloc_test` comparisons fail silently when `props` is empty. Every payload field must appear in `props`.
- **Using an inline lambda in `on<>()`** — the pattern is always `on<Event>(_onEvent)` + a private method. Inline lambdas make the BLoC constructor grow and are hard to test in isolation.
- **Calling a repository directly from a BLoC** — use cases are the BLoC's domain boundary. Direct repository calls bypass validation logic and violate the architecture.
- **BLoC registered as `registerLazySingleton`** — see [KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons](../../KNOWN_ISSUES.md#blocs-must-be-factories-repositories-singletons). Adding a new BLoC or Cubit requires `registerFactory`.

# Canonical example — Widget test

- **Pattern:** Page-level widget test
- **Canonical file:** `test/features/log/presentation/log_page_test.dart`
- **Locked by:** commit `ed68d1b` — test suite stabilised after userId-scoping refactor; this file has been unchanged since
- **Last verified:** 2026-05-21
- **Related references:** [[bloc_test]]
- **Companion playbook:** _(to be added by Adoption 05: `.claude/skills/add-feature.md`)_
- **Embodied conventions:**
  - Every widget test builds the subject via a `buildSubject(...)` helper function — never inline `pumpWidget` calls with different configurations
  - Pages are wrapped in `AppShell` to provide the scaffold, navigation, and theme required by the real app shell
  - `pumpAndSettle()` after every `pumpWidget` and after every interaction — never `pump(Duration(...))` unless you are testing animation timing specifically
  - Tab content is injected via builder lambdas in tests, preventing BLoC/DI setup for content that is not under test
  - `group('PageName', ...)` wraps all tests for the same widget — one group per file

---

## Why this is the canonical

`log_page_test.dart` is the canonical widget test because it demonstrates how to test a page's *structural* and *interaction* behaviour without needing to mock BLoCs or wire up DI. `LogPage` accepts tab-content builders as constructor arguments, so the test substitutes simple `Text` widgets and focuses entirely on tab-switching logic. This is the right level of abstraction for a page test: verify that the page navigates and renders its shell correctly; leave BLoC state transitions to `bloc_test` (see [[bloc_test]]).

The `buildSubject` pattern and the `AppShell` wrapper are the two things to carry into every new page test, regardless of whether the page uses injected builders or BLoC providers.

---

## Walkthrough

### `buildSubject` helper (lines 7–26)

`log_page_test.dart:7-26` — `buildSubject` is a local function (not a method) that returns a `Widget`. It accepts all page-level parameters as named optional arguments with sensible defaults. Every `testWidgets` call uses `buildSubject(...)` instead of inlining a `pumpWidget` argument. This serves three purposes:
1. The test's intent ("respects the initial tab index") reads without noise.
2. Adding a new parameter to the page requires updating only `buildSubject`, not every test.
3. The helper is the single place to understand how this page is constructed in tests.

`log_page_test.dart:11-25` — `AppShell` wraps the page. `AppShell` provides the theme, `MediaQuery`, and navigator context that most pages implicitly rely on. Without it, many pages throw layout exceptions (`No MediaQuery ancestor`, `No Navigator ancestor`). Always wrap in `AppShell`; never try to add individual `MaterialApp` / `MediaQuery` providers by hand.

The tab-content builders return minimal `const Center(child: Text('...'))` widgets. The exact content doesn't matter; what matters is that each tab's content is unique and `findsOneWidget` / `findsNothing` can distinguish which tab is active.

### Golden-path render test (lines 29–36)

`log_page_test.dart:29-36` — The first test verifies that the three tab labels render. `pumpAndSettle()` waits for all animations (tab transitions, fade-ins) to complete before assertions run. Never skip `pumpAndSettle`; some widgets render asynchronously even without explicit `Future` awaits.

### Interaction test — tap and settle (lines 47–63)

`log_page_test.dart:47-63` — After tapping a tab widget found by its label text, `pumpAndSettle()` is called again before asserting. The tap dispatches an event; the widget tree re-renders; `pumpAndSettle` waits for that re-render. The pattern is always: `tap` → `pumpAndSettle` → `expect`. Asserting immediately after `tap` without settling will see the pre-tap state.

Each assertion pair checks that exactly one tab content is visible (`findsOneWidget`) and the others are absent (`findsNothing`). This is more robust than only checking the active tab — a bug that renders two tabs simultaneously would pass a `findsOneWidget`-only assertion.

### Edge-case test — invalid index clamping (lines 75–83)

`log_page_test.dart:75-83` — Tests the boundary condition `initialIndex: 99`. Widget tests should cover one happy path, at least one failure/edge path, and the key interactions. This test doubles as documentation: "the page clamps out-of-range indices to the last tab." Without this test, a future refactor of `LogPage`'s tab initialisation could silently break the contract.

---

## Before you copy this

- [ ] **Extract a `buildSubject(...)` local function at the top of `main`.** Never inline page construction in individual `testWidgets` calls.
- [ ] **Wrap in `AppShell`.** Most pages need scaffold, theme, and navigator; `AppShell` provides all three in one call.
- [ ] **`await tester.pumpAndSettle()` after every `pumpWidget` and after every user interaction** (`tap`, `enterText`, `drag`). Never assume the widget tree is settled without it.
- [ ] **Use `findsNothing` for widgets that must be absent** — not just `findsOneWidget` for widgets that must be present. A bug that renders extra content is only caught by the negative assertion.
- [ ] **Inject BLoC dependencies via builder lambdas or `BlocProvider.value`**, not by calling `GetIt.instance` in tests. If a page requires a BLoC, provide it explicitly in `buildSubject`; do not depend on global DI state.
- [ ] **Group all tests for one widget under `group('WidgetName', ...)`.** One group per file; one `group` nesting level for simple pages.
- [ ] **Test one happy path, one failure/edge path, and the key user interactions** for every page. Widget tests are not exhaustive; leave exhaustive state-transition coverage to `bloc_test`.

---

## If you change the pattern

If the widget-testing conventions change — for example, `AppShell` is renamed, a new required ancestor widget is introduced, or `pumpAndSettle` is replaced by an explicit `pump` + `delay` idiom — update this file in the same PR and update the companion playbook in `.claude/skills/`.

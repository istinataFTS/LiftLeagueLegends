# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

All Flutter commands run from the `fitness_tracker/` directory. All Deno/backend commands run from `fitness_tracker/supabase/functions/`.

### Flutter (app)

```sh
flutter pub get                         # install dependencies
flutter run                             # run on connected device/emulator
flutter test                            # run all tests
flutter test test/path/to/file_test.dart  # run a single test file
dart format lib test                    # format code
flutter analyze                         # static analysis
```

### Backend (Supabase Edge Functions)

```sh
deno test --allow-all                   # run all backend tests (from supabase/functions/)
deno test --allow-all voice-chat/       # run tests for a single function
deno fmt                                # format Deno code
deno lint                               # lint Deno code
```

### Local Supabase stack

```sh
supabase start                          # start local Postgres + Edge Function runtime
supabase functions serve --env-file .env.local   # serve all edge functions locally
supabase db push                        # apply pending migrations
```

See `supabase/.env.local` (gitignored) for required local env vars — `OPENAI_API_KEY`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`.

### Deploy (CI)

Supabase deploy is manual — trigger the `Supabase Deploy` GitHub Action (`workflow_dispatch`) with target `functions`, `migrations`, or `both`. Do not push to production without applying migrations first.

### Flutter compile-time config (`--dart-define`)

All config is injected at build time via `--dart-define`. `EnvConfig` (`lib/config/env_config.dart`) is the single source of truth. Supabase is **off by default** (`ENABLE_SUPABASE=false`) — a bare `flutter run` produces a local-only build whose sign-in surface fails with "Remote auth is not configured".

**`dart_defines.json` is gitignored** — it contains secrets and must never be committed. A `dart_defines.example.json` template is committed instead. On a fresh clone:

```powershell
copy dart_defines.example.json dart_defines.json   # Windows
cp  dart_defines.example.json dart_defines.json    # macOS/Linux
# then edit dart_defines.json and fill in real values
```

Use the wrapper script so a single command does the right thing on every machine:

```powershell
./scripts/run.ps1                    # debug, default device, Supabase enabled
./scripts/run.ps1 --release          # forwards extra flags to `flutter run`
./scripts/run.ps1 -d chrome          # pick a device
```

The script errors if `dart_defines.json` is missing. Equivalent raw command: `flutter run --dart-define-from-file=dart_defines.json`. VS Code launch configs in `.vscode/launch.json` mirror the same values for IDE-driven runs.

**Required keys in `dart_defines.json`:**

| Key | Description |
|---|---|
| `APP_ENV` | `development` / `production` |
| `ENABLE_SUPABASE` | `true` / `false` |
| `SUPABASE_URL` | Your Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon/public key |

## Platform support

**Android: shipping.** Full Gradle/Kotlin/AndroidManifest setup under `android/`. CI builds and tests Android on `ubuntu-latest`.

**iOS: not buildable yet — half-scaffolded.** Only `ios/Runner/Info.plist` (privacy strings: mic, speech recognition, tracking) and the auto-generated `GeneratedPluginRegistrant.{h,m}` exist. The following are intentionally **absent** and must be generated before iOS can build:

- `ios/Runner.xcodeproj/` and `ios/Runner.xcworkspace/`
- `ios/Podfile` and `ios/Podfile.lock`
- `ios/Runner/AppDelegate.swift` (or `.h`/`.m`)
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- `ios/Runner/Base.lproj/{Main,LaunchScreen}.storyboard`

**To fully scaffold iOS** (when ready, in its own PR — do **not** bundle with feature work):

1. From `fitness_tracker/`, run `flutter create --platforms=ios .` — generates ~30 files including the Xcode project, Podfile, AppDelegate, asset catalog, and storyboards. Do **not** overwrite the existing `ios/Runner/Info.plist` (it has hand-written voice privacy strings).
2. Flip `ios: true` in `pubspec.yaml` under `flutter_launcher_icons`, then run `dart run flutter_launcher_icons` to generate the iOS icon set from `assets/branding/app_icon.png`.
3. Add a `macos-latest` job to `.github/workflows/flutter-ci.yml` running `flutter build ios --no-codesign` so iOS regressions surface in CI.
4. Document any iOS-specific quirks in `KNOWN_ISSUES.md` under a new `### iOS` section.

**Cross-platform code in this repo is already written to be iOS-ready** — every voice plugin (`record`, `speech_to_text`, `flutter_tts`, `permission_handler`) supports iOS, and all platform-specific behaviour goes through domain-layer abstractions (`VoiceSttService`, `VoiceTtsService`, `VoicePermissionService`, etc.). When iOS scaffolding lands, the voice feature should work without further Dart changes.

**Platform-specific source files** live under `android/` only. Anything platform-specific belongs in:
- `android/app/src/main/res/...` — Android resources (icons, themes, strings)
- `android/app/src/main/AndroidManifest.xml` — Android permissions and intent filters
- `ios/Runner/Info.plist` — iOS permissions and bundle config (already present)
- `ios/Runner/Assets.xcassets/` — iOS icons (does not exist yet)

Do not introduce platform-specific Dart code via `Platform.isAndroid` / `Platform.isIOS` checks unless the platform abstraction layer (a `VoiceXxxService` interface in `lib/domain/services/`) cannot reasonably express the difference. Prefer one interface, two implementations registered per platform in DI.

## Known issues and the 15-minute rule

**The 15-minute rule.** If you spend more than 15 minutes debugging something that is specific to this codebase's stack (not generic Flutter behaviour), add an entry to [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) using the template at the top of that file. Do this *before* opening a PR with the fix — the entry is part of the PR.

`KNOWN_ISSUES.md` covers recurring traps: SQLite migration quirks, sync-ordering constraints, voice budget enforcement, dart-define behaviour, DI registration rules, and CI tooling gotchas. Consult it at the start of any debugging session — the problem may already be documented.

## Canonical examples

Before writing a new datasource, repository, use case, BLoC, injection module, or test, read the matching canonical example in `.claude/reference/`. Each file points at the live, blessed implementation of one pattern with an annotated walkthrough explaining what makes it canonical and what to watch out for when copying it.

- [Local datasource](.claude/reference/datasource.md) — `UserScopedLocalDatasource`, `whereOwned(...)`, `ownerId()`
- [Repository implementation](.claude/reference/repository.md) — `RepositoryGuard.run`, `Either<Failure, T>`, `DataSourcePreference`, offline-resilient remote reads
- [Use case](.claude/reference/use_case.md) — pure domain, `call()` entry point, session resolution, chained side effects
- [BLoC](.claude/reference/bloc.md) — `BlocEffectsMixin`, event/state/effect types, load-vs-refresh pattern
- [Injection module](.claude/reference/injection_module.md) — `registerFactory` for BLoCs, `registerLazySingleton<Interface>` for everything else, env-gate pattern
- [BLoC test](.claude/reference/bloc_test.md) — `bloc_test` + `mocktail`, effect assertion, `setUp`/`tearDown`
- [Widget test](.claude/reference/widget_test.md) — `buildSubject` helper, `AppShell` wrapper, `pumpAndSettle`

If you change a canonical pattern's shape, update the matching reference file in the same PR.

## Task playbooks

Before starting any of the recurring tasks below, read the matching playbook in `.claude/skills/`. Each playbook is a step-by-step checklist with explicit file paths, canonical references, and KNOWN_ISSUES pointers. Do not re-derive the steps from scratch.

- [Add a new feature end-to-end](.claude/skills/add-feature.md) — domain entity → datasource → repository → use case → BLoC → DI → tests → page
- [Add a user-scoped local datasource](.claude/skills/add-datasource.md) — `UserScopedLocalDatasource`, `whereOwned(...)`, auth-only guards, DI wiring, tests
- [Add a use case to an existing feature](.claude/skills/add-use-case.md) — `Params`, `call()`, repository delegation, DI, BLoC wiring, tests
- [Add a new event, state, or effect to an existing BLoC](.claude/skills/add-bloc-effect.md) — event/state/effect classes, handler registration, `BlocEffectsMixin`, tests
- [Add a SQLite schema migration](.claude/skills/add-migration.md) — `databaseVersion` bump, `_onUpgrade` branch, additive-only rules, migration test
- [Add a Supabase edge function](.claude/skills/add-edge-function.md) — shared budget enforcement, `voice_usage_log`, OpenAI wrapper, Deno tests

## Codebase map

Before exploring the codebase, read [`.claude/memory/state.json`](.claude/memory/state.json). It lists every feature (`home`, `log`, `history`, `library`, `profile`, `settings`, `auth`, `voice`) with its BLoC class names, repository interfaces, use case files, injection module path, and database tables. Loading this file first eliminates the exploration phase for common questions about feature wiring.

**If you change feature wiring** (add a BLoC, rename a use case, add a table, change an injection module), update `state.json` in the same PR. `tool/check_state_freshness.dart` runs as a CI step after `check_conventions` and fails the build if any per-feature fingerprint is stale. Run it locally to get the expected fingerprint values to paste in:

```sh
dart run tool/check_state_freshness.dart
```

## Convention checker

`tool/check_conventions.dart` runs as a CI step (between `flutter analyze` and `flutter test`). A sibling step `tool/check_state_freshness.dart` runs immediately after it to validate the codebase map. Together they enforce these invariants that the Dart analyzer cannot express:

1. **`user-scoped-datasource`** — Every concrete local datasource under `lib/data/datasources/local/` must extend `UserScopedLocalDatasource`, or be on the documented exemption list in `tool/convention_rules/user_scoped_datasource.dart`.
2. **`presentation-layer-data-import`** — No file under `lib/features/*/presentation/` may import from `lib/data/`. Use domain repository interfaces or use cases instead.
3. **`bloc-factory-registration`** — BLoCs and Cubits must be `registerFactory`, not `registerLazySingleton`, in `lib/injection/modules/`. (See KNOWN_ISSUES.md `#blocs-must-be-factories-repositories-singletons`.)
4. **`sql-userid-interpolation`** — SQL queries must not interpolate owner-id variables into the string literal. Use parameterised `whereArgs` or `whereOwned(...)`.
5. **`known-issues-schema`** — Every entry in `KNOWN_ISSUES.md` must have the nine mandatory fields (Severity, Status, First observed, Last verified, Area, Symptom, Root cause, Workaround / fix, References) with valid controlled-vocabulary values and ISO-8601 dates.
6. **`playbook-canonical-link`** — Every file in `.claude/skills/` must declare the locked metadata schema, have `Estimated steps:` match the actual step count, and resolve every `[[canonical]]` reference, KNOWN_ISSUES.md anchor, and backtick-wrapped source-file path it cites.
7. **`widget-state-bloc-field`** — Widget `State<…>` subclasses must not field-capture a BLoC/Cubit. Read it via `context.read`/`context.watch` in `build`/`didChangeDependencies`. (See KNOWN_ISSUES.md `#widget-state-must-not-field-capture-factory-blocs-or-cubits`.)
8. **`cross-feature-presentation-import`** — A file under `lib/features/<F1>/presentation/` may not import from another feature's `presentation/`, `application/`, or `data/`. Use the named-route registry in `lib/app/routes/`. (See KNOWN_ISSUES.md `#cross-feature-presentation-imports-are-architectural-cycles`.)
9. **`migration-test-coverage`** — Every `if (oldVersion < N)` branch in `lib/data/datasources/local/database_helper.dart` (for `N >= 21`, the version that introduced the pattern) must have a corresponding `test/data/datasources/local/database_helper_vN_migration_test.dart`. Older migrations (v3–v20) are exempt by design — they shipped before the dedicated-test convention.
10. **`no-skipped-tests`** — Test files under `test/` may not contain `@Skip(...)`, `skip: <truthy>`, or `solo: <truthy>`. `skip: false` / `skip: null` are explicitly accepted as "not skipped." Genuine temporary skips need an inline waiver tied to a tracked issue or KNOWN_ISSUES anchor. `test/tool/` is exempt because rule-test files legitimately reference these patterns in fixtures and descriptions.
11. **`forbid-print`** — Production code under `lib/` may not call the top-level `print(...)` function. Use `AppLogger.debug/info/warning/error` instead so the message participates in level gating and categorisation. `debugPrint`, methods named `print` on objects (e.g. PDF printers), and `dart:developer` `log()` are allowed.
12. **`forbid-todo-without-anchor`** — `// TODO` / `// FIXME` / `// XXX` / `// HACK` comments under `lib/` and `test/` must reference a tracked anchor — either a `KNOWN_ISSUES.md` slug (`#kebab-slug`) or a GitHub issue/PR number (`#NNN`). Untracked TODOs decay into noise. `test/tool/` is exempt for the same reason as `no-skipped-tests`.
13. **`state-freshness`** *(sibling script)* — `.claude/memory/state.json` must have per-feature fingerprints that match the live source tree. Enforced by `tool/check_state_freshness.dart` (not part of `check_conventions.dart`). Run `dart run tool/check_state_freshness.dart` to see expected values when stale.

Run locally: `dart run tool/check_conventions.dart` from `fitness_tracker/`.

To run the codebase-map check locally: `dart run tool/check_state_freshness.dart` from `fitness_tracker/`.

### Waivers

To exempt a specific line from a rule, add an inline comment on the offending line or the line immediately above it:

```dart
// convention-checker:allow=<rule-id> reason=<at-least-10-character prose>
```

The `reason=` clause is mandatory (minimum 10 characters). Waivers are reviewed in PR. See `lib/injection/modules/register_settings_module.dart` for the one documented waiver (`AppSettingsCubit` intentional singleton).

### Adding a new rule

1. Implement `ConventionRule` in `tool/convention_rules/<rule-id>.dart`.
2. Register it in `tool/check_conventions.dart`.
3. Add a test file at `test/tool/<rule-id>_test.dart` covering at least one pass case and one fail case.
4. Document it in this section.

### Local pre-commit hook

A version-controlled hook at `.githooks/pre-commit` (in the repo root, alongside `.github/`) runs `dart format --set-exit-if-changed` on staged Dart files and `dart run tool/check_conventions.dart` before every commit. It catches the two most common CI failure causes — formatting drift and rule violations — locally, so they never reach a push.

Install once per clone:

```sh
git config core.hooksPath .githooks
```

The hook deliberately does NOT run `flutter analyze`, `flutter test`, `check_state_freshness`, `check_coverage`, or the APK build. Those are slow enough to be disruptive on every commit and CI catches them anyway. The hook's whole budget is ~5 seconds.

In a genuine emergency, bypass with `git commit --no-verify`. Don't make a habit of it — every bypass is a CI failure that will surface ~5 minutes after push instead of immediately.

## Architecture

### Flutter app — Clean Architecture

The app follows a strict three-layer architecture. Presentation never imports data-layer types directly.

```
domain/       — entities, repository interfaces, use cases (pure Dart, no Flutter)
data/         — repository implementations, local datasources (sqflite), remote datasources (Supabase), sync coordinators
features/     — one directory per feature; each contains application/ (BLoC/Cubit), presentation/ (pages, widgets), and a barrel export
core/         — shared utilities, error handling, sync orchestration, auth, logging
injection/    — get_it wiring, split into modules per feature (register_*_module.dart)
```

### State management

All features use `flutter_bloc`. BLoCs and Cubits are registered as **factories** (new instance per page) in `injection/`. Repository and use-case singletons are `registerLazySingleton`.

One-shot side effects (navigation, snackbars) are emitted via `BlocEffectsMixin` — a broadcast `StreamController<Effect>` mixed into a BLoC. Listen in the widget with `bloc.effects.listen(...)`.

### Error handling

All repository methods return `Either<Failure, T>` (via `dartz`). Use `RepositoryGuard.run(() => ...)` to wrap datasource calls — it catches all exceptions and maps them to `Failure` subtypes via `RepositoryErrorMapper`.

### Data / sync architecture

- **Offline-first**: local writes are immediately committed; sync runs in the background.
- **Source of truth**: Supabase for authenticated users (`ConflictResolutionStrategy.serverWins`).
- **SyncOrchestrator** (`core/sync/`) runs on `appLaunch`, `appResume`, `connectivityRestored`, `manualRefresh`, `writeThrough`, and `initialSignIn`.
- **Initial sign-in**: triggers prepare → push → pull, ordered by FK dependency: exercises → meals → workout_sets → nutrition_logs.
- **Post-sync hooks**: after every sync, `MuscleFactorHealHook` runs first (ensures exercise factors are present), then `MuscleStimulusRebuildHook` rebuilds derived stimulus data.

### User-scoped local datasources

Every local datasource whose rows are owned by a user **must** extend `UserScopedLocalDatasource` (`lib/data/datasources/local/user_scoped_local_datasource.dart`). This is a structural requirement, not a convention — adding a new user-scoped datasource without extending the base class will fail CI in Adoption 04.

The base class provides:
- `ownerId()` — returns the current authenticated owner ID; throws `MissingUserContextException` if no user is in context. **There is no guest mode** — every datasource call runs above the sign-in gate.
- `whereOwned({required String ownerId, String? extra, List<Object?> extraArgs})` — builds a scoped `WHERE` clause for `db.query()` calls.

Three datasources are **exempt** (documented in the base class doc comment): `AppMetadataLocalDataSource`, `MuscleFactorLocalDataSource`, `PendingSyncDeleteLocalDataSource`.

### Local database

SQLite via `sqflite`. Current schema version: **27**. Migration history is documented inline in `EnvConfig.databaseVersion`. Version upgrades are additive; version 15+ rejects incompatible legacy databases rather than destroying data.

### Voice bot

The voice feature is split across Flutter (on-device I/O) and a single Supabase Edge Function (LLM):

- **STT** — `NetworkAwareVoiceSttService` routes each `listen()` to a remote **Whisper** backend (`voice-transcribe` Supabase edge function, `WhisperVoiceSttService`) when online (better gym-jargon recognition, billed server-side and logged to `voice_usage_log`), and falls back to the on-device `speech_to_text` plugin (`SpeechToTextVoiceSttService`) when offline. Hard-capped at 15 s per utterance (`VoiceConstants.sttListenTimeout`).
- **LLM** — one Deno Edge Function (`supabase/functions/voice-chat/`) backed by GPT-4o-mini. Receives the transcript + up to 3 turns of history, returns plain text or a structured tool call. Daily cap: $0.50/UTC-day enforced server-side.
- **TTS** — on-device via `flutter_tts` (`FlutterTtsVoiceTtsService`). No server call, no cost.
- **Wake word** — on-device sherpa-onnx (k2-fsa) keyword spotting (`SherpaOnnxVoiceWakeWordService`), offline, **no access key**; 3 presets (samoLevski / trainer / thomas) bundled as a tokenised `keywords.txt` over the `sherpa-onnx-kws-zipformer-gigaspeech` int8 model under `assets/wake_words/kws/`.
- **Tap-to-wake (Android only, foreground)** — a single headphone/headset media-button press (`KEYCODE_HEADSETHOOK` / `KEYCODE_MEDIA_PLAY_PAUSE`) starts a conversation the same way the wake word does. Implemented via a `MediaSessionCompat` owned by `MainActivity` and surfaced to Dart through `PlatformChannelVoiceMediaButtonService` (`VoiceMediaButtonService` port). Active only while the wake word is armed in the foreground; not available on iOS (no-op via `NoopVoiceMediaButtonService`). Reliability limits: AirPods on Android do not expose tap gestures as standard media events; another app holding media focus may intercept the press. See `KNOWN_ISSUES.md #headphone-tap-to-wake-unreliable-on-airpods-and-when-another-app-holds-media-focus`.
- **`VoiceBloc`** (`features/voice/application/`) orchestrates the full STT → chat → TTS sequence and owns the tool dispatcher. Tool calls are dispatched to existing blocs (`WorkoutBloc`, `NutritionLogBloc`, `HistoryBloc`) — never to repositories directly.
- **Shared backend modules** live in `supabase/functions/_shared/` (budget enforcement, OpenAI chat wrapper, cost accounting). All LLM calls are logged to `voice_usage_log`, including failures (`status=<error_code>`, `cost_usd=0`).
- `OPENAI_API_KEY` lives exclusively as a Supabase function secret — it is never present in Flutter client code.
- If Supabase is not configured, the voice module falls back to `NoopVoiceRemoteDataSource` (all calls return `ServerFailure`).

### Feature list

`home`, `log` (workout + nutrition), `history`, `library` (exercises + meals), `profile`, `settings`, `auth` (sign-in, sign-up, OTP — sign-in is required to use the app; there is no guest mode), `voice`.

### CI

Two GitHub Actions jobs on push to `main`, `develop`, and any `chore/**`, `ci/**`, `docs/**`, `feat/**`, `feature/**`, `fix/**`, `perf/**`, or `refactor/**` branch, plus on every PR targeting `main` or `develop`:
- **Flutter**: format check → `flutter analyze --no-fatal-infos` → `check_conventions` → `check_state_freshness` → `flutter test --coverage` → `check_coverage` (per-directory thresholds in `tool/check_coverage.dart`) → `flutter build apk --debug --dart-define-from-file=dart_defines.json`
- **Backend**: `deno fmt --check` → `deno lint` → `deno check` (type-check every `.ts`) → `deno test --allow-all`

The debug APK build runs end-to-end to catch manifest, Gradle, Kotlin-side, and plugin-registration regressions that the analyzer and unit tests cannot see. It uses the dart-defines file (built earlier in the job from repository secrets) so the Supabase-enabled production code path is compiled, not the defaults-only fallback. Release builds are not run in CI because the repo does not ship a CI signing configuration yet.

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

All config is injected at build time via `--dart-define`. `EnvConfig` (`lib/config/env_config.dart`) is the single source of truth. Supabase is **off by default** (`ENABLE_SUPABASE=false`). To run with a real backend:

```sh
flutter run \
  --dart-define=ENABLE_SUPABASE=true \
  --dart-define=SUPABASE_URL=https://xxx.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=eyJ...
```

## Known issues and the 15-minute rule

**The 15-minute rule.** If you spend more than 15 minutes debugging something that is specific to this codebase's stack (not generic Flutter behaviour), add an entry to [`KNOWN_ISSUES.md`](KNOWN_ISSUES.md) using the template at the top of that file. Do this *before* opening a PR with the fix — the entry is part of the PR.

`KNOWN_ISSUES.md` covers recurring traps: SQLite migration quirks, sync-ordering constraints, voice budget enforcement, dart-define behaviour, DI registration rules, and CI tooling gotchas. Consult it at the start of any debugging session — the problem may already be documented.

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

- **Guest mode**: local SQLite only (`sqflite`). No remote calls.
- **Authenticated mode**: offline-first. Local writes are immediately committed; sync runs in the background.
- **Source of truth**: Supabase for authenticated users (`ConflictResolutionStrategy.serverWins`).
- **SyncOrchestrator** (`core/sync/`) runs on `appLaunch`, `appResume`, `connectivityRestored`, `manualRefresh`, `writeThrough`, and `initialSignIn`.
- **Initial sign-in**: guest data is migrated to the authenticated user before any pull (prepare → push → pull, ordered by FK dependency: exercises → meals → workout_sets → nutrition_logs).
- **Post-sync hooks**: after every sync, `MuscleFactorHealHook` runs first (ensures exercise factors are present), then `MuscleStimulusRebuildHook` rebuilds derived stimulus data.

### Local database

SQLite via `sqflite`. Current schema version: **19**. Migration history is documented inline in `EnvConfig.databaseVersion`. Version upgrades are additive; version 15+ rejects incompatible legacy databases rather than destroying data.

### Voice bot

The voice feature is split across Flutter (on-device I/O) and a single Supabase Edge Function (LLM):

- **STT** — on-device via `speech_to_text` (`SpeechToTextVoiceSttService`). No server call, no cost. Hard-capped at 10 s per utterance (`VoiceConstants.sttListenTimeout`).
- **LLM** — one Deno Edge Function (`supabase/functions/voice-chat/`) backed by GPT-4o-mini. Receives the transcript + up to 3 turns of history, returns plain text or a structured tool call. Daily cap: $0.50/UTC-day enforced server-side.
- **TTS** — on-device via `flutter_tts` (`FlutterTtsVoiceTtsService`). No server call, no cost.
- **Wake word** — on-device Picovoice Porcupine (`PorcupineVoiceWakeWordService`), 3 presets: samoLevski, trainer, thomas.
- **`VoiceBloc`** (`features/voice/application/`) orchestrates the full STT → chat → TTS sequence and owns the tool dispatcher. Tool calls are dispatched to existing blocs (`WorkoutBloc`, `NutritionLogBloc`, `HistoryBloc`) — never to repositories directly.
- **Shared backend modules** live in `supabase/functions/_shared/` (budget enforcement, OpenAI chat wrapper, cost accounting). All LLM calls are logged to `voice_usage_log`, including failures (`status=<error_code>`, `cost_usd=0`).
- `OPENAI_API_KEY` lives exclusively as a Supabase function secret — it is never present in Flutter client code.
- If Supabase is not configured, the voice module falls back to `NoopVoiceRemoteDataSource` (all calls return `ServerFailure`).
- Guest users cannot use voice (FAB is visible-but-disabled with a sign-in CTA).

### Feature list

`home`, `log` (workout + nutrition), `history`, `library` (exercises + meals), `profile`, `settings`, `auth` (sign-in, sign-up, OTP), `voice`.

### CI

Two GitHub Actions jobs on push/PR to `main`, `develop`, `feature/**`, `fix/**`, `refactor/**`:
- **Flutter**: format check → `flutter analyze` → `flutter test`
- **Backend**: `deno fmt --check` → `deno lint` → `deno test --allow-all`

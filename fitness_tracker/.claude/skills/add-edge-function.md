# Playbook — Add a Supabase edge function

- **Task:** Create a new Supabase edge function with shared budget enforcement and usage logging
- **When to use:** When a backend capability is needed that calls an LLM, performs server-side computation, or must not expose a secret key to the Flutter client
- **Estimated steps:** 7
- **Last verified:** 2026-05-21
- **Canonical references:**
- **Touches:** supabase/functions
- **Related playbooks:** [add-feature](add-feature.md)

---

## 0. Preconditions

- Read KNOWN_ISSUES.md entries for the `voice` area before starting. They document the cost-cap, timeout, and API-key constraints that apply to **every** edge function that calls an LLM.
- All edge-function commands run from `fitness_tracker/supabase/functions/`, not from `fitness_tracker/`.
- `OPENAI_API_KEY` must **never** appear in Flutter client code. It lives exclusively as a Supabase function secret. See [KNOWN_ISSUES.md#dart-define-is-build-time-not-runtime](../../KNOWN_ISSUES.md#dart-define-is-build-time-not-runtime).
- The existing `voice-chat` function at `supabase/functions/voice-chat/index.ts` is the closest living example to follow.

---

## Steps

### 1. Create the function directory

- [ ] Create `supabase/functions/<name>/index.ts`. The entry point must export a `serve` handler via `Deno.serve(...)` (or the Supabase equivalent for your Deno version).
- [ ] Mirror the directory layout of `supabase/functions/voice-chat/`: `index.ts` (handler) and `index.test.ts` (test).
- [ ] Do not put shared logic in `index.ts`. Shared logic lives in `supabase/functions/_shared/`.

### 2. Reuse shared modules from `_shared/`

- [ ] Import budget enforcement from `../_shared/budget.ts`. Never implement your own daily-cap logic.
- [ ] Import the OpenAI wrapper from `../_shared/openai.ts`. Never call `fetch` on the OpenAI API directly.
- [ ] Import cost accounting from `../_shared/cost.ts` and usage logging from `../_shared/usage.ts`. Every LLM call — success or failure — must be logged to `voice_usage_log`.
- [ ] Import `../_shared/cors.ts` for CORS headers. All responses must include CORS headers.

### 3. Define request and response types; validate inputs server-side

- [ ] Define a TypeScript interface for the expected request body. Validate every field before calling any external service. Return `400 Bad Request` with a structured error body for invalid input.
- [ ] Do not trust the Flutter client to send well-formed data. Validate lengths, types, and required fields explicitly.

### 4. Gate every LLM call on the daily budget cap and log the result

- [ ] Call `checkDailyBudget(supabaseClient)` from `../_shared/budget.ts` before every LLM call. If the cap is exceeded, return `429 Too Many Requests`. See [KNOWN_ISSUES.md#voice-daily-cost-cap-is-server-side-only](../../KNOWN_ISSUES.md#voice-daily-cost-cap-is-server-side-only).
- [ ] After the LLM call (success or error), call `logUsage(...)` from `../_shared/usage.ts` with the actual `cost_usd`. For errors, set `cost_usd: 0` and `status: '<error_code>'`. Every call must be logged.
- [ ] Set a hard HTTP timeout of 30 seconds on the Supabase edge function invocation. See [KNOWN_ISSUES.md#voice-edge-function-must-have-30s-http-timeout](../../KNOWN_ISSUES.md#voice-edge-function-must-have-30s-http-timeout).

### 5. Write Deno tests

- [ ] Create `supabase/functions/<name>/index.test.ts`. Mirror the structure of `supabase/functions/voice-chat/index.test.ts`.
- [ ] Test the happy path and at least: budget-exceeded path (mock the budget check to return exceeded), invalid-input path.
- [ ] Run `deno test --allow-all <name>/` from `supabase/functions/` and confirm all tests pass.

### 6. Update the deployment workflow if needed

- [ ] If the `Supabase Deploy` GitHub Action lists specific functions to deploy, add `<name>` to that list. Migrations must be applied before functions — confirm the deploy order.
- [ ] If `supabase/.env.local` needs a new secret, document it in `supabase/.env.local` (gitignored) and update the team's secret-management instructions (not in this repo).

### 7. Wire the Flutter client

- [ ] In Flutter, call the function via `Supabase.instance.client.functions.invoke('<name>', body: {...})`. The function is only reachable when `ENABLE_SUPABASE=true`. If Supabase is disabled, the call site must return `Left(ServerFailure(...))` without actually invoking the function. See [KNOWN_ISSUES.md#supabase-disabled-by-default](../../KNOWN_ISSUES.md#supabase-disabled-by-default).

---

## Verification

Run the following from `fitness_tracker/` and confirm each passes before opening a PR:

```sh
dart format --output=none --set-exit-if-changed $(git diff --name-only origin/main -- '*.dart')
flutter analyze
dart run tool/check_conventions.dart
flutter test
```

Then from `fitness_tracker/supabase/functions/`:

```sh
deno fmt --check
deno lint
deno test --allow-all
```

---

## Pitfalls

- **`OPENAI_API_KEY` in Flutter client code** — this is a critical security leak. The key must only exist as a Supabase function secret, never in `EnvConfig` or `--dart-define`. See [KNOWN_ISSUES.md#dart-define-is-build-time-not-runtime](../../KNOWN_ISSUES.md#dart-define-is-build-time-not-runtime).
- **No daily budget cap** — without `checkDailyBudget`, a single misbehaving client can exhaust the OpenAI budget in seconds. See [KNOWN_ISSUES.md#voice-daily-cost-cap-is-server-side-only](../../KNOWN_ISSUES.md#voice-daily-cost-cap-is-server-side-only).
- **No HTTP timeout** — Supabase edge functions have a default timeout but the Flutter HTTP client may not. Set an explicit 30-second timeout. See [KNOWN_ISSUES.md#voice-edge-function-must-have-30s-http-timeout](../../KNOWN_ISSUES.md#voice-edge-function-must-have-30s-http-timeout).
- **Supabase disabled in tests** — `ENABLE_SUPABASE` defaults to `false`. Flutter tests that call the function directly will fail. Gate the call behind the Supabase-enabled check or use `NoopVoiceRemoteDataSource` as the pattern.

# Supabase — Fitness Tracker Voice Bot Backend

## Architecture

One Edge Function: **`voice-chat`** (GPT-4o-mini with tool calling).

STT and TTS run **on-device** (Android `SpeechRecognizer` / iOS `SFSpeechRecognizer`
for STT; Android `TextToSpeech` / iOS `AVSpeechSynthesizer` for TTS) — no audio
ever reaches the server. Only the transcribed text is sent to `voice-chat`.

## Prerequisites

- Supabase CLI ≥ 1.180
- Deno ≥ 1.40

## First-time setup

```sh
supabase login
supabase link --project-ref <your-project-ref>
supabase secrets set OPENAI_API_KEY=sk-...
```

`SUPABASE_SERVICE_ROLE_KEY` and `SUPABASE_URL` are injected automatically by
the Edge Function runtime — do **not** set them manually.

## Local development

Create `.env.local` (gitignored) with:

```
OPENAI_API_KEY=sk-...
SUPABASE_URL=http://localhost:54321
SUPABASE_SERVICE_ROLE_KEY=<service-role-key-from-supabase-start>
SUPABASE_ANON_KEY=<anon-key-from-supabase-start>
```

Then start the local stack and serve the Edge Function:

```sh
supabase start
supabase functions serve --env-file .env.local
```

## Running tests

Run from the `fitness_tracker/` directory:

```sh
deno test --allow-all supabase/functions
```

## Deploying

Apply migrations first, then deploy the function:

```sh
supabase db push
supabase functions deploy voice-chat
```

The `.github/workflows/supabase-deploy.yml` GitHub Action (`workflow_dispatch`)
does this in one step against the linked project.

## Pricing & cost monitoring

All `voice-chat` LLM calls are recorded in `voice_usage_log`. Query today's
spend per user:

```sql
select
  user_id,
  sum(cost_usd)  as total_usd,
  count(*)       as calls
from voice_usage_log
where created_at >= date_trunc('day', now() at time zone 'UTC')
group by user_id
order by total_usd desc;
```

Estimated cost: ~$0.0001 per voice interaction (GPT-4o-mini tokens only).
Daily cap: $0.50 per user.

## Where the OpenAI key lives (and where it doesn't)

The `OPENAI_API_KEY` lives **only** as a Supabase Function secret set via
`supabase secrets set`. It is:

- ✅ Read inside the `voice-chat` Edge Function via `Deno.env.get('OPENAI_API_KEY')`
- ❌ Never present in `lib/` (Flutter client code)
- ❌ Never in git history
- ❌ Never logged by any Edge Function

## One-off maintenance scripts

SQL scripts under `supabase/` that are **not** Supabase migrations — they are
applied manually once and are idempotent (running them again is a no-op).

| Script | Purpose | When to run |
|---|---|---|
| `cleanup_duplicate_exercises_and_meals.sql` | Collapses duplicate (user_id, name) exercise/meal rows and adds the UNIQUE constraint. | Already applied. Do not re-run unless starting from a fresh schema. |
| `cleanup_legacy_catalog_ids.sql` | Rewrites exercise/meal rows whose `id` was stamped with the pre-owner-scoping name-only UUIDv5 formula to the current owner-scoped formula. | Apply once after Plan 1 (guest-mode removal) has shipped. Required for fresh-device installs to sync without UNIQUE conflicts. |

### Running a maintenance script on the VPS

```sh
docker exec -i supabase-db \
  psql -U postgres -d postgres \
  < supabase/<script-name>.sql
```

Each script contains a **STEP 1 DRY RUN** block and a **STEP 2 CLEANUP** block.
Always run STEP 1 first, inspect the output, then run STEP 2.  Confirm
idempotency by re-running STEP 1 afterwards — it should return zero rows.

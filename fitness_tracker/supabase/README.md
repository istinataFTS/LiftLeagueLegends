# Supabase — Fitness Tracker Backend

This directory holds the Postgres schema, migrations, and one-off
maintenance scripts for the app's Supabase backend. There are no Edge
Functions here — the voice bot that used to live in `functions/` was
removed in Spec A, along with its migrations, tables, and functions.

## Contents

- `schema.sql` — bootstraps a clean Supabase project (tables, indexes, RLS
  policies, and the shared `set_updated_at()` trigger helper). Run once
  against a brand-new project only; an existing project evolves through
  `migrations/` instead.
- `migrations/` — ordered SQL migrations for the linked Supabase project.
- `ops/` — one-off, hand-run SQL scripts that are deliberately **not**
  migrations. See `ops/drop_voice_schema.sql` below.
- `config.toml` — local Supabase CLI configuration (used by `supabase
  start` / `supabase db push`).
- `cleanup_duplicate_exercises_and_meals.sql`,
  `cleanup_legacy_catalog_ids.sql` — ad-hoc, idempotent cleanup scripts (see
  "One-off maintenance scripts" below).

## First-time setup

```sh
supabase login
supabase link --project-ref <your-project-ref>
```

## Local development

Run from the `fitness_tracker/` directory:

```sh
supabase start    # starts the local Postgres + Supabase stack
supabase db push  # applies pending migrations to the linked project
```

Nothing in this directory needs its own `.env.local` or secrets anymore —
that requirement belonged to the Edge Functions (`OPENAI_API_KEY` and
friends), which no longer exist in this repo.

## Deploying

Deploys are manual: trigger the `Supabase Deploy` GitHub Action
(`workflow_dispatch`, defined at `.github/workflows/supabase-deploy.yml` in
the repo root) to push pending migrations to the linked project. Review the
pending migrations first — never deploy out of order.

## `ops/drop_voice_schema.sql`

A one-off, hand-run cleanup script — not a migration, not applied
automatically by `supabase db push`. Spec A deleted the four voice
migrations from history instead of adding reverting migrations, so this
script exists to bring an already-deployed project back in line with the
current `schema.sql`: it drops the `voice_sessions` and `voice_usage_log`
tables and the `voice_session_append_turn` and `global_voice_spend_since`
functions.

**This is owner-run, by hand, against the live project.** Execute it once
via the Supabase Dashboard SQL Editor (see the file's own header for the
exact instructions), then repair the migration ledger so `supabase db push`
stops complaining about remote versions with no local migration file:

```sh
supabase migration repair --status reverted 20260507000000
supabase migration repair --status reverted 20260511000000
supabase migration repair --status reverted 20260527000000
supabase migration repair --status reverted 20260625000000
```

## One-off maintenance scripts

SQL scripts in this directory that are **not** Supabase migrations — they
are applied manually and are idempotent (safe to re-run).

| Script | Purpose |
|---|---|
| `cleanup_duplicate_exercises_and_meals.sql` | Collapses duplicate `(user_id, name)` exercise/meal rows and adds the UNIQUE constraint that backs them. |
| `cleanup_legacy_catalog_ids.sql` | Rewrites exercise/meal rows whose `id` used the pre-owner-scoping name-only UUIDv5 formula to the current owner-scoped formula. |

Each script contains a **STEP 1 DRY RUN** block and a **STEP 2 CLEANUP**
block — read the file header, run STEP 1 first, inspect the output, then
run STEP 2.

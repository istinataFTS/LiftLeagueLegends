-- =============================================================================
-- One-time cleanup: normalise legacy catalog exercise and meal IDs on Supabase.
-- Rewrites rows whose id was stamped with the old name-only UUIDv5 formula to
-- the owner-scoped formula used by all current app versions.
--
-- Background
-- ----------
-- Before guest-mode removal (Plan 1, 2026-05-30), DeterministicCatalogId used
-- a name-only UUIDv5 key when the owner was the empty string. Rows that were
-- synced to Supabase before owner scoping was enforced carry:
--
--   id = uuid_v5(namespace, canonicalName)                    -- legacy
--
-- instead of the current:
--
--   id = uuid_v5(namespace, user_id || '|' || canonicalName)  -- owner-scoped
--
-- (namespace = 'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e',
--  source:     lib/core/utils/deterministic_catalog_id.dart)
--
-- The local SQLite schema was corrected by Plan 1's v22 migration. This script
-- normalises the Supabase side so that fresh-device installs do not hit a
-- UNIQUE(user_id, name) conflict when pushing a newly seeded owner-scoped row
-- that Supabase already holds under the legacy ID.
--
-- Known affected rows on this project's Supabase instance (as of 2026-05-30):
--   exercises: "Bench Press", "Bulgarian Split Squat" (id 5de79a89-…)
--   meals:     none expected
--
-- Safety properties
-- -----------------
-- Transactional  — the cleanup block wraps all writes in a single transaction;
--                  any error rolls the whole thing back.
-- Idempotent     — rows whose id already matches the owner-scoped formula are
--                  not selected; running the script twice is safe.
-- Defensive      — if the target new_id somehow already exists (an unlikely
--                  race), that row is skipped with a NOTICE rather than
--                  crashing the transaction.
-- Diagnostic     — RAISE NOTICE lines report every touched row and final
--                  counts so you can confirm what happened.
--
-- How to run
-- ----------
-- 1. Run STEP 1 (DRY RUN, read-only).  Inspect the result set — confirm the
--    listed exercises/meals and counts match expectations before writing.
-- 2. Run STEP 2 (CLEANUP).  Watch NOTICE output in the Supabase SQL Editor
--    console (or psql session) for per-row messages and the summary.
-- 3. Run STEP 1 again to verify zero rows remain.  That confirms idempotency.
--
-- On the VPS (self-hosted Supabase with Docker):
--   docker exec -i supabase-db \
--     psql -U postgres -d postgres \
--     < supabase/cleanup_legacy_catalog_ids.sql
--
-- Via Supabase Dashboard SQL Editor:
--   Paste the STEP 2 block only and run it.  NOTICE output appears in the
--   "Messages" tab below the results grid.
--
-- This script is NOT run by CI or automatic deploys.  Apply it manually once.
-- =============================================================================


-- =============================================================================
-- STEP 1 — DRY RUN (read-only).  Inspect this before writing anything.
-- =============================================================================

-- Enable uuid-ossp for uuid_generate_v5 (no-op if already enabled).
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Exercises whose id currently matches the legacy name-only formula.
-- These are the exact rows that STEP 2 will update.
WITH legacy AS (
  SELECT
    e.id             AS legacy_id,
    e.user_id,
    e.name,
    lower(trim(regexp_replace(e.name, '\s+', ' ', 'g'))) AS canonical,
    uuid_generate_v5(
      'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e'::uuid,
      e.user_id::text
        || '|'
        || lower(trim(regexp_replace(e.name, '\s+', ' ', 'g')))
    ) AS new_id
  FROM public.exercises e
  WHERE e.id = uuid_generate_v5(
    'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e'::uuid,
    lower(trim(regexp_replace(e.name, '\s+', ' ', 'g')))
  )
)
SELECT
  legacy_id,
  new_id,
  user_id,
  name,
  EXISTS (
    SELECT 1 FROM public.exercises ex WHERE ex.id = legacy.new_id
  )                                                               AS new_id_already_exists,
  (
    SELECT count(*)
    FROM   public.workout_sets ws
    WHERE  ws.exercise_id = legacy.legacy_id
  )                                                               AS workout_sets_referencing
FROM legacy
ORDER BY name;

-- Meals whose id currently matches the legacy name-only formula.
-- Expected result: zero rows.
WITH legacy AS (
  SELECT
    m.id             AS legacy_id,
    m.user_id,
    m.name,
    lower(trim(regexp_replace(m.name, '\s+', ' ', 'g'))) AS canonical,
    uuid_generate_v5(
      'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e'::uuid,
      m.user_id::text
        || '|'
        || lower(trim(regexp_replace(m.name, '\s+', ' ', 'g')))
    ) AS new_id
  FROM public.meals m
  WHERE m.id = uuid_generate_v5(
    'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e'::uuid,
    lower(trim(regexp_replace(m.name, '\s+', ' ', 'g')))
  )
)
SELECT
  legacy_id,
  new_id,
  user_id,
  name,
  EXISTS (
    SELECT 1 FROM public.meals ml WHERE ml.id = legacy.new_id
  )                                                               AS new_id_already_exists,
  (
    SELECT count(*)
    FROM   public.nutrition_logs nl
    WHERE  nl.meal_id = legacy.legacy_id
  )                                                               AS nutrition_logs_referencing
FROM legacy
ORDER BY name;


-- =============================================================================
-- STEP 2 — CLEANUP (writes).  Run after inspecting STEP 1.
-- Wrapped in a single transaction — any error rolls everything back.
-- =============================================================================

BEGIN;

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$
DECLARE
  v_namespace    CONSTANT uuid := 'b0d7c1e2-3a4f-5b6c-8d9e-0f1a2b3c4d5e';
  r              RECORD;
  v_canonical    text;
  v_legacy_id    uuid;
  v_new_id       uuid;
  v_rows_updated integer;
  v_ex_count     integer := 0;
  v_ex_skipped   integer := 0;
  v_meal_count   integer := 0;
  v_meal_skipped integer := 0;
BEGIN

  -- -----------------------------------------------------------------------
  -- Exercises: rows whose id matches the legacy name-only formula.
  -- -----------------------------------------------------------------------
  FOR r IN
    SELECT e.id, e.user_id, e.name
    FROM   public.exercises e
    WHERE  e.id = uuid_generate_v5(
             v_namespace,
             lower(trim(regexp_replace(e.name, '\s+', ' ', 'g')))
           )
    ORDER  BY e.name
  LOOP
    v_canonical := lower(trim(regexp_replace(r.name, '\s+', ' ', 'g')));
    v_legacy_id := r.id;
    v_new_id    := uuid_generate_v5(v_namespace, r.user_id::text || '|' || v_canonical);

    -- Idempotency guard: skip if the target id already exists.
    IF EXISTS (SELECT 1 FROM public.exercises WHERE id = v_new_id) THEN
      RAISE NOTICE 'SKIP exercise "%" — new id % already exists (already normalised)', r.name, v_new_id;
      v_ex_skipped := v_ex_skipped + 1;
      CONTINUE;
    END IF;

    RAISE NOTICE 'Updating exercise "%" | legacy_id=% → new_id=%', r.name, v_legacy_id, v_new_id;

    -- Reassign workout_sets FK references BEFORE changing the PK.
    -- (The FK has ON DELETE CASCADE but no ON UPDATE CASCADE, so we must
    --  update the child rows explicitly to avoid a FK violation.)
    UPDATE public.workout_sets
    SET    exercise_id = v_new_id
    WHERE  exercise_id = v_legacy_id;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    IF v_rows_updated > 0 THEN
      RAISE NOTICE '  … reassigned % workout_set row(s) to new exercise id', v_rows_updated;
    END IF;

    -- Update the exercise PK.
    UPDATE public.exercises
    SET    id = v_new_id
    WHERE  id = v_legacy_id;

    v_ex_count := v_ex_count + 1;
  END LOOP;

  RAISE NOTICE '=== Exercises: % updated, % skipped ===', v_ex_count, v_ex_skipped;

  -- -----------------------------------------------------------------------
  -- Meals: same pattern.  Legacy IDs are expected to be absent here, but
  -- the check runs regardless so this script remains correct if that
  -- assumption ever turns out to be wrong for another user account.
  -- -----------------------------------------------------------------------
  FOR r IN
    SELECT m.id, m.user_id, m.name
    FROM   public.meals m
    WHERE  m.id = uuid_generate_v5(
             v_namespace,
             lower(trim(regexp_replace(m.name, '\s+', ' ', 'g')))
           )
    ORDER  BY m.name
  LOOP
    v_canonical := lower(trim(regexp_replace(r.name, '\s+', ' ', 'g')));
    v_legacy_id := r.id;
    v_new_id    := uuid_generate_v5(v_namespace, r.user_id::text || '|' || v_canonical);

    IF EXISTS (SELECT 1 FROM public.meals WHERE id = v_new_id) THEN
      RAISE NOTICE 'SKIP meal "%" — new id % already exists (already normalised)', r.name, v_new_id;
      v_meal_skipped := v_meal_skipped + 1;
      CONTINUE;
    END IF;

    RAISE NOTICE 'Updating meal "%" | legacy_id=% → new_id=%', r.name, v_legacy_id, v_new_id;

    -- Reassign nutrition_logs FK references (nullable column, no ON UPDATE CASCADE).
    UPDATE public.nutrition_logs
    SET    meal_id = v_new_id
    WHERE  meal_id = v_legacy_id;

    GET DIAGNOSTICS v_rows_updated = ROW_COUNT;
    IF v_rows_updated > 0 THEN
      RAISE NOTICE '  … reassigned % nutrition_log row(s) to new meal id', v_rows_updated;
    END IF;

    -- Update the meal PK.
    UPDATE public.meals
    SET    id = v_new_id
    WHERE  id = v_legacy_id;

    v_meal_count := v_meal_count + 1;
  END LOOP;

  RAISE NOTICE '=== Meals: % updated, % skipped ===', v_meal_count, v_meal_skipped;

END $$;

COMMIT;

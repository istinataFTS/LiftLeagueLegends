-- One-off cleanup script — NOT a migration. Do not move this file into
-- supabase/migrations/.
--
-- Spec A (voice removal) deleted the four voice migrations from history
-- rather than adding a reverting migration. Deleting those files does not
-- drop anything from a project they were already applied to, so this script
-- exists to bring a deployed project back in line with the declared schema.
--
-- Run once, by pasting this file's contents into the Supabase Dashboard's
-- SQL Editor (Project -> SQL Editor -> New query) and executing it there.
--
-- Alternatively, with psql and the connection string from
-- Project Settings -> Database -> Connection string:
--   psql "<connection-string>" -f supabase/ops/drop_voice_schema.sql
--
-- Then repair the migration ledger so `supabase db push` stops complaining
-- about remote versions with no local file:
--
--   supabase migration repair --status reverted 20260507000000
--   supabase migration repair --status reverted 20260511000000
--   supabase migration repair --status reverted 20260527000000
--   supabase migration repair --status reverted 20260625000000
--
-- Idempotent: every statement uses IF EXISTS.

-- Global daily spend aggregate (20260625000000_global_voice_spend_rpc.sql).
-- Deployed signature takes one argument: p_since timestamptz.
drop function if exists public.global_voice_spend_since(timestamptz);

-- Atomic session-turn append helper (20260507000000_voice_assistant.sql).
-- Deployed signature: (uuid, uuid, jsonb, numeric).
drop function if exists public.voice_session_append_turn(uuid, uuid, jsonb, numeric);

-- voice_sessions — opt-in full transcripts, owner-deletable.
drop table if exists public.voice_sessions cascade;

-- voice_usage_log — per-call cost and metadata, service-role writes only.
drop table if exists public.voice_usage_log cascade;

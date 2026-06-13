-- Migration: drop the follows table
--
-- Social/follow graph feature was never shipped to users and the table was
-- manually deleted from the production Supabase project on 2026-06-12. This
-- migration brings the migration history in line so fresh environments and
-- replays match production state.

drop policy if exists "follows: authenticated users can read" on public.follows;
drop policy if exists "follows: owner can insert"             on public.follows;
drop policy if exists "follows: owner can delete"             on public.follows;

drop index if exists public.idx_follows_follower_id;
drop index if exists public.idx_follows_following_id;
drop index if exists public.idx_follows_created_at;

drop table if exists public.follows;

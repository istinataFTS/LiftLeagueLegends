-- Global daily spend ceiling (assertWithinGlobalBudget) originally summed
-- voice_usage_log rows client-side in the edge function. Fetching one row per
-- call across ALL users hits PostgREST's default 1000-row cap: past that the
-- result is silently truncated, the sum undercounts real spend, and the global
-- budget guard never trips — the exact overspend it exists to prevent.
--
-- Push the aggregation into the database so it returns a single scalar sum,
-- immune to row limits and with O(1) network transfer. SECURITY DEFINER so the
-- function aggregates across every user's rows regardless of the caller's RLS
-- scope (matches voice_session_append_turn). The edge function calls it via the
-- service-role client.
create or replace function public.global_voice_spend_since(p_since timestamptz)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(cost_usd), 0)
  from public.voice_usage_log
  where created_at >= p_since;
$$;

-- A SECURITY DEFINER function is granted EXECUTE to PUBLIC by default, which
-- would let any signed-in client call it directly and read service-wide
-- financial totals across all users. Lock it down to the service-role client
-- the edge functions use; standard anon/authenticated clients must not see it.
--
-- Supabase ALSO grants EXECUTE to the `anon` and `authenticated` roles
-- explicitly (via ALTER DEFAULT PRIVILEGES on the public schema), separately
-- from the PUBLIC grant. Revoking from PUBLIC alone does NOT remove those, so
-- they must be named explicitly or any signed-in client retains access.
-- Revoking a privilege a role does not hold is a harmless no-op, so this stays
-- correct on a fresh database where those default grants are absent.
revoke execute on function public.global_voice_spend_since(timestamptz)
  from public, anon, authenticated;
grant execute on function public.global_voice_spend_since(timestamptz)
  to service_role;

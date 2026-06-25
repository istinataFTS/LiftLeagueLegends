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

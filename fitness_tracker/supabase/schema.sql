-- =============================================================================
-- Fitness Tracker — Supabase schema
-- Run this file against a clean Supabase project to fully bootstrap the schema.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- Helper: automatically bump updated_at on every row change
-- ---------------------------------------------------------------------------
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- =============================================================================
-- Phase 3 — Core user-data tables
-- =============================================================================

-- ---------------------------------------------------------------------------
-- exercises
-- ---------------------------------------------------------------------------
create table public.exercises (
  id            uuid        primary key default gen_random_uuid(),
  user_id       uuid        not null references auth.users(id) on delete cascade,
  name          text        not null,
  muscle_groups text[]      not null default '{}',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  -- Mirrors the local sqlite UNIQUE(name, COALESCE(owner_user_id, '')).
  -- Without this, the client's pull step trips its local UNIQUE index when
  -- two cloud rows share (user_id, name).
  constraint exercises_user_id_name_key unique (user_id, name)
);

create index idx_exercises_user_id   on public.exercises(user_id);
create index idx_exercises_updated_at on public.exercises(updated_at);

create trigger trg_exercises_updated_at
  before update on public.exercises
  for each row execute function public.set_updated_at();

alter table public.exercises enable row level security;

create policy "exercises: owner select"
  on public.exercises for select
  to authenticated
  using (user_id = auth.uid());

create policy "exercises: owner insert"
  on public.exercises for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "exercises: owner update"
  on public.exercises for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "exercises: owner delete"
  on public.exercises for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- meals
-- ---------------------------------------------------------------------------
create table public.meals (
  id                 uuid        primary key default gen_random_uuid(),
  user_id            uuid        not null references auth.users(id) on delete cascade,
  name               text        not null,
  serving_size_grams double precision not null,
  carbs_per_100g     double precision not null,
  protein_per_100g   double precision not null,
  fat_per_100g       double precision not null,
  calories_per_100g  double precision not null,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  -- See note on public.exercises.exercises_user_id_name_key.
  constraint meals_user_id_name_key unique (user_id, name)
);

create index idx_meals_user_id    on public.meals(user_id);
create index idx_meals_updated_at on public.meals(updated_at);

create trigger trg_meals_updated_at
  before update on public.meals
  for each row execute function public.set_updated_at();

alter table public.meals enable row level security;

create policy "meals: owner select"
  on public.meals for select
  to authenticated
  using (user_id = auth.uid());

create policy "meals: owner insert"
  on public.meals for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "meals: owner update"
  on public.meals for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "meals: owner delete"
  on public.meals for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- workout_sets
-- References exercises(id) — exercises must be synced first.
-- ---------------------------------------------------------------------------
create table public.workout_sets (
  id           uuid        primary key default gen_random_uuid(),
  user_id      uuid        not null references auth.users(id) on delete cascade,
  exercise_id  uuid        not null references public.exercises(id) on delete cascade,
  reps         integer     not null,
  weight       double precision not null,
  intensity    integer     not null,
  performed_at timestamptz not null,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_workout_sets_user_id      on public.workout_sets(user_id);
create index idx_workout_sets_exercise_id  on public.workout_sets(exercise_id);
create index idx_workout_sets_performed_at on public.workout_sets(performed_at);
create index idx_workout_sets_updated_at   on public.workout_sets(updated_at);

create trigger trg_workout_sets_updated_at
  before update on public.workout_sets
  for each row execute function public.set_updated_at();

alter table public.workout_sets enable row level security;

create policy "workout_sets: owner select"
  on public.workout_sets for select
  to authenticated
  using (user_id = auth.uid());

create policy "workout_sets: owner insert"
  on public.workout_sets for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "workout_sets: owner update"
  on public.workout_sets for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "workout_sets: owner delete"
  on public.workout_sets for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- nutrition_logs
-- meal_id is nullable — a log may reference a saved meal or be ad-hoc.
-- ---------------------------------------------------------------------------
create table public.nutrition_logs (
  id             uuid        primary key default gen_random_uuid(),
  user_id        uuid        not null references auth.users(id) on delete cascade,
  meal_id        uuid        references public.meals(id) on delete set null,
  meal_name      text        not null,
  grams_consumed double precision,
  protein_grams  double precision not null,
  carbs_grams    double precision not null,
  fat_grams      double precision not null,
  calories       double precision not null,
  logged_at      timestamptz not null,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now()
);

create index idx_nutrition_logs_user_id    on public.nutrition_logs(user_id);
create index idx_nutrition_logs_meal_id    on public.nutrition_logs(meal_id);
create index idx_nutrition_logs_logged_at  on public.nutrition_logs(logged_at);
create index idx_nutrition_logs_updated_at on public.nutrition_logs(updated_at);

create trigger trg_nutrition_logs_updated_at
  before update on public.nutrition_logs
  for each row execute function public.set_updated_at();

alter table public.nutrition_logs enable row level security;

create policy "nutrition_logs: owner select"
  on public.nutrition_logs for select
  to authenticated
  using (user_id = auth.uid());

create policy "nutrition_logs: owner insert"
  on public.nutrition_logs for insert
  to authenticated
  with check (user_id = auth.uid());

create policy "nutrition_logs: owner update"
  on public.nutrition_logs for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

create policy "nutrition_logs: owner delete"
  on public.nutrition_logs for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- user_profiles
-- One row per auth user. id is the FK to auth.users.
-- is_public controls profile discoverability in the social graph.
-- ---------------------------------------------------------------------------
create table public.user_profiles (
  id           uuid        primary key references auth.users(id) on delete cascade,
  username     text        not null unique,
  display_name text,
  bio          text,
  avatar_url   text,
  is_public    boolean     not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create index idx_user_profiles_username   on public.user_profiles(username);
create index idx_user_profiles_updated_at on public.user_profiles(updated_at);

create trigger trg_user_profiles_updated_at
  before update on public.user_profiles
  for each row execute function public.set_updated_at();

alter table public.user_profiles enable row level security;

-- Owner always sees their own profile; others see it only when is_public = true.
create policy "user_profiles: select"
  on public.user_profiles for select
  to authenticated
  using (id = auth.uid() or is_public = true);

create policy "user_profiles: owner insert"
  on public.user_profiles for insert
  to authenticated
  with check (id = auth.uid());

create policy "user_profiles: owner update"
  on public.user_profiles for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy "user_profiles: owner delete"
  on public.user_profiles for delete
  to authenticated
  using (id = auth.uid());

-- =============================================================================
-- Voice assistant tables (Plan C-1)
-- =============================================================================

-- ---------------------------------------------------------------------------
-- voice_usage_log — per billed-call cost + metadata, always written.
-- voice-chat (GPT-4o-mini) and voice-transcribe (Whisper STT) both incur cost
-- and are logged here. On-device TTS and on-device STT fallback are free.
-- ---------------------------------------------------------------------------
create table public.voice_usage_log (
  id              uuid          primary key default gen_random_uuid(),
  user_id         uuid          not null references auth.users(id) on delete cascade,
  function_name   text          not null
                                  check (function_name in ('voice-chat', 'voice-transcribe')),
  model           text          not null,
  input_tokens    integer       null check (input_tokens  is null or input_tokens  >= 0),
  output_tokens   integer       null check (output_tokens is null or output_tokens >= 0),
  cost_usd        numeric(10,6) not null default 0 check (cost_usd >= 0),
  pricing_version text          not null,
  latency_ms      integer       not null check (latency_ms >= 0),
  session_id      uuid          null,
  status          text          not null default 'OK',
  created_at      timestamptz   not null default now()
);

create index idx_voice_usage_log_user_created
  on public.voice_usage_log (user_id, created_at desc);

create index idx_voice_usage_log_user_day
  on public.voice_usage_log (user_id, (date_trunc('day', created_at)));

alter table public.voice_usage_log enable row level security;

create policy "voice_usage_log: owner select"
  on public.voice_usage_log for select
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- voice_sessions — opt-in full transcripts
-- ---------------------------------------------------------------------------
create table public.voice_sessions (
  id              uuid          primary key,
  user_id         uuid          not null references auth.users(id) on delete cascade,
  started_at      timestamptz   not null default now(),
  ended_at        timestamptz   null,
  transcript      jsonb         not null default '[]'::jsonb,
  turn_count      integer       not null default 0  check (turn_count     >= 0),
  total_cost_usd  numeric(10,6) not null default 0  check (total_cost_usd >= 0),
  outcome         text          null
                                  check (outcome is null
                                         or outcome in ('completed','cancelled','budget_exceeded','error')),
  created_at      timestamptz   not null default now(),
  updated_at      timestamptz   not null default now()
);

create index idx_voice_sessions_user_started
  on public.voice_sessions (user_id, started_at desc);

create trigger trg_voice_sessions_updated_at
  before update on public.voice_sessions
  for each row execute function public.set_updated_at();

alter table public.voice_sessions enable row level security;

create policy "voice_sessions: owner select"
  on public.voice_sessions for select
  to authenticated
  using (user_id = auth.uid());

create policy "voice_sessions: owner delete"
  on public.voice_sessions for delete
  to authenticated
  using (user_id = auth.uid());

-- ---------------------------------------------------------------------------
-- Helper: atomic append of one turn to a voice session.
-- ---------------------------------------------------------------------------
create or replace function public.voice_session_append_turn(
  p_session_id    uuid,
  p_user_id       uuid,
  p_turn          jsonb,
  p_cost_usd      numeric
) returns void
language plpgsql
security definer
as $$
begin
  insert into public.voice_sessions (id, user_id, transcript, turn_count, total_cost_usd)
  values (p_session_id, p_user_id, jsonb_build_array(p_turn), 1, p_cost_usd)
  on conflict (id) do update set
    transcript     = voice_sessions.transcript || jsonb_build_array(p_turn),
    turn_count     = voice_sessions.turn_count + 1,
    total_cost_usd = voice_sessions.total_cost_usd + p_cost_usd,
    updated_at     = now();
end;
$$;

-- ---------------------------------------------------------------------------
-- Helper: total voice spend across ALL users since a timestamp. Aggregates
-- server-side so the global-budget guard is immune to PostgREST row limits
-- (a client-side row fetch truncates at 1000 rows and undercounts spend).
-- SECURITY DEFINER so it sums every user's rows regardless of RLS scope.
-- ---------------------------------------------------------------------------
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

-- Lock the SECURITY DEFINER aggregate down to the edge functions' service-role
-- client. Without this, the default EXECUTE-to-PUBLIC grant would let any
-- signed-in client read service-wide spend totals across all users.
revoke execute on function public.global_voice_spend_since(timestamptz)
  from public;
grant execute on function public.global_voice_spend_since(timestamptz)
  to service_role;

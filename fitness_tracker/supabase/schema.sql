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

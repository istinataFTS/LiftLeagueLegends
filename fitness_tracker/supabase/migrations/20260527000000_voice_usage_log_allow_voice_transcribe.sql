-- Whisper STT (function_name='voice-transcribe') was added after the original
-- voice_usage_log CHECK constraint that only permitted 'voice-chat'. Every
-- voice-transcribe insert has been failing in production with constraint
-- violation 23514, leaving Whisper cost off the budget. Broaden the
-- constraint to the current set of functions that bill against the user's
-- daily voice budget.
do $$
begin
  if exists (
    select 1 from pg_constraint
    where conrelid = 'public.voice_usage_log'::regclass
      and conname  = 'voice_usage_log_function_name_check'
  ) then
    alter table public.voice_usage_log
      drop constraint voice_usage_log_function_name_check;
  end if;
end;
$$;

alter table public.voice_usage_log
  add constraint voice_usage_log_function_name_check
  check (function_name in ('voice-chat', 'voice-transcribe'));

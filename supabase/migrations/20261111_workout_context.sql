-- Contexto para la rutina del día: competencias, chequeo y nota del coach.
-- Ejecutar en el editor SQL de Supabase.

alter table public.training_programs
  add column if not exists coach_notes text;

create table if not exists public.meets (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  meet_date date not null,
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now())
);

create table if not exists public.daily_checkins (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.profiles(id) on delete cascade,
  checkin_date date not null,
  sleep_hours numeric,
  soreness integer check (soreness between 1 and 5),
  feeling text check (feeling in ('mal', 'normal', 'bien')),
  created_at timestamptz not null default timezone('utc', now()),
  unique (athlete_id, checkin_date)
);

grant select, insert, update, delete on public.meets to authenticated;
grant select, insert, update, delete on public.daily_checkins to authenticated;

alter table public.meets enable row level security;
alter table public.daily_checkins enable row level security;

drop policy if exists meets_rw on public.meets;
create policy meets_rw on public.meets
  for all
  using (
    athlete_id = auth.uid()
    or exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid() and ca.athlete_id = meets.athlete_id
    )
  )
  with check (
    athlete_id = auth.uid()
    or exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid() and ca.athlete_id = meets.athlete_id
    )
  );

drop policy if exists daily_checkins_rw on public.daily_checkins;
create policy daily_checkins_rw on public.daily_checkins
  for all
  using (
    athlete_id = auth.uid()
    or exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid() and ca.athlete_id = daily_checkins.athlete_id
    )
  )
  with check (
    athlete_id = auth.uid()
    or exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid() and ca.athlete_id = daily_checkins.athlete_id
    )
  );

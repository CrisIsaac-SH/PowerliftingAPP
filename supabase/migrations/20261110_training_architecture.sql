-- Arquitectura de entrenamientos: metas semanales, prescripción en sets
-- y programas de coach. Ejecutar en el editor SQL de Supabase.
-- No modifica profiles, exercises, forum_posts, coach_athletes ni weekly_blocks.

alter table public.sets
  add column if not exists status text not null default 'completed',
  add column if not exists performed_at timestamptz,
  add column if not exists target_weight numeric,
  add column if not exists target_reps integer,
  add column if not exists target_rpe numeric;

alter table public.workouts
  add column if not exists origin text not null default 'manual',
  add column if not exists is_customized boolean not null default false,
  add column if not exists completed_at timestamptz,
  add column if not exists program_id uuid;

create table if not exists public.weekly_goals (
  id uuid primary key default gen_random_uuid(),
  athlete_id uuid not null references public.profiles(id) on delete cascade,
  week_start date not null,
  target_sessions integer not null check (target_sessions > 0),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default timezone('utc', now()),
  unique (athlete_id, week_start)
);

create table if not exists public.weekly_lift_goals (
  id uuid primary key default gen_random_uuid(),
  weekly_goal_id uuid not null references public.weekly_goals(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  target_weight_kg numeric,
  unique (weekly_goal_id, exercise_id)
);

create table if not exists public.training_programs (
  id uuid primary key default gen_random_uuid(),
  coach_id uuid not null references public.profiles(id),
  athlete_id uuid not null references public.profiles(id),
  name text not null,
  start_date date not null,
  end_date date not null,
  status text not null default 'active',
  created_at timestamptz not null default timezone('utc', now()),
  check (end_date >= start_date)
);

create table if not exists public.program_day_templates (
  id uuid primary key default gen_random_uuid(),
  program_id uuid not null references public.training_programs(id) on delete cascade,
  weekday integer not null check (weekday between 1 and 7),
  unique (program_id, weekday)
);

create table if not exists public.template_sets (
  id uuid primary key default gen_random_uuid(),
  template_id uuid not null references public.program_day_templates(id) on delete cascade,
  exercise_id uuid not null references public.exercises(id),
  set_number integer not null,
  target_weight_kg numeric,
  target_reps integer,
  target_rpe numeric,
  unique (template_id, exercise_id, set_number)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conname = 'workouts_program_id_fkey'
  ) then
    alter table public.workouts
      add constraint workouts_program_id_fkey
      foreign key (program_id) references public.training_programs(id);
  end if;
end $$;

grant select, insert, update, delete on public.weekly_goals to authenticated;
grant select, insert, update, delete on public.weekly_lift_goals to authenticated;
grant select, insert, update, delete on public.training_programs to authenticated;
grant select, insert, update, delete on public.program_day_templates to authenticated;
grant select, insert, update, delete on public.template_sets to authenticated;

alter table public.weekly_goals enable row level security;
alter table public.weekly_lift_goals enable row level security;
alter table public.training_programs enable row level security;
alter table public.program_day_templates enable row level security;
alter table public.template_sets enable row level security;

drop policy if exists weekly_goals_rw on public.weekly_goals;
create policy weekly_goals_rw on public.weekly_goals
  for all
  using (
    athlete_id = auth.uid()
    or exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid() and ca.athlete_id = weekly_goals.athlete_id
    )
  )
  with check (
    athlete_id = auth.uid()
    or exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid() and ca.athlete_id = weekly_goals.athlete_id
    )
  );

drop policy if exists weekly_lift_goals_rw on public.weekly_lift_goals;
create policy weekly_lift_goals_rw on public.weekly_lift_goals
  for all
  using (
    exists (
      select 1 from public.weekly_goals g
      where g.id = weekly_lift_goals.weekly_goal_id
        and (
          g.athlete_id = auth.uid()
          or exists (
            select 1 from public.coach_athletes ca
            where ca.coach_id = auth.uid() and ca.athlete_id = g.athlete_id
          )
        )
    )
  )
  with check (
    exists (
      select 1 from public.weekly_goals g
      where g.id = weekly_lift_goals.weekly_goal_id
        and (
          g.athlete_id = auth.uid()
          or exists (
            select 1 from public.coach_athletes ca
            where ca.coach_id = auth.uid() and ca.athlete_id = g.athlete_id
          )
        )
    )
  );

drop policy if exists training_programs_select on public.training_programs;
create policy training_programs_select on public.training_programs
  for select
  using (athlete_id = auth.uid() or coach_id = auth.uid());

drop policy if exists training_programs_write on public.training_programs;
create policy training_programs_write on public.training_programs
  for all
  using (coach_id = auth.uid())
  with check (
    coach_id = auth.uid()
    and exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid() and ca.athlete_id = training_programs.athlete_id
    )
  );

drop policy if exists program_day_templates_select on public.program_day_templates;
create policy program_day_templates_select on public.program_day_templates
  for select
  using (
    exists (
      select 1 from public.training_programs p
      where p.id = program_day_templates.program_id
        and (p.athlete_id = auth.uid() or p.coach_id = auth.uid())
    )
  );

drop policy if exists program_day_templates_write on public.program_day_templates;
create policy program_day_templates_write on public.program_day_templates
  for all
  using (
    exists (
      select 1 from public.training_programs p
      where p.id = program_day_templates.program_id and p.coach_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1 from public.training_programs p
      where p.id = program_day_templates.program_id and p.coach_id = auth.uid()
    )
  );

drop policy if exists template_sets_select on public.template_sets;
create policy template_sets_select on public.template_sets
  for select
  using (
    exists (
      select 1
      from public.program_day_templates t
      join public.training_programs p on p.id = t.program_id
      where t.id = template_sets.template_id
        and (p.athlete_id = auth.uid() or p.coach_id = auth.uid())
    )
  );

drop policy if exists template_sets_write on public.template_sets;
create policy template_sets_write on public.template_sets
  for all
  using (
    exists (
      select 1
      from public.program_day_templates t
      join public.training_programs p on p.id = t.program_id
      where t.id = template_sets.template_id and p.coach_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.program_day_templates t
      join public.training_programs p on p.id = t.program_id
      where t.id = template_sets.template_id and p.coach_id = auth.uid()
    )
  );

-- El coach puede crear y mantener las sesiones de sus atletas.
-- Las políticas del atleta sobre sus propias filas se conservan.
drop policy if exists workouts_coach_write on public.workouts;
create policy workouts_coach_write on public.workouts
  for all
  using (
    exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid()
        and ca.athlete_id = workouts.user_id
    )
  )
  with check (
    exists (
      select 1 from public.coach_athletes ca
      where ca.coach_id = auth.uid()
        and ca.athlete_id = workouts.user_id
    )
  );

drop policy if exists sets_coach_write on public.sets;
create policy sets_coach_write on public.sets
  for all
  using (
    exists (
      select 1
      from public.workouts w
      join public.coach_athletes ca on ca.athlete_id = w.user_id
      where w.id = sets.workout_id
        and ca.coach_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
      from public.workouts w
      join public.coach_athletes ca on ca.athlete_id = w.user_id
      where w.id = sets.workout_id
        and ca.coach_id = auth.uid()
    )
  );

-- ══════════════════════════════════════════════
-- CRS — Schema completo para Supabase
-- Ejecutar en: SQL Editor del dashboard de Supabase
-- ══════════════════════════════════════════════

-- 1. TEAMS
create table public.teams (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  created_by uuid references auth.users(id),
  created_at timestamptz default now()
);

-- 2. PLAYERS
create table public.players (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  active boolean default true,
  team_id uuid references public.teams(id) on delete cascade,
  created_at timestamptz default now()
);

-- 3. PROFILES
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text,
  email text,
  role text default 'player' check (role in ('admin','captain','player')),
  player_id uuid references public.players(id),
  created_at timestamptz default now()
);

-- 4. TRAINING ROUNDS
create table public.training_rounds (
  id uuid primary key default gen_random_uuid(),
  round_number integer not null,
  base_azul jsonb default '[]'::jsonb,
  base_roja jsonb default '[]'::jsonb,
  score integer default 0,
  mission_data jsonb default '{}'::jsonb,
  time_remaining integer default 0,
  created_by uuid references auth.users(id),
  team_id uuid references public.teams(id) on delete cascade,
  created_at timestamptz default now()
);

-- 5. ATTENDANCE SESSIONS
create table public.attendance_sessions (
  id uuid primary key default gen_random_uuid(),
  session_date date not null,
  notes text default '',
  created_by uuid references auth.users(id),
  team_id uuid references public.teams(id) on delete cascade,
  created_at timestamptz default now()
);

-- 6. ATTENDANCE RECORDS
create table public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  session_id uuid references public.attendance_sessions(id) on delete cascade,
  player_id uuid references public.players(id) on delete cascade,
  present boolean default false,
  created_at timestamptz default now()
);

-- ══════════════════════════════════════════════
-- ROW LEVEL SECURITY
-- ══════════════════════════════════════════════

alter table public.teams enable row level security;
alter table public.players enable row level security;
alter table public.profiles enable row level security;
alter table public.training_rounds enable row level security;
alter table public.attendance_sessions enable row level security;
alter table public.attendance_records enable row level security;

create policy "Allow all for authenticated" on public.teams
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Allow all for authenticated" on public.players
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Allow all for authenticated" on public.profiles
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Allow all for authenticated" on public.training_rounds
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Allow all for authenticated" on public.attendance_sessions
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

create policy "Allow all for authenticated" on public.attendance_records
  for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ══════════════════════════════════════════════
-- TRIGGER: crear perfil automáticamente al registrarse
-- El primer usuario → admin, los demás → player
-- ══════════════════════════════════════════════

create or replace function public.handle_new_user()
returns trigger as $$
declare
  user_count integer;
  user_role text;
begin
  select count(*) into user_count from public.profiles;
  if user_count = 0 then
    user_role := 'admin';
  else
    user_role := 'player';
  end if;

  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    new.email,
    user_role
  );
  return new;
end;
$$ language plpgsql security definer;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

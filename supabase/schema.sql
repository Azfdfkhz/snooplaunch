-- SNOOP: skema awal Supabase (PRD bagian 11). Tinjau sebelum produksi.
create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text, institution text, company_name text,
  timezone text default 'Asia/Jakarta',
  created_at timestamptz default now(), updated_at timestamptz default now()
);

create table public.work_schedules (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null, description text,
  start_at timestamptz not null, end_at timestamptz,
  location_name text, reminder_enabled boolean default false,
  status text not null default 'upcoming'
    check (status in ('upcoming','in_progress','completed','skipped','cancelled')),
  created_at timestamptz default now()
);

create table public.attendance_records (
  id uuid primary key,  -- dibuat klien (idempotensi saat retry)
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  schedule_id uuid references public.work_schedules(id) on delete set null,
  check_in_at timestamptz not null,
  check_out_at timestamptz,
  check_in_latitude double precision check (check_in_latitude between -90 and 90),
  check_in_longitude double precision check (check_in_longitude between -180 and 180),
  check_in_accuracy_m double precision check (check_in_accuracy_m >= 0),
  check_out_latitude double precision check (check_out_latitude between -90 and 90),
  check_out_longitude double precision check (check_out_longitude between -180 and 180),
  status text not null default 'pending'
    check (status in ('pending','present','late','checked_out','needs_attention')),
  device_time_at timestamptz,
  server_time_at timestamptz not null default now(),
  created_at timestamptz default now()
);
create unique index attendance_one_per_day
  on public.attendance_records (user_id, ((check_in_at at time zone 'Asia/Jakarta')::date));

create table public.documentations (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  schedule_id uuid references public.work_schedules(id) on delete set null,
  attendance_id uuid references public.attendance_records(id) on delete set null,
  drive_file_id text, drive_file_url text,
  captured_at timestamptz not null,
  latitude double precision, longitude double precision, location_accuracy_m double precision,
  title text not null, description text,
  upload_status text not null default 'pending'
    check (upload_status in ('pending','uploading','uploaded','failed')),
  created_at timestamptz default now()
);

create table public.reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null, description text, reminder_type text not null,
  scheduled_at timestamptz, recurrence_rule jsonb,
  enabled boolean not null default true,
  created_at timestamptz default now()
);

-- RLS: pengguna hanya mengakses datanya sendiri
alter table public.profiles enable row level security;
create policy "profiles_own" on public.profiles for all
  using (id = auth.uid()) with check (id = auth.uid());

do $$
declare t text;
begin
  foreach t in array array['work_schedules','attendance_records','documentations','reminders'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('create policy "%s_own" on public.%I for all using (user_id = auth.uid()) with check (user_id = auth.uid())', t, t);
    execute format('create index on public.%I (user_id)', t);
  end loop;
end $$;


-- Keep profile.updated_at consistent on profile updates.
create or replace function public.set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
for each row execute function public.set_updated_at();

-- Additional query indexes used by history and reminder screens.
create index if not exists attendance_records_user_checkin_idx
  on public.attendance_records (user_id, check_in_at desc);
create index if not exists documentations_user_captured_idx
  on public.documentations (user_id, captured_at desc);
create index if not exists work_schedules_user_start_idx
  on public.work_schedules (user_id, start_at);
create index if not exists reminders_user_enabled_idx
  on public.reminders (user_id, enabled) where enabled = true;

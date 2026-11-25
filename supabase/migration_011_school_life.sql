-- SNOOP School Life 2.0 — School Workspace (jadwal pelajaran, tugas, kalender akademik, catatan) + pemisahan dokumentasi PKL.
-- Jalankan SEKALI di Supabase SQL Editor (staging dulu, lalu production). Aman dijalankan ulang (idempotent).
--
-- PRINSIP: TIDAK ada DROP, TRUNCATE, atau DELETE pada tabel PKL (attendance_records, work_schedules, documentations).
-- Semua data PKL tetap utuh; dokumentasi lama otomatis berstatus workspace = 'pkl' (default kolom) dan hanya dibaca
-- lewat Arsip PKL (read-only) di aplikasi. Rollback: lihat bagian paling bawah (hanya objek baru yang dihapus).
--
-- CATATAN KLIEN: pada rilis 2.0.0 aplikasi baru mengirim `profiles.class_name/major/academic_year` dan kolom ruang kerja
-- `documentations`. Tabel akademik di bawah disiapkan lebih dulu; sinkronisasi klien untuk tabel-tabel itu adalah
-- pekerjaan lanjutan (data akademik saat ini lokal-pertama di perangkat).

create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------------ 0. Pembantu
create or replace function public.snoop_touch_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at := now();
  return new;
end $$;

-- ------------------------------------------------------------------ 1. Profil siswa
alter table public.profiles
  add column if not exists class_name text,
  add column if not exists major text,
  add column if not exists academic_year text,
  add column if not exists timezone text not null default 'Asia/Jakarta';
-- `company_name` dan `period` (PKL) tidak diubah dan tidak dihapus.

-- ------------------------------------------------------------------ 2. Mata pelajaran
create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null check (length(btrim(name)) > 0),
  teacher_name text,
  default_room text,
  color_key text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists subjects_user_idx on public.subjects (user_id, deleted_at);

-- ------------------------------------------------------------------ 3. Jadwal pelajaran mingguan + pengecualian
create table if not exists public.timetable_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null check (length(btrim(title)) > 0),
  day_of_week smallint not null check (day_of_week between 1 and 7),  -- 1 = Senin
  start_time time not null,
  end_time time not null,
  teacher_name text,
  room text,
  color_key text,
  note text,
  valid_from date,
  valid_until date,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint timetable_time_order check (end_time > start_time),
  constraint timetable_valid_order check (valid_until is null or valid_from is null or valid_until >= valid_from)
);
create index if not exists timetable_entries_user_day_idx on public.timetable_entries (user_id, day_of_week) where deleted_at is null;

create table if not exists public.timetable_exceptions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  timetable_entry_id uuid references public.timetable_entries(id) on delete cascade,
  event_date date not null,
  action text not null check (action in ('cancel', 'replace', 'extra')),
  title text,
  start_time time,
  end_time time,
  room text,
  teacher_name text,
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint exception_time_order check (end_time is null or start_time is null or end_time > start_time)
);
create index if not exists timetable_exceptions_user_date_idx on public.timetable_exceptions (user_id, event_date) where deleted_at is null;

-- ------------------------------------------------------------------ 4. Tugas + lampiran
create table if not exists public.tasks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null check (length(btrim(title)) > 0),
  description text,
  task_type text not null default 'assignment' check (task_type in ('assignment', 'project', 'exam_preparation', 'other')),
  priority text not null default 'normal' check (priority in ('low', 'normal', 'high', 'urgent')),
  status text not null default 'todo' check (status in ('todo', 'in_progress', 'completed', 'archived')),
  due_at timestamptz,
  completed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists tasks_user_status_due_idx on public.tasks (user_id, status, due_at) where deleted_at is null;

create table if not exists public.task_attachments (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  task_id uuid not null references public.tasks(id) on delete cascade,
  kind text not null check (kind in ('photo', 'file', 'link')),
  storage_ref text not null,          -- id/URL Drive untuk berkas; URL untuk tautan
  file_name text,
  mime_type text,
  file_size bigint check (file_size is null or file_size >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists task_attachments_task_idx on public.task_attachments (task_id) where deleted_at is null;

-- ------------------------------------------------------------------ 5. Kalender akademik
create table if not exists public.academic_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  title text not null check (length(btrim(title)) > 0),
  description text,
  event_type text not null default 'school_event'
    check (event_type in ('exam', 'school_event', 'holiday', 'deadline', 'extracurricular', 'personal', 'other')),
  starts_at timestamptz not null,
  ends_at timestamptz,
  all_day boolean not null default false,
  location text,
  linked_task_id uuid references public.tasks(id) on delete set null,
  subject_id uuid references public.subjects(id) on delete set null,
  reminder_lead_min integer check (reminder_lead_min is null or reminder_lead_min >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint event_time_order check (ends_at is null or ends_at >= starts_at)
);
create index if not exists academic_events_user_start_idx on public.academic_events (user_id, starts_at) where deleted_at is null;

-- ------------------------------------------------------------------ 6. Catatan pelajaran
create table if not exists public.subject_notes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  title text not null default '',
  body text not null default '',
  tags text[] not null default '{}',
  is_pinned boolean not null default false,
  version integer not null default 1,   -- optimistic concurrency: update harus menyertakan versi yang dibaca
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);
create index if not exists subject_notes_user_idx on public.subject_notes (user_id, updated_at desc) where deleted_at is null;

-- ------------------------------------------------------------------ 7. Dokumentasi: pemisahan ruang kerja
-- Data lama otomatis 'pkl' lewat default; tidak ada baris yang diubah atau dihapus.
alter table public.documentations
  add column if not exists workspace text not null default 'pkl',
  add column if not exists category text,
  add column if not exists subject_id uuid references public.subjects(id) on delete set null,
  add column if not exists task_id uuid references public.tasks(id) on delete set null;
do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'documentations_workspace_check') then
    alter table public.documentations add constraint documentations_workspace_check check (workspace in ('school', 'pkl'));
  end if;
  if not exists (select 1 from pg_constraint where conname = 'documentations_category_check') then
    alter table public.documentations add constraint documentations_category_check
      check (category is null or category in ('classroom', 'school_event', 'assignment', 'project', 'extracurricular', 'personal', 'other'));
  end if;
end $$;
create index if not exists documentations_user_workspace_idx on public.documentations (user_id, workspace, captured_at desc);

-- ------------------------------------------------------------------ 8. RLS + pemicu updated_at untuk semua tabel baru
do $$
declare t text;
begin
  foreach t in array array['subjects', 'timetable_entries', 'timetable_exceptions', 'tasks', 'task_attachments', 'academic_events', 'subject_notes'] loop
    execute format('alter table public.%I enable row level security', t);
    execute format('drop policy if exists "%s_own" on public.%I', t, t);
    execute format('create policy "%s_own" on public.%I for all using (user_id = auth.uid()) with check (user_id = auth.uid())', t, t);
    execute format('drop trigger if exists %I on public.%I', t || '_touch', t);
    execute format('create trigger %I before update on public.%I for each row execute function public.snoop_touch_updated_at()', t || '_touch', t);
  end loop;
end $$;

-- ------------------------------------------------------------------ Verifikasi (jalankan manual setelah migrasi)
-- select count(*) from public.documentations where workspace = 'pkl';   -- harus = jumlah dokumentasi sebelum migrasi
-- select count(*) from public.documentations where workspace is null;   -- harus 0
-- select count(*) from public.attendance_records;                       -- harus sama dengan sebelum migrasi

-- ------------------------------------------------------------------ Rollback (hanya objek baru; data PKL tidak tersentuh)
-- drop table if exists public.subject_notes, public.academic_events, public.task_attachments, public.tasks,
--   public.timetable_exceptions, public.timetable_entries, public.subjects cascade;
-- alter table public.documentations drop column if exists task_id, drop column if exists subject_id,
--   drop column if exists category, drop column if exists workspace;
-- alter table public.profiles drop column if exists timezone, drop column if exists academic_year,
--   drop column if exists major, drop column if exists class_name;

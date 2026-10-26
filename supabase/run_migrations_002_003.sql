-- Jalankan di Supabase > SQL Editor SETELAH schema.sql (aman dijalankan ulang).
-- SNOOP migrasi 002: absensi dengan waktu server.
-- Jalankan SETELAH schema.sql, di Supabase Dashboard > SQL Editor. Aman dijalankan ulang.

alter table public.attendance_records
  add column if not exists late boolean not null default false,
  add column if not exists time_source text not null default 'server'
    check (time_source in ('server', 'device_queued')),
  add column if not exists check_out_time_source text
    check (check_out_time_source in ('server', 'device_queued'));

-- Klien tidak boleh menulis absensi langsung (waktu bisa dimanipulasi).
-- Semua penulisan lewat fungsi di bawah, yang memakai now() milik server.
revoke insert, update, delete on public.attendance_records from anon, authenticated;

create or replace function public.snoop_check_in(
  p_id uuid,
  p_device_time timestamptz default null,
  p_queued boolean default false,
  p_work_start_min int default 480,
  p_tolerance_min int default 15,
  p_lat double precision default null,
  p_lng double precision default null,
  p_acc double precision default null
) returns public.attendance_records
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  t timestamptz := now();
  src text := 'server';
  rec public.attendance_records;
  local_min int;
  is_late boolean;
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  -- Idempoten: id yang sama mengembalikan catatan yang ada.
  select * into rec from public.attendance_records where id = p_id and user_id = uid;
  if found then return rec; end if;

  -- Dikirim belakangan (offline): pakai waktu perangkat hanya jika wajar (maks. 48 jam lalu, tidak di masa depan).
  if p_queued and p_device_time is not null
     and p_device_time <= now() and p_device_time >= now() - interval '48 hours' then
    t := p_device_time;
    src := 'device_queued';
  end if;

  -- Satu catatan per pengguna per tanggal kerja (Asia/Jakarta).
  select * into rec from public.attendance_records
   where user_id = uid
     and (check_in_at at time zone 'Asia/Jakarta')::date = (t at time zone 'Asia/Jakarta')::date;
  if found then return rec; end if;

  local_min := extract(hour from (t at time zone 'Asia/Jakarta'))::int * 60
             + extract(minute from (t at time zone 'Asia/Jakarta'))::int;
  is_late := local_min > p_work_start_min + p_tolerance_min;

  insert into public.attendance_records (
    id, user_id, check_in_at, status, late, time_source, device_time_at,
    check_in_latitude, check_in_longitude, check_in_accuracy_m
  ) values (
    p_id, uid, t, case when is_late then 'late' else 'present' end, is_late, src, p_device_time,
    p_lat, p_lng, p_acc
  ) returning * into rec;
  return rec;
end $$;

create or replace function public.snoop_check_out(
  p_id uuid,
  p_device_time timestamptz default null,
  p_queued boolean default false,
  p_lat double precision default null,
  p_lng double precision default null,
  p_acc double precision default null
) returns public.attendance_records
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  t timestamptz := now();
  src text := 'server';
  rec public.attendance_records;
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;

  select * into rec from public.attendance_records where id = p_id and user_id = uid for update;
  if not found then
    raise exception 'attendance_not_found' using errcode = 'P0002';
  end if;
  if rec.check_out_at is not null then return rec; end if; -- idempoten

  if p_queued and p_device_time is not null
     and p_device_time <= now() and p_device_time >= rec.check_in_at then
    t := p_device_time;
    src := 'device_queued';
  end if;
  if t < rec.check_in_at then
    raise exception 'checkout_before_checkin' using errcode = '22023';
  end if;

  update public.attendance_records
     set check_out_at = t, status = 'checked_out', check_out_time_source = src,
         check_out_latitude = p_lat, check_out_longitude = p_lng
   where id = p_id
   returning * into rec;
  return rec;
end $$;

revoke all on function public.snoop_check_in(uuid, timestamptz, boolean, int, int, double precision, double precision, double precision) from public, anon;
revoke all on function public.snoop_check_out(uuid, timestamptz, boolean, double precision, double precision, double precision) from public, anon;
grant execute on function public.snoop_check_in(uuid, timestamptz, boolean, int, int, double precision, double precision, double precision) to authenticated;
grant execute on function public.snoop_check_out(uuid, timestamptz, boolean, double precision, double precision, double precision) to authenticated;

-- Kolom upload Drive diisi hanya oleh Edge Function (service role); klien tidak perlu menulisnya.
-- Pengguna tetap boleh upsert metadata dokumentasi miliknya sendiri lewat policy RLS yang sudah ada.

-- Update 1.0.0 — Penyimpanan foto permanen di Google Drive.
-- Jalankan sekali di SQL Editor setelah schema.sql dan migration_002_server_time.sql.
-- Aman dijalankan ulang.

alter table public.documentations
  add column if not exists drive_size bigint,
  add column if not exists drive_uploaded_at timestamptz,
  add column if not exists upload_error text,
  add column if not exists upload_claimed_at timestamptz;

-- Satu file Drive hanya boleh dimiliki satu dokumentasi.
create unique index if not exists documentations_drive_file_id_key
  on public.documentations (drive_file_id) where drive_file_id is not null;

-- Klien (role authenticated) tidak boleh menulis kolom Drive / status unggah.
-- Tanpa ini pengguna bisa mengisi drive_file_id dengan id file milik orang lain lalu
-- membacanya lewat fungsi drive-photo. Hanya Edge Function (service_role) yang boleh mengubahnya.
create or replace function public.documentations_guard_drive_fields()
returns trigger language plpgsql as $$
begin
  if coalesce(auth.role(), '') = 'service_role' or current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.drive_file_id := null;  new.drive_file_url := null;  new.drive_size := null;
    new.drive_uploaded_at := null;  new.upload_status := 'pending';
    new.upload_error := null;  new.upload_claimed_at := null;
  else
    new.drive_file_id := old.drive_file_id;  new.drive_file_url := old.drive_file_url;
    new.drive_size := old.drive_size;  new.drive_uploaded_at := old.drive_uploaded_at;
    new.upload_status := old.upload_status;  new.upload_error := old.upload_error;
    new.upload_claimed_at := old.upload_claimed_at;
  end if;
  return new;
end $$;

drop trigger if exists documentations_guard_drive on public.documentations;
create trigger documentations_guard_drive
  before insert or update on public.documentations
  for each row execute function public.documentations_guard_drive_fields();

-- Penghapusan hanya lewat Edge Function drive-delete (menghapus file Drive lebih dulu),
-- supaya baris tidak terhapus sementara file Drive tertinggal.
drop policy if exists "documentations_own" on public.documentations;
drop policy if exists "documentations_select_own" on public.documentations;
drop policy if exists "documentations_insert_own" on public.documentations;
drop policy if exists "documentations_update_own" on public.documentations;
create policy "documentations_select_own" on public.documentations for select using (user_id = auth.uid());
create policy "documentations_insert_own" on public.documentations for insert with check (user_id = auth.uid());
create policy "documentations_update_own" on public.documentations for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Klaim unggahan atomik: mencegah dua permintaan (retry/ketukan ganda) mengunggah bersamaan.
-- Klaim kedaluwarsa setelah 2 menit supaya unggahan yang mati tidak memblokir selamanya.
create or replace function public.snoop_claim_upload(p_id uuid, p_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update public.documentations
     set upload_status = 'uploading', upload_claimed_at = now(), upload_error = null
   where id = p_id and user_id = p_user and drive_file_id is null
     and (upload_status <> 'uploading' or upload_claimed_at is null or upload_claimed_at < now() - interval '2 minutes');
  get diagnostics n = row_count;
  return n > 0;
end $$;
revoke all on function public.snoop_claim_upload(uuid, uuid) from public, anon, authenticated;
grant execute on function public.snoop_claim_upload(uuid, uuid) to service_role;

-- Muat ulang schema cache PostgREST agar fungsi baru terlihat oleh API
notify pgrst, 'reload schema';

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

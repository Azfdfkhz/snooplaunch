-- SNOOP migrasi 004 (Update 1.0.5): izin / sakit / lainnya sebagai pengganti absen masuk.
-- Jalankan SETELAH migrasi 003, di Supabase Dashboard > SQL Editor. Aman dijalankan ulang.

-- 1. Status baru 'leave' untuk absensi izin/sakit.
alter table public.attendance_records drop constraint if exists attendance_records_status_check;
alter table public.attendance_records add constraint attendance_records_status_check
  check (status in ('pending', 'present', 'late', 'checked_out', 'needs_attention', 'leave'));

-- 2. Jenis dan keterangan izin.
alter table public.attendance_records
  add column if not exists leave_type text check (leave_type in ('izin', 'sakit', 'lainnya')),
  add column if not exists note text;

-- 3. Fungsi pencatatan izin. Waktu dari server (now()), kecuali pengiriman tertunda (maks. 48 jam lalu).
create or replace function public.snoop_record_leave(
  p_id uuid,
  p_type text,
  p_note text default '',
  p_device_time timestamptz default null,
  p_queued boolean default false
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
  if p_type not in ('izin', 'sakit', 'lainnya') then
    raise exception 'invalid_leave_type' using errcode = '22023';
  end if;

  -- Idempoten: id yang sama mengembalikan catatan yang ada.
  select * into rec from public.attendance_records where id = p_id and user_id = uid;
  if found then return rec; end if;

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

  insert into public.attendance_records (
    id, user_id, check_in_at, status, late, time_source, device_time_at, leave_type, note
  ) values (
    p_id, uid, t, 'leave', false, src, p_device_time, p_type, nullif(left(coalesce(p_note, ''), 300), '')
  ) returning * into rec;
  return rec;
end $$;

revoke all on function public.snoop_record_leave(uuid, text, text, timestamptz, boolean) from public, anon;
grant execute on function public.snoop_record_leave(uuid, text, text, timestamptz, boolean) to authenticated;

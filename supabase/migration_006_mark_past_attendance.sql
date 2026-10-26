-- SNOOP migrasi 006 (Update 1.0.9): tandai hadir (masuk) untuk hari kerja lampau yang belum ada absensinya.
-- Jalankan di Supabase Dashboard > SQL Editor. Aman dijalankan ulang.
-- Catatan ditandai di kolom note agar mudah dibedakan dari absen real.

create or replace function public.snoop_mark_past_attendance(p_day date, p_note text default '')
returns public.attendance_records
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  today date := (now() at time zone 'Asia/Jakarta')::date;
  rec public.attendance_records;
  t_in timestamptz;
  t_out timestamptz;
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_day is null or p_day >= today then
    raise exception 'only_past_days' using errcode = '22023';
  end if;

  -- Sudah ada absensi di tanggal itu: kembalikan yang ada (idempoten, tidak menimpa).
  select * into rec from public.attendance_records
   where user_id = uid and (check_in_at at time zone 'Asia/Jakarta')::date = p_day;
  if found then return rec; end if;

  t_in := (p_day + time '07:50') at time zone 'Asia/Jakarta';
  t_out := (p_day + case when extract(isodow from p_day) = 6 then time '16:00' else time '17:00' end) at time zone 'Asia/Jakarta';

  insert into public.attendance_records (
    id, user_id, check_in_at, check_out_at, status, late, time_source, check_out_time_source, note
  ) values (
    gen_random_uuid(), uid, t_in, t_out, 'checked_out', false, 'server', 'server',
    nullif(left(coalesce(p_note, ''), 300), '')
  ) returning * into rec;
  return rec;
end $$;

revoke all on function public.snoop_mark_past_attendance(date, text) from public, anon;
grant execute on function public.snoop_mark_past_attendance(date, text) to authenticated;

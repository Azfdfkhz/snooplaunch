-- SNOOP migrasi 007 (Update 1.0.9 build 12): atur status hari lampau: hadir / izin / sakit / lainnya.
-- Jalankan di Supabase Dashboard > SQL Editor. Aman dijalankan ulang. Perlu migration_004 (kolom leave_type) sudah dijalankan.
-- Aturan:
--   * Hanya tanggal sebelum hari ini.
--   * Hari kosong: dibuat. Hari yang sudah ada: DIUBAH hanya bila bukan absen masuk asli
--     (tanpa koordinat lokasi), yaitu hasil backfill, tanda manual, atau izin/sakit sebelumnya.
--   * Absen asli dengan lokasi tidak ditimpa (error real_record_locked).

-- Pemeriksaan: tabel harus ada di project yang sedang terbuka. Bila tidak, skrip berhenti dengan pesan jelas.
do $$
begin
  if to_regclass('public.attendance_records') is null then
    raise exception 'Tabel public.attendance_records TIDAK ADA di project Supabase ini. Buka project yang dipakai aplikasi (ref akryjpsockddgptbnlnm) atau jalankan schema.sql dan migration_002..004 lebih dulu.';
  end if;
end $$;

-- Mengembalikan jsonb (baris absensi) agar tidak bergantung pada tipe tabel.
create or replace function public.snoop_set_past_status(p_day date, p_kind text, p_note text default '')
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  today date := (now() at time zone 'Asia/Jakarta')::date;
  rec record;
  t_in timestamptz;
  t_out timestamptz;
  note_txt text := nullif(left(coalesce(p_note, ''), 300), '');
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_day is null or p_day >= today then
    raise exception 'only_past_days' using errcode = '22023';
  end if;
  if p_kind not in ('hadir', 'izin', 'sakit', 'lainnya') then
    raise exception 'invalid_kind' using errcode = '22023';
  end if;

  t_in := (p_day + time '07:50') at time zone 'Asia/Jakarta';
  t_out := (p_day + case when extract(isodow from p_day) = 6 then time '16:00' else time '17:00' end) at time zone 'Asia/Jakarta';

  select * into rec from public.attendance_records
   where user_id = uid and (check_in_at at time zone 'Asia/Jakarta')::date = p_day;

  if found then
    if rec.check_in_latitude is not null then
      raise exception 'real_record_locked' using errcode = '22023';
    end if;
    if p_kind = 'hadir' then
      update public.attendance_records
         set check_in_at = t_in, check_out_at = t_out, status = 'checked_out', late = false,
             leave_type = null, note = coalesce(note_txt, 'Ditandai manual (lupa absen)'),
             time_source = 'server', check_out_time_source = 'server'
       where id = rec.id returning * into rec;
    else
      update public.attendance_records
         set check_in_at = t_in, check_out_at = null, status = 'leave', late = false,
             leave_type = p_kind, note = note_txt,
             time_source = 'server', check_out_time_source = null
       where id = rec.id returning * into rec;
    end if;
    return to_jsonb(rec);
  end if;

  if p_kind = 'hadir' then
    insert into public.attendance_records (id, user_id, check_in_at, check_out_at, status, late, time_source, check_out_time_source, note)
    values (gen_random_uuid(), uid, t_in, t_out, 'checked_out', false, 'server', 'server', coalesce(note_txt, 'Ditandai manual (lupa absen)'))
    returning * into rec;
  else
    insert into public.attendance_records (id, user_id, check_in_at, status, late, time_source, leave_type, note)
    values (gen_random_uuid(), uid, t_in, 'leave', false, 'server', p_kind, note_txt)
    returning * into rec;
  end if;
  return to_jsonb(rec);
end $$;

revoke all on function public.snoop_set_past_status(date, text, text) from public, anon;
grant execute on function public.snoop_set_past_status(date, text, text) to authenticated;
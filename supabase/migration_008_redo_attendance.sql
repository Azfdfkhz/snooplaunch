-- SNOOP migrasi 008: absen ulang untuk perbaikan (hanya hari ini, hanya milik sendiri).
-- Jalankan di Supabase Dashboard > SQL Editor. Aman dijalankan ulang.
-- Aturan:
--   * p_kind = 'masuk'  : catatan hari ini dihapus (hanya bila belum ada absen pulang). Absen masuk baru
--                         memakai waktu server saat itu, jadi jam tidak bisa dimundurkan.
--   * p_kind = 'pulang' : jam dan lokasi pulang dikosongkan; status kembali hadir/terlambat.
--   * Hanya tanggal hari ini (Asia/Jakarta); izin/sakit tidak bisa diulang dengan fungsi ini.
--   * Bila catatan belum ada di server, fungsi mengembalikan {"redone": false} (bukan error).

create or replace function public.snoop_redo_attendance(p_id uuid, p_kind text)
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  today date := (now() at time zone 'Asia/Jakarta')::date;
  rec public.attendance_records;
begin
  if uid is null then
    raise exception 'not_authenticated' using errcode = '28000';
  end if;
  if p_kind not in ('masuk', 'pulang') then
    raise exception 'invalid_kind' using errcode = '22023';
  end if;

  select * into rec from public.attendance_records where id = p_id and user_id = uid for update;
  if not found then
    return jsonb_build_object('redone', false);
  end if;
  if (rec.check_in_at at time zone 'Asia/Jakarta')::date <> today then
    raise exception 'only_today' using errcode = '22023';
  end if;
  if rec.status = 'leave' then
    raise exception 'not_a_check_in' using errcode = '22023';
  end if;

  if p_kind = 'masuk' then
    if rec.check_out_at is not null then
      raise exception 'checkout_exists' using errcode = '22023';
    end if;
    delete from public.attendance_records where id = rec.id;
  else
    update public.attendance_records
       set check_out_at = null, check_out_time_source = null,
           check_out_latitude = null, check_out_longitude = null,
           status = case when late then 'late' else 'present' end
     where id = rec.id;
  end if;
  return jsonb_build_object('redone', true);
end $$;

revoke all on function public.snoop_redo_attendance(uuid, text) from public, anon;
grant execute on function public.snoop_redo_attendance(uuid, text) to authenticated;

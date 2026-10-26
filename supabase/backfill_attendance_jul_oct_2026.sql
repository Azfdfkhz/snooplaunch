-- SNOOP — backfill absensi PKL (Juli–Oktober 2026). Jalankan di Supabase Dashboard > SQL Editor.
-- 1. Ganti EMAIL_ANDA dengan email akun SNOOP Anda (yang dipakai masuk di aplikasi).
-- 2. Aturan yang dipakai:
--    * 20–31 Juli 2026  : Senin–Sabtu hadir (PKL di tempat lain, masih masuk hari Sabtu).
--    * 1 Agustus 2026 s.d. kemarin : Senin–Jumat hadir (Sabtu & Minggu tidak dihitung).
--    * Jam masuk 07:50 WIB. Jam pulang 17:00 WIB (Senin–Jumat), 16:00 WIB (Sabtu).
--    * Hari ini TIDAK dimasukkan. Catat absen hari ini lewat aplikasi.
-- 3. Aman dijalankan ulang: hari yang sudah punya catatan tidak diduplikasi.
-- Catatan: hari libur nasional tidak dikecualikan. Jika ada, hapus dari daftar sebelum menjalankan.

with akun as (
  select id from auth.users where email = 'EMAIL_ANDA'
),
hari as (
  select d::date as tgl
  from generate_series(
    date '2026-07-20',
    (now() at time zone 'Asia/Jakarta')::date - 1,
    interval '1 day'
  ) as d
  where (d::date between date '2026-07-20' and date '2026-07-31' and extract(isodow from d) between 1 and 6)
     or (d::date >= date '2026-08-01' and extract(isodow from d) between 1 and 5)
)
insert into public.attendance_records (
  id, user_id, check_in_at, check_out_at, status, late, time_source, check_out_time_source
)
select
  gen_random_uuid(),
  akun.id,
  (hari.tgl + time '07:50') at time zone 'Asia/Jakarta',
  (hari.tgl + case when extract(isodow from hari.tgl) = 6 then time '16:00' else time '17:00' end) at time zone 'Asia/Jakarta',
  'checked_out',
  false,
  'server',
  'server'
from hari
cross join akun
where not exists (
  select 1 from public.attendance_records r
  where r.user_id = akun.id
    and (r.check_in_at at time zone 'Asia/Jakarta')::date = hari.tgl
);

-- Verifikasi (jalankan setelah insert): jumlah hari per bulan.
-- select to_char((check_in_at at time zone 'Asia/Jakarta'), 'YYYY-MM') as bulan, count(*)
-- from public.attendance_records r join auth.users u on u.id = r.user_id
-- where u.email = 'EMAIL_ANDA' group by 1 order by 1;

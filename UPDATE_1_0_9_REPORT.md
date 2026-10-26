# Update 1.0.9 — Tandai hadir untuk hari kosong dan layar api streak

**Status verifikasi:** BELUM dikompilasi (Flutter SDK tidak tersedia di lingkungan pembuatan).
Wajib sebelum rilis: `flutter analyze`, `flutter test`, dan uji di perangkat.

## 1. Hari kerja tanpa absensi bisa ditandai hadir
- Di Jadwal, pada tanggal lampau yang merah ("Tidak ada absensi" di hari kerja), muncul tombol **Tandai hadir (masuk)**.
- Catatan yang dibuat: masuk 07:50, pulang 17:00 (Sabtu 16:00), status selesai, dan catatan "Ditandai manual (lupa absen)".
- Fungsi server baru: `snoop_mark_past_attendance` (`supabase/migration_006_mark_past_attendance.sql`, **wajib dijalankan**).
  Hanya untuk tanggal sebelum hari ini. Tidak menimpa absensi yang sudah ada.
- Memerlukan akun cloud dan koneksi.
- Cara lain untuk banyak hari sekaligus: jalankan ulang `supabase/backfill_attendance_jul_oct_2026.sql`. Script itu hanya mengisi hari yang masih kosong.
  Perhatikan bahwa script itu juga menganggap 17 Agustus 2026 (Senin) sebagai hadir. Hapus tanggal itu bila Anda tidak hadir.

## 2. Layar api streak (gaya TikTok)
- Ketuk api di Beranda atau Jadwal untuk membuka layar penuh.
- Isi layar: api besar yang berdenyut dengan angka streak di dalamnya, pesan status hari ini, deretan 7 hari minggu ini (hadir, izin/sakit, tidak hadir, akhir pekan), rekor, total hadir, kalender 5 minggu terakhir, dan tombol **Bagikan streak**.
- Angka pada api naik secara animasi saat layar dibuka.

## 3. Berkas
- Ditambah: `supabase/migration_006_mark_past_attendance.sql`, `UPDATE_1_0_9_REPORT.md`.
- Diubah: `lib/screens/streak_screen.dart` (diganti total), `lib/screens/schedule_screen.dart`, `lib/screens/home_screen.dart`,
  `lib/core/state.dart`, `lib/services/backend_service.dart`, `pubspec.yaml` (1.0.9+10).

# Update 1.0.5 — Laporan perubahan

**Status verifikasi:** BELUM dikompilasi. Flutter SDK tidak tersedia di lingkungan pembuatan. Sebelum rilis wajib
dijalankan: `flutter pub get`, `flutter analyze`, `flutter test`, lalu uji di perangkat Android.
Pemeriksaan yang sudah dilakukan: keseimbangan kurung di seluruh berkas Dart, dan tidak ada pemanggilan API lama yang tersisa.

## 1. Jadwal per hari (perbaikan bug)
- Status kegiatan sebelumnya disimpan sekali per kegiatan, sehingga "selesai" hari Senin terbawa ke hari berikutnya.
  Sekarang status dicatat per tanggal (`ScheduleItem.days`). Data lama dengan status tunggal diabaikan (dianggap belum dicatat).
- Hari lalu yang tidak dicatat ditampilkan "Terlewat". Hari ini memakai jam, hari depan "Akan datang".

## 2. Jam pulang 17:00 (Senin–Jumat)
- Jam pulang Senin–Jumat = 17:00. Sabtu–Minggu tetap 16:00 **(asumsi)**: permintaan tidak menyebut jam akhir pekan.
  Dapat diubah di Pengaturan > Jam kerja.
- Migrasi otomatis dari data v1: jam pulang 16:00 dipindah ke 17:00; kegiatan "Absen Pulang" dan pengingat "absen" ikut dipindah.

## 3. Izin / sakit / lainnya saat absen masuk
- Tombol absen masuk membuka pilihan: Hadir (ambil foto), Izin, Sakit, Lainnya. Izin/sakit meminta keterangan opsional.
- Status baru `leave` di aplikasi. Di server: `supabase/migration_004_leave_and_drive_trash.sql` (wajib dijalankan).
- Izin tidak dihitung sebagai kehadiran untuk streak dan ringkasan minggu.

## 4. Navigasi swipe (kiri/kanan)
- Urutan halaman: Drawer ← Beranda → Jadwal → Memories → Pengingat → Pengaturan.
- Navbar kapsul sekarang 5 tab. Tab **Profil dihapus**; isinya dipindah ke bagian atas Pengaturan.

## 5. Animasi gaya iOS
- Transisi halaman `CupertinoPageTransitionsBuilder` di semua platform.
- Gulir memantul (`BouncingScrollPhysics`) dan tanpa efek glow Android.
- Perpindahan tanggal di Jadwal memakai fade + slide.

## 6. Tanggal dan riwayat
- Jadwal menampilkan tanggal yang dipilih: panah kiri/kanan, pemilih tanggal, dan tombol "Hari ini".
- Per tanggal: status kegiatan, kartu absensi (masuk, pulang, terlambat, izin/sakit), dan penanda kehadiran di strip minggu.
- Mode Mingguan: ringkasan tiap hari dan catatan minggu (tugas, target, keterangan) yang tersimpan per minggu.

## 7. Hapus foto
- Penghapusan dokumentasi di Drive sekarang memindahkan file ke **Sampah Google Drive** (bisa dipulihkan ±30 hari), bukan hapus permanen.
  Ubah `supabase/functions/_shared/drive.ts` — **redeploy Edge Function `drive-delete`** (dan `drive-upload` bila ikut dipakai).
- Menghapus aplikasi dari perangkat **tidak bisa** menghapus file Drive: Android tidak menjalankan kode saat aplikasi dihapus.
  Solusi yang ditambahkan: Pengaturan > Data > "Hapus semua dokumentasi" (menghapus dari Drive dan perangkat). Sebaiknya dilakukan sebelum menghapus aplikasi.

## 8. Pengingat
- Pengingat "Setiap 2 jam" / "Setiap 4 jam" sebelumnya hanya berbunyi sekali sehari. Sekarang berulang sampai jam pulang.
- Pilihan baru: Sekali sehari / Tiap 2 jam / Tiap 4 jam, dan "Hanya Senin–Jumat".
- Pengingat dapat diubah (ketuk). Pengingat absen pulang memakai 17:00 dan Senin–Jumat.
- Notifikasi lama dibatalkan sebelum pengingat diubah atau dihapus.

## 9. Berkas yang diubah / ditambah / dihapus
- Diubah: `lib/core/models.dart`, `lib/core/state.dart`, `lib/core/theme.dart`, `lib/core/widgets.dart`,
  `lib/services/notification_service.dart`, `lib/services/backend_service.dart`, `lib/main.dart`,
  `lib/screens/shell.dart`, `lib/screens/home_screen.dart`, `lib/screens/schedule_screen.dart`,
  `lib/screens/reminders_screen.dart`, `lib/screens/settings_screen.dart`, `lib/screens/checkin_screen.dart`,
  `lib/screens/memories_screen.dart`, `supabase/functions/_shared/drive.ts`.
- Ditambah: `supabase/migration_004_leave_and_drive_trash.sql`, `UPDATE_1_0_5_REPORT.md`.
- Dihapus: `lib/screens/profile_screen.dart`.

## 10. Belum dikerjakan / perlu konfirmasi
- Jam pulang Sabtu–Minggu (16:00, asumsi) — mohon konfirmasi.
- Pengingat interval belum memperhitungkan hari libur.
- Layar Absensi (foto, pratinjau, hasil), Login, dan Splash belum diuji visualnya.
- Tema gelap penuh (dari laporan sebelumnya) belum dikerjakan.
- Tanggal picker memakai bahasa default Material (Inggris) karena belum ada delegasi lokalisasi.

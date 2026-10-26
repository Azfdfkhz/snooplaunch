# Update 1.0.8 — Riwayat absensi dari server dan api streak

**Status verifikasi:** BELUM dikompilasi (Flutter SDK tidak tersedia di lingkungan pembuatan).
Wajib sebelum rilis: `flutter analyze`, `flutter test`, dan uji di perangkat dengan akun yang sudah memiliki data backfill.

## 1. Riwayat absensi dari server
- Sebelumnya aplikasi hanya membaca absensi lokal. Data yang sudah ada di server (termasuk hasil SQL backfill) tidak tampil.
- Sekarang seluruh riwayat ditarik dari server saat aplikasi dibuka, setelah masuk akun, dan saat koneksi kembali.
  Pengambilan dipaginasi per 1000 baris, sehingga tidak lagi dibatasi 60 baris.
- Catatan lokal yang belum terkirim tidak ditimpa. Antrean akan mengirimnya.
- Data ini memengaruhi Jadwal (per tanggal), penanda kalender, dan streak.
- Syarat: akun harus sudah masuk. Tanpa akun, aplikasi hanya menampilkan data di perangkat.

## 2. Api streak
- Aturan:
  - Hari kerja berturut-turut dengan absensi menambah streak.
  - Akhir pekan tanpa absensi tidak memutus streak.
  - Izin atau sakit tidak memutus streak.
  - Hari kerja tanpa absensi memutus streak.
  - Hari ini yang belum absen belum dianggap putus.
- Api streak tampil di Beranda (kartu absensi) dan Jadwal.
- Ketuk api untuk melihat lembar detail: streak saat ini, rekor, total hadir, dan kalender 5 minggu terakhir
  (hadir, izin/sakit, hari kerja tanpa absensi).
- Catatan: hari libur nasional belum diperhitungkan. Hari libur yang tidak masuk absensi akan memutus streak.

## 3. Berkas
- Diubah: `lib/core/state.dart`, `lib/services/backend_service.dart`, `lib/core/widgets.dart`,
  `lib/screens/home_screen.dart`, `lib/screens/schedule_screen.dart`, `pubspec.yaml` (1.0.8+9).
- Ditambah: `lib/screens/streak_screen.dart`, `UPDATE_1_0_8_REPORT.md`.

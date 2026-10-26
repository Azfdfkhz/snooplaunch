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

## 4. Perbaikan lanjutan (build 11)

**Status verifikasi:** BELUM dikompilasi (Flutter SDK tidak tersedia). Jalankan `flutter analyze`, `flutter test`, lalu uji di perangkat.

### Streak turun dari 65 menjadi 2 setelah pindah ke aplikasi lain
Penyebab yang ditemukan di kode:
- Penyimpanan lokal (`_save`) berjalan tanpa ditunggu dan bisa tumpang tindih. Aplikasi launcher mudah dimatikan sistem saat pengguna membuka aplikasi lain, sehingga catatan yang baru ditandai bisa belum tertulis.
- Tidak ada penanganan lifecycle: saat aplikasi ke latar belakang data tidak dipaksa tersimpan, dan saat kembali ke depan riwayat tidak dimuat ulang dari server.
- Pembacaan data lokal melewati catatan yang tidak terbaca, lalu simpan berikutnya menimpa daftar yang sudah terpotong.

Perbaikan:
- `AppState._save` diganti antrean berurutan; seluruh data di-encode lebih dulu sehingga satu simpan = satu keadaan utuh. Ada `flush()` untuk menunggu selesai.
- `Shell` memanggil `onAppPaused()` (simpan) saat aplikasi ke latar belakang dan `onAppResumed()` saat kembali: kirim antrean tertunda lalu muat ulang riwayat dari server (maks. 1x per 20 detik).
- **Tandai hadir** kini langsung memasukkan baris dari server ke data lokal dan menunggu penyimpanan selesai, bukan menunggu tarik ulang seluruh riwayat.
- `pullAttendanceFromServer` menggabungkan semua baris lalu menyimpan sekali; satu baris rusak tidak menggagalkan yang lain; tidak berjalan ganda.
- Pelindung data: hari absensi yang pernah dimuat dan tiba-tiba hilang dari daftar dikembalikan sebelum menyimpan. `Attendance.fromJson` tidak lagi gagal karena indeks status di luar jangkauan.
- Tes baru di `test/state_test.dart`: streak 65 hari bertahan setelah simpan dan muat ulang; hari yang hilang dikembalikan.

### UI api streak
- Ikon api bawaan (yang membuat angka tampak berada di lubang bergaris) diganti api gambar sendiri: `lib/core/flame.dart`.
- Satu ujung utama + lidah api kecil, gradasi, dan inti terang tempat angka berada. Angka tiga digit mengecil otomatis.
- Warna naik tingkat: 1–6 hari kuning, 7–29 oranye, 30+ merah-oranye. Streak 0 = api abu-abu.
- Animasi: berkibar halus, berdenyut, percikan naik, cahaya lembut di belakang. Mengikuti pengaturan "kurangi animasi" perangkat.
- Hari kerja ini belum absen padahal streak > 0: api redup tanpa percikan sebagai pengingat.
- Penanda hari "hadir" di deret 7 hari dan badge di Beranda/Jadwal memakai bentuk api yang sama.

### Berkas
- Baru: `lib/core/flame.dart`.
- Diubah: `lib/core/state.dart`, `lib/core/models.dart`, `lib/core/widgets.dart`, `lib/screens/streak_screen.dart`, `lib/screens/shell.dart`, `test/state_test.dart`, `pubspec.yaml` (1.0.9+11).

## 5. Status hari lampau: hadir / izin / sakit / lainnya (build 12)

**Status verifikasi:** BELUM dikompilasi. **Wajib dijalankan di Supabase:** `supabase/migration_007_set_past_status.sql`.

Masalah: tombol di Jadwal hanya bisa "Tandai hadir", dan hari yang dulu izin/sakit (atau terisi hadir oleh script backfill) tidak bisa diperbaiki, sehingga streak salah.

- Fungsi server baru `snoop_set_past_status(tanggal, jenis, catatan)` dengan jenis `hadir`, `izin`, `sakit`, `lainnya`.
  - Hari kosong dibuat. Hari yang sudah ada **diubah** bila bukan absen masuk asli (tanpa koordinat lokasi): hasil backfill, tanda manual, atau izin/sakit sebelumnya.
  - Absen asli dengan lokasi tidak ditimpa. Hanya tanggal sebelum hari ini.
- Jadwal: hari kerja kosong menampilkan **Tandai: hadir / izin / sakit**; hari lampau yang sudah terisi (dan boleh diubah) menampilkan **Ubah status**. Izin/sakit/lainnya meminta keterangan.
- Aturan streak tidak berubah: izin/sakit tidak memutus streak dan tidak menambah hitungan.
- Berkas: baru `supabase/migration_007_set_past_status.sql`; diubah `lib/core/state.dart`, `lib/services/backend_service.dart`, `lib/screens/schedule_screen.dart`, `test/state_test.dart`, `pubspec.yaml` (1.0.9+12).

## 6. Pilihan status langsung tampil (build 13)
Di Jadwal, hari kerja lampau yang kosong kini menampilkan tombol **Hadir · Izin · Sakit** langsung di kartu Absensi, plus **Alasan lain**. Tidak perlu membuka menu dulu. Izin/sakit/lainnya tetap meminta keterangan. `pubspec.yaml` 1.0.9+13. Tetap wajib menjalankan `migration_007_set_past_status.sql`.

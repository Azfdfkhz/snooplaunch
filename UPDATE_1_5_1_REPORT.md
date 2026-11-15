# SNOOP 1.5.1

**Status: BELUM dikompilasi.** Flutter/Dart SDK tidak tersedia di lingkungan pengerjaan (sama seperti 1.5.0), jadi
`flutter analyze`, `flutter test`, dan build APK belum dijalankan. Yang sudah dilakukan: tinjauan manual, pemeriksaan keseimbangan
kurung pada file yang diubah, dan tes baru yang ditulis (belum dijalankan). Jalankan `flutter analyze && flutter test` sebelum rilis.

## 1. App Drawer menjadi popup (tanpa geser ke samping)
- `lib/screens/shell.dart`: App Drawer **bukan lagi halaman PageView**. Halaman geser kini: Beranda, Jadwal, Memories, Pengingat, Pengaturan.
  Nomor halaman logis tetap 1..5 (indeks PageView = nomor - 1), jadi semua `onGoTo(n)` di Home tidak berubah.
- `lib/screens/app_drawer_screen.dart`: fungsi baru `showAppDrawerPopup(context)` (panel kaca/blur membulat, animasi skala dari kanan bawah,
  dekat tombol dock) dan parameter `popup` pada `AppDrawerScreen` (latar transparan, tombol tutup X). Isi drawer (pencarian, kategori,
  favorit, tekan lama) tidak berubah.
- Ditutup: tombol X, ketuk area gelap, tombol kembali sistem, tombol Home, atau setelah sebuah aplikasi dibuka.
- Dibuka dari tombol grid di dock (ketuk) atau geser dock ke atas (tetap ada).
- Swipe kanan dari Beranda tidak lagi membuka drawer.

## 2. Profil tidak lagi kembali ke placeholder
Akar masalah (dua lapis):
1. **Profil tidak pernah ada di cloud.** Tabel `profiles` ada tapi aplikasi tidak memakainya, jadi login cloud tidak mengembalikan apa pun.
2. **Update memakai kunci tanda tangan berbeda.** `build.gradle.kts` menandatangani dengan *debug key* mesin build. Bila APK 1.5.0 dan 1.5.1
   dibuild dengan kunci berbeda, Android menolak update, pengguna harus uninstall, dan seluruh data lokal (profil, memories) hilang.

Perbaikan:
- `AppState`: flag `profileSet` (+ `profile_dirty`) yang disimpan lokal. `syncProfile()` dua arah: perubahan lokal yang belum terkirim menang
  dan dikirim ke cloud; selain itu profil cloud dipakai. Dipanggil saat start, saat login/perubahan sesi, dan saat aplikasi kembali ke depan.
  Edit profil langsung dikirim ke cloud bila sudah masuk (bila offline, dikirim nanti).
- `BackendService.fetchProfile/upsertProfile`. Bila kolom `period` belum ada, kolom lain tetap tersimpan.
- `supabase/migration_009_profile_period.sql`: menambah kolom `period` di `profiles`. **Jalankan sekali di SQL Editor.**
- `android/app/build.gradle.kts`: bila `android/key.properties` ada, debug dan release memakai kunci tetap yang sama.
  Contoh: `android/key.properties.example`.

**Penting supaya update berikutnya tidak menghapus data**
1. Pasang 1.5.1 sebagai update di atas 1.5.0 hanya bila keduanya ditandatangani kunci yang sama. Di mesin yang membuild 1.5.0:
   `cp ~/.android/debug.keystore android/snoop.keystore`, lalu salin `android/key.properties.example` ke `android/key.properties`
   (alias `androiddebugkey`, sandi `android`). Itu kunci yang sama dengan build sebelumnya, jadi update tidak perlu uninstall.
2. Bila 1.5.0 di HP sudah terlanjur dibuild di mesin lain dan pemasangan ditolak, **masuk ke akun cloud dulu** (profil + memories akan
   dimuat dari cloud setelah 1.5.1 dipasang), baru uninstall dan pasang 1.5.1. Setelah itu pakai kunci tetap yang sama selamanya.
3. Profil yang diisi **sebelum** 1.5.1 belum ada di cloud. Setelah update, buka Pengaturan > Edit Profil sekali dan simpan (saat sudah masuk akun cloud).

## 3. Memories
**Data (tidak tampil setelah update):** dokumentasi hanya dibaca dari penyimpanan lokal. Kini:
- `AppState.pullMemoriesFromServer()`: memuat tabel `documentations` dari cloud (judul, waktu, lokasi, deskripsi, referensi foto Drive) dan
  menggabungkannya. Data lokal tidak ditimpa; foto yang sudah terkonfirmasi di Drive diperbarui statusnya. Dipanggil saat start, login,
  aplikasi kembali ke depan, saat halaman Memories dibuka, dan tarik-ke-bawah.
- Dokumentasi yang sengaja dihapus di perangkat dicatat (`deleted_memories`) supaya tidak muncul lagi.
- Foto asli tetap diambil lewat Edge Function Drive (tidak berubah). Dokumentasi yang foto di Drive-nya memang tidak pernah terunggah
  tampil dengan status "Foto tidak terunggah" (datanya tetap ada).

**UI:** `MemoriesScreen` memakai bahasa visual Beranda 1.5.0: latar krem, judul piksel, jumlah foto, filter berbentuk pil oranye,
kartu foto membulat dengan penanda status cloud, tarik-untuk-muat-ulang, dan pesan kosong yang jelas (mengarahkan masuk akun cloud bila belum masuk).
Layar detail memori tidak diubah.

## 4. Sabtu dan Minggu libur
- `SessionPhase.holiday` (baru) di `attendance_session.dart`: Sabtu/Minggu **tanpa catatan** = libur. Tidak ada jendela absen masuk/pulang,
  tidak ada status "terlewat", tidak ada popup otomatis, tidak ada tombol absen.
- Beranda: lingkaran absensi menampilkan "Libur / Akhir Pekan"; kartu absensi menampilkan "Hari libur"; timeline "Libur".
- Jadwal: "Absen Masuk"/"Absen Pulang" bawaan tidak muncul di Sabtu/Minggu (tidak memengaruhi hitungan countdown/Berikutnya).
- Bila sudah ada catatan di akhir pekan (mis. izin), tampilan catatan itu tetap dipakai. Streak sudah mengabaikan akhir pekan sejak sebelumnya.
- Batasan: ini aturan di aplikasi. Fungsi SQL `snoop_check_in` tidak diubah, jadi server belum menolak absen akhir pekan dari klien lain.

## File yang berubah
`lib/core/attendance_session.dart`, `lib/core/state.dart`, `lib/services/backend_service.dart`, `lib/screens/shell.dart`,
`lib/screens/app_drawer_screen.dart`, `lib/screens/memories_screen.dart`, `lib/screens/home_screen.dart`,
`lib/features/home/controllers/home_controller.dart`, `android/app/build.gradle.kts`, `pubspec.yaml` (1.5.1+151),
`supabase/migration_009_profile_period.sql` (baru), `android/key.properties.example` (baru), `.gitignore`,
tes: `attendance_session_test`, `home_controller_test`, `state_test`.

## Checklist uji di perangkat
- [ ] Dock: ketuk tombol grid membuka popup; X / ketuk luar / Back menutup; buka aplikasi menutup popup; Beranda tidak bergeser ke drawer.
- [ ] Edit profil, tutup aplikasi, buka lagi: nama tetap. Pasang update di atas versi lama: nama tetap.
- [ ] Masuk akun cloud di HP baru/pasang ulang: nama, sekolah, perusahaan, periode kembali.
- [ ] Memories: daftar muncul setelah update dan setelah login; tarik ke bawah memuat ulang; foto Drive tampil.
- [ ] Sabtu/Minggu: tidak ada popup absen, lingkaran "Libur", tidak ada "Absen Masuk" di Jadwal. Senin: kembali normal.
- [ ] `flutter analyze` dan `flutter test` bersih.

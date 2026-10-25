# Status pengerjaan SNOOP

## Sudah dibuat
- Design system: palet dari gambar (#F5F4F6, #E8E6E8, #D8E8DE, #C9DDEB, #F2B7C5, #29282A), kartu membulat, tombol pil, navbar kapsul gelap, kartu polaroid
- 10 layar: Splash, Beranda, Absensi Masuk/Pulang (+preview & konfirmasi), Jadwal (+tambah, tandai selesai), Pengingat (+tambah, hapus geser, toggle), App Drawer (cari, favorit via tekan lama, buka app), Memories (filter), Detail Memori (hapus), Profil, Pengaturan
- Absensi: kamera, lokasi aktual (tanpa polling), reverse geocoding, status Hadir/Terlambat (toleransi 15 mnt), cegah duplikasi per hari, tautan otomatis ke jadwal terdekat
- Launcher Android native: intent HOME, daftar aplikasi + ikon, buka aplikasi, info aplikasi, buka pengaturan launcher default
- Data lokal tersimpan (SharedPreferences)
- supabase/schema.sql: 5 tabel + RLS + constraint 1 absensi/hari

## Belum dibuat / belum selesai
- TIDAK DIUJI: Flutter SDK tidak tersedia di lingkungan ini, jadi kode belum pernah dikompilasi. Kemungkinan ada error kecil saat `flutter analyze`.
- Notifikasi pengingat sungguhan (AlarmManager / flutter_local_notifications, reboot, zona waktu, tunda). Saat ini pengingat hanya data + UI.
- Integrasi Supabase (auth, sinkronisasi, antrean offline) — hanya kontrak `SyncService` + SQL
- Upload Google Drive (Edge Function + OAuth) — belum ada
- Maskot: placeholder ikon; ganti dengan ilustrasi di assets/
- Pengelompokan kategori di App Drawer (hanya favorit + semua aplikasi)
- Jadwal mingguan: masih template harian yang sama; kalender per tanggal belum
- Tema gelap, ukuran font, edit profil, absensi offline berstatus Pending
- Peta "Lihat di Google Maps" di detail memori


## Perubahan revisi production-hardening (belum build-verified)
- Notifikasi lokal sungguhan untuk pengingat harian, izin Android 13+, kanal notifikasi, dan receiver reboot/perubahan zona waktu.
- Pilihan tema terang/gelap dan edit profil tersimpan.
- Kategori App Drawer berbasis heuristik.
- UUID untuk absensi/memori baru agar sesuai tipe UUID pada Supabase.
- Bootstrap Supabase via `--dart-define`, adapter metadata, dan antrean retry persisten.
- Tombol Google Maps di detail memori; penghapusan memori juga mencoba menghapus foto lokal.
- SQL mendapat constraint koordinat, indeks query, dan trigger `updated_at`.
- Baca `PRODUCTION_READINESS.md`: autentikasi UI, upload Drive, kalender per tanggal, antrean SQLite/background worker, pengujian device, dan audit rilis masih diperlukan. Flutter/Dart SDK tidak tersedia pada lingkungan pembuatan ZIP, sehingga belum bisa dijalankan `flutter pub get`, `flutter analyze`, atau tes Android.

## Revisi UI + swipe (PRD SnoopUpdate, Tahap 2-3) — BELUM dikompilasi
- Design tokens baru (`C`, `R`, `S` di `lib/core/theme.dart`): sky blue + ivory + charcoal; alias lama dipertahankan.
- Home didesain ulang: kartu absensi dinamis (sky saat belum absen, charcoal setelah), baris kehadiran minggu ini, streak, progres tugas (semua dari data aktual), jadwal dengan penanda "Berlangsung", pengingat berikutnya. Jam punya timer sendiri.
- Navigasi: `Shell` memakai PageView. Swipe kanan dari Home -> App Drawer, swipe kiri -> Home. Swipe dikunci di tab selain Beranda. Tombol kembali: Drawer -> Home -> tab Beranda. Tombol alternatif "Aplikasi" di Home.
- App Drawer: tertanam di PageView, cache daftar aplikasi (`LauncherService`), urut A-Z, segar otomatis saat halaman dibuka (maks. 1x/30 dtk).
- Belum: absensi online (waktu server/RPC, login UI), dark mode penuh, statistik, antrean SQLite, ukur performa.
- Catatan: `android_overrides/MainActivity.kt` (package com.snoop.snoop) berbeda dari `android/.../com/example/snoop/MainActivity.kt`. Samakan package dengan applicationId sebelum build.

## Revisi 2: stabilitas, backend, Drive, redesain (BELUM dikompilasi)
- Startup: `main()` hanya membaca penyimpanan lokal lalu `runApp`; Supabase, notifikasi (dialog izin), dan sinkronisasi jalan di latar (`AppState.startBackground`). Sebelumnya startup menunggu dialog izin dan jaringan.
- Error build tidak lagi layar merah penuh: `ErrorWidget.builder` menampilkan kartu kecil dengan pesan asli (screenshot untuk pelacakan). Error async tidak mematikan aplikasi.
- Data lokal rusak/lama dilewati per elemen saat dibaca.
- Performa: tab dibangun saat pertama dikunjungi, tanpa I/O sinkron saat render foto, tanpa blur shadow di grid aplikasi, jam punya timer sendiri.
- Backend: `lib/core/env.dart` (URL/anon key), `AuthScreen` (masuk/daftar), kartu status sinkronisasi di Pengaturan, banner di Home, izin INTERNET di manifest override.
- Absensi: fungsi SQL `snoop_check_in/out` (waktu server, idempoten, satu per hari, pulang tidak sebelum masuk); klien tidak bisa menulis tabel absensi langsung. Absen offline ditandai "menunggu server" dan, bila dikirim belakangan, waktu perangkat divalidasi (maks. 48 jam) dan ditandai `device_queued`.
- Drive: Edge Function `supabase/functions/drive-upload` (OAuth refresh token di Secrets server). Panduan: `supabase/SETUP.md`.
- UI: logo geometris SnoopMark, kartu berlekuk (NotchCard) dengan tombol bulat, nav kapsul gelap, tipografi besar/berat, cincin progres, animasi masuk. Tema gelap dinonaktifkan sementara (token warna masih statis terang).
- Tes: `test/state_test.dart` (belum dijalankan).

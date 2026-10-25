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

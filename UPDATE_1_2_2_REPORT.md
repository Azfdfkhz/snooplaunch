# Update 1.2.2 — Island bulat, Spotify + lirik, panggilan WhatsApp, timer kiri–kanan kamera

## Status verifikasi (jujur)
- **BELUM dikompilasi dan BELUM dijalankan di perangkat.** Flutter SDK dan Android SDK tidak tersedia di lingkungan pembuatan.
- Yang SUDAH dicek: sintaks semua berkas Dart yang diubah (`dart format`), analisis statis + uji perilaku untuk kode Dart murni
  (`lib/core/media_models.dart`, `lib/services/lyrics_service.dart`: 23 pernyataan lulus). Kode Kotlin hanya ditinjau manual.
- Jalankan: `flutter pub get`, `flutter analyze`, `flutter test`, lalu `flutter run` di Samsung A51.
- Tidak ada dependensi baru di `pubspec.yaml` (hanya versi → 1.2.2+17).

## 1. Island diam = bulat, tanpa teks
`dynamic_island.dart`: mode `idle` kini bulatan hitam polos selebar tingginya (mengelilingi kamera), tanpa teks. Status absensi
tetap ada di tab Info dan dibacakan lewat label aksesibilitas.

## 2. Island tertutup ikon status (Bluetooth, mode getar, dll.)
Penyebab: Island digambar di dalam aplikasi, di bawah ikon status bar milik sistem, jadi ikon selalu menimpa bagian Island yang
melebar. Perubahan:
- Bulatan diam cukup kecil untuk muat di area kamera.
- Saat Island melebar (timer/musik, banner, panggilan, hub), **status bar sistem disembunyikan sementara** dan muncul lagi saat
  Island kembali bulat atau aplikasi ke latar belakang (`IslandController._applyChrome`). Hanya status bar; bilah navigasi tetap.
- `main.dart` → `_StableTop` menahan `padding.top` supaya halaman tidak melompat naik saat status bar hilang.
- Pengaturan → "Sembunyikan status bar saat Island melebar" (bawaan aktif). Bila dimatikan, mode lebar turun ke bawah status bar.
- Konsekuensi: selama Pomodoro berjalan (mode lebar), jam/baterai status bar tidak terlihat di layar SNOOP.
- Android sudah memakai `windowLayoutInDisplayCutoutMode=shortEdges` (values-v28/styles.xml), jadi area kamera tetap terpakai.

## 3. Spotify terdeteksi + lirik
- Native: `SnoopNotificationListener.kt` (NotificationListenerService) membaca MediaSession aktif (judul, artis, album, durasi,
  posisi, sampul) dan meneruskan kontrol putar/jeda/berikutnya/sebelumnya/seek. Bukan khusus Spotify: YouTube Music dll. ikut terbaca.
- Wajib: **Akses notifikasi** untuk SNOOP (Pengaturan → "Deteksi Spotify & panggilan WhatsApp", atau tombol di tab Musik).
- Tab Musik: kartu "sedang diputar" (sampul, kontrol, seek, lirik 3 baris yang bergulir). Pemutar lokal tetap ada (tombol
  "Pemutar lokal" / "Lagu Spotify" untuk berpindah). Pemutar lokal yang sedang memutar diprioritaskan.
- Lirik: `lyrics_service.dart` → LRCLIB (https://lrclib.net, gratis, tanpa kunci). Dicari sekali per lagu dari judul + artis + album +
  durasi, lalu pencarian cadangan. Perlu internet; tidak semua lagu ada; hasil "tidak ditemukan" di-cache, gagal jaringan bisa
  diketuk untuk coba lagi.

## 4. Panggilan WhatsApp di Island + jawab dari Island
- Native membaca notifikasi `com.whatsapp` / `com.whatsapp.w4b` yang punya aksi bertuliskan Jawab/Terima/Answer (atau kategori
  panggilan + full-screen intent). Aksi dicocokkan lewat judul tombol (Indonesia/Inggris), bukan urutan.
- Island menampilkan kartu: nama penelepon, suara/video, tombol **Tolak** (merah) dan **Jawab** (hijau). Geser kartu ke atas =
  sembunyikan kartu tanpa menolak. Kartu hilang saat notifikasi panggilan hilang/berubah (dijawab, ditolak, terlewat).
- Bila aksi "Jawab" tidak ditemukan, tombol hijau menjadi "Buka WhatsApp" (membuka layar panggilan WhatsApp).

## 5. Pomodoro saat mengecil: loader kiri, waktu kanan
Mode ringkas kini tiga bagian: cincin progres (dan equalizer bila musik) di pojok kiri, celah tengah selebar kamera
(lebar cutout + 12 dp, diambil dari `MediaQuery.displayFeatures`), waktu di pojok kanan. Mode hanya musik: equalizer kiri, judul kanan.

## Berkas
Baru: `lib/core/media_models.dart`, `lib/services/lyrics_service.dart`, `lib/services/system_bridge.dart`,
`android/.../SnoopNotificationListener.kt`, `test/lyrics_test.dart`, `test/system_bridge_test.dart`.
Diubah: `dynamic_island.dart`, `island_service.dart`, `main.dart`, `settings_screen.dart`, `MainActivity.kt`
(channel `snoop/system`), `AndroidManifest.xml` (service listener), `test/island_test.dart`, `pubspec.yaml`.
`android_overrides/` TIDAK diubah (sudah tertinggal dari `android/`; jangan pakai `setup.sh` di atas proyek ini).

## Batasan yang perlu diketahui
- Island tetap overlay di dalam aplikasi SNOOP: kartu panggilan/lagu hanya terlihat saat SNOOP di layar (mis. saat jadi launcher
  default dan Anda di Home). Tidak tampil di atas aplikasi lain. Itu butuh izin overlay/AccessibilityService (belum dikerjakan).
- Android 13+ untuk APK di luar Play Store: izin Akses notifikasi bisa terkunci ("Pengaturan terbatas"). Buka Info aplikasi SNOOP →
  menu ⋮ → "Izinkan pengaturan terbatas", lalu aktifkan lagi Akses notifikasi.
- Tombol Jawab WhatsApp bergantung pada isi notifikasi versi WhatsApp Anda; bisa saja hanya membuka layar panggilan.
- Notifikasi panggilan bawaan WhatsApp tetap muncul bersama kartu Island (tidak dibuang).
- Samsung dapat mematikan layanan di latar belakang; `MainActivity.onResume` meminta sistem menyambungkan ulang listener.
- Pemutar lokal masih tidak menyimpan daftar putar setelah aplikasi dimulai ulang (tidak berubah dari 1.2.0).

## Daftar uji di Samsung A51
1. Diam tanpa notif: bulatan hitam polos di kamera, tanpa teks, ikon BT/getar tidak menimpa.
2. Mulai Pomodoro: status bar hilang, cincin di kiri kamera, waktu di kanan; halaman tidak melompat. Jeda/lewati/setel ulang → status bar kembali.
3. Aktifkan Akses notifikasi → putar lagu di Spotify → kembali ke SNOOP: Island melebar dengan equalizer; tab Musik menampilkan lagu, sampul, lirik berjalan; coba kontrol & seek.
4. Panggilan WhatsApp saat SNOOP di layar: kartu muncul; uji Tolak, Jawab, dan geser ke atas.
5. Matikan "Sembunyikan status bar…" dan ulangi 2 untuk memastikan Island turun di bawah status bar.

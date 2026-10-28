# Update 1.2.0 — Dynamic Island + Pencarian Google

## Dynamic Island (`lib/core/dynamic_island.dart`, `lib/services/island_service.dart`)
Pil hitam di tengah atas layar, melayang di atas semua halaman (dipasang lewat `MaterialApp.builder`).
- **Ringkas**: status absensi hari ini (Belum absen / Masuk hh:mm / Terlambat / Pulang / Izin). Saat Pomodoro atau musik aktif berubah jadi cincin progres + sisa waktu dan equalizer.
- **Banner notifikasi** (4 detik; geser ke atas untuk menutup, ketuk untuk membuka hub): pengingat yang jatuh pada menit itu (saat aplikasi terbuka), fokus/istirahat selesai, absensi berubah menjadi "tercatat di server", galat pemutar musik.
- **Hub** (ketuk pil; geser ke atas / ketuk di luar untuk menutup), tiga tab:
  - **Fokus**: Pomodoro 25/5/15 (preset 50/10/30 dan 15/3/10), 4 sesi lalu istirahat panjang, mulai/jeda/lewati/setel ulang, hitungan sesi hari ini. Istirahat berjalan otomatis setelah fokus; fokus berikutnya menunggu ditekan. Timer memakai waktu akhir, jadi akurat saat aplikasi di latar belakang, dan notifikasi sistem dijadwalkan untuk saat fase selesai.
  - **Musik**: pemutar lokal (`just_audio`). Pilih lagu dari perangkat, daftar putar, putar/jeda, sebelumnya/berikutnya, seek, ulang semua.
  - **Info**: status absensi, kegiatan berikutnya, pengingat berikutnya, 4 notifikasi terbaru.
- Bisa dimatikan di Pengaturan → Dynamic Island.

## Pencarian Google (`lib/screens/google_search_sheet.dart`)
Tombol profil di sebelah tulisan SNOOP pada Beranda diganti tombol cari. Membuka lembar pencarian: Semua / Gambar / Berita / Maps; mengetik alamat http(s) langsung membukanya. Profil tetap dapat dibuka dengan mengetuk nama pada panel Beranda (atau lewat halaman Pengaturan).

## Lain-lain
- `notification_service.dart`: `scheduleOnce` / `cancelId` + kanal "Fokus (Pomodoro)".
- `pubspec.yaml`: tambah `just_audio ^0.9.40`, versi 1.2.0+15.
- Tes baru: `test/island_test.dart`.

## Batasan yang perlu diketahui
- BELUM DIKOMPILASI (Flutter SDK tidak tersedia). Jalankan `flutter pub get`, `flutter analyze`, `flutter test`.
- Musik hanya memutar berkas lokal yang dipilih; daftar putar tidak disimpan setelah aplikasi dimulai ulang. Belum ada kontrol dari notifikasi/layar kunci dan belum membaca musik dari Spotify/YouTube Music (butuh izin akses notifikasi + kode native).
- Notifikasi akhir Pomodoro memakai jadwal "inexact" Android, jadi bisa terlambat beberapa menit saat mode hemat daya.
- Island adalah overlay di dalam aplikasi (bukan Live Activity sistem): tidak tampil saat aplikasi lain sedang terbuka.

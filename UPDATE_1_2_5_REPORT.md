# Update 1.2.5 — Tombol tab Island dipindah ke bawah (bulat, mengambang)

## Status verifikasi (jujur)
- **BELUM dikompilasi dan BELUM dijalankan di perangkat.** Jalankan `flutter pub get`, `flutter analyze`, `flutter test`, `flutter run`. Versi 1.2.5+20, tanpa dependensi baru.

## Perubahan
1. **Pil Dynamic Island tetap di atas seperti sebelumnya** (bulatan di kamera saat diam, melebar untuk timer/musik/notifikasi/panggilan/hub).
2. **Tombol Fokus / Musik / Info dipindah ke bawah** (`_bottomTabs` di `lib/core/dynamic_island.dart`): deretan tombol bulat 54 dp yang
   terpisah dari pil, mengambang di atas area aman bawah. Muncul meluncur naik dengan pantulan saat hub terbuka, turun saat ditutup.
   Tab aktif putih, lainnya hitam; ada tombol bulat X untuk menutup. Tersembunyi saat keyboard terbuka.
3. Isi hub di atas kini hanya konten tab (baris tab lama dihapus). Menutup hub juga bisa lewat geser ke atas atau ketuk di luar.
4. **Island di seluruh aplikasi**: dipasang di `MaterialApp.builder` (di atas Navigator) sehingga tampil dan bisa diketuk di semua layar, dialog, dan sheet.

## Island di atas aplikasi lain (perbaikan "menghilang di aplikasi lain")
Penyebab: Island adalah widget Flutter, jadi hanya tergambar saat SNOOP di layar. Kini ada pil native (`IslandOverlay.kt`)
yang digambar di atas aplikasi lain dengan izin "Tampil di atas aplikasi lain" (sama dengan kartu panggilan).
- Tampil saat SNOOP tidak di layar: bulatan hitam di kamera saat diam; melebar saat Pomodoro/musik aktif (cincin/equalizer kiri, waktu/judul kanan).
- Ketuk pil → SNOOP terbuka dengan hub Island terbuka.
- Waktu Pomodoro dihitung native dari waktu akhir, jadi tetap berjalan walau Flutter ditahan sistem.
- Kartu panggilan WhatsApp menimpa pil selama panggilan. Pil hilang otomatis saat SNOOP kembali ke layar atau Island dimatikan di Pengaturan.
- Geometri (posisi kamera, penyetelan manual) dikirim dari Flutter lewat `SystemBridge.pushIsland` (channel `snoop/system`, metode `island`).
- Butuh Kotlin baru: `IslandOverlay.kt`, perubahan di `SnoopNotificationListener.kt` (IslandBridge) dan `MainActivity.kt`.
- Banner notifikasi tidak ditampilkan di overlay; saat SNOOP di latar, notifikasi sistem Android yang dipakai.

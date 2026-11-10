# Update 1.2.8 — laporan (di atas tema Braun v2)

Dasar proyek: `snooplaunch-braun-v2` (skin Braun). Semua perubahan 1.2.8 digabung ke atasnya dengan merge tiga arah; konflik diselesaikan ke versi Braun.

Belum dikompilasi di sini (tidak ada Flutter SDK/Kotlin di lingkungan kerja). Jalankan `flutter pub get` (ada paket baru `qr_flutter`), lalu `flutter analyze` dan `flutter test`.

## 1. Foto kamera belakang tidak di-mirror
- `CaptureService.capture(camera:)`: un-mirror hanya untuk kamera depan; kamera belakang tidak dibalik.
- Layar absen: pemilih **Depan / Belakang**. Pratinjau: tombol **Balik** untuk membalik manual.
- Catatan: kamera sistem bisa dialihkan pengguna di dalam aplikasi kameranya, dan aplikasi tidak bisa tahu itu. Bila hasilnya terbalik, pakai tombol Balik.
- Tes baru di `test/capture_normalization_test.dart`.

## 2. Tema gelap (Braun gelap)
- Pengaturan > Tema: Terang / Gelap / Ikuti sistem.
- Token `C` dan `B` (badan, tutup tombol, sumur, LCD, garis tepi, teks, `ink`, warna status) sekarang mengikuti tema lewat `B.dark`. Oranye aksen, teks putih di atas oranye, layar gelap (`B.screen`), dan Dynamic Island sama di kedua tema. LCD gelap berwarna hijau-arang dengan angka terang.
- `const` yang memakai token tersebut dilepas otomatis (85 tempat); konstruktor `ProductLabel`, `SegmentDisplay`, `AppTile`, `StatusChip` diubah agar warnanya opsional (null = mengikuti tema). Saat tema berganti, seluruh pohon widget dibangun ulang sekali.
- Layar Absensi Tercatat dan gambar bukti absensi tetap berlatar kertas terang di kedua tema (palet `M`), supaya gambar yang dibagikan tidak berubah.
- Belum ditinjau visualnya per layar di mode gelap; kemungkinan ada kontras yang perlu disetel.

## 3. Status bar kustom
- Status bar sistem disembunyikan selama SNOOP di layar; jam, jaringan, dan baterai digambar di kiri/kanan Island (kapsul hitam). Kamera di pojok: semua dipindah ke sisi yang kosong.
- Di aplikasi lain: jendela overlay hitam setinggi status bar menutup status bar sistem dan menampilkan jam, jaringan, baterai (`IslandOverlay.kt`). Butuh izin "Tampil di atas aplikasi lain" (sama seperti Island).
- Pengaturan: "Status bar kustom" untuk mematikan.
- Batas: ikon jaringan menunjukkan jenis (Wi-Fi/seluler/offline), bukan kekuatan sinyal. Belum diuji di perangkat; posisi bisa perlu penyesuaian di HP dengan kamera tidak standar.

## 4. Logo
- Ketujuh desain dari SVG (A–C dari `snooplaunch_logo_revisi.svg`, D–G dari `snooplaunch_logo_alternatif_2.svg`) digambar persis lewat Canvas (`lib/core/snoop_logo.dart`).
- Pilih di Pengaturan > Logo. Bawaan: A (knob). Ganti bawaan lewat `SnoopLogos.defaultVariant`.
- Ikon peluncur Android dan ikon web dibuat ulang dari varian A. Bila memilih varian lain, ikon peluncur perlu dibuat ulang.
- `snooplaunch_logo_concepts.svg` (wordmark) belum dipakai.

## 5. Mode Sekolah + QR absen
- Pengaturan > Mode aplikasi, atau kapsul di header Beranda: PKL <-> Sekolah. Data PKL tidak dihapus.
- Mode Sekolah: kartu absensi foto PKL diganti kartu **QR Absen Sekolah**; jadwal, dokumentasi, dan pengingat tetap.
- QR Absen: tambah dari galeri, foto kamera, atau ketik isi QR (digambar ulang tajam). Ketuk untuk layar penuh, latar putih, kecerahan maksimal. Ubah nama / hapus lewat menu. Tersimpan lokal, bisa dibuka tanpa internet.

# Update 1.1.0 — Tampilan Bagikan Foto Absen (gaya Mindate)

Yang berubah (hanya tampilan; data, backend, dan alur absensi tidak disentuh):

- `lib/services/evidence_service.dart` — gambar bukti yang dibagikan dirender ulang:
  latar gradien biru langit → mint, wordmark SNOOP + pil "Bukti Absensi PKL",
  kartu foto membulat bertumpuk (foto penuh, scrim, chip kaca "Hadir/Terlambat/Pulang" di kiri atas,
  chip lokasi, judul besar "Absen Masuk/Pulang" + jam kecil di pojok, tanggal, chip status kirim/Ref./jam perangkat),
  lalu panel putih "Detail Absensi" bergaya daftar Chats (avatar foto untuk nama, ikon sekolah/PKL/lokasi/jam foto).
  Catatan "belum berarti diverifikasi guru" dan jejak ekspor tetap ada.
- `lib/screens/attendance_done_screen.dart` — layar "Absensi Tercatat" memakai gradien + kartu foto yang sama, panel status putih, tombol pil.
- `lib/core/theme.dart` — palet baru `M` (hanya untuk fitur ini; tema global tidak berubah).
- `test/evidence_test.dart` — tambah tes warna kehadiran.
- `pubspec.yaml` — versi 1.1.0+14.

Perilaku foto: kartu mengikuti rasio foto (3:4 muat utuh). Foto yang sangat tinggi/lebar dipotong tipis agar kartu
proporsional; foto asli tetap utuh di Google Drive. Teks di atas foto memakai scrim gelap supaya terbaca.

BELUM DIKOMPILASI: Flutter SDK tidak tersedia saat pengerjaan. Jalankan `flutter pub get`, `flutter analyze`,
`flutter test`, lalu coba tombol "Bagikan Bukti Absensi" di perangkat dan periksa hasil gambarnya.

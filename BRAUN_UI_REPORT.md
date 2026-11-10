# SNOOP — Skin keluarga produk Braun

Mengikuti gambar referensi (perangkat Braun: tuner, jam alarm, MP3 player, kalkulator, layar CRT kecil) dan sama dengan skin SnoopUX di laptop.

## Bahasa desain
- Halaman = meja abu hangat `#EFEEEA`; kartu = badan plastik `#E6E5E0` dengan gradien, tepi halus, bayangan lembut (`braunBody`).
- Tombol = tutup timbul (`braunCap`), tombol utama = knob/tombol oranye `#F15A22` (`BraunKnob`).
- Layar = jendela LCD cekung `#D3D6CA` dengan angka 7-segmen (`LcdWell`, `SegmentDisplay`). Layar gelap kecil `#1D201A` untuk Dynamic Island dan alur kamera absensi.
- Label produk `SNOOP` + nama model dengan lampu oranye (`ProductLabel`), kisi-kisi speaker (`SpeakerGrille`).
- Oranye hanya untuk hal yang ditekan, diputar, atau aktif.

## Perubahan
- `core/theme.dart`: semua token `C` dipetakan ke palet Braun (nama lama dipertahankan, jadi semua layar ikut berubah). `night*` kini berarti permukaan perangkat terang. Tema Material: input = LCD, tombol = oranye, dialog/sheet/switch/slider/picker bergaya Braun. Palet bukti absensi (`M`) menjadi kertas abu hangat.
- `core/widgets.dart`: `SnoopCard`, `PillButton`, `StatusChip`, `FilterChipRow`, dan `CapsuleNav` (lima tombol timbul, lampu oranye pada tombol aktif, label model).
- `core/braun.dart`: tambah `SpeakerGrille`.
- `core/glass.dart`: alur absensi memakai layar gelap hijau-arang dan knob oranye.
- Beranda: panel organik kuning diganti perangkat dengan LCD jam 7-segmen, tanggal, sapaan, dan knob pencarian; kartu absensi, jadwal (jam 7-segmen), memories, pengingat, pintasan, dan dock memakai badan/tutup tombol; tombol App Drawer berupa knob oranye.
- App Drawer: kolom cari = LCD, chip kategori = tombol.
- Dynamic Island: layar gelap, aksen oranye, timer Pomodoro 7-segmen, tombol putar musik = knob oranye.
- Splash: perangkat dengan jendela LCD berisi logo.
- Teks pada latar oranye diganti putih di tombol/chip terpilih.

## Belum diverifikasi
- Flutter SDK tidak tersedia, jadi kode BELUM dikompilasi. Jalankan `flutter pub get`, `flutter analyze`, `flutter test`, lalu uji di perangkat.
- Font tetap bawaan sistem (Roboto). Belum ada font Helvetica/Akkurat yang dibundel.
- Putih di atas oranye `#F15A22` berkontras sekitar 3,5:1 (cukup untuk teks tebal/besar). Teks kecil di atas oranye perlu ditinjau.
- Layar yang tidak disentuh langsung (Profil, Pengaturan, Memories, Pengingat, Login, Hasil Absensi) ikut berubah lewat token dan tema; belum ditinjau visualnya satu per satu.
- Riak sentuh pada ikon dock tidak terlihat (digambar di balik badan dock); fungsi tap tetap normal.

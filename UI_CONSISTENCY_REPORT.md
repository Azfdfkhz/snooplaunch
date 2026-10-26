# Laporan Konsistensi UI/UX SNOOP

Dokumen ini mengikuti bagian 9 PRD "Snoop UI/UX Consistency Update".

## 1. Halaman yang diperiksa
- Beranda (`home_screen.dart`): acuan, tidak diubah.
- App Drawer (`app_drawer_screen.dart`): diperiksa, tidak diubah (sudah memakai token gelap).
- Jadwal (`schedule_screen.dart`): diperbaiki.
- Pengingat (`reminders_screen.dart`): diperbaiki.
- Memories + Detail Memori (`memories_screen.dart`): diperbaiki.
- Profil (`profile_screen.dart`): diperbaiki.
- Pengaturan (`settings_screen.dart`): diperiksa, tidak diubah (sudah berkelompok).
- Foto Absensi, Pratinjau, Hasil Absensi, Login, Splash: hanya diperiksa secara otomatis (pencarian warna dan alias). Belum ditinjau visualnya secara manual.

## 2. Perubahan per halaman
- Jadwal: alias palet lama (`C.mint`, `C.blue`, `C.orangeSoft`) dan warna hardcode di luar palet (`0xFF3B6F94`, `0xFFC77A2B`) diganti token. Chip status kini memakai ikon dan label Indonesia ("Akan datang", sebelumnya "Upcoming"). Pilihan hari, tab Hari Ini/Minggu, dan FAB memakai aksen kuning seperti Beranda.
- Pengingat: filter memakai `FilterChipRow`. Latar geser-hapus memakai `errorSoft` dengan teks "Hapus" (sebelumnya peach `C.pink` tanpa label). Ikon "absen" disamakan dengan Beranda (fingerprint).
- Memories: header memakai `PageTitle` dengan ikon. Filter memakai `FilterChipRow`.
- Profil: header memakai `PageTitle` dengan ikon.
- Kartu polaroid: `Colors.white` diganti `C.surface`.

## 3. Komponen bersama baru (`core/widgets.dart`)
- `PageTitle`: judul tab dengan ikon opsional.
- `FilterChipRow<T>`: baris filter kapsul; terpilih = kuning, tidak terpilih = soft; tinggi 48 dp.

## 4. Pengujian
- Flutter SDK tidak tersedia di lingkungan pembuatan, sehingga kode BELUM dikompilasi.
- Yang sudah diperiksa: keseimbangan tanda kurung dan kurung kurawal pada file yang diubah, serta tidak ada referensi tersisa ke fungsi yang dihapus (`chip(`).
- Wajib dijalankan: `flutter pub get`, `flutter analyze`, `flutter test`, dan uji di perangkat/emulator.
- Logika bisnis, Supabase, sinkronisasi, Google Drive, dan absensi TIDAK diubah.

## 5. Masalah yang masih tersisa
- Pemisahan visual: Beranda dan App Drawer memakai latar gelap (`C.night`), sedangkan tab Jadwal, Memories, Profil, dan Pengingat memakai latar ivory (`C.bg`). Ini belum diputuskan: apakah tab tetap terang, atau dibuat gelap seperti Beranda.
- Dialog dan time picker masih memakai default Material, belum diberi gaya khusus.
- Layar Absensi (foto, pratinjau, hasil), Login, dan Splash belum ditinjau secara visual.
- Maskot masih placeholder `SnoopMark`.
- Titik logo tetap memakai `C.pink` (warna logo, disengaja).

## 6. File yang diubah
- `lib/core/widgets.dart`
- `lib/screens/schedule_screen.dart`
- `lib/screens/reminders_screen.dart`
- `lib/screens/memories_screen.dart`
- `lib/screens/profile_screen.dart`
- `UI_CONSISTENCY_REPORT.md` (baru)

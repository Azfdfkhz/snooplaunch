# Laporan: PRD 1.3.0 UI Enhancement dan Dynamic Attendance

Mode kerja: DURING (Anti-Slop). Identitas visual: Braun yang sudah ada, tanpa warna atau design system baru.

**BELUM dikompilasi.** Flutter SDK tidak tersedia di lingkungan pembuatan. Hanya logika Dart murni yang dijalankan (lihat bagian Pengujian).

## 1. Dynamic Attendance

Kartu absensi di Beranda kini mengikuti fase hari ini. Fase dihitung dari jam dan data absensi setiap build, tanpa flag tersimpan, sehingga tetap akurat saat halaman dibuka ulang.

| Fase | Kondisi | Tampilan |
|---|---|---|
| Sebelum masuk | belum ada catatan, sebelum 06:00 | Status tenang, tanpa tombol |
| Masuk buka | belum ada catatan, 06:00 sampai jam pulang | Kartu absen masuk, batas tepat waktu dan sisa waktu |
| Bekerja | sudah masuk, sebelum jam pulang | Jam masuk, lama bekerja, hitung mundur ke absen pulang, bilah progres |
| Pulang buka | sudah masuk, jam pulang sampai 23:59 | Kartu absen pulang |
| Selesai | masuk dan pulang tercatat | Ringkasan, chip hanya bila ada yang perlu diperhatikan |
| Izin | izin, sakit, atau lainnya tercatat | Ringkasan izin |
| Terlewat | tanpa catatan setelah jam pulang | Kartu redup, aksi yang sama tetap tersedia |

Jam pulang: 17:00 Senin sampai Jumat, 16:00 Sabtu dan Minggu (`AppState.workEndFor`, tidak diubah).

Pemicu hitung ulang: timer tepat di batas fase (atau 30 detik untuk teks hitung mundur), aplikasi kembali aktif, data absensi berubah, pergantian hari.

Tidak diubah: pencatatan masuk dan pulang, validasi, waktu server, status terlambat, sinkronisasi, absen ulang, mode Sekolah (QR).

## 2. UI dan interaksi

- `Pressable`: kartu dan tombol yang bisa diketuk mengecil sedikit saat ditekan. Dipasang di `SnoopCard` (hanya bila `onTap` ada), `PillButton`, kartu Jadwal dan Memories, pil pengingat, pintasan, dan tombol absen.
- Pergantian fase: pudar dan tinggi kartu menyesuaikan. Titik hari ini berdenyut hanya saat jendela absen terbuka. Centang muncul sekali di fase Selesai. Haptic ringan pada tombol absen.
- Semua animasi mengikuti pengaturan "kurangi animasi" sistem.
- Warna: token yang sudah ada. Permukaan kartu diberi tint `accentSoft` (jendela terbuka, izin), `successSoft` (selesai), `warningSoft` (terlewat).
- `StreakBadge` diperbesar ke target sentuh 44 dp.

## 3. Lencana (Daily Streak sudah ada, tidak dibuat ulang)

Bagian "Lencana" di layar Streak, 9 lencana dari data nyata: rekor streak (3, 7, 14, 30), hari hadir (1, 10, 25, 50), hari lengkap masuk dan pulang (5). Dihitung ulang dari data, tanpa tabel atau migrasi. Tidak ada lencana "tepat waktu" karena status terlambat hilang di perangkat setelah absen pulang.

## 4. Keputusan yang diterapkan

D1 sampai D9 dari rencana. Daily Motivation diterapkan sebagai teks kontekstual (hitung mundur, batas tepat waktu, streak), bukan bank kutipan. Virtual Pet dan Mini Games ditunda.

## 5. Temuan D8 (belum diubah, menunggu persetujuan)

Layar Foto, Pratinjau, dan Hasil Absensi memakai `core/glass.dart` (blur 18, glow, kaca gelap), berbeda dari bahasa Braun di Beranda. `attendance_done_screen.dart` juga menulis ulang warna status sebagai konstanta heks (`_kErrSoft`, `_kOkSoft`, `_kWarnSoft`, `_kPeach`) yang sama dengan token `C`. Rekomendasi: selaraskan ke Braun dan token pada pekerjaan terpisah.

## 6. Konsep (belum diterapkan)

Maskot yang bereaksi pada streak dan status absen (mis. berubah ekspresi saat jendela absen terbuka atau setelah selesai), tanpa mekanik memberi makan atau permainan. Butuh ilustrasi pengganti `SnoopMark`. Mini games: tidak direkomendasikan untuk rilis ini.

## 7. File

Baru: `lib/core/attendance_session.dart`, `lib/core/achievements.dart`, `test/attendance_session_test.dart`, `test/achievements_test.dart`.
Diubah: `lib/screens/home_screen.dart`, `lib/core/widgets.dart`, `lib/screens/streak_screen.dart`.
Tidak diubah: `state.dart`, `models.dart`, `supabase/*`, layanan sinkronisasi dan backend, `android/*`, Dynamic Island, `pubspec.yaml` (tanpa dependensi baru).

## 8. Pengujian

Dijalankan (Dart 3.14, shim minimal untuk `group/test/expect`): 15 tes sesi absensi dan 4 tes lencana, semua lulus. Pemeriksaan sintaks (`dart format`) pada semua file yang diubah, tanpa kesalahan.

BELUM dijalankan, wajib oleh Anda:
1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. Uji di perangkat: tema terang dan gelap, lebar 320, 360, 411 dp, skala teks 1,3 dan 2,0, TalkBack, "kurangi animasi", serta pergantian fase dengan mengubah jam perangkat (06:00, jam pulang, 00:00).

## 9. Delivery Gate

| Kelompok | Pemeriksaan | Hasil |
|---|---|---|
| A | Elemen visual punya alasan (peninjauan kode) | PASS |
| A | Arah visual mengikuti brief, tanpa warna baru (peninjauan kode) | PASS |
| A | Komposisi dan karakter terlihat sesuai (perlu dilihat di layar) | NOT TESTED |
| B | Tidak ada tautan atau navigasi palsu, tidak ada angka atau klaim karangan | PASS |
| B | Logika fase dan lencana, termasuk batas waktu | PASS |
| B | Semua kontrol berfungsi di aplikasi berjalan | NOT TESTED |
| B | State loading, kosong, error di UI | NOT TESTED |
| C | Tidak ada overflow atau clipping | NOT TESTED |
| C | Navigasi dan form di layar kecil | NOT TESTED |
| C | Focus state dan keyboard | NOT TESTED |
| C | Kontras dan label (label semantik ditulis, kontras belum diukur) | NOT TESTED |
| D | Perubahan dalam ruang lingkup, business logic dan Supabase tidak diubah | PASS |
| D | `flutter analyze` dan `flutter test` | NOT TESTED |
| D | Keterbatasan dilaporkan | PASS |

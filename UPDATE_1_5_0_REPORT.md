# SNOOP 1.5.0 — Retro Industrial Interactive Dashboard (PRD v1.2)

**Status: BELUM dikompilasi.** Flutter/Dart SDK tidak tersedia di lingkungan pengerjaan (sama seperti update sebelumnya), jadi
`flutter analyze`, `flutter test`, dan build APK belum pernah dijalankan. Yang sudah dilakukan: pemeriksaan keseimbangan kurung
pada semua file baru, tinjauan manual API, pemeriksaan tabrakan nama, perhitungan tata letak (tanpa tumpang tindih) pada lebar
320/360/411/430 dp, dan pratinjau visual font piksel. Jalankan checklist di bagian bawah sebelum dirilis.

## Yang berubah

| File | Perubahan |
|---|---|
| `lib/core/theme.dart` | Kelas baru `DS` = design tokens PRD 3.1 (Warm Cream, Soft Cyan, Dark Teal, Attendance Red, Action Orange, Charcoal, Warm Beige) + turunan (teal terang, jalur progres, amber, orange panel). Sadar tema gelap. Token lama `C`/`B`/`M` tidak diubah. |
| `lib/core/pixel_font.dart` (baru) | `PixelText`: tipografi piksel digambar dari tabel bitmap 5x7 (huruf besar/kecil, angka, tanda baca). **Tanpa berkas font**, jadi tidak ada aset yang perlu ditambah di `pubspec.yaml`. Mengecil otomatis (tidak meluap) pada ruang sempit. |
| `lib/core/seven_segment.dart` (baru) | `SevenSegmentText`: jam/countdown seven-segment dengan segmen mati redup. |
| `lib/features/home/controllers/home_controller.dart` (baru) | Logika tampilan murni (tanpa Flutter state): countdown, Next Activity, milestone timeline, wajah Attendance Shape, label & foto panel absensi, bagian tanggal. |
| `lib/features/home/widgets/*.dart` (baru, 10 file) | `home_header`, `attendance_panel`, `attendance_timeline`, `profile_pill`, `next_activity_panel`, `attendance_shape`, `countdown_display`, `memories_orbit`, `statistics_panel`, `bottom_launcher_dock` (struktur PRD 13.2). |
| `lib/screens/home_screen.dart` | Bagian tampilan ditulis ulang menjadi komposisi referensi. **Dipertahankan apa adanya**: `_sessionCard`, `_startAttendance`, `_leaveNote`, `_serverAlert`, `_SessionArea`, `_WeekRow`, popup absensi + popup otomatis (`AttendancePopupGate`), mode Sekolah/QR. |
| `lib/screens/shell.dart` | Hanya warna latar & navigation bar halaman Beranda menjadi krem (`DS.cream`). Swipe Drawer/Home/tab tidak berubah. |
| `test/home_controller_test.dart`, `test/home_widgets_test.dart` (baru) | Uji logika (countdown, timeline, wajah absensi, panel, header) dan uji render widget pada layar 320x568, 360x740, 430x932 tanpa overflow. |

Tidak berubah: `AppState`, model data, Supabase/backend, `CaptureService`, `LauncherService`, `NotificationService`,
sinkronisasi, seluruh kode native Kotlin (Dynamic Island, overlay, mirror), App Drawer, Jadwal, Pengingat, Memories, Pengaturan,
dan semua aturan bisnis absensi. Tidak ada model data baru dan tidak ada perubahan skema.

## Pemetaan PRD -> implementasi

| PRD | Implementasi | Sumber data |
|---|---|---|
| 4.2 Date Header | `HomeHeader`: hari, tanggal, bulan, jam (bahasa Indonesia, piksel) | `DateTime.now()` (diperbarui tiap 20 dtk) |
| 4.3 Attendance Panel | `AttendancePanel`: ketuk buka/tutup, foto bukti, animasi ekspansi | `Attendance` + `Memory` absensi hari ini |
| 4.4 Timeline | `AttendanceTimeline`: Masuk → Kegiatan → Pulang; state upcoming/active/completed/missed; label pengingat berikutnya (ketuk = Pengingat) | fase sesi, `tasksDone/total`, `nextReminder` |
| 4.5 Profile Pill | `ProfilePill`: avatar → Pengaturan/Profil, sapaan "Hi <nama depan>", tombol cari → pencarian yang sudah ada | `AppState.name` |
| 4.6 Attendance Shape | `AttendanceShape`: Absen Masuk / Hadir+jam / Terlambat+jam / Selesai+durasi (+ Izin, Terlewat, QR Sekolah); ikon jam pasir bila belum dikonfirmasi server | fase sesi + `Attendance` |
| 4.7 Countdown | `CountdownDisplay`: HH:MM menuju mulai kegiatan; saat berlangsung: sisa menuju selesai atau status; tanpa jadwal: `--:--` + "Tidak ada jadwal" | `AppState.nextSchedule` |
| 4.8 Memories Orbit | `MemoriesOrbit`: dua lingkaran + garis geometris; placeholder bila kosong; lencana bila belum terunggah/gagal; ketuk = detail memori | `AppState.memories` |
| 4.9 Next Activity | `NextActivityPanel`: ketuk handle atau geser untuk buka/tutup; isi diketuk = Jadwal | `ScheduleItem`, `tasksDone` |
| 4.10 Statistik | `StatisticsPanel`: angka streak piksel; **0 bila belum ada riwayat (tidak dikarang)**; ketuk = ringkasan streak | `AppState.streak` |
| 4.11 Dock | `BottomLauncherDock`: tombol grid + aplikasi dock pilihan pengguna; ketuk atau geser ke atas = App Drawer | `AppState.dock`, `LauncherService` |
| 12 Responsif | Bingkai acuan 430x840 dengan skala seragam `min(lebar/430, tinggi/840)`, dipusatkan; inset status bar/navigasi dari `MediaQuery`; teks sans dibatasi 1,2x; teks piksel mengecil, bukan meluap | — |

## Keputusan yang saya ambil (PRD/referensi tidak spesifik)

1. **Timeline 3 milestone** (Masuk, Kegiatan, Pulang) mengikuti contoh alur di PRD 4.4, bukan 4 titik "minum" seperti pada gambar referensi. Progres: separuh jalur pertama sebanding kegiatan selesai, separuh kedua terisi saat sudah pulang. Label di bawahnya menampilkan pengingat berikutnya.
2. **Countdown HH:MM** (jam:menit), bukan mm:ss, karena Home diperbarui tiap 20 detik. Ada keterangan kecil di bawah angka supaya jelas menuju apa.
3. **Edge Shape (panel App Drawer di tepi kanan, 1.3.2) dihapus dari Home**; sisi kanan kini dipakai Statistics Panel sesuai referensi. App Drawer tetap lewat Dock (ketuk/geser atas) dan swipe kanan dari Home (Shell). `edge_drawer_panel.dart` masih ada di repo, hanya tidak dipakai Home — aman dihapus.
4. **Ikon "Snoop" kiri bawah** (ada di referensi, PRD tidak menjelaskan fungsinya) saya jadikan pintasan ke Pengaturan, supaya tidak dekoratif murni. Ubah di `_snoopTile` bila ingin fungsi lain (mis. membuka app favorit).
5. **Dock memuat aplikasi dock pilihan pengguna** (maks. 4) di sisi kiri; bila kosong tampilannya sama persis dengan referensi (kapsul oranye + tombol grid).
6. **Chip mode PKL/Sekolah** (fitur 1.2.8) ditempatkan di bawah tanggal; tidak ada di referensi tetapi fitur lama tidak boleh hilang.
7. **Pintasan lama** lewat elemen baru: Jadwal = panel Berikutnya / countdown; Memories = lingkaran orbit; Pengingat = label timeline; Profil/Pengaturan = avatar; Streak = panel statistik.
8. **Tipografi piksel digambar sendiri** karena font piksel tidak bisa diunduh di lingkungan ini dan menambah aset tanpa kompilasi berisiko merusak build. Jika ingin font asli (mis. Pixelify Sans), taruh di `assets/fonts/`, daftarkan di `pubspec.yaml`, dan ganti isi `PixelText`. Teks piksel tidak ikut skala font sistem (bitmap); setiap elemen punya label Semantics untuk pembaca layar.
9. **Tema gelap**: token `DS` punya varian gelap sederhana; belum diuji visual.

## Belum dikerjakan (di luar prioritas PRD: "halaman lain mengikuti bertahap")

- Restyle App Drawer, Jadwal, Pengingat, Memories, Pengaturan ke design system baru (fungsi sudah utuh; tampilan masih Braun).
- Animasi transisi antar-state absensi pada lingkaran (selain denyut jendela absen dan ekspansi panel).
- Uji perangkat nyata (lihat checklist).

## Uji di perangkat (checklist)

1. `flutter pub get && flutter analyze && flutter test` — perbaiki galat kecil bila ada (kemungkinan: impor tak terpakai, peringatan `unused_element` untuk `_reminderIcon`/`_PulseRing`).
2. Tampilan Home di 320, 360, 411, 430 dp + font sistem besar + ponsel berponi + navigasi 3 tombol vs gestur: tidak ada overflow, panel samping bisa diketuk, dock tidak menempel navigasi.
3. Bandingkan dengan dua gambar referensi: header, panel cyan (ketuk → foto, ketuk lagi → tutup), timeline tersembunyi sebagian saat panel terbuka, panel Berikutnya (ketuk handle & geser), lingkaran merah, garis hitam, countdown, panel statistik, dock.
4. Absensi: Belum absen → "Absen Masuk" berdenyut; ketuk → popup lama; ambil foto → "Hadir 07:51"; panel cyan menampilkan foto itu; Terlambat; Absen pulang → "Selesai 9j 11m". Tidak ada record ganda.
5. Mode offline: lingkaran menampilkan ikon jam pasir; sinkronisasi Supabase tetap jalan.
6. Countdown: ubah jadwal → angka berubah; tanpa jadwal → `--:--`; kegiatan berlangsung → keterangan sesuai.
7. Memories Orbit: tanpa foto → placeholder; dengan foto lokal/cloud → foto; foto belum terunggah → lencana awan.
8. Streak 0 tampil redup; streak > 0 menampilkan titik oranye.
9. Dock: ketuk tombol grid / geser atas → App Drawer; ikon dock membuka aplikasi; tekan lama → aksi aplikasi.
10. Tombol Home native, Dynamic Island (overlay notifikasi/panggilan/mirror) tidak terganggu; jadikan SNOOP launcher default dan ulangi.
11. Aktifkan "hapus animasi" sistem: panel & timeline berpindah tanpa animasi.
12. Tema gelap: kontras latar, pill, dan teks.

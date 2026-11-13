# SNOOP 1.3.2 — Personal Visual Launcher & Dynamic Shape Interaction

**Status: BELUM dikompilasi.** Flutter SDK tidak tersedia di lingkungan pengerjaan, jadi `flutter analyze` dan `flutter test`
belum pernah dijalankan. Yang sudah dilakukan: pemeriksaan keseimbangan kurung, tinjauan manual API, dan perhitungan tata letak
pada lebar 320/360/411/480 dp (tanpa tumpang tindih). Jalankan langkah di bagian "Uji di perangkat" sebelum dirilis.

## Yang berubah

| File | Perubahan |
|---|---|
| `lib/screens/home_screen.dart` | Ditulis ulang bagian tampilan: komposisi Shape, Absensi Shape + popup, pemicu popup otomatis, dock tipis. Logika absensi lama (`_sessionCard`, `_startAttendance`, `_leaveNote`, `_weekMarks`, `_serverAlert`, `_SessionArea`, `_WeekRow`) dipertahankan apa adanya. |
| `lib/core/shapes.dart` (baru) | `DotGrid` (latar titik), `SnoopShape` (lingkaran / kotak membulat / kapsul), `showShapePopup` (popup yang tumbuh dari posisi Shape), `monoStyle`. |
| `lib/screens/edge_drawer_panel.dart` (baru) | `EdgeShape` (tab tepi kanan) dan `showEdgeDrawer` (morph tab -> panel). Panel memuat `AppDrawerScreen` yang sudah ada. |
| `lib/core/attendance_popup_gate.dart` (baru) | Membatasi popup otomatis: sekali per fase per hari, tersimpan di perangkat. |
| `lib/core/attendance_session.dart` | Tambahan getter murni `allowsAutoPopup`. Tidak ada aturan lama yang diubah. |
| `lib/screens/app_drawer_screen.dart` | Tambahan callback opsional `onLaunched` (panel menutup diri setelah aplikasi dibuka). |
| `test/attendance_popup_test.dart` (baru) | Tes `allowsAutoPopup` dan `AttendancePopupGate`. |
| `pubspec.yaml`, `STATUS.md` | Versi 1.3.2+24, catatan status. |

Tidak berubah: `Shell`, autentikasi, penyimpanan, backend, database, Dynamic Island, `LauncherService`, `CheckInScreen`,
Jadwal, Memories, Pengingat, Pengaturan, dan seluruh aturan bisnis absensi.

## Perilaku

- **Home**: latar titik halus; header tanggal/jam monospasi + identitas SNOOP kecil; kapsul profil (ketuk = Pengaturan, tombol bulat = cari Google); Photo Shape, Information Shape, Absensi Shape, Pengingat, dan Streak (Custom Shape) dengan ukuran dan posisi berbeda. Semua dari `AppState`, tanpa data contoh.
- **Photo Shape**: foto terbaru. Ketuk = Memories. Dua foto lebih lama tampil sebagai lingkaran (hanya bila ada), ketuk = detail memori.
- **Information Shape**: kegiatan berlangsung/berikutnya. Ketuk = Jadwal.
- **Absensi Shape**: wajahnya mengikuti fase hari ini (belum dibuka, ABSEN MASUK, HADIR/TERLAMBAT jam, ABSEN PULANG, SELESAI, izin, TERLEWAT). Ketuk membuka popup berisi kartu absensi yang sama seperti sebelumnya + peringatan server. Ikon jam pasir bila data belum dikonfirmasi server. Mode Sekolah: Shape ini menjadi QR Absen, tanpa popup.
- **Popup otomatis**: hanya pada fase `entryOpen` / `exitOpen`, sekali per fase per hari (tersimpan, jadi tidak muncul lagi saat Home dibuka ulang atau aplikasi dimulai ulang), hanya bila Home sedang di atas (tidak ada layar lain), tidak di mode Sekolah, dan absen masuk tidak otomatis di Sabtu/Minggu. Ada tombol tutup; tombol kembali menutup popup dulu; setelah ditutup absensi tetap bisa dibuka lewat Absensi Shape.
- **Edge Shape**: tab miring di tepi kanan, hanya sebagian terlihat. Ketuk -> tab mengembang menjadi panel berisi `AppDrawerScreen` (favorit, pencarian, kategori, ikon asli, buka lewat `LauncherService`). Tombol "Semua aplikasi" membuka halaman App Drawer penuh. Panel menutup sendiri setelah aplikasi dibuka.
- Animasi: skala + pudar (popup), morph rect (panel). Dimatikan bila animasi sistem dimatikan.

## Keputusan yang saya ambil (PRD tidak spesifik)

1. **"Jadwal absensi"** saya artikan: absen masuk otomatis hanya Senin–Jumat; absen pulang otomatis selama sudah absen masuk. Bila Sabtu/Minggu juga hari kerja Anda, hapus satu baris `weekday >= saturday` di `_maybeAutoPopup`.
2. **Edge Shape hanya ketukan, bukan geser dari tepi.** Tepi kanan dipakai gestur kembali Android; geser dari sana bentrok.
3. **Dock tetap ada** (versi tipis, datar). PRD tidak meminta menghapusnya dan tanpa itu aplikasi pilihan pengguna hilang dari Home. Bila ingin dihapus, aplikasi dock tetap terkelola lewat tekan-lama di App Drawer.
4. **Pintasan lama** (Jadwal, Memories, Pengingat, Pengaturan, Favorit) kini lewat Shape: Information, Photo, Pengingat, avatar, dan panel Edge Shape. Blok "Favorit" di Home dihapus karena favorit tampil paling atas di App Drawer.
5. **Peringatan server** ("belum masuk akun", "server belum dikonfigurasi", antrean sinkronisasi) kini tampil di dalam popup absensi, bukan di Home. Di Home hanya ada ikon jam pasir pada Absensi Shape.
6. **Teks di Home dibatasi skala 1,2x** karena Shape berukuran tetap; mencegah overflow, tetapi sedikit mengurangi efek pembesaran font sistem di layar ini.
7. **Tipografi**: font `monospace` bawaan sistem sebagai pengganti font piksel pada referensi (tanpa aset font tambahan). Ganti di `monoStyle()` bila ingin font piksel.
8. Mode PKL/Sekolah kini lingkaran kecil di bawah tanggal (sebelumnya kapsul di header).

## Uji di perangkat (checklist)

1. `flutter pub get && flutter analyze && flutter test` — perbaiki bila ada galat kecil.
2. Home di layar 320, 360, 411 dp dan teks sistem besar: tidak ada overflow, tab tidak menimpa Shape.
3. Ubah jam kerja / jam perangkat ke dalam jendela masuk (Senin–Jumat): popup muncul sekali; tutup; buka ulang Home: tidak muncul lagi; ketuk Absensi Shape: muncul.
4. Absen masuk lewat popup (foto) sampai selesai; ulangi untuk pulang. Status Shape dan popup ikut berubah.
5. Akhir pekan dan mode Sekolah: tidak ada popup otomatis.
6. Edge Shape: ketuk, cari aplikasi, ganti kategori, buka aplikasi (panel menutup), "Semua aplikasi" membuka halaman penuh, tombol kembali menutup panel, keyboard tidak menutupi isi panel.
7. Tombol Home native menutup popup/panel.
8. Tema gelap: kontras Shape dan titik latar.
9. Performa: scroll Home dan animasi panel pada perangkat kelas menengah.

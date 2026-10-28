# Update 1.2.4 — Foto Absensi Tanpa Mirror, Orientasi Tegak Lurus, dan Redesain UI Minimalis

## Ringkasan Perubahan
1. **Foto Absensi Kamera Depan Jangan Mirror**:
   - Membuka kamera depan secara otomatis saat absensi (`preferredCameraDevice: CameraDevice.front`).
   - Normalisasi fisik piksel: un-mirror (`img.flipHorizontal`) secara otomatis pada hasil tangkapan kamera depan, sehingga wajah, seragam, dan teks identitas (seperti kartu TKA/sekolah) tidak terbalik seperti cermin.
   - Menyediakan tombol interaktif **Cermin / Balik** di layar pratinjau (`AttendancePreviewScreen`) untuk kontrol manual instan.

2. **Bukti Foto Lurus (Jangan Miring)**:
   - Mengatasi masalah foto miring 90° (seperti contoh pada tangkapan layar user di Samsung A51):
     - Membaca dan menerapkan orientasi EXIF fisik (`img.bakeOrientation`).
     - Deteksi otomatis: bila sensor kamera menyimpan piksel secara lanskap (`width > height`), foto otomatis diputar 90° searah jarum jam sehingga selalu tegak lurus (portrait) sebelum disimpan atau diunggah ke Google Drive.
     - Menyediakan tombol interaktif **Putar 90°** di layar pratinjau (`AttendancePreviewScreen`) bila ingin mengatur ulang sudut foto.
     - Semua downstream (tampilan Home, Google Drive thumbnail, layar hasil, dan kartu bukti) dijamin menampilkan foto tegak lurus.

3. **Redesain UI Foto Absensi Lebih Minimalis (Dark Glassmorphism)**:
   - Mengikuti referensi desain (`media_1793112803505.png`):
     - **Layar Buka Kamera (`CheckInScreen`)**: Menggunakan tema gelap elegan (`#201724` ke `#120E15`), tombol kembali kaca melingkar, kartu viewfinder ber-radius halus (`36px`) dengan ikon aperture modern, tag petunjuk minimalis, serta tombol shutter kamera bulat mewah dengan ring aksen kuning hangat (`C.accent`).
     - **Layar Tinjau Foto (`AttendancePreviewScreen`)**: Foto ber-radius penuh (`32px`) dengan floating pill tags transparan untuk waktu, lokasi, dan status, plus tombol melayang *Putar* dan *Cermin*. Aksi utama "Gunakan Foto" berbentuk pil elegan.
     - **Layar Absensi Tercatat (`AttendanceDoneScreen`)**: Diperbarui dari gradien biru-mint lama ke dark glassmorphism senada dengan launcher; kartu foto heroik ber-radius `32px` dengan stiker tag mengambang dan kartu panel status yang rapi.
     - **Widget Foto di Home (`HomeScreen: _memoriesWidget`)**: Dirombak dari kotak terpotong dengan bar hitam bawah menjadi kartu foto full-bleed ber-radius membulat dengan floating pill tags transparan (jam, status cloud, dan nama kegiatan) yang menyatu dengan foto seperti pada desain referensi.

---

## Status Verifikasi
- `flutter analyze`: **0 issues** (clean).
- `flutter test`: **55 passed** (semua unit test, widget test, dan uji normalisasi foto lulus).
- Versi diperbarui ke: `1.2.4+19`.

---

## Berkas yang Diubah / Ditambahkan
- `lib/services/capture_service.dart`:
  - `preferredCameraDevice: CameraDevice.front`.
  - Fungsi `processPhoto` (isolate compute), `rotatePhoto90`, `flipPhotoHorizontal`.
  - Normalisasi otomatis: bake EXIF, luruskan portrait, un-mirror, dan kompresi JPEG tajam.
- `lib/screens/checkin_screen.dart`:
  - Redesain dark glassmorphic minimalis, kartu viewfinder baru, tombol shutter modern.
- `lib/screens/attendance_preview_screen.dart`:
  - Redesain minimalis dengan floating badge info dan tombol alat *Putar* & *Cermin*.
- `lib/screens/attendance_done_screen.dart`:
  - Redesain minimalis dark theme, foto heroik dengan stiker tag melayang, tombol aksi elegan.
- `lib/screens/home_screen.dart`:
  - Redesain `_memoriesWidget` menjadi full-bleed photo card dengan floating badges ala referensi.
  - Pembersihan parameter `_Pill`.
- `lib/services/evidence_service.dart`:
  - Pembersihan konstanta dan import.
- `pubspec.yaml`:
  - Versi dinaikkan ke `1.2.4+19`.
- `test/capture_normalization_test.dart`:
  - Pengujian otomatis pemulihan foto lanskap menjadi tegak, un-mirror, dan transformasi sudut.

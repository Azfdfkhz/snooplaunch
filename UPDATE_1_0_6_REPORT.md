# Update 1.0.6 — Laporan perubahan

**Status verifikasi:** BELUM dikompilasi. Flutter SDK tidak tersedia di lingkungan pembuatan.
Wajib sebelum rilis: `flutter pub get` (ada dependensi baru `file_picker`), `flutter analyze`, `flutter test`,
dan uji di perangkat Android. Yang sudah diperiksa: keseimbangan kurung di seluruh berkas Dart.

## 1. Kegiatan berbeda tiap hari
- Hanya **Absen Masuk** dan **Absen Pulang** yang tetap muncul setiap hari.
- Kegiatan lain hanya berlaku untuk tanggal yang dipilih (saat menekan + di Jadwal).
- Migrasi: contoh bawaan (UI Design Development, Istirahat Makan Siang, Project Development) dihapus.
  Kegiatan lain yang sudah ada dikunci ke tanggal migrasi (hari ini). Pindahkan manual bila perlu.
- Hapus kegiatan: menu kegiatan > "Hapus kegiatan ini" (dengan konfirmasi). Absen Masuk/Pulang tidak bisa dihapus.

## 2. Tombol absen sesuai jam
- **Absen masuk**: dibuka pukul **06:00**. Sebelum itu muncul keterangan "Absen masuk dibuka pukul 06:00".
- **Absen pulang**: dibuka pada jam pulang hari itu (**17:00** Senin–Jumat, 16:00 Sabtu–Minggu). Sebelum itu muncul keterangan "Absen pulang dibuka pukul 17:00".
- Panel absensi di Beranda diperbarui otomatis tiap 20 detik, sehingga tombol muncul tanpa membuka ulang aplikasi.
- Catatan: jam absen dibatasi di aplikasi. Server tidak memblokir absen di luar jam ini.

## 3. Bukti tugas: foto, dokumen, atau tautan
- Setelah kegiatan ditandai **Tandai selesai**, muncul sheet "Bukti" (opsional).
- Juga bisa dibuka kapan saja dari menu kegiatan > **Bukti tugas**.
- Pilihan: Foto (kamera), Foto (galeri), Dokumen (PDF, Word, Excel, PowerPoint, gambar), Tautan (https://).
- Foto dan dokumen disalin ke folder aplikasi. Tautan dibuka di browser. Dokumen dibagikan ke aplikasi lain untuk dibuka.
- Jumlah bukti tampil sebagai ikon klip di kartu kegiatan.
- **Batasan:** bukti disimpan **di perangkat**, belum diunggah ke Google Drive. Menghapus aplikasi akan menghilangkannya.
  Unggah bukti ke Drive (sama seperti foto dokumentasi) adalah pekerjaan berikutnya.

## 4. Backfill absensi (SQL)
- File: `supabase/backfill_attendance_jul_oct_2026.sql`. Ganti `EMAIL_ANDA` dengan email akun Anda.
- Aturan:
  - 20–31 Juli 2026: Senin–Sabtu.
  - 1 Agustus s.d. kemarin: Senin–Jumat.
  - Masuk 07:50 WIB; pulang 17:00 WIB (Senin–Jumat), 16:00 WIB (Sabtu).
- Hari ini tidak dimasukkan. Hari libur nasional tidak dikecualikan (hapus dari daftar bila perlu).
- Data ini masuk ke server. **Catatan:** aplikasi belum menarik riwayat dari server, sehingga data ini belum tampil di Jadwal/Beranda di perangkat. Itu bisa ditambahkan sebagai pekerjaan berikutnya.

## 5. Berkas
- Diubah: `lib/core/models.dart`, `lib/core/state.dart`, `lib/screens/home_screen.dart`, `lib/screens/schedule_screen.dart`,
  `lib/screens/memories_screen.dart`, `pubspec.yaml` (versi 1.0.6+7, dependensi `file_picker: ^8.1.2`).
- Ditambah: `lib/services/task_evidence_store.dart`, `supabase/backfill_attendance_jul_oct_2026.sql`, `UPDATE_1_0_6_REPORT.md`.
- Pakai `flutter pub get` untuk memperbarui `pubspec.lock`.

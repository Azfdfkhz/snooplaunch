# SNOOP — Home UI + Penyimpanan Foto Google Drive: Laporan

## STATUS VERIFIKASI (baca dulu)
**Belum dikompilasi, belum dijalankan, belum diuji ke Supabase maupun Google Drive.** Flutter/Dart/Deno tidak ada di
lingkungan ini (unduhan SDK diblokir). Yang benar-benar dilakukan: audit kode, keseimbangan kurung seluruh file Dart
yang diubah, dan pemeriksaan sintaks TypeScript pada keempat file Edge Function (transpile saja, bukan type-check).
Tidak ada kriteria penerimaan yang bisa dinyatakan lulus tanpa menjalankan langkah di bawah.

    flutter pub get && flutter analyze && flutter test
    # SQL Editor: supabase/migration_003_drive_storage.sql
    supabase functions deploy drive-upload drive-photo drive-delete   # sesuai supabase/SETUP.md

## Temuan audit
1. **zip tidak konsisten**: `capture_service.dart` di zip adalah versi lama, padahal `checkin_screen.dart` memakai API barunya
   (`CaptureFailure`, `takenAt`, `discard`) → tidak akan ter-compile. Saya kembalikan API baru (tanpa `persist`).
2. `Memories` di zip kehilangan tombol Drive/`errorBuilder` (diganti seluruhnya sekarang).
3. Retry antrean sebelumnya **membawa `photoPath` lokal** dan foto tidak pernah dihapus setelah upload.
4. `drive-upload` lama: percaya `confirmed` dari HTTP 200 saja, MIME dari klaim klien, idempotensi lemah
   (balapan dua permintaan → file ganda), dan **RLS `for all` membuat klien bisa mengisi `drive_file_id` sendiri**.
5. Tidak ada cara menampilkan foto privat dari Drive dan tidak ada penghapusan file Drive.
6. Model hanya menyimpan URL (tanpa ID file).
7. `env.dart` di zip berisi URL Supabase + publishable key milik Anda. Itu key publik (aman di aplikasi), tetapi
   jangan pernah menaruh service-role key atau secret Google di sana.

## Perubahan
**Backend**: `migration_003_drive_storage.sql`; `functions/_shared/drive.ts`; `drive-upload` (ditulis ulang: verifikasi
baca-ulang + MD5, magic bytes, klaim atomik, reuse file lama, kompensasi saat DB gagal, mode verify/status);
`drive-photo` (baru); `drive-delete` (baru, idempoten); `SETUP.md` diperbarui.

**Aplikasi**
- `Memory`: `driveFileId` (diturunkan dari URL untuk data lama), `uploadError`, status `uploading` (ditambah di akhir enum
  agar indeks lama tetap valid).
- `BackendService`: upload terverifikasi (`confirmed`), `verifyPhoto`, `fetchPhoto`, `deleteRemote`, `driveStatus`,
  pesan error yang dapat dibaca.
- `AppState`: `uploadMemoryPhoto` (berkas lokal dihapus **hanya** setelah `confirmed`), `discardLocalPhoto`,
  `migrateLegacyPhotos`, `removeMemory` (hapus cloud dulu; gagal → data tetap ada), cache dibersihkan saat keluar akun.
- `SyncService`: antrean hanya metadata; foto tidak pernah masuk antrean.
- `CloudPhotoService` + `MemoryPhoto`: foto cloud lewat server, cache sementara dibatasi (120 berkas / 80 MB), loading/
  error/offline/foto-terhapus.
- Layar hasil absensi: status absensi dan status foto terpisah, "Coba Unggah Lagi", foto yang gagal dibuang saat layar
  ditutup. Preview: peringatan bila foto belum bisa diunggah. Memories: status foto per item, detail memakai foto utuh,
  hapus aman. Pengaturan > Sinkronisasi: status foto, pemeriksaan Drive, tombol migrasi.
- **Home**: chip absensi tidak lagi menyatakan sukses bila baru tersimpan di perangkat; status koneksi dipindah ke kartu
  peringatan (dampak + satu tindakan); penanda hari mingguan membedakan hadir/terlambat/belum di server/tidak ada
  absensi/belum tiba/akhir pekan; pengingat diringkas jadi satu baris; instruksi favorit dihapus dari Home;
  widget Memories menampilkan jam + status foto.

## Keterbatasan dan keputusan yang perlu Anda ketahui
1. **Screenshot Home tidak ikut terunggah** pada pesan ini. Audit UI saya berdasarkan kode `home_screen.dart`, bukan gambar.
   Kemungkinan ada masalah visual yang tidak terlihat dari kode (mis. bentrok status bar). Pengaturan system bars di
   `shell.dart` saya nilai sudah benar dan tidak diubah.
2. **Isolasi dua akun di perangkat yang sama belum ada**: `memories`/`attendance` lokal tidak diberi pemilik. Akun B yang
   masuk di perangkat yang sama akan mengunggah foto lama akun A atas namanya. Di server RLS tetap memisahkan data, tetapi
   ini harus diperbaiki (simpan `ownerId` per catatan, atau kosongkan data lokal saat ganti akun) sebelum dipakai bersama.
3. Absensi offline tetap dicatat (aturan bisnis), tetapi **foto tidak**: sesuai kebijakan, foto hanya berkas sementara dan
   dibuang bila unggahan gagal dan layar hasil ditutup. Jika aplikasi dimatikan paksa saat mengunggah, foto sisa diproses
   migrasi pada start berikutnya (kecuali cache sudah dibersihkan sistem → ditandai "tidak terunggah").
4. Penghapusan dokumentasi butuh koneksi (cloud dihapus dulu). Tidak ada antrean hapus offline.
5. Thumbnail memakai `thumbnailLink` Drive bila tersedia, jika tidak foto penuh (≤5 MB, dalam base64). Belum diuji apakah
   thumbnail file privat bisa diambil dengan bearer token; fallback ke foto penuh sudah ada.
6. Verifikasi MD5 memakai `crypto.subtle.digest("MD5")`; bila runtime Edge tidak menyediakan, verifikasi turun ke ukuran.
7. Mode token OAuth *Testing* kedaluwarsa 7 hari (lihat SETUP.md).
8. Tombol bagikan bukti masih hanya di layar hasil; bukti dibuat dari salinan foto di memori, bukan dari Drive.
9. Tidak ada tes widget/integrasi; `test/photo_storage_test.dart` (state/model/antrean) dan `test/evidence_test.dart` belum dijalankan.

## Pengujian yang HARUS dijalankan (belum ada yang dijalankan)
Foto baru → Drive; unggah gagal + coba lagi tanpa file ganda; offline; buka Memories setelah restart; hapus dokumentasi
(cloud + cache); migrasi foto lama (berkas ada / hilang / sudah di Drive); dua akun (RLS dan, setelah diperbaiki, lokal);
percobaan klien mengisi `drive_file_id` sendiri (harus diabaikan trigger).

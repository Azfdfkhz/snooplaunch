# Foto Absensi — Laporan Implementasi (UI/UX + Bukti Absensi)

## STATUS VERIFIKASI
Kode **belum dikompilasi dan belum dijalankan**. Flutter/Dart SDK tidak tersedia di lingkungan ini (unduhan SDK
diblokir jaringan). Yang dilakukan hanya: audit kode, pengecekan keseimbangan kurung, dan verifikasi signature
`Image.fromBytes`/`encodeJpg` pada sumber paket `image` 4.2.0. Tidak ada skenario pengujian yang dinyatakan lulus.

Langkah pertama di mesin Anda:

    flutter pub get
    flutter analyze
    flutter test test/evidence_test.dart
    flutter run

## Hasil audit
- Layar absensi: `lib/screens/checkin_screen.dart` (dibuka dari widget Absensi di Home, `isOut` ditentukan Home).
- Kamera: `image_picker` (kamera sistem) + lokasi `geolocator`/`geocoding` di `CaptureService`. Dipertahankan.
- Pencatatan: `AppState.recordCheckIn/Out` (local-first, satu absensi per hari, waktu dicatat saat konfirmasi) lalu
  `SyncService` (antrean retry). Tidak diubah.
- Share/ekspor: belum ada sebelumnya.
- Preview lama: bottom sheet dengan foto di-crop (`BoxFit.cover`, tinggi 240) dan jam yang selalu `DateTime.now()`.

## Perubahan
| File | Perubahan |
|---|---|
| `lib/screens/checkin_screen.dart` | Ditulis ulang: layar "Foto Absensi" (header, panduan, chip jenis/jadwal, tombol shutter, error izin kamera + "Buka Pengaturan", loading bertahap). Orkestrasi alur ambil → tinjau → catat → hasil, termasuk loop "Ambil Ulang". |
| `lib/screens/attendance_preview_screen.dart` | Baru: halaman konfirmasi penuh. Foto `BoxFit.contain` (tanpa crop), chip "Siap dikirim", jenis, tanggal-waktu, lokasi; aksi Gunakan Foto / Ambil Ulang / Batalkan. |
| `lib/screens/attendance_done_screen.dart` | Baru: hasil absensi, status penyimpanan/sinkronisasi (dibedakan dari "terverifikasi"), tombol **Bagikan Bukti Absensi**, error + coba lagi. |
| `lib/services/evidence_service.dart` | Baru: validasi data, render gambar bukti (dart:ui Canvas, 1080 px, JPEG q90 di isolate), simpan di cache `bukti_absensi/`, share sheet via `share_plus`, pembersihan berkas >1 jam pada ekspor berikutnya. |
| `lib/services/capture_service.dart` | `CaptureFailure` (izin kamera ditolak / kamera tidak ada), `takenAt`, `persist` (salin foto ke penyimpanan aplikasi), `discard`, `openAppSettings`. Kualitas 80 → 85. |
| `lib/core/models.dart` | `Memory.takenAt` opsional (kompatibel dengan data lama). |
| `pubspec.yaml` | + `share_plus`, `path_provider`, `image`. |
| `test/evidence_test.dart` | Baru: nama file dan label status (belum dijalankan). |

## Perilaku yang sengaja dijaga
- Waktu absen tetap saat konfirmasi; waktu foto diambil disimpan terpisah dan hanya tampil di gambar bila selisih ≥ 1 menit.
- Status pengiriman: "Tersimpan di perangkat" / "Menunggu sinkronisasi" / "Tercatat di server". Tidak ada "Terverifikasi".
- Nomor referensi hanya tampil bila absensi sudah dikonfirmasi server. Tidak ada QR.
- Lokasi hanya tampil bila benar-benar didapat; selain itu "Lokasi tidak tersedia".
- Setelah share sheet, aplikasi hanya menyatakan gambar "diserahkan ke aplikasi pilihan"; tidak mengklaim terkirim/dibaca.

## Belum selesai / keputusan yang perlu Anda ketahui
1. **Tidak ada pratinjau kamera langsung di dalam aplikasi.** Kamera tetap kamera sistem (`image_picker`) agar izin,
   rotasi EXIF, dan alur yang sudah berjalan tidak diganti. Panel panduan di layar bukan live preview. Pratinjau
   langsung membutuhkan paket `camera` dan itu kamera baru; perlu keputusan Anda.
2. Belum diuji: seluruh skenario di bagian 11 prompt (izin, portrait/landscape, offline, share ke WhatsApp, layar kecil, sesi kedaluwarsa).
3. Orientasi EXIF pada gambar bukti mengandalkan decoder Flutter; harus dicek dengan foto portrait di perangkat nyata.
4. Ukuran 1080 px dan kualitas JPEG 90 adalah titik awal, belum ditentukan lewat pengujian. WhatsApp akan mengompres
   ulang; kirim sebagai "Dokumen" bila butuh kualitas penuh.
5. Tombol bagikan baru ada di layar hasil. Belum ada di Detail Memori (model `Memory` belum menyimpan jenis masuk/pulang).
6. Foto yang hilang karena Android mematikan aplikasi saat kamera terbuka (`retrieveLostData`) belum ditangani.
7. Label zona waktu masih "WIB" tetap, mengikuti konvensi yang sudah ada di aplikasi.
8. Tidak ada tes widget/integrasi untuk alur kamera.

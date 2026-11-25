# SNOOP School Life 2.0.0 — laporan implementasi terhadap PRD v2.0

Dasar: `SNOOP_School_Life_PRD_v2_0.md`. Dokumen ini jujur soal apa yang SUDAH dikerjakan, apa yang BELUM, dan apa yang
**belum terverifikasi**.

## Status verifikasi (baca dulu)

| Hal | Status |
|---|---|
| Logika domain murni (jadwal, tugas, kalender, catatan, statistik, perencana pengingat, pemetaan migrasi) | **Dianalisis dan diuji nyata** di Dart SDK 3.14.1: `dart analyze` bersih, 31 tes (`test/school_logic_test.dart`) lulus. |
| Kode yang memakai Flutter (layar, `SchoolStore`, `AppState`, notifikasi, backend) | **Belum dikompilasi.** Flutter SDK dan pub.dev tidak dapat diakses di lingkungan kerja ini. Nama kelas/metode/token tema yang dirujuk sudah dicocokkan manual dengan kode yang ada, tetapi tetap harus dijalankan `flutter pub get && flutter analyze && flutter test` sebelum dipakai. Kemungkinan ada galat kecil. |
| Tes `school_store_test`, `pkl_migration_test` (grup AppState), `school_home_controller_test` | Ditulis, **belum dijalankan** (butuh Flutter). |
| SQL `supabase/migration_011_school_life.sql` | Ditulis, **belum dijalankan** di Supabase. Wajib di staging dulu. |
| Perangkat nyata (notifikasi, kamera, Drive, TalkBack) | **Belum diuji.** |

## Yang dikerjakan (peta ke PRD)

- **3 / 4.1 Pivot & Home**: `SchoolHomeScreen` memakai komposisi Retro Industrial 1.5.0 dan widget `features/home/widgets`
  (panel Hari Ini, Daily Learning Timeline, Current/Next Class, countdown kelas/ujian/tenggat, Task Focus, Productivity
  Snapshot, orbit School Memories, dock). Pengalih mode PKL/Sekolah dihapus (`AppState.mode/schoolMode/setMode`).
  Menu aksi cepat menggantikan posisi chip mode.
- **4.2 Jadwal pelajaran**: slot mingguan berulang disimpan sekali; pengecualian per tanggal (batal/ganti/tambah); validasi jam;
  deteksi bentrok sebelum simpan (konfirmasi); masa berlaku; aktif/nonaktif; tampilan harian + mingguan; kelas berlangsung/berikutnya.
- **4.3 Tugas**: tipe/prioritas/status, tenggat timezone-aware, lampiran foto/dokumen/tautan (maks 20 MB, tidak hilang saat status
  berubah), filter + cari, terlambat, riwayat selesai, arsip.
- **4.4 Kalender akademik**: event 7 tipe, bulan + agenda; tenggat tugas **diproyeksikan** (bukan disalin) dan tidak ganda bila event menaut tugas.
- **4.5 Catatan**: cari judul/isi/tag, mapel, sematan, lampiran, autosave + indikator, **optimistic concurrency** (versi usang ditolak, tidak menimpa).
- **4.6 School Memories**: `Memory.workspace` (`school`/`pkl`), kategori, mapel, tugas. Data lama tanpa penanda = `pkl`. Alur tambah dokumentasi sekolah (tanpa lokasi).
- **4.7 Pengingat**: tipe akademik; pengingat otomatis kelas/tenggat/ujian/acara dengan ID deterministik dan rekonsiliasi (tidak menggandakan); pemetaan eksplisit tipe lama.
- **4.8 QR Sekolah**: diberi nama ulang menjadi QR vault/viewer; tidak mengklaim validasi absensi.
- **4.9 Statistik**: completion rate (`null` → "Belum ada data", bukan 0%), periode minggu/bulan/semua/kustom, arsip/terhapus tidak dihitung, data PKL tidak ikut.
- **4.10 Arsip PKL (read-only)**: profil/jam kerja, riwayat absensi, jadwal kerja, dokumentasi (detail `readOnly`), bukti, catatan mingguan, pencapaian, metadata arsip. Tidak ada aksi tulis.
- **6.2/6.4 Arsitektur**: `SchoolStore` (repository, terpisah dari `AppState`) dengan UUID, `updatedAt`, soft delete, `syncStatus`, isolasi record rusak, tulis berurutan.
- **7.x / 9 Data & migrasi**: SQL 011 (tabel, constraint, indeks, RLS, trigger; tanpa DROP/DELETE data PKL; rollback hanya objek baru). Migrasi lokal v3→v4: cadangan JSON, metadata arsip, pemetaan pengingat, verifikasi jumlah record, versi baru **hanya** setelah lolos verifikasi, idempotent.
- Profil siswa: kelas, jurusan, tahun ajaran (tidak diisi otomatis dari data PKL). `company`/`period` dipertahankan, tidak diedit dari UI.

## Batasan yang disengaja / belum dikerjakan

1. **Penyimpanan masih SharedPreferences (JSON)**, bukan SQLite/Drift + outbox (PRD 6.3). `SchoolStore` memakai antarmuka `KeyValueStore` sehingga penggantian tidak mengubah UI.
2. **Sinkronisasi cloud data akademik belum ada.** Tabel server sudah disiapkan, klien belum mendorong/menarik jadwal, tugas, kalender, catatan. Pengaturan menampilkan jumlah item "hanya di perangkat". Hanya profil siswa dan dokumentasi sekolah (workspace+kategori) yang disinkronkan, dengan fallback bila SQL 011 belum dijalankan. `subject_id`/`task_id` dokumentasi tidak dikirim sampai mapel/tugas tersinkron (kunci asing).
3. **Pengingat kelas berulang mingguan** dan tidak mengikuti pembatalan pada tanggal tertentu. Pengingat sekali-jalan dibatasi 60 hari / 60 buah.
4. Lampiran tugas/catatan belum diunggah ke Drive (hanya lokal); membuka berkas non-foto memakai `url_launcher` dan dapat gagal di sebagian perangkat Android.
5. Jam sekolah/kalender akademik **tidak** diisi bawaan; tidak ada data contoh.
6. Lokasi dokumentasi sekolah tidak diambil (PRD 8.3: opt-in; belum diimplementasi).
7. Jembatan SnoopDesk (`workspace_bridge`) masih mengirim jadwal kerja PKL lama; belum memetakan jadwal pelajaran.
8. Kode absensi PKL (`home_screen.dart`, `schedule_screen.dart`, `checkin_screen.dart`, `streak_screen.dart`, `profile_screen.dart`) **dipertahankan tetapi tidak terjangkau dari Shell**; dihapus hanya setelah migrasi terbukti aman di perangkat nyata (PRD 18). `HomeScreen` memuat catatan LEGACY.
9. Instalasi baru tidak lagi diberi jadwal/pengingat PKL bawaan (tes lama diperbarui sesuai).
10. Tes widget/integrasi/aksesibilitas (TalkBack, 200% font, tema gelap) belum ditulis.
11. Nama paket/aplikasi/ikon/ID Android tidak diubah (menghindari pemutusan update dan sinkronisasi).

## Langkah verifikasi yang disarankan

1. `flutter pub get && flutter analyze && flutter test` — perbaiki galat kompilasi bila ada.
2. Jalankan `migration_011_school_life.sql` di **staging**; cek tiga query verifikasi di akhir berkas.
3. Pasang 2.0.0 **di atas** instalasi 1.5.3 berisi data PKL nyata: cek Arsip PKL (jumlah absensi, foto, bukti, catatan), `v4_backup_json` terbuat, `data_version` = 4, pengingat "Absen Pulang" nonaktif tapi ada.
4. Uji pengingat (kelas, tenggat, event) dan pengingat tidak ganda setelah edit berulang dan reboot.
5. Uji TalkBack, font 200%, tema gelap pada Home dan tiap layar baru.

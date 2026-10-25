# SNOOP — Product Requirements Document (PRD)

**Produk:** SNOOP — Smart PKL Launcher  
**Platform:** Android (Flutter + integrasi native Kotlin)  
**Versi dokumen:** 1.1  
**Tanggal:** 25 Oktober 2026  
**Status:** Draft kerja — diperbarui berdasarkan audit kode aktual

> Dokumen ini diperbarui dari v1.0 setelah audit menyeluruh terhadap seluruh source code (`lib/`, `android/`, `supabase/`). Perbedaan antara klaim sebelumnya dan kondisi aktual telah dikoreksi. Status implementasi belum dianggap terverifikasi sampai build dan pengujian perangkat berhasil.

## Daftar Isi

1. [Ringkasan Produk](#1-ringkasan-produk)
2. [Masalah dan Peluang](#2-masalah-dan-peluang)
3. [Tujuan Produk](#3-tujuan-produk)
4. [Bukan Tujuan](#4-bukan-tujuan-non-goals)
5. [Pengguna dan Skenario Utama](#5-pengguna-dan-skenario-utama)
6. [Prinsip Pengalaman dan Design System](#6-prinsip-pengalaman-dan-design-system)
7. [Cakupan Fitur dan Kebutuhan Fungsional](#7-cakupan-fitur-dan-kebutuhan-fungsional)
8. [Aturan Bisnis Absensi](#8-aturan-bisnis-absensi)
9. [Data dan Model Konseptual](#9-data-dan-model-konseptual)
10. [Persyaratan Nonfungsional](#10-persyaratan-nonfungsional)
11. [Arsitektur dan Integrasi](#11-arsitektur-dan-integrasi)
12. [Status Implementasi](#12-status-implementasi-saat-dokumen-dibuat)
13. [Kriteria Penerimaan](#13-kriteria-penerimaan)
14. [Rencana Pengujian](#14-rencana-pengujian)
15. [Risiko dan Mitigasi](#15-risiko-dan-mitigasi)
16. [Roadmap](#16-roadmap-yang-disarankan)
17. [Keputusan yang Masih Perlu Dikonfirmasi](#17-keputusan-yang-masih-perlu-dikonfirmasi)
18. [Definition of Done](#18-definisi-selesai-definition-of-done)

---

## 1. Ringkasan Produk

SNOOP adalah aplikasi Android yang menggabungkan launcher personal, dashboard aktivitas PKL, absensi masuk/pulang berbasis kamera dan lokasi, jadwal, pengingat, serta dokumentasi kegiatan bergaya polaroid dalam Memories.

Aplikasi mengutamakan antarmuka pastel yang rapi, komponen membulat, tombol pil, navbar kapsul gelap, dan pengalaman yang ringan. Data harus tetap dapat digunakan secara lokal ketika jaringan tidak tersedia, lalu disinkronkan secara aman ketika koneksi dan sesi akun tersedia.

---

## 2. Masalah dan Peluang

- Aktivitas PKL tersebar di beberapa aplikasi: jadwal, absensi, catatan kegiatan, dan pengingat.
- Pengguna membutuhkan cara cepat membuka aplikasi favorit tanpa meninggalkan dashboard aktivitas.
- Dokumentasi foto kegiatan perlu terhubung dengan jadwal dan catatan absensi agar mudah ditinjau kembali.
- Koneksi internet tidak selalu tersedia; pencatatan lokal dan sinkronisasi tertunda perlu memiliki status yang jelas.

---

## 3. Tujuan Produk

- Menyediakan satu tempat untuk melihat aktivitas, jadwal, pengingat, dan dokumentasi PKL.
- Membuat proses check-in/check-out mudah, transparan, dan memiliki jejak waktu serta lokasi.
- Memberikan launcher Android yang dapat dipilih sebagai aplikasi Home default.
- Menjaga data pengguna terpisah, mendukung operasi offline, dan menyediakan sinkronisasi ketika backend dikonfigurasi.
- Menyediakan fondasi yang dapat diuji dan dikembangkan menuju rilis produksi.

---

## 4. Bukan Tujuan (Non-goals)

- Bukan sistem payroll, HRIS, atau penentu resmi kehadiran tanpa persetujuan institusi/perusahaan.
- Tidak menjamin lokasi sebagai bukti anti-kecurangan; GPS perangkat dapat tidak akurat atau dimanipulasi.
- Tidak mengunggah foto ke Google Drive sebelum autentikasi dan alur backend yang aman selesai dibuat.
- Tidak menganggap build atau fitur sebagai production-ready hanya karena source code tersedia.

---

## 5. Pengguna dan Skenario Utama

| Persona | Kebutuhan | Skenario |
|---|---|---|
| Peserta PKL | Mencatat kehadiran dan kegiatan dengan cepat | Buka Beranda → check-in → ambil foto → konfirmasi → lihat status. |
| Peserta PKL saat offline | Tetap mencatat data tanpa jaringan | Check-in lokal → status `pending` → sinkronisasi saat online dan login. |
| Pengguna launcher | Membuka aplikasi favorit dari satu tempat | Buka App Drawer → cari/kategori/favorit → buka aplikasi. |
| Pengguna Memories | Meninjau dokumentasi aktivitas | Buka Memories → filter → buka detail → lihat waktu/lokasi dan jadwal terkait. |

---

## 6. Prinsip Pengalaman dan Design System

| Elemen | Ketentuan |
|---|---|
| Gaya visual | Pastel, minimal, ramah, rapi; hindari tema karakter hewan. |
| Palet dasar | `#F5F4F6` (bg), `#E8E6E8` (soft), `#D8E8DE` (mint), `#C9DDEB` (blue), `#F2B7C5` (pink), `#29282A` (text). |
| Komponen | Kartu membulat (`SnoopCard` radius 20), tombol pil (`PillButton`/`StadiumBorder`), navbar kapsul (`CapsuleNav`), bayangan lembut, kartu foto polaroid (`PolaroidCard`). |
| Maskot | Saat ini placeholder `Mascot` (ikon wajah di lingkaran biru); ilustrasi final harus diletakkan di `assets/` dan memiliki fallback. |
| Aksesibilitas | `CapsuleNav` sudah memiliki `Semantics(button:true, label:...)`. Kontras teks, ukuran target sentuh, skala font, dan mode gelap harus diuji lebih lanjut. |
| Responsif | Tampilan utama harus layak di berbagai ukuran layar Android; jangan mengandalkan ukuran piksel tunggal. |

---

## 7. Cakupan Fitur dan Kebutuhan Fungsional

Prioritas: **P1** = inti sebelum rilis awal; **P2** = peningkatan setelah fitur inti stabil.

| ID | Fitur | Kebutuhan | Prioritas |
|---|---|---|---|
| FR-01 | Splash | Menampilkan identitas SNOOP saat aplikasi dibuka dan meneruskan pengguna ke layar Shell. | P1 |
| FR-02 | Beranda | Merangkum status absensi hari ini, jadwal sedang/segera berlangsung, pengingat berikutnya, Memories terbaru, dan pintasan fitur. Dashboard diperbarui tiap 20 detik. | P1 |
| FR-03 | Absensi masuk | Meminta izin kamera/lokasi, mengambil foto dan lokasi via `CaptureService`, menampilkan preview bottom-sheet, lalu meminta konfirmasi sebelum menyimpan dan membuat `Memory` terkait. | P1 |
| FR-04 | Absensi pulang | Mencatat waktu pulang; tidak mengizinkan checkout tanpa check-in valid; mengupdate `Attendance.status` ke `checkedOut`. | P1 |
| FR-05 | Aturan kehadiran | Status hadir/terlambat dihitung dari `workStartMin` + `lateToleranceMin` (default 15 menit) saat check-in. Jadwal tidak otomatis `completed` hanya karena waktu berlalu. | P1 |
| FR-06 | Pencegahan duplikasi | Hanya satu record `Attendance` per hari (berdasarkan `dayKey` — `yyyy-mm-dd` dari `DateTime.now()`); check-in kedua ditolak di klien. | P1 |
| FR-07 | Jadwal | Lihat, tambah, tandai selesai; tampilan harian dan mingguan per hari. `ScheduleItem` berisi `id`, `title`, `place`, `startMin`, `endMin?`, `status`. | P1 |
| FR-08 | Pengingat | Buat, hapus, aktifkan/nonaktifkan; filter per tipe (air, istirahat, absen, dokumentasi, kustom); notifikasi harian dijadwalkan via `NotificationService`. | P1 |
| FR-09 | Notifikasi lokal | `NotificationService` menjadwalkan notifikasi harian `zonedSchedule` dengan timezone `Asia/Jakarta`; `stableId` berbasis FNV-1a; izin diminta saat inisialisasi. | P1 |
| FR-10 | App Drawer | Menampilkan aplikasi yang tersedia via `LauncherService` (MethodChannel `snoop/launcher`), demo data pada non-Android, ikon, pencarian, favorit tekan lama, kategori heuristik. | P1 |
| FR-11 | Launcher default | Intent-filter `HOME` + `DEFAULT` pada `MainActivity`; `openHomeSettings()` membuka selektor launcher default. | P1 |
| FR-12 | Memories | Grid polaroid dari `Memory`; filter (Semua/Hari Ini/Minggu Ini/Kegiatan); detail menampilkan foto, meta, lokasi Maps, deskripsi, dan jadwal terkait. | P1 |
| FR-13 | Lokasi Memories | Koordinat `lat/lng` disimpan di `Memory`; tombol membuka `geo:` URI di aplikasi peta. | P2 |
| FR-14 | Profil | Edit `fullName`, `school`, `company`, `period`, `workStartMin/EndMin`; disimpan lokal via SharedPreferences; ditandai untuk sinkronisasi ketika auth tersedia. | P1 |
| FR-15 | Pengaturan | Tema terang/gelap (`setTheme('Terang'/'Gelap')`); notifikasi test; set launcher default; info akun. | P2 |
| FR-16 | Autentikasi | `BackendService` menyediakan `signIn`, `signUp`, `signOut`; UI autentikasi (layar login/daftar) **belum ada**; perlu dibuat. | P1 |
| FR-17 | Sinkronisasi | `HybridSyncService` push `Attendance` dan `Memory` ke Supabase; gagal ke antrean `PendingSyncQueue` (SharedPreferences); `retryPending()` dipanggil saat startup. | P1 |
| FR-18 | Mode offline | Semua operasi CRUD berjalan tanpa jaringan; data `Pending` tetap tersedia setelah aplikasi ditutup/dibuka ulang. | P1 |
| FR-19 | Google Drive | Upload foto melalui backend tepercaya; simpan `driveFileId/URL` di `Memory.upload`; belum diimplementasikan. | P2 |
| FR-20 | Privasi data | Penjelasan pemakaian kamera, lokasi, foto; ekspor/penghapusan data; kebijakan privasi. Belum diimplementasikan. | P1 |

---

## 8. Aturan Bisnis Absensi

1. Satu pengguna hanya memiliki satu record `Attendance` harian; kunci adalah `dayKey(DateTime.now())` (`yyyy-mm-dd`). Perubahan zona waktu perangkat tidak boleh menyebabkan duplikasi atau kehilangan record.
2. Status hadir/terlambat dihitung dari `workStartMin + lateToleranceMin` (default 15 menit). **Masih perlu dikonfirmasi:** apakah tepat pada menit ke-15 termasuk Hadir atau Terlambat (lihat §17).
3. Check-out hanya dapat dilakukan setelah check-in valid (`today != null && today.checkOutAt == null`).
4. Foto dan lokasi disimpan setelah pengguna mengonfirmasi di preview. Jika izin ditolak atau pengambilan gagal, `CaptureService` menyertakan `locationNote` yang menjelaskan dampaknya.
5. Data lokal yang belum diterima server berstatus **`pending`** (dalam `PendingSyncQueue`). Status final dari server (`present`, `late`, `checked_out`, `needs_attention`) harus dibedakan dari status lokal sementara.
6. Validasi penting harus dilakukan atau diverifikasi di backend. Waktu perangkat dan koordinat bukan bukti anti-kecurangan yang mutlak.
7. Aturan satu absensi per hari harus konsisten antara Flutter dan SQL. Skema saat ini menggunakan `Asia/Jakarta` untuk indeks unik — konfirmasi apakah mengikuti profil pengguna (lihat §17).

---

## 9. Data dan Model Konseptual

### Model Dart (`lib/core/models.dart`)

| Kelas | Tujuan / field penting |
|---|---|
| `ScheduleItem` | `id`, `title`, `place`, `startMin` (int menit), `endMin?`, `status` (`ScheduleStatus` enum). Method `effective(now)` mengembalikan status tampilan tanpa auto-complete. |
| `Reminder` | `id`, `title`, `detail`, `type` (air/istirahat/absen/dokumentasi/kustom), `atMin`, `enabled`. |
| `Memory` | `id`, `title`, `scheduleId?`, `photoPath?`, `capturedAt`, `lat?`, `lng?`, `accuracy?`, `placeName?`, `description`, `upload` (`UploadStatus` enum). |
| `Attendance` | `id`, `day` (yyyy-mm-dd), `checkInAt`, `checkOutAt?`, `status` (`AttendanceStatus` enum). |

### Skema Supabase (`supabase/schema.sql`)

| Tabel | Keterangan |
|---|---|
| `profiles` | ID akun, nama, institusi, perusahaan, zona waktu (default `Asia/Jakarta`), waktu pembaruan. |
| `work_schedules` | Pemilik, judul, deskripsi, `start_at`/`end_at` (timestamptz — **berbeda dari model Dart yang pakai `int startMin`**). |
| `attendance_records` | Pemilik, check-in/out timestamptz, koordinat, status, `device_time_at`. Indeks unik per hari berdasarkan `Asia/Jakarta`. |
| `documentations` | Pemilik, `schedule_id`, `captured_at`, koordinat, judul/deskripsi, `upload_status`. |
| `reminders` | Pemilik, judul/deskripsi, tipe, waktu terjadwal, aturan pengulangan, status aktif. |

> **Ketidaksesuaian skema:** `work_schedules` menyimpan waktu sebagai `timestamptz`, sementara model Dart menggunakan `int startMin` (menit dalam hari). Perlu konversi di layer sinkronisasi yang belum ada.

Skema perlu diuji di project staging, ditinjau untuk konsistensi zona waktu, dan diuji dengan dua akun untuk memastikan RLS benar-benar mengisolasi data.

---

## 10. Persyaratan Nonfungsional

| Area | Persyaratan |
|---|---|
| Keamanan | RLS aktif untuk seluruh tabel milik pengguna; kunci `service_role` dan kredensial Google tidak pernah disimpan di klien. `BackendService` menggunakan `String.fromEnvironment` untuk URL/key Supabase. |
| Privasi | Minta izin sesuai konteks (kamera, lokasi); minimalkan lokasi yang disimpan; jelaskan tujuan, retensi, ekspor, dan penghapusan. |
| Keandalan | Operasi lokal tidak hilang saat aplikasi ditutup; `PendingSyncQueue` persistent di SharedPreferences; sinkronisasi idempoten (upsert by UUID). |
| Kinerja | Layar utama dan App Drawer responsif; operasi jaringan di luar UI thread; `PolaroidCard` menggunakan `cacheWidth: 400` untuk efisiensi memori. |
| Kompatibilitas | Target awal Android 10+ (API 29); validasi build pada Android 13, 14, dan 15 serta beberapa OEM. |
| Aksesibilitas | Kontras warna, skala font, TalkBack/label (`CapsuleNav` sudah ada `Semantics`), ukuran sentuh, dan mode gelap diperiksa. |
| Observabilitas | Catat error teknis tanpa membocorkan foto, token, koordinat sensitif, atau data pribadi ke log. |
| Pemeliharaan | Migrasi skema/data berversi, tes otomatis, dokumentasi setup, dan proses build yang dapat diulang. |

---

## 11. Arsitektur dan Integrasi

```
lib/
├── main.dart          AppScope (InheritedNotifier<AppState>) + SnoopApp
├── core/
│   ├── models.dart    ScheduleItem, Reminder, Memory, Attendance + enum
│   ├── state.dart     AppState (ChangeNotifier) — local-first, SharedPreferences
│   ├── theme.dart     C (palet warna), snoopTheme(), utilitas format waktu
│   └── widgets.dart   SnoopCard, PillButton, PolaroidCard, CapsuleNav, dll.
├── screens/           10 layar (splash, shell, home, checkin, schedule,
│                      reminders, app_drawer, memories, profile, settings)
└── services/
    ├── backend_service.dart   Supabase adapter + PendingSyncQueue
    ├── capture_service.dart   Kamera (image_picker) + GPS (geolocator ^12)
    ├── launcher_service.dart  MethodChannel 'snoop/launcher' ke MainActivity.kt
    ├── notification_service.dart  flutter_local_notifications + timezone
    └── sync_service.dart      HybridSyncService / NoopSyncService
```

- **Frontend:** Flutter/Dart, SDK `>=3.3.0 <4.0.0`.
- **Android native:** Kotlin di `MainActivity.kt` melalui `MethodChannel('snoop/launcher')` untuk `getApps`, `launch`, `appInfo`, `openHomeSettings`.
- **Penyimpanan lokal:** `SharedPreferences` — cukup untuk MVP; perlu diganti SQLite/Drift untuk produksi (TODO ada di `state.dart`).
- **Backend:** Supabase Auth + Postgres + RLS. Dikonfigurasi via `--dart-define=SUPABASE_URL=...` dan `--dart-define=SUPABASE_ANON_KEY=...`. Backend **opsional** — aplikasi tetap berjalan lokal jika env var kosong.
- **Foto:** Belum diunggah ke Drive; `Memory.upload` bertipe `UploadStatus.pending` sebagai default.
- **Notifikasi:** `flutter_local_notifications ^17.2.4` + `timezone ^0.9.4`; timezone di-hardcode `Asia/Jakarta`; `AndroidScheduleMode.inexactAllowWhileIdle`.
- **State management:** `AppState extends ChangeNotifier` + `AppScope extends InheritedNotifier<AppState>`. Layar membaca via `AppScope.of(context)`.

---

## 12. Status Implementasi Saat Dokumen Dibuat

> Berdasarkan audit kode aktual — bukan klaim. Build belum diverifikasi.

### Sudah ada dalam source dan secara struktural lengkap

| Komponen | Catatan |
|---|---|
| Design system pastel | `theme.dart` (palet C), `widgets.dart` (semua komponen), `snoopTheme()` Material 3 |
| `AppState` + `AppScope` | `ChangeNotifier` + `InheritedNotifier`; load/save SharedPreferences; semua CRUD |
| Model data | `ScheduleItem`, `Reminder`, `Memory`, `Attendance` + enum; `toJson`/`fromJson` |
| 10 layar | Splash, Shell (nav 4 tab), Home, CheckIn, Schedule, Reminders, AppDrawer, Memories, Profile, Settings |
| Alur absensi | Foto + GPS (`CaptureService`), preview, confirm, simpan `Attendance` + `Memory` |
| Jadwal | CRUD; tampilan harian/mingguan; status chip |
| Pengingat | CRUD; toggle aktif; filter tipe; notifikasi harian dijadwalkan |
| App Drawer | MethodChannel ke native; demo data; favorit; kategori heuristik |
| `NotificationService` | `scheduleDaily` (zonedSchedule + matchDateTimeComponents); `stableId` FNV-1a |
| `BackendService` | Supabase init opsional; `signIn/Up/Out`; `syncAttendance`; `syncMemory` (upsert) |
| `HybridSyncService` | Push attendance/memory; antrean retry `PendingSyncQueue` |
| `PendingSyncQueue` | Persistent di SharedPreferences; idempoten (cek duplikasi sebelum enqueue) |

### Diperbaiki dalam v1.1

| File | Perbaikan |
|---|---|
| `lib/services/capture_service.dart` | API `Geolocator.getCurrentPosition` disesuaikan parameter `desiredAccuracy` dan `timeLimit` sesuai geolocator 12.0.0 |
| `lib/screens/schedule_screen.dart` | Perbandingan tanggal gunakan full date `_sameDay(a,b)` — perbaiki bug batas bulan |
| `lib/screens/schedule_screen.dart` | Header bagian jadwal dinamis: "Jadwal Hari Ini" vs "Jadwal Minggu Ini" |
| `lib/screens/home_screen.dart` & `checkin_screen.dart` | Hapus redundant string interpolation untuk linter bersih |
| `lib/services/backend_service.dart` | Ganti deprecated `anonKey` dengan `publishableKey` |
| `android/app/build.gradle.kts` | Aktifkan `isCoreLibraryDesugaringEnabled = true` + `desugar_jdk_libs:2.1.4` untuk `flutter_local_notifications` |
| `android/app/build.gradle.kts` | Update `compileSdk = 36` dan `minSdk = 21` |
| `android/build.gradle.kts` | Subproject override `compileSdkVersion(36)` agar plugin kompatibel dengan AndroidX terbaru (mis. `geocoding_android`) |
| `android/app/src/main/kotlin/.../MainActivity.kt` | Implementasi MethodChannel `snoop/launcher` (`getApps`, `launch`, `appInfo`, `openHomeSettings`) |
| `android/app/src/main/AndroidManifest.xml` | Tambah permissions: CAMERA, ACCESS_FINE_LOCATION, ACCESS_COARSE_LOCATION, ACCESS_NETWORK_STATE, POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM, USE_EXACT_ALARM, RECEIVE_BOOT_COMPLETED, INTERNET |
| `android/app/src/main/AndroidManifest.xml` | Tambah intent-filter HOME + DEFAULT dan `launchMode="singleTask"` untuk fungsionalitas launcher (FR-11) |
| `android/app/src/main/AndroidManifest.xml` | Daftarkan `ScheduledNotificationBootReceiver` (BOOT, REPLACED, TIME_SET, TIMEZONE_CHANGED) dan `ScheduledNotificationReceiver` |
| `android/app/src/main/AndroidManifest.xml` | Tambah `queries` block untuk enumerasi aplikasi terinstall (LauncherService) |

### Ada tetapi perlu pengujian

| Komponen | Catatan |
|---|---|
| Launcher HOME intent | Terkonfigurasi dan native bridge terimplementasi; perlu pengujian di perangkat fisik |
| Notifikasi reboot | Receiver terdaftar; perlu pengujian reboot di perangkat fisik |
| Alur tema gelap | `setTheme('Gelap'/'Terang')` di state; perlu uji visual |
| `retryPending()` | Dipanggil saat startup; tidak ada backoff/batas retry; race condition jika dipanggil bersamaan |
| Skema SQL timezone | Indeks unik hardcode `Asia/Jakarta`; profil punya field timezone tapi tidak dipakai di indeks |

### Belum diimplementasikan

| Komponen | Catatan |
|---|---|
| Layar autentikasi | `BackendService` ada method auth tapi tidak ada UI login/daftar/reset password |
| Sinkronisasi jadwal/pengingat | `BackendService` hanya sync `attendance` + `memory`; jadwal dan pengingat tidak tersinkron |
| Upload Google Drive | `Memory.upload` selalu `pending`; belum ada backend edge function |
| Kalender per-tanggal | Schedule hanya flat list; kalender per-tanggal belum ada |
| Snooze pengingat | FR-08 menyebut menunda pengingat; tidak ada implementasi |
| Ekspor/hapus data | FR-20 privasi; tidak ada layar atau alur |
| Signing rilis | `build.gradle.kts` masih debug signing + `com.example.snoop` (perlu diganti) |
| Aksesibilitas audit | Belum ada audit formal TalkBack, kontras, ukuran sentuh |

---

## 13. Kriteria Penerimaan

- [x] Project dapat menjalankan `flutter pub get`, `flutter analyze`, dan `flutter test` tanpa error yang belum diselesaikan atau didokumentasikan (Terverifikasi: `flutter analyze` 0 issues).
- [x] APK debug dapat dibangun dengan konfigurasi yang terdokumentasi (Terverifikasi: `flutter build apk --debug` sukses).
- [ ] Pengguna dapat check-in, melihat preview, mengonfirmasi, lalu melihat record dan status yang sesuai.
- [ ] Checkout tanpa check-in valid ditolak dengan pesan yang jelas.
- [ ] Duplikasi absensi harian dicegah di klien dan backend, termasuk ketika dua permintaan datang hampir bersamaan.
- [ ] Ketika offline, data ditandai Pending dan tetap tersedia setelah aplikasi ditutup/dibuka ulang.
- [ ] Setelah online dan login, antrean dapat tersinkron tanpa membuat duplikasi; kegagalan terlihat dan dapat dicoba ulang.
- [ ] Dua akun Supabase tidak dapat membaca atau mengubah data satu sama lain (RLS).
- [ ] Notifikasi diuji pada perangkat nyata: izin diberikan/ditolak, reboot, battery saver, force-stop.
- [ ] Foto tidak dianggap sudah diunggah ke Drive sampai server mengonfirmasi file ID/URL.
- [ ] Pengguna dapat mengetahui data apa yang dikumpulkan dan memiliki jalur untuk mengekspor atau menghapus data.
- [ ] Launcher dapat dipilih sebagai Home default, menampilkan aplikasi yang tersedia, dan membuka aplikasi di perangkat fisik.

---

## 14. Rencana Pengujian

| Kelompok | Kasus minimum |
|---|---|
| Unit | Batas toleransi terlambat (`workStartMin + lateToleranceMin`); `dayKey` pergantian hari; `_sameDay` bulan berbeda; `effective()` status jadwal; `PendingSyncQueue` idempoten; `_stableId` FNV-1a. |
| Widget | Splash → Shell; dashboard status absensi; preview/konfirmasi checkin; jadwal harian vs mingguan; pengingat toggle; App Drawer search; Memories filter; profil edit; settings tema. |
| Integrasi | Kamera/lokasi (izin diberikan/ditolak/denied forever); notifikasi (izin, schedule, cancel); Supabase Auth; RLS dua akun; antrean offline; `retryPending` setelah koneksi pulih. |
| Perangkat | Android 10+; Android 13/14/15; izin ditolak; jaringan lambat/putus; storage penuh; proses aplikasi dihentikan; OEM berbeda. |
| Keamanan | RLS dengan dua akun; token kedaluwarsa; rahasia tidak ada di bundle/log; SUPABASE_URL/KEY tidak dikompilasi tanpa `--dart-define`. |
| Rilis | Signing; AAB; izin Manifest vs runtime; audit aksesibilitas; crash/error reporting; `applicationId` bukan `com.example`. |

---

## 15. Risiko dan Mitigasi

| Risiko | Dampak | Mitigasi |
|---|---|---|
| Aturan waktu berbeda antara klien dan server | Status hadir salah atau duplikasi lintas hari | Tetapkan zona waktu dan batas toleransi secara eksplisit; uji boundary; server sebagai sumber kebenaran. Indeks SQL `Asia/Jakarta` perlu diselaraskan dengan kebijakan. |
| Notifikasi tidak muncul pada perangkat tertentu | Pengingat terlewat | Uji berbagai OEM/versi Android; jelaskan izin dan batasan `inexactAllowWhileIdle`; receiver boot sudah terdaftar di Manifest. |
| Antrean SharedPreferences rusak/bertumbuh | Data pending hilang atau sinkronisasi macet | `PendingSyncQueue` sudah idempoten; migrasi ke SQLite/Drift untuk produksi; tambahkan batas ukuran dan versioning. |
| `retryPending` race condition | Double-sync record yang sama | Tambahkan flag `_retrying` atau mutex; `PendingSyncQueue.enqueue` sudah mencegah duplikasi. |
| Credentials Drive bocor | Akses file tidak sah | Simpan credentials hanya di backend; validasi JWT dan ownership; batasi MIME/ukuran dan akses file. |
| Data sensitif terlalu lama tersimpan | Risiko privasi | Tetapkan retensi, ekspor/penghapusan, minimisasi lokasi, dan dokumentasi persetujuan. |
| Launcher tidak kompatibel dengan OEM | Aplikasi tidak dapat menjadi Home default | Intent-filter HOME sudah ada; uji perangkat nyata dan sediakan fallback serta pesan yang jelas. |
| `applicationId = com.example.snoop` | Konflik di Play Store / perangkat lain | Ganti ke ID unik di `build.gradle.kts` sebelum distribusi. |
| Skema SQL `work_schedules` timestamptz vs Dart `int startMin` | Sinkronisasi jadwal tidak mungkin tanpa konversi | Buat konversi di `BackendService.syncSchedule()` sebelum implementasi sync jadwal. |

---

## 16. Roadmap yang Disarankan

| Tahap | Fokus | Output |
|---|---|---|
| A — Stabilitas | `flutter pub get`, `flutter analyze`, `flutter test`, build APK debug | Build debug berhasil; error prioritas tinggi ditutup. |
| B — Auth & Profil | Buat layar login/daftar; sambungkan `BackendService.signIn/Up`; sync profil | Alur autentikasi end-to-end tervalidasi. |
| C — Data inti | Sync jadwal + pengingat; RLS dua akun; offline queue produksi | Isolasi data dan sinkronisasi tervalidasi. |
| D — Media & notifikasi | Drive upload backend; retry; uji notifikasi reboot/OEM | Foto terunggah aman dan notifikasi teruji. |
| E — Pengalaman produk | Kalender per-tanggal; kategori drawer; maskot; detail Memories; snooze | Fitur pelengkap konsisten dengan design system. |
| F — Rilis | Privasi, aksesibilitas, crash reporting, signing, `applicationId`, CI, AAB | Checklist release terpenuhi; deployment terdokumentasi. |

---

## 17. Keputusan yang Masih Perlu Dikonfirmasi

1. **Toleransi 15 menit:** apakah terlambat mulai setelah melewati 15 menit, atau tepat pada menit ke-15 sudah terlambat? *(Implementasi saat ini: `at.hour*60+at.minute > workStartMin+lateToleranceMin` — lebih dari batas = terlambat.)*
2. **Foto wajib/opsional:** apakah check-in dan check-out wajib mengambil foto dan lokasi, atau salah satunya opsional? *(Implementasi saat ini: foto wajib; lokasi opsional dengan `locationNote`.)*
3. **Visibilitas data:** siapa yang dapat melihat data absensi — pengguna sendiri, pembimbing, atau admin institusi?
4. **Penyimpanan foto:** Google Drive pribadi pengguna atau Drive organisasi?
5. **Retensi data:** berapa lama foto, koordinat, dan riwayat absensi disimpan?
6. **Login wajib:** apakah aplikasi dapat digunakan sepenuhnya tanpa akun, atau login diperlukan untuk sinkronisasi? *(Implementasi saat ini: lokal-first, Supabase opsional.)*
7. **Zona waktu absensi:** `dayKey` menggunakan `DateTime.now()` (zona waktu perangkat), sementara indeks SQL hardcode `Asia/Jakarta`. Apakah harus seragam ke `Asia/Jakarta` atau mengikuti profil pengguna?
8. **Status kehadiran final:** ditentukan perangkat atau dikonfirmasi server/institusi? *(Rekomendasi: simpan status lokal sementara, validasi server sebagai sumber kebenaran.)*
9. **`applicationId`:** ganti `com.example.snoop` ke ID unik sebelum distribusi — apa ID yang diinginkan?

---

## 18. Definisi Selesai (Definition of Done)

- [ ] Implementasi memenuhi kriteria penerimaan yang relevan.
- [ ] Tes otomatis terkait lulus dan langkah uji manual dicatat.
- [ ] Perubahan skema memiliki migrasi/dokumentasi dan diuji di staging.
- [ ] Tidak ada rahasia server di kode klien, konfigurasi build, atau log.
- [ ] Kegagalan jaringan/izin ditangani dengan pesan yang dapat dipahami pengguna.
- [ ] Dokumentasi setup, konfigurasi, batasan, dan langkah rilis diperbarui.
- [ ] Build release dan pengujian pada perangkat nyata berhasil sebelum fitur diberi status production-ready.

---

**Akhir dokumen — SNOOP PRD v1.1**

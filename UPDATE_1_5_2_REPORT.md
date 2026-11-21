# SNOOP 1.5.2 (pendamping SnoopDesk 1.0.2)

**Status: BELUM dikompilasi** (tidak ada Flutter/Kotlin SDK di lingkungan pengerjaan). Jalankan `flutter analyze && flutter test`, lalu uji di HP.

Tujuan: kegiatan, absensi, dokumentasi, catatan, baterai, dan notifikasi HP tampil di Workspace SnoopDesk.

## Yang berubah
- `supabase/migration_010_workspace_bridge.sql` (**jalankan sekali** di SQL Editor): tabel `workspace_items`, `bridge_devices`, `device_status`, `device_notifications` + fungsi `workspace_replace`, `bridge_register`, `bridge_push`, `bridge_unregister`. RLS aktif; desktop hanya bisa membaca/menghapus datanya sendiri.
- `lib/services/workspace_bridge.dart` (baru): mendaftarkan HP (rahasia acak 32 byte, hanya hash disimpan di server), mendorong kegiatan, pengingat, dan catatan mingguan bila berubah (debounce 4 dtk), laporan baterai tiap menit saat aplikasi hidup.
- `android/.../CloudBridge.kt` (baru): layanan native mengirim baterai + notifikasi ke fungsi `bridge_push` hanya dengan anon key + rahasia perangkat, jadi tetap jalan saat Flutter tidak aktif dan tidak membagi token sesi.
- `SnoopNotificationListener.kt`: meneruskan notifikasi yang layak (kepentingan >= default, bukan ongoing/progres/media/sistem/grup/SNOOP sendiri; notifikasi `VISIBILITY_SECRET` hanya nama aplikasi) dan melaporkan baterai saat berubah.
- `MainActivity.kt` + `system_bridge.dart`: metode `bridgeConfigure/bridgeClear/bridgeNotifs/bridgePushBattery/bridgeInfo`.
- `state.dart`: `WorkspaceBridge.attach` di startBackground, sinkron saat login/resume/`changed()`, `disconnect()` saat keluar akun.
- `connect_desktop_screen.dart`: kartu "Workspace SnoopDesk" (status, saklar kirim notifikasi, tombol Akses notifikasi).
- `pubspec.yaml`: 1.5.2+1.

## Privasi
Judul dan isi notifikasi dikirim ke akun Supabase milik pengguna sendiri (disimpan 100 terbaru). Ada saklar untuk mematikan; keluar akun menghapus perangkat, status, dan notifikasi di server.

## Batasan
- Absensi dan dokumentasi tidak butuh tabel baru: desktop membaca `attendance_records` dan `documentations`.
- Notifikasi yang gagal terkirim (offline) ditahan di memori maks. 30 dan hilang bila proses dimatikan.
- Hanya satu HP aktif per akun (pendaftaran terbaru menang).
- Aturan weekend (`itemsOn`) ditiru di desktop; bila aturan di HP berubah, ubah juga `SchedulePanel`.

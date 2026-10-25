# SNOOP — Smart PKL Launcher (Flutter, Android)

## Cara menjalankan
1. Pasang Flutter SDK (>= 3.22, Dart >= 3.3).
2. Di root proyek: `./setup.sh`  (membuat folder `android/`, menyalin manifest launcher + MainActivity.kt, `flutter pub get`).
3. `flutter run` di perangkat Android (Android 10+).
4. Jadikan SNOOP launcher: Pengaturan > Launcher Default (atau tombol Home lalu pilih SNOOP).

## Struktur
- `lib/core` tema, model, state (SharedPreferences), widget reusable
- `lib/screens` 10 layar sesuai desain
- `lib/services` launcher (MethodChannel), kamera+lokasi, kontrak sinkronisasi
- `android_overrides` AndroidManifest (intent HOME, queries) + MainActivity.kt (daftar & buka aplikasi)
- `supabase/schema.sql` tabel + RLS sesuai PRD bagian 11

## Status
Lihat STATUS.md.


## Catatan rilis
Baca [`PRODUCTION_READINESS.md`](PRODUCTION_READINESS.md) untuk konfigurasi, fitur yang sudah ditambahkan, batasan yang masih ada, dan checklist sebelum rilis. Paket ini belum diverifikasi melalui build Flutter di lingkungan pembuat ZIP.

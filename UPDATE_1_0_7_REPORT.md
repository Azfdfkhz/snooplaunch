# Update 1.0.7 — Launcher default

**Status verifikasi:** BELUM dikompilasi dan BELUM diuji di perangkat (Flutter/Android SDK tidak tersedia di lingkungan pembuatan).
Uji wajib: build APK, pasang di Android 10+, lalu tekan tombol Home dan periksa apakah SNOOP muncul sebagai pilihan.

## Penyebab
- `android/app/src/main/AndroidManifest.xml`: filter HOME digabung dengan filter deep link (`<data android:scheme="com.snoop.snoop" …>`).
  Intent HOME tidak membawa data, sehingga filter yang memiliki `<data>` tidak pernah cocok. Akibatnya SNOOP tidak masuk daftar launcher.
- Versi yang benar sebenarnya sudah ada di `android_overrides/AndroidManifest.xml`, tetapi tidak dipakai saat build.

## Perubahan
1. Manifest: filter HOME berdiri sendiri (tanpa `<data>`). Deep link login dipisah ke filter sendiri.
2. `MainActivity.kt` (Android 10+): memakai `RoleManager` untuk meminta peran Home langsung (dialog sistem "Jadikan default").
   Method baru: `requestHome`, `isHomeDefault`. Di Android 9 ke bawah, atau bila peran tidak tersedia, membuka Pengaturan Aplikasi Home.
3. Pengaturan > "Jadikan launcher default": menjalankan permintaan di atas dan menampilkan hasilnya.

## Cara pakai
- Pengaturan > Jadikan launcher default, lalu pilih SNOOP di dialog sistem.
- Bila tidak muncul dialog, pilih SNOOP dari Pengaturan > Aplikasi > Aplikasi Home (pengaturan akan terbuka otomatis).

## Berkas
- Diubah: `android/app/src/main/AndroidManifest.xml`, `android/app/src/main/kotlin/com/example/snoop/MainActivity.kt`,
  `lib/services/launcher_service.dart`, `lib/screens/settings_screen.dart`, `pubspec.yaml` (1.0.7+8).
- Ditambah: `UPDATE_1_0_7_REPORT.md`.

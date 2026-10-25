#!/usr/bin/env bash
# Jalankan sekali di root proyek (butuh Flutter SDK terpasang).
set -e
flutter create --org com.snoop --project-name snoop --platforms=android .
cp android_overrides/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
mkdir -p android/app/src/main/kotlin/com/snoop/snoop
cp android_overrides/MainActivity.kt android/app/src/main/kotlin/com/snoop/snoop/MainActivity.kt
flutter pub get
echo "Selesai. Jalankan: flutter run  (lalu pilih SNOOP sebagai Home di Pengaturan > Launcher Default)"

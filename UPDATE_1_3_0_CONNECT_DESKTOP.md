# Update 1.3.0 — Connect to Desktop (berbagi layar ke SnoopUX Desktop)

**BELUM dikompilasi / diuji di perangkat** (tidak ada Flutter/Kotlin SDK di lingkungan pembuatan). Jalankan `flutter analyze`, `flutter test` dan uji di HP nyata.

## Alur
1. Laptop (SnoopUX Desktop): island -> Connect to Mobile -> pilih Wi-Fi / Hotspot / USB -> Connect. Laptop menampilkan alamat + kode 6 digit.
2. HP: Pengaturan -> Connect to Desktop -> isi alamat (USB: `127.0.0.1`) + kode -> Connect.
3. Kode diverifikasi DULU; baru setelah benar HP meminta izin MediaProjection. Tolak = laptop menampilkan "Izin ditolak".
4. Setelah izin: MirrorService (foreground, notifikasi + tombol Hentikan) menangkap layar, encode H.264, kirim lewat WebSocket.

## Berkas
- Kotlin: `MirrorWebSocket.kt` (klien WS tanpa dependensi), `MirrorSession.kt` (pairing, heartbeat, sambung ulang), `MirrorService.kt` (capture + encoder), `MainActivity.kt` (channel `snoop/mirror`), `AndroidManifest.xml` (izin FOREGROUND_SERVICE[_MEDIA_PROJECTION], service `mediaProjection`).
- Dart: `lib/services/mirror_service.dart`, `lib/screens/connect_desktop_screen.dart`, baris di Pengaturan, `test/mirror_test.dart`.
- Status penting muncul sebagai banner Dynamic Island (layar dibagikan / berhenti / gagal).
- Catatan: `android_overrides/` adalah salinan lama (package com.snoop.snoop) dan TIDAK diubah; perubahan ada di `android/app/src/main`.

## Protokol (ringkas)
JSON teks: HP->laptop `hello{code|token,name}`, `approved`, `declined`, `config{codec,w,h}`, `hb`, `error`, `bye`; laptop->HP `paired{token}`, `rejected{reason}`, `resumed`, `keyframe`, `bye`.
Biner (HP->laptop): `[0=key|1=delta][pts µs 8 byte BE][H.264 Annex B]`, key frame diawali SPS/PPS.

## Batasan yang diketahui
- Lalu lintas Wi-Fi/hotspot TIDAK dienkripsi (kode hanya mengikat sesi). Pakai jaringan tepercaya atau USB.
- Hanya lihat layar; kendali mouse/keyboard belum ada.
- Rotasi layar tidak diadaptasi (resolusi encoder tetap sesuai orientasi awal).
- USB butuh `adb` di PATH laptop dan USB debugging aktif.
- Firewall laptop harus mengizinkan port TCP 47821 untuk Wi-Fi/hotspot.

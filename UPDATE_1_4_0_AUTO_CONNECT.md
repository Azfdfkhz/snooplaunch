# Update 1.4.0 — Auto-connect ala Mac (tanpa input alamat/kode)

**BELUM dikompilasi / diuji di perangkat** (tidak ada Flutter/Kotlin SDK di lingkungan pembuatan). Jalankan `flutter analyze`, `flutter test`, lalu uji di HP + laptop nyata.

## Alur baru
1. Laptop (SnoopUX Desktop): buka Dynamic Island -> tab **Connect to Mobile**. Laptop otomatis "terlihat" (tanpa menekan Connect).
2. HP: buka Dynamic Island -> tab **Connect** (sejajar Fokus, Musik, Info). Nama laptop muncul sebagai baris dengan tombol *Connect*.
3. Ketuk baris itu. Laptop menampilkan "<nama HP> ingin terhubung" dengan tombol **Izinkan / Tolak**; setelah Izinkan, Android meminta izin berbagi layar (tetap wajib, tiap sesi). Selama laptop menunggu jawaban (maks. 30 dtk), HP lain ditolak (busy).
4. Titik hijau di tombol tab Connect muncul bila ada laptop terdeteksi saat hub terbuka di tab lain.

Jalur manual (Pengaturan -> Connect to Desktop, alamat + kode 6 digit) **tetap ada** sebagai cadangan (jaringan berbeda / broadcast diblokir).

## Cara kerja
- Laptop memancarkan beacon UDP ke port **47822** tiap ~1,5 dtk: `{"snoop":1,"id":"<12 heksa>","name":"<host>","port":47821,"auto":true}`; dan menjawab `GET /snoop-info` (port 47821) dengan JSON yang sama. Keduanya hanya selama menunggu pairing.
- HP memindai **hanya saat hub Island terbuka dan belum ada sesi**: `MirrorDiscovery.kt` (UDP + probe `127.0.0.1` untuk kabel USB + probe alamat terakhir bila broadcast diblokir). Daftar laptop dikirim ke Flutter lewat metode `peers`.
- Ketukan mengirim `hello{v:2, auto:true, id, name}` (bukan `code`). Laptop menerima bila: sesi auto aktif, `id` cocok, dan asal koneksi berada di jaringan privat/loopback. Setelah itu alur lama identik: `paired{token}` -> izin MediaProjection -> stream.
- Galat baru: `denied` (laptop menolak / tidak dijawab) dan `stale_session` (laptop berganti sesi) -> pesan "Sesi laptop sudah berganti, ketuk lagi".

## Berkas
- Baru: `android/.../MirrorDiscovery.kt`.
- Diubah: `MirrorSession.kt` (`begin(..., code?, peerId?)`), `MainActivity.kt` (`connect` menerima `id`; `scanStart`/`scanStop`), `AndroidManifest.xml` (`CHANGE_WIFI_MULTICAST_STATE`), `lib/services/mirror_service.dart` (`DesktopPeer`, `setScanning`, `connectPeer`), `lib/core/dynamic_island.dart` (tab Connect index 3, tombol tab keempat + badge), `connect_desktop_screen.dart` (teks), `test/mirror_test.dart`.
- `android_overrides/` tidak diubah (salinan lama).

## Keamanan — perubahan yang perlu Anda ketahui
- **Kode 6 digit tidak lagi menjadi syarat di jalur auto.** Gantinya, berlapis: (1) laptop hanya terlihat saat panel Connect to Mobile sengaja dibuka, (2) hanya jaringan privat + `id` sesi yang cocok, (3) **pemilik laptop harus menekan Izinkan** untuk setiap HP yang menekan Connect, (4) percobaan salah dikunci setelah 5x, (5) Android **selalu** meminta izin berbagi layar di HP.
- Sisa risiko: HP lain bisa memunculkan prompt Izinkan di laptop (nama perangkat bisa dipalsukan; tolak bila bukan HP Anda), dan laptop palsu bisa tampil di daftar HP (tanpa izin Android layar tidak terkirim). Hindari jaringan publik; gunakan kabel USB atau jalur kode manual di jaringan yang tidak tepercaya.
- Lalu lintas Wi-Fi/hotspot masih tidak dienkripsi (tidak berubah dari 1.3.0).

## Batasan / yang perlu diuji di perangkat
- Router dengan *AP/client isolation* memblokir broadcast: HP tidak melihat laptop. Cadangan: probe alamat terakhir (hanya setelah pernah tersambung) atau kode manual.
- Firewall laptop harus mengizinkan TCP 47821 (masuk) dan UDP keluar ke 47822. Windows: izinkan SnoopUX di jaringan Privat.
- Hotspot: broadcast ke subnet hotspot diharapkan sampai, belum diuji nyata.
- USB: butuh `adb` di PATH laptop dan USB debugging aktif (tidak berubah); setelah `adb reverse`, HP menemukan laptop lewat probe `127.0.0.1`.

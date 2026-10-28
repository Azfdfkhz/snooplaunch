# Update 1.2.3 — Bulatan lebih kecil, musik/lirik tidak telat, panggilan WhatsApp di atas aplikasi lain, tombol beranimasi

## Status verifikasi (jujur)
- **BELUM dikompilasi dan BELUM dijalankan di perangkat.** Flutter/Dart/Kotlin tidak tersedia di lingkungan pembuatan.
- Yang sudah dicek: keseimbangan kurung semua berkas Dart/Kotlin yang diubah, dan alur logika dengan membaca ulang kode.
- Jalankan: `flutter pub get`, `flutter analyze`, `flutter test`, lalu `flutter run` di Samsung A51. Tidak ada dependensi baru
  (`path_provider` sudah ada di pubspec). Versi → 1.2.3+18.
- Kotlin baru: `CallOverlay.kt`, tiga ikon vektor di `res/drawable/`, izin `SYSTEM_ALERT_WINDOW` di manifest.

## 1. Bulatan Island masih terasa besar
Penyebab: bulatan diam memakai tinggi pil mode lebar = tinggi kamera + 12 dp, minimal 32 dp, jadi hampir dua kali kamera.
- Bulatan kini seukuran kamera itu sendiri (sisi terpendek area cutout), tanpa bayangan, dan dipusatkan di kamera.
- Pengaturan → "Atur posisi & ukuran Dynamic Island" → slider **Ukuran bulatan** (-8 s.d. +12 dp). Bila masih terasa besar/kecil,
  geser slider sampai pas lalu simpan; nilainya tersimpan di perangkat.
- Perpindahan bulatan ↔ mode lebar kini juga menganimasikan posisi vertikal.

## 2. Lagu dan lirik selalu telat
Penyebab yang ditemukan di kode 1.2.2:
1. Lirik baru dicari **saat tab Musik dibuka**, jadi selalu mulai dari "Mencari lirik…".
2. Dua permintaan ke LRCLIB berjalan **berurutan**, dan koneksi HTTPS dibuka baru untuk setiap lagu.
3. Baris lirik diperbarui tiap 250 ms + animasi 220 ms, tanpa kompensasi jeda kanal native.
4. Tombol jeda/seek menunggu laporan native dulu sebelum tampilan berubah.
5. Sampul (JPEG) dikirim ulang di setiap pembaruan status.

Perbaikan:
- Lirik dicari **begitu lagu terdeteksi** (`NowPlayingController.update`), tidak menunggu tab Musik.
- Permintaan "tepat" dan "pencarian" berjalan **bersamaan**; satu HttpClient dipakai ulang (keep-alive).
- **Cache disk** (`<app support>/lyrics`, maks. 80 berkas): lagu yang pernah diputar langsung punya lirik, juga tanpa internet.
- Native menyinkronkan posisi tiap 2 dtk selama lagu diputar (tanpa mengirim ulang sampul), sehingga baris lirik tidak melenceng.
  Sampul dikirim sekali per lagu.
- Baris lirik dinyalakan 300 ms lebih awal; pembaruan tampilan tiap 100 ms hanya pada seek bar + lirik (kartu lain tidak ikut dibangun ulang).
- Jeda/lanjut dan seek **langsung tampil** di UI; dibetulkan otomatis bila native gagal.
- Ganti baris lirik: geser ke atas + pudar (baris lama naik keluar, baris baru naik masuk).

## 3. Panggilan WhatsApp
Catatan: deteksi panggilan sebenarnya sudah ada di 1.2.2, tetapi kartunya **hanya tampil bila SNOOP sedang di layar** dan
mengandalkan daftar aksi notifikasi. Perubahan:
- **Overlay native di atas aplikasi lain** (`CallOverlay.kt`): kartu hitam di atas layar dengan nama penelepon, tombol Tolak (merah)
  dan Jawab (hijau), animasi masuk meluncur + memantul, tombol mengecil saat ditekan, geser ke atas untuk menyembunyikan tanpa menolak.
  Muncul hanya saat SNOOP tidak di layar; saat SNOOP di layar, kartu Dynamic Island Flutter yang dipakai (tidak dobel).
- Butuh izin **Tampil di atas aplikasi lain**: Pengaturan → "Tampil di atas aplikasi lain (panggilan WhatsApp)".
  Akses notifikasi tetap wajib (Pengaturan → "Deteksi Spotify & panggilan WhatsApp").
- Deteksi lebih kuat: selain mencocokkan tombol Jawab/Tolak, kini juga membaca notifikasi panggilan resmi Android 12+ (CallStyle:
  `android.answerIntent` / `android.declineIntent`) dan mengabaikan notifikasi "panggilan berlangsung".
- **Uji kartu panggilan** (Pengaturan): panggilan palsu muncul dalam 5 detik, hilang sendiri setelah 15 detik. Tekan Home dalam 5 detik
  itu untuk menguji overlay di atas aplikasi lain tanpa perlu ditelepon. Tombol Jawab/Tolak pada panggilan uji hanya menutup kartu.
- Kartu Island: ikon telepon dengan cincin berdenyut dan getar saat "berdering".

## 4. Tombol & UI Island (info, musik, fokus) rapi dan beranimasi
- Pemilih tab bergaya segmen: penanda putih meluncur (dengan pantulan) ke tab terpilih, warna ikon/teks berubah halus.
- Semua tombol (bulat, pil, tab, preset) memakai satu perilaku sentuh: mengecil saat ditekan, memantul kembali, getar halus.
- Ikon tombol berganti dengan animasi (putar/jeda berubah bentuk), warna tombol berubah halus.
- Isi tiap tab muncul bertahap (pudar + naik); Info kini berupa kartu-kartu rapi; tab berganti dengan geser halus.
- Fokus: cincin bergerak halus antar detik, titik siklus membesar saat terisi, pilihan preset beranimasi.
- Musik: sampul "bernapas" (mengecil saat jeda, bersinar saat diputar), judul berganti dengan animasi, seek bar punya gagang.

## Berkas
Baru: `android/.../CallOverlay.kt`, `android/app/src/main/res/drawable/ic_call.xml`, `ic_call_end.xml`, `ic_videocam.xml`,
`UPDATE_1_2_3_REPORT.md`.
Diubah: `SnoopNotificationListener.kt` (IslandBridge + overlay, sinkron posisi, CallStyle), `MainActivity.kt` (visibilitas, izin overlay,
panggilan uji), `AndroidManifest.xml`, `dynamic_island.dart`, `island_service.dart`, `system_bridge.dart`, `lyrics_service.dart`,
`media_models.dart`, `settings_screen.dart`, `pubspec.yaml`, `test/lyrics_test.dart`, `test/system_bridge_test.dart`, `test/island_test.dart`.

## Batasan yang perlu diketahui
- Overlay panggilan butuh dua izin: Akses notifikasi + Tampil di atas aplikasi lain. Tanpa izin kedua, kartu hanya tampil di dalam SNOOP.
- Tombol Jawab memakai aksi dari notifikasi WhatsApp; bergantung pada versi WhatsApp. Bila aksinya tidak ada, tombol hijau membuka
  layar panggilan WhatsApp (overlay yang sedang tampil memberi SNOOP izin membuka layar itu dari latar belakang).
- Notifikasi bawaan WhatsApp tetap muncul bersama kartu SNOOP (tidak dibuang).
- Samsung dapat mematikan layanan latar belakang; jika kartu/lagu tidak muncul, buka SNOOP sekali (listener disambungkan ulang) dan
  kecualikan SNOOP dari penghematan baterai.
- Lirik bergantung pada LRCLIB: tidak semua lagu ada, dan timing lirik komunitas bisa meleset. Tidak ada pengatur offset lirik manual.
- Ukuran bulatan diturunkan dari bounds cutout yang dilaporkan sistem; bila Samsung melaporkan bounds lebih besar dari lubang kamera,
  turunkan lewat slider.

## Daftar uji di Samsung A51
1. Diam: bulatan hitam seukuran kamera, tanpa bayangan. Geser slider "Ukuran bulatan" dan lihat perubahannya langsung.
2. Pengaturan → aktifkan Akses notifikasi dan Tampil di atas aplikasi lain (keduanya harus "Aktif").
3. Pengaturan → "Uji kartu panggilan" → tetap di SNOOP: kartu Island muncul; ulangi lalu tekan Home dalam 5 detik: kartu overlay muncul
   di atas Home/aplikasi lain; uji Tolak, Jawab, dan geser ke atas.
4. Telepon WhatsApp sungguhan (suara dan video) saat berada di aplikasi lain dan di SNOOP; uji Jawab dan Tolak.
5. Putar lagu baru di Spotify (jangan buka SNOOP dulu), tunggu ±2 dtk, lalu buka Island → Musik: judul dan lirik harus sudah tampil.
   Putar lagu yang sama lagi dengan internet mati: lirik tetap muncul (cache disk).
6. Jeda/lanjut dan seek di tab Musik: tampilan berubah seketika. Baris lirik mengikuti suara tanpa melenceng setelah seek.
7. Tab Fokus/Musik/Info: penanda tab meluncur, tombol mengecil saat ditekan, isi tab muncul bertahap.

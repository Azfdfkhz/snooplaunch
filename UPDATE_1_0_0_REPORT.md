# SNOOP Update 1.0.0 — Laporan Implementasi

Spesifikasi: `SnoopUpdate.md`. Referensi visual: tiga gambar Smart Launcher / aplikasi gelap-kuning yang diberikan.

## STATUS VERIFIKASI (baca dulu)

**Kode ini BELUM dikompilasi dan BELUM dijalankan.** Flutter/Dart SDK tidak tersedia di lingkungan pengerjaan
(unduhan SDK diblokir jaringan). Yang benar-benar dilakukan hanya pemeriksaan statis manual:
keseimbangan kurung seluruh file `lib/`, pencarian sisa token lama (`C.sky`, `NotchCard`, `GeoDecor` = tidak ada),
sinkronisasi dua salinan `MainActivity.kt`. Kemungkinan ada error kecil saat `flutter analyze`.

Langkah pertama di mesin Anda:

    flutter pub get
    flutter analyze
    flutter test
    flutter build apk --debug      # lalu pasang & pilih SNOOP sebagai Home default

## Sudah dikerjakan

| Area PRD | Hasil |
|---|---|
| 4.1 Palet | Token baru di `lib/core/theme.dart` (`C.accent #F4BD22`, `C.night #252422`, `C.nightSurface #383735`, `C.bg #F5F3ED`, `C.onNight2 #D0CCC3`). Token lama `sky/skySoft` diganti `accent/accentSoft`; alias `blue/mint/pink/orange/red` dipertahankan. Warna "terlambat/peringatan" sengaja oranye-coklat agar tidak bisa tertukar dengan kuning aksen. |
| 5.1 Home | Ditulis ulang (`home_screen.dart`): panel kuning organik (`OrganicPanelClipper`, kiri turun, kanan naik dengan lengkung S) berisi SNOOP, tombol profil, jam 84sp, tanggal, sapaan. Di bawahnya widget gelap, favorit, dan dock membulat. Area tengah bisa di-scroll; dock tetap di bawah. |
| 5.2 Widget | **Absensi**: status aktual + chip berikon (Belum absen / Hadir / Terlambat / Pulang / Menunggu server / Perlu perhatian), 7 hari minggu ini, streak, tombol aksi. **Jadwal**: kegiatan berlangsung/berikutnya (`AppState.nextSchedule`), progres tugas, status kosong. **Memories**: foto terbaru nyata, status kosong. **Pengingat**: pil ke halaman Pengingat. Petunjuk offline/belum masuk/antrean tampil sebagai pil peringatan. Tidak ada data contoh. Cuaca/musik tidak dibuat (PRD 13). |
| 5.3 App Drawer | Tema gelap, pencarian dengan tombol hapus, Favorit + Semua Aplikasi, loading / kosong / error + tombol coba lagi. Chip kategori hanya untuk kategori yang berisi (dengan jumlah); **pencarian mengabaikan kategori** dan mencocokkan nama atau package; aplikasi tak terklasifikasi masuk "Lainnya". Grid adaptif (`maxCrossAxisExtent` 92, tinggi sel mengikuti ukuran teks sistem). Label maks. 2 baris. |
| 5.4 Dock | Pil gelap, hingga 4 aplikasi pilihan pengguna + tombol App Drawer. Tidak ada ikon bawaan yang dianggap wajib; dock kosong menampilkan petunjuk. Tekan lama di drawer/favorit/dock: favorit, tambah/hapus dock, info aplikasi. Aplikasi yang sudah dihapus dilewati; gagal membuka → snackbar. |
| 5.5 Navigasi | App Drawer dapat dibuka lewat: swipe kanan dari Home, tombol di dock, **swipe ke atas pada dock**. Tombol kembali: Drawer → Home, tab lain → Beranda, di Home tidak menutup launcher. Tombol Home Android saat SNOOP berjalan menutup halaman terbuka dan kembali ke Home utama. Ikon navigasi punya label semantik. |
| 7 Aksesibilitas | Label `Semantics` pada widget/dock/ikon; target sentuh ≥ 48dp; chip status selalu teks + ikon; animasi masuk dan perpindahan halaman dimatikan bila "kurangi animasi" aktif; tinggi widget Home mengikuti `textScaler`. |
| Status bar | Ikon status/navigasi mengikuti halaman (Home kuning, Drawer gelap, tab terang). |
| Onboarding | Layar pembuka hanya tampil sekali (`AppState.onboarded`); setelah itu launcher langsung ke Home. |

## File yang diubah

Baru: `lib/core/launcher_widgets.dart`, `UPDATE_1_0_0_REPORT.md`
Diubah: `lib/screens/home_screen.dart`, `lib/screens/app_drawer_screen.dart`, `lib/screens/shell.dart`,
`lib/screens/splash_screen.dart`, `lib/main.dart`, `lib/core/theme.dart`, `lib/core/widgets.dart`,
`lib/core/state.dart`, `lib/services/launcher_service.dart`,
`android/app/src/main/kotlin/com/example/snoop/MainActivity.kt`, `android_overrides/MainActivity.kt`,
`test/state_test.dart`, `pubspec.yaml` (versi `1.0.0+2`), `SnoopUpdate.md` (diganti PRD terbaru).

## Perubahan yang berdampak pada perilaku launcher (PRD §9)

1. `MainActivity.kt`: tambah `onNewIntent` (intent HOME → kirim `onHome` ke Flutter); `launch` kini menangkap exception → mengembalikan `false`. Manifest tidak diubah.
2. `AppState`: field `dock` dan `onboarded` baru di SharedPreferences (kunci `dock`, `onboarded`). Tidak ada perubahan skema backend, autentikasi, atau aturan absensi.
3. Tombol kembali di Home tidak lagi memanggil keluar aplikasi (`canPop: false`).
4. Splash tidak lagi tampil tiap start.

## Belum dikerjakan / tidak terverifikasi

- Kompilasi, `flutter analyze`, `flutter test` (termasuk 2 tes baru: dock & `nextSchedule`), build APK, uji emulator/perangkat — **belum ada yang dijalankan**.
- Pemeriksaan visual: bentuk lengkung panel, posisi identitas di kiri-bawah panel, tinggi widget (176dp × textScale), dan kerapatan Home pada layar kecil belum pernah dilihat. Kemungkinan perlu penyesuaian angka (`cut: 64`, tinggi widget, ukuran jam).
- Pengujian layar kecil/besar, font besar, keyboard terbuka, orientasi lanskap, gesture navigation vs 3-button: belum.
- Dock/favorit/App Drawer sudah memakai notifier, tetapi pemasangan/penghapusan aplikasi hanya terdeteksi saat kembali ke SNOOP (maks. 1× / 30 dtk), bukan lewat broadcast paket.
- Heuristik kategori masih berbasis kata kunci package/nama; sengaja tidak menjadi penghalang pencarian.
- Tema gelap global **tidak diklaim selesai**: Home/Drawer gelap secara desain, sedangkan Jadwal, Memories, Profil, Pengaturan, Absensi, Pengingat tetap tema terang dengan token baru (warna kuning). Pilihan "Gelap" di Pengaturan masih tidak berefek (sama seperti sebelumnya).
- Halaman pendukung hanya ikut berubah lewat token; belum ada penyelarasan layout per halaman.
- Ikon diambil native 96px; bisa tampak sedikit lembut di layar sangat padat.
- Package Android: `android/` memakai `com.example.snoop`, `android_overrides/` & `setup.sh` memakai `com.snoop.snoop` (ketidakkonsistenan lama, tidak diubah).

## Pekerjaan lanjutan (di luar Update 1.0.0)

Widget cuaca/musik, penyusunan ulang dock (drag), pendeteksi paket via broadcast, tema gelap penuh, penyelarasan layout halaman pendukung, uji golden/widget.

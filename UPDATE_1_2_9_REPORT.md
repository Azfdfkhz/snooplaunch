# Update 1.2.9 — laporan

Belum dikompilasi di sini. Jalankan `flutter pub get`, `flutter analyze`, lalu `flutter run`.

## 1. Bar jam/baterai/jaringan juga di luar aplikasi (menggantikan bar Samsung)
Penyebab di 1.2.8: overlay biasa (`TYPE_APPLICATION_OVERLAY`) tergambar DI BAWAH status bar sistem Samsung, jadi bar hitam tidak menutupinya.
- Baru: layanan Aksesibilitas `SnoopAccessibilityService` ("SNOOP Status Bar"). Layanan ini kosong (tidak membaca layar, `canRetrieveWindowContent=false`); fungsinya hanya mengizinkan jendela bertipe `TYPE_ACCESSIBILITY_OVERLAY`, yang tergambar di atas status bar.
- `OverlayHost.kt` memilih tipe jendela untuk pil Island, bar, kartu panggilan, dan banner: aksesibilitas aktif = di atas status bar; tidak aktif = cara lama (di bawah status bar).
- Cara mengaktifkan: Pengaturan SNOOP > "Layanan SNOOP Status Bar" > Aplikasi terinstal > SNOOP Status Bar > aktifkan. Android 13+ untuk aplikasi di luar Play Store: Info aplikasi SnoopLaunch > menu ⋮ > "Izinkan setelan terbatas" dulu.
- Status bar Samsung tidak benar-benar dimatikan (tidak mungkin tanpa root/ADB); ia ditutup bar hitam SNOOP. Bar tidak menerima sentuhan, jadi menarik panel notifikasi dari atas tetap bisa.

## 2. Notifikasi di bawah kamera depan
- Baru: `NotifOverlay.kt`. Notifikasi penting (setara heads-up) dari aplikasi apa pun (WhatsApp, pesan, email, dll.) tampil sebagai kartu hitam tepat di bawah kamera: ikon/foto, nama aplikasi, judul, isi 2 baris. Ketuk = buka notifikasi; geser ke atas = tutup; hilang sendiri setelah ±5,5 detik.
- Tidak ditampilkan: notifikasi senyap, berlangsung (pemutar musik, unduhan), ringkasan grup, kategori sistem/panggilan, notifikasi SNOOP sendiri, dan pembaruan tanpa isi baru.
- Panggilan: sekarang dikenali dari aplikasi telepon mana pun (kategori panggilan), bukan hanya WhatsApp. Kartu panggilan di luar aplikasi pindah ke bawah kamera; pil Island dan bar jam tetap tampil di atasnya.
- Pengaturan: "Notifikasi di bawah kamera" (aktif/mati) dan "Uji banner notifikasi".
- Batas: popup notifikasi bawaan Samsung tetap muncul karena tidak bisa dimatikan dari aplikasi. Supaya tidak dobel, matikan di Pengaturan > Notifikasi > Gaya pemberitahuan > Pop-up singkat (atau per aplikasi).
- Belum diuji di perangkat (SM-A515F); posisi vertikal bisa perlu disetel lewat "Atur posisi & ukuran Dynamic Island".

# Update 1.2.1 — Animasi Island, sejajar kamera, notifikasi lewat Island

## 1. Animasi Dynamic Island lebih halus
- Satu gerak terpadu: lebar, tinggi, sudut, bayangan, dan posisi bergerak bersama memakai kurva pegas (`Cubic(.3, 1.2, .42, 1)`, 520 ms) yang sedikit melewati target lalu mengendap, seperti Island iOS.
- Konten lama tidak lagi menahan ukuran pil: ia ditumpuk dan memudar, konten baru muncul sedikit terlambat (fade + skala 0.92 → 1). Pil langsung mulai berubah ukuran.
- Isi ditata pada lebar akhirnya lalu "dibuka" dari tengah (`_Reveal`), jadi tidak ada teks terperas / garis overflow selama animasi.
- Tekan pil → mengecil sedikit (feedback), getar ringan saat dibuka, latar peredup hub memudar halus, ganti tab Fokus/Musik/Info juga cross-fade.

## 2. Sejajar kamera depan
- Posisi dihitung dari data cutout sistem (`MediaQuery.displayFeatures`): pil dipusatkan tepat di kamera, tingginya = tinggi kamera + 12 dp sehingga terlihat menyatu. Bila kamera tidak di tengah (pojok), pil ringkas menempel ke kamera; saat melebar kembali ke tengah layar.
- Tanpa data cutout, pil ditaruh di tengah status bar.
- Android 9+: tema `values-v28` / `values-night-v28` memakai `windowLayoutInDisplayCutoutMode=shortEdges` agar aplikasi boleh menggambar di area kamera.
- Cadangan: Pengaturan → "Atur posisi Dynamic Island" (geser kiri-kanan / atas-bawah, ada tombol Contoh dan Setel ulang). Tersimpan di perangkat.

## 3. Notifikasi lewat Island, bukan bawaan HP
- Saat SNOOP terbuka dan Island aktif, notifikasi sistem Android untuk pengingat dan Pomodoro dimatikan sementara; pengingat dan akhir fase fokus tampil sebagai banner Island. "Uji Notifikasi" juga tampil di Island.
- Saat SNOOP ke latar belakang (pengguna membuka aplikasi lain), notifikasi sistem dijadwalkan lagi supaya pengingat tetap berbunyi. Bila Island dimatikan, perilaku lama (notifikasi sistem) kembali.
- Perbaikan: notifikasi akhir Pomodoro tidak lagi bisa terbatal oleh timer dalam aplikasi saat aplikasi di latar belakang (id notifikasi bergantian per fase).

## Batasan
- BELUM DIKOMPILASI / diuji di perangkat (Flutter SDK tidak tersedia). Posisi kamera bergantung data cutout dari HP; bila meleset, pakai penyetel posisi.
- Island hanya terlihat di dalam SNOOP. Menampilkannya di atas aplikasi lain, atau menampilkan notifikasi aplikasi lain (WhatsApp dll.) di Island, membutuhkan izin "Tampil di atas aplikasi lain" dan "Akses notifikasi" serta kode native Android — belum ada.

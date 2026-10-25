# SNOOP — Product Requirements Document
## Update 1.0.0 — Launcher UI/UX Redesign

**Produk:** SNOOP — Smart PKL Launcher  
**Versi dokumen:** PRD Update 1.0.0  
**Jenis pembaruan:** UI/UX Redesign & Launcher Experience  
**Platform utama:** Android  
**Teknologi:** Flutter, Dart, dan integrasi native Android yang sudah tersedia  
**Status:** Spesifikasi untuk implementasi

---

## 1. Latar Belakang

SNOOP merupakan aplikasi launcher Android yang juga berfungsi sebagai pendamping kegiatan Praktik Kerja Lapangan (PKL). Aplikasi menggabungkan akses aplikasi Android dengan informasi dan aktivitas PKL, termasuk absensi, jadwal, pengingat, serta dokumentasi.

Pada versi sebelumnya, perhatian utama masih perlu diarahkan pada pengalaman visual launcher. Tampilan beranda berpotensi lebih terasa seperti dashboard aplikasi produktivitas daripada launcher yang digunakan setiap hari.

Update 1.0.0 bertujuan memperbaiki identitas visual, hierarki informasi, navigasi, serta pengalaman penggunaan launcher dengan mengacu pada referensi Smart Launcher yang diberikan.

Pembaruan harus mempertahankan fungsi yang sudah berjalan dan tidak mengubah aturan bisnis, mekanisme autentikasi, maupun sistem penyimpanan tanpa kebutuhan teknis yang jelas.

## 2. Visi Produk

Menjadikan SNOOP sebagai launcher Android yang personal, praktis, modern, dan terintegrasi dengan aktivitas PKL.

SNOOP harus memungkinkan pengguna:
- Mengakses aplikasi Android dengan cepat.
- Melihat informasi PKL yang relevan tanpa membuka banyak halaman.
- Melakukan tindakan penting melalui pintasan yang jelas.
- Menikmati antarmuka yang konsisten, responsif, dan mudah dipahami.

**Prinsip utama:** launcher menjadi pusat pengalaman, sedangkan fitur PKL menjadi bagian yang menyatu dengan launcher.

## 3. Tujuan Pembaruan

1. Memperkuat identitas visual SNOOP sebagai launcher Android.
2. Mengurangi kepadatan informasi yang tidak diperlukan pada beranda.
3. Mempermudah akses aplikasi favorit dan seluruh aplikasi.
4. Menampilkan informasi PKL secara kontekstual.
5. Menyeragamkan komponen UI, warna, tipografi, dan spacing.
6. Memastikan navigasi serta gesture mudah dipahami.
7. Mempertahankan kompatibilitas dengan fungsi dan data yang sudah ada.

### 3.1 Bukan tujuan pembaruan

Update ini tidak bertujuan untuk:
- Membuat ulang aplikasi dari nol.
- Mengganti Flutter dengan framework lain.
- Menghapus fitur PKL yang sudah tersedia.
- Mengubah aturan absensi atau sistem autentikasi.
- Mengganti ikon aplikasi Android asli dengan ikon dekoratif.
- Menambahkan fitur yang tidak memiliki kebutuhan produk yang jelas.
- Menjadikan seluruh layar sebagai kumpulan kartu dashboard.

## 4. Referensi dan Arah Visual

Referensi utama adalah gambar Smart Launcher yang diberikan pengguna.

Karakteristik yang perlu diadaptasi:
- Panel utama dengan bentuk asimetris dan lengkungan organik.
- Perpaduan area terang dan gelap yang memiliki batas visual jelas.
- Jam digital besar sebagai elemen identitas beranda.
- Widget dengan ukuran dan proporsi bervariasi.
- Dock aplikasi membulat pada bagian bawah.
- Komposisi yang ringkas dan tidak monoton.

Adaptasi untuk SNOOP harus mempertahankan ciri tersebut tanpa menyalin seluruh desain produk referensi.

### 4.1 Palet warna

| Elemen | Warna acuan | Penggunaan |
|---|---|---|
| Kuning hangat | `#F4BD22` | Panel utama dan aksen |
| Charcoal | `#252422` | Area gelap |
| Abu-abu gelap | `#383735` | Widget dan dock |
| Ivory | `#F5F3ED` | Alternatif latar terang |
| Putih | `#FFFFFF` | Teks pada area gelap |
| Abu-abu netral | `#D0CCC3` | Teks sekunder pada area gelap |

Warna merupakan token awal dan boleh disesuaikan setelah pemeriksaan kontras serta implementasi pada perangkat nyata.

Status seperti berhasil, terlambat, gagal, atau offline harus memiliki pembeda yang jelas. Warna kuning tidak boleh menjadi satu-satunya penanda status.

### 4.2 Tipografi dan komponen

- Gunakan tipografi yang mudah dibaca pada layar ponsel.
- Jam menjadi elemen teks paling menonjol di beranda.
- Judul bagian harus lebih menonjol daripada keterangan sekunder.
- Gunakan radius dan spacing yang konsisten.
- Hindari shadow berlebihan, gradient dekoratif, dan border pada semua elemen.
- Gunakan ikon yang konsisten dan mudah dikenali.
- Pastikan label tetap terbaca pada ukuran layar kecil.

## 5. Persyaratan Fungsional dan Visual

### 5.1 Home Screen

Home Screen merupakan halaman utama yang muncul saat launcher dibuka.

**Persyaratan:**

1. Menampilkan jam digital secara jelas.
2. Menampilkan tanggal sesuai waktu lokal perangkat.
3. Menampilkan identitas SNOOP secara ringkas.
4. Menggunakan panel utama dengan bentuk organik yang mengikuti arah desain referensi.
5. Menampilkan pintasan fitur PKL yang relevan.
6. Menyediakan akses cepat ke aplikasi favorit.
7. Menampilkan dock aplikasi pada bagian bawah.
8. Mendukung akses ke App Drawer.
9. Mempertahankan status dan data aktual dari sistem yang sudah ada.
10. Menyesuaikan layout dengan ukuran layar dan area aman perangkat.

**Hierarki konten yang direkomendasikan:**

1. Identitas, jam, dan tanggal.
2. Informasi atau tindakan PKL utama.
3. Widget pendukung.
4. Aplikasi favorit.
5. Dock dan akses App Drawer.

Hierarki ini dapat disesuaikan dengan tinggi layar. Tidak semua informasi wajib terlihat sekaligus.

### 5.2 Widget PKL

Widget digunakan untuk memberikan akses cepat ke aktivitas PKL, bukan menggantikan halaman fitur lengkap.

Widget yang diprioritaskan:

**A. Absensi**
- Menampilkan status absensi aktual.
- Menyediakan tindakan sesuai status pengguna.
- Menampilkan status loading, gagal mengambil data, atau offline secara jelas.
- Tidak mengasumsikan pengguna sudah atau belum hadir sebelum data tersedia.

**B. Jadwal**
- Menampilkan kegiatan berikutnya jika tersedia.
- Mengarahkan pengguna ke halaman Jadwal.
- Menangani kondisi ketika tidak ada jadwal.

**C. Dokumentasi / Memories**
- Menyediakan akses cepat ke dokumentasi PKL.
- Menampilkan informasi aktual apabila implementasi yang ada mendukungnya.
- Tidak menggunakan data contoh sebagai data pengguna.

**D. Widget pendukung**
- Widget cuaca atau musik hanya menjadi opsi apabila integrasi yang dibutuhkan benar-benar tersedia.
- Widget tersebut tidak boleh menghambat fungsi utama launcher.
- Jika integrasi tidak tersedia, gunakan ruang tersebut untuk fitur yang memang sudah didukung SNOOP.

### 5.3 App Drawer

App Drawer merupakan tempat untuk menemukan dan membuka seluruh aplikasi Android yang tersedia.

**Persyaratan:**
- Menampilkan aplikasi yang berhasil ditemukan oleh sistem.
- Mempertahankan fungsi pencarian.
- Menyediakan bagian Favorit dan Semua Aplikasi.
- Mempertahankan kategori yang tersedia apabila masih relevan.
- Menampilkan ikon aplikasi asli.
- Menjaga nama aplikasi tetap terbaca.
- Memiliki tampilan loading, kosong, dan error.
- Mempertahankan fungsi membuka aplikasi dan informasi aplikasi yang sudah ada.
- Memastikan aplikasi tidak hilang hanya karena klasifikasi kategorinya tidak sesuai.

Ukuran ikon, jumlah kolom, dan ukuran label harus disesuaikan melalui pengujian di beberapa ukuran layar, bukan ditentukan hanya dari screenshot.

### 5.4 Dock Launcher

Dock merupakan area pintasan aplikasi yang selalu mudah dijangkau di beranda.

**Persyaratan:**
- Menggunakan bentuk membulat.
- Memiliki latar gelap atau transparan yang kontras dengan latar di belakangnya.
- Menampilkan aplikasi pilihan pengguna.
- Mendukung pembukaan aplikasi secara langsung.
- Menyediakan pintasan App Drawer.
- Menjaga ukuran target sentuh tetap nyaman.
- Menghindari benturan dengan gesture sistem Android.

Jumlah ikon mengikuti kapasitas layar dan konfigurasi yang didukung. Ikon telepon, pesan, kamera, atau aplikasi lain tidak boleh dianggap wajib jika aplikasinya tidak tersedia atau tidak dipilih pengguna.

### 5.5 Navigasi

Navigasi harus memiliki perilaku yang konsisten pada semua halaman.

**Persyaratan:**
- Pengguna dapat kembali ke Home Screen dengan cara yang jelas.
- App Drawer dapat dibuka melalui tombol atau gesture yang ditetapkan.
- Tombol kembali Android mengikuti konteks halaman.
- Gesture tidak mengganggu scroll, carousel, atau interaksi halaman lain.
- Ikon navigasi memiliki label atau deskripsi aksesibilitas.
- Perubahan tab tidak boleh menghilangkan data yang belum tersimpan.

Implementasi tidak boleh mengasumsikan bahwa swipe horizontal adalah satu-satunya cara membuka App Drawer.

### 5.6 Halaman pendukung

Halaman berikut tetap dipertahankan dan harus mengikuti sistem visual yang sama:
- Jadwal.
- Memories dan detail dokumentasi.
- Pengingat.
- Profil.
- Pengaturan.
- Absensi.
- Autentikasi dan onboarding.

Penyelarasan visual tidak berarti semua halaman harus memakai layout yang identik. Setiap halaman tetap mengikuti kebutuhan fungsionalnya.

## 6. Sistem Desain

Implementasikan atau rapikan design system terpusat untuk:

- Palet warna.
- Tipografi.
- Spacing.
- Radius.
- Ukuran ikon.
- Elevasi.
- Gaya tombol.
- Widget status.
- Input dan pencarian.
- Empty state.
- Loading state.
- Error state.

Gunakan token yang sudah ada jika masih sesuai. Hindari membuat token baru yang menduplikasi fungsi token lama.

Komponen harus mendukung tema terang dan gelap jika keduanya merupakan bagian dari cakupan aplikasi. Jangan mengklaim tema gelap selesai jika masih ada warna yang ditetapkan secara statis dan tidak mengikuti tema.

## 7. Responsivitas dan Aksesibilitas

Antarmuka harus diuji pada:
- Layar Android kecil.
- Layar Android berukuran umum.
- Layar berukuran besar.
- Perubahan ukuran teks sistem.
- Keyboard terbuka.
- Orientasi yang didukung.
- Safe area dan system bars.

**Kriteria:**
- Tidak ada overflow yang terlihat pada ukuran yang diuji.
- Teks penting tidak terpotong tanpa alasan.
- Tombol dan ikon interaktif mudah disentuh.
- Kontras teks memadai.
- Elemen interaktif memiliki label aksesibilitas.
- Informasi status tidak bergantung pada warna saja.
- Animasi tidak menghalangi interaksi dan menghormati pengaturan pengurangan animasi jika didukung.

## 8. Integrasi Android

Karena SNOOP berfungsi sebagai launcher, pengujian tidak cukup dilakukan melalui screenshot atau preview Flutter.

Periksa:
- Kemampuan aplikasi terdaftar sebagai kandidat Home launcher Android.
- Pemilihan SNOOP sebagai Home default.
- Perilaku tombol Home.
- Perilaku tombol kembali.
- Pembukaan aplikasi lain.
- Kembali ke SNOOP setelah aplikasi lain ditutup.
- Penanganan aplikasi yang tidak tersedia.
- Izin dan perilaku sistem Android yang relevan.

Perubahan pada AndroidManifest atau integrasi native hanya dilakukan apabila diperlukan dan setelah memeriksa implementasi saat ini.

## 9. Batasan Teknis

- Pertahankan Flutter dan Dart.
- Pertahankan integrasi native yang telah berjalan.
- Pertahankan sumber data aktual.
- Pertahankan autentikasi dan penyimpanan.
- Hindari refactor besar yang tidak diperlukan untuk tujuan pembaruan.
- Jangan menambahkan ketergantungan baru tanpa kebutuhan yang jelas.
- Hindari perubahan kontrak API atau struktur database dalam pekerjaan UI ini.
- Pisahkan perubahan visual dari perbaikan bug fungsional jika keduanya dapat dikerjakan secara aman.
- Catat setiap perubahan yang berdampak pada perilaku launcher.

## 10. Acceptance Criteria

Pembaruan dianggap memenuhi persyaratan apabila:

1. Home Screen memiliki komposisi panel organik yang terinspirasi referensi.
2. Jam dan tanggal ditampilkan dengan benar.
3. Widget PKL menggunakan data aktual dan memiliki status fallback yang jelas.
4. Aplikasi favorit dapat dibuka langsung.
5. App Drawer dapat dibuka, dicari, dan digunakan untuk meluncurkan aplikasi.
6. Kategori tidak menjadi penghalang untuk menemukan aplikasi.
7. Navigasi dan tombol kembali berfungsi sesuai konteks.
8. Tampilan menyesuaikan ukuran layar yang diuji.
9. Tidak ada fungsi lama yang hilang akibat perubahan UI.
10. Tema dan komponen menggunakan design system yang konsisten.
11. Tidak ada error baru yang belum ditangani akibat perubahan.
12. Hasil pengujian dan pekerjaan yang belum selesai dilaporkan secara transparan.

## 11. Rencana Implementasi

### Tahap 1 — Audit
- Periksa kode aktual.
- Identifikasi widget, state, dan layanan yang digunakan.
- Dokumentasikan masalah visual dan fungsional yang terbukti.
- Tentukan komponen yang dapat dipakai kembali.

### Tahap 2 — Redesign Home
- Perbarui layout beranda.
- Terapkan panel organik.
- Susun ulang jam, informasi PKL, widget, dan pintasan.
- Validasi data dan state.

### Tahap 3 — Redesign App Drawer dan Dock
- Rapikan grid aplikasi.
- Perbaiki pencarian dan kategori.
- Sesuaikan ikon, label, spacing, dan interaksi.
- Validasi fungsi pembukaan aplikasi.

### Tahap 4 — Konsistensi dan Responsivitas
- Terapkan design system.
- Selaraskan halaman pendukung.
- Uji berbagai ukuran layar dan tema.

### Tahap 5 — QA dan Verifikasi
- Jalankan flutter pub get.
- Jalankan flutter analyze.
- Jalankan flutter test jika tersedia.
- Build aplikasi Android.
- Uji pada perangkat atau emulator.
- Catat hasil pengujian dan temuan yang belum diselesaikan.

## 12. Deliverables

Hasil pekerjaan harus mencakup:

1. Implementasi UI Home Screen terbaru.
2. Implementasi App Drawer dan Dock yang telah diperbaiki.
3. Penyelarasan design system.
4. Perbaikan responsivitas dan aksesibilitas yang masuk cakupan.
5. Daftar file yang diubah.
6. Ringkasan perubahan sebelum dan sesudah.
7. Hasil pengujian yang benar-benar dijalankan.
8. Daftar bug yang ditemukan dan belum terselesaikan.
9. Daftar pekerjaan lanjutan yang tidak termasuk cakupan Update 1.0.0.

## 13. Di Luar Cakupan

Fitur berikut tidak otomatis masuk dalam pembaruan ini:
- Integrasi cuaca baru.
- Integrasi musik baru.
- Pengembangan backend PKL baru.
- Perubahan sistem autentikasi.
- Perubahan struktur database.
- Penambahan fitur bisnis baru.
- Penggantian keseluruhan arsitektur aplikasi.

Fitur tambahan hanya dapat dimasukkan setelah kebutuhan, dependensi, dan dampaknya dikonfirmasi.

## 14. Definisi Selesai

Update 1.0.0 selesai ketika desain launcher telah diimplementasikan ke kode yang ada, fungsi utama tetap berjalan, tampilan diuji pada lingkungan yang tersedia, dan seluruh hasil serta keterbatasan pengujian didokumentasikan.

**Arah akhir:** SNOOP harus terasa seperti launcher Android yang memiliki identitas visual sendiri, bukan dashboard generik yang kebetulan dapat membuka aplikasi.

---

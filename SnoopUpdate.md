# PRODUCT REQUIREMENTS DOCUMENT (PRD)
# SNOOP Launcher — Fresh UI & PKL Productivity

**Versi:** 1.0.0  
**Status:** Draft untuk implementasi  
**Platform utama:** Android  
**Produk:** Launcher Android personal untuk produktivitas dan absensi Praktik Kerja Lapangan (PKL)

---

## 1. Ringkasan Produk

SNOOP adalah launcher Android yang menggabungkan fungsi home screen, app drawer, pengingat aktivitas, manajemen jadwal, dan sistem absensi PKL dalam satu antarmuka yang ringan.

Pengembangan versi ini berfokus pada pembaruan UI/UX secara menyeluruh berdasarkan referensi desain yang diberikan pengguna, optimalisasi performa, serta pengembangan sistem absensi dari penyimpanan lokal menjadi sistem yang terintegrasi dengan backend.

Desain harus mempertahankan karakter visual referensi berupa komposisi kartu membulat, kontras visual yang kuat, tipografi modern, ilustrasi atau ikon terpilih, serta tata letak yang terstruktur. Warna boleh berbeda dari referensi.

### Tujuan utama

1. Menciptakan tampilan launcher yang fresh, modern, konsisten, dan tidak terlihat seperti template generik.
2. Mengurangi penggunaan sumber daya dan meningkatkan responsivitas aplikasi.
3. Menjadikan swipe horizontal sebagai navigasi utama antara Home dan App Drawer.
4. Menghadirkan absensi masuk dan pulang yang benar-benar tersimpan secara online.
5. Mengintegrasikan jadwal, tugas, pengingat minum, istirahat, dan aktivitas PKL.
6. Mempertahankan fitur lama yang masih relevan dan memperbaiki implementasinya tanpa menulis ulang seluruh proyek secara tidak perlu.

## 2. Referensi Desain

Gambar referensi dari pengguna menjadi acuan untuk prinsip desain, bukan untuk menyalin warna atau konten aslinya.

### Karakteristik visual yang wajib dipertahankan

- Kartu dengan radius besar dan bentuk geometris yang konsisten.
- Hierarki konten yang jelas antara judul, angka, status, dan informasi pendukung.
- Kontras yang tegas antara permukaan utama dan komponen aksen.
- Komposisi modular yang memungkinkan berbagai jenis informasi disajikan dalam satu layar.
- Ikon dan ilustrasi digunakan secara selektif, bukan sebagai dekorasi berlebihan.
- Tombol utama memiliki bentuk, ukuran, dan posisi yang konsisten.
- Penggunaan whitespace yang terukur, bukan jarak kosong yang terlalu besar.
- Tampilan setiap halaman memiliki identitas yang jelas tetapi tetap menggunakan design system yang sama.

### Adaptasi untuk SNOOP

Elemen habit tracker pada referensi diubah menjadi fitur produktivitas PKL:

| Elemen referensi | Adaptasi SNOOP |
|---|---|
| Daily Goal | Status absensi dan target harian |
| Habit Streak | Konsistensi kehadiran |
| Task Board | Jadwal dan pekerjaan PKL |
| Habit List | Pengingat minum, istirahat, dan rutinitas |
| Project Progress | Progres tugas dan proyek |
| Goal Statistics | Statistik kehadiran dan penyelesaian tugas |
| Add Button | Menambah tugas atau pengingat |

Tidak semua komponen harus ditampilkan sekaligus. Prioritaskan informasi yang paling dibutuhkan pengguna pada saat membuka launcher.

## 3. Target Pengguna

Pengguna utama adalah siswa atau peserta PKL yang menggunakan Android sebagai perangkat sehari-hari.

Kebutuhan pengguna:

- Melihat jadwal dan agenda tanpa membuka banyak aplikasi.
- Melakukan absensi masuk dan pulang dengan cepat.
- Mengetahui status kehadiran hari ini.
- Mendapat pengingat yang relevan dan tepat waktu.
- Membuka aplikasi terpasang dengan navigasi yang intuitif.
- Mengakses data absensi dan tugas dengan koneksi internet yang terbatas.
- Menggunakan launcher tanpa mengalami lag, freeze, atau konsumsi baterai berlebihan.

## 4. Design System

### 4.1 Palet warna

Warna tidak harus mengikuti hijau pada gambar referensi. Gunakan palet yang sesuai dengan identitas SNOOP.

Palet awal yang direkomendasikan:

- Primary: sky blue atau blue-grey.
- Background: ivory atau off-white.
- Surface: putih atau warna permukaan yang sedikit berbeda dari background.
- Primary contrast: charcoal atau near-black.
- Success: hijau lembut.
- Warning: amber yang tidak terlalu terang.
- Error: merah lembut.
- Secondary accent: warna pastel tambahan, digunakan secara terbatas.

Nilai warna akhir harus didefinisikan sebagai design tokens, bukan ditulis berulang kali pada masing-masing widget.

Tema light dan dark harus didukung dengan kontras teks yang memadai. Dark mode menggunakan permukaan gelap dengan pemisahan tingkat permukaan yang jelas, bukan sekadar membalik seluruh warna.

### 4.2 Bentuk dan spacing

- Kartu utama: radius besar dan konsisten.
- Kartu sekunder: radius sedikit lebih kecil.
- Tombol: radius konsisten dengan karakter kartu.
- Spacing: menggunakan skala terstruktur, misalnya kelipatan 4 atau 8 dp.
- Ikon: gunakan satu gaya visual yang konsisten.
- Bayangan: minimal dan hanya jika membantu membedakan permukaan.
- Hindari blur berat, efek kaca berlapis-lapis, dan gradien yang tidak memberikan manfaat fungsional.

### 4.3 Tipografi

Gunakan tipografi sans-serif yang mudah dibaca. Ukuran dan bobot font harus menunjukkan hierarki yang jelas.

Urutan prioritas:

1. Jam dan status absensi.
2. Judul halaman dan agenda.
3. Informasi tugas dan pengingat.
4. Metadata, waktu, label, dan status sekunder.

Hindari teks terlalu kecil, khususnya pada tombol, status absensi, dan informasi penting.

## 5. Struktur Navigasi

Navigasi utama terdiri dari dua halaman horizontal.

### 5.1 Home

Home menjadi halaman utama saat launcher dibuka.

Konten yang diprioritaskan:

- Jam dan tanggal.
- Salam singkat atau identitas pengguna.
- Kartu absensi hari ini.
- Agenda atau pekerjaan berikutnya.
- Pengingat aktif.
- Ringkasan progres harian.
- Akses cepat ke aplikasi favorit.

### 5.2 App Drawer

App Drawer menampilkan aplikasi Android yang terpasang pada perangkat.

Fitur:

- Grid ikon aplikasi.
- Nama aplikasi.
- Pencarian aplikasi.
- Pengurutan yang konsisten.
- Pembukaan aplikasi dengan satu ketukan.
- Refresh daftar saat aplikasi baru dipasang atau dihapus.
- Caching ikon dan metadata untuk mengurangi pemuatan berulang.

App Drawer tidak boleh bergantung pada daftar aplikasi hardcoded.

### 5.3 Aturan gesture

**Navigasi utama harus menggunakan swipe horizontal, bukan swipe ke atas.**

- Dari Home, swipe ke kanan membuka App Drawer.
- Dari App Drawer, swipe ke kiri kembali ke Home.
- Perpindahan halaman memiliki animasi singkat dan natural.
- Tidak ada kewajiban menggunakan swipe ke atas untuk menampilkan aplikasi.
- Tombol alternatif untuk membuka daftar aplikasi boleh tersedia jika tidak mengganggu desain.

Implementasi gesture harus mempertimbangkan bahwa sebagian perangkat Android menggunakan swipe tepi layar untuk navigasi sistem. Gesture launcher tidak boleh mengambil alih navigasi sistem secara agresif.

Swipe untuk menghapus pengingat atau melakukan tindakan lain harus memiliki area dan arah interaksi yang jelas agar tidak bentrok dengan perpindahan halaman.

## 6. Spesifikasi Halaman

### 6.1 Home / Today

Home harus menjawab tiga pertanyaan dalam beberapa detik:

- Apa agenda saya berikutnya?
- Apakah saya sudah absen?
- Apakah ada pengingat penting?

Komponen:

**A. Header**
- Jam dan tanggal.
- Identitas pengguna atau salam.
- Informasi singkat yang relevan.

**B. Attendance Card**
- Status: belum absen, sudah absen masuk, sudah absen pulang, atau menunggu sinkronisasi.
- Jam masuk dan jam pulang.
- Tombol aksi utama yang berubah sesuai status.
- Indikator koneksi dan status penyimpanan.

**C. Today's Schedule**
- Daftar kegiatan berdasarkan waktu.
- Nama kegiatan, waktu, dan status.
- Penanda kegiatan yang sedang berlangsung.
- Akses ke detail tugas.

**D. Reminder Cards**
- Pengingat minum.
- Pengingat istirahat.
- Pengingat kegiatan dan tenggat.
- Kontrol menunda atau menyelesaikan pengingat.

**E. Daily Progress**
- Jumlah tugas selesai.
- Tugas yang masih berjalan.
- Ringkasan aktivitas harian.

Informasi harus diprioritaskan secara dinamis. Jika pengguna belum melakukan absensi, kartu absensi harus mendapat perhatian visual paling besar.

### 6.2 Attendance Detail

Halaman absensi menyediakan informasi yang lebih lengkap:

- Status kehadiran hari ini.
- Waktu masuk dan pulang.
- Informasi lokasi apabila kebijakan PKL mewajibkannya.
- Status sinkronisasi.
- Riwayat kehadiran.
- Catatan atau keterangan absensi.
- Informasi kesalahan dan cara mengatasinya.

Tombol absensi harus memiliki status loading, sukses, dan gagal yang jelas. Ketukan berulang tidak boleh menghasilkan catatan absensi ganda.

### 6.3 Task

Halaman tugas memiliki dua kategori utama:

- Daily Task.
- Project.

Setiap tugas dapat memuat judul, deskripsi, waktu, tenggat, status, dan prioritas. Progres ditampilkan dengan indikator yang mudah dipahami.

Fitur minimal:

- Menambah tugas.
- Mengubah detail tugas.
- Menandai tugas selesai.
- Mengurutkan tugas berdasarkan waktu atau prioritas.
- Menampilkan detail proyek.

Fitur lama yang sudah berjalan harus diperiksa sebelum diganti.

### 6.4 Reminder

Pengguna dapat membuat pengingat berdasarkan waktu dan pengulangan.

Contoh:

- Minum air setiap interval yang ditentukan.
- Istirahat pada jam tertentu.
- Persiapan berangkat PKL.
- Tenggat pekerjaan.
- Pengingat absensi masuk dan pulang.

Pengingat harus dapat diaktifkan, dinonaktifkan, ditunda, dan dihapus. Jadwal notifikasi harus tetap konsisten setelah perangkat dimulai ulang jika didukung oleh implementasi Android.

Jangan mengandalkan notifikasi yang membutuhkan proses aplikasi terus-menerus berjalan di latar belakang.

### 6.5 Statistics / Goal

Halaman statistik menampilkan:

- Total kehadiran.
- Jumlah keterlambatan jika aturan tersebut tersedia.
- Jumlah tugas selesai.
- Jumlah tugas yang masih berjalan.
- Ringkasan progres mingguan.

Data statistik harus berasal dari data aktual, bukan angka contoh yang ditampilkan sebagai data pengguna.

## 7. Sistem Absensi Online

### 7.1 Backend

Supabase direkomendasikan sebagai backend untuk autentikasi, database, dan penyimpanan riwayat absensi.

Implementasi harus memeriksa konfigurasi proyek yang sudah tersedia dan menggunakan kembali integrasi yang masih relevan.

Data minimum absensi:

- ID absensi.
- ID pengguna.
- Tanggal kerja berdasarkan zona waktu yang ditetapkan.
- Timestamp masuk.
- Timestamp pulang.
- Status absensi.
- Metadata lokasi jika diperlukan.
- Catatan atau keterangan.
- Status sinkronisasi lokal.

Gunakan tipe data dan constraint yang sesuai, serta relasi foreign key ke identitas pengguna.

### 7.2 Autentikasi

- Pengguna harus login sebelum melakukan absensi online.
- Data setiap pengguna terikat pada identitas autentikasi.
- Sesi harus dipertahankan dengan aman.
- Logout harus membersihkan informasi sensitif dari state aplikasi.
- Pengguna tidak boleh dapat mengakses atau mengubah absensi milik orang lain.

### 7.3 Validasi absensi

Validasi harus dilakukan di server atau melalui mekanisme backend tepercaya.

Persyaratan:

- Satu catatan absensi per pengguna per tanggal kerja, sesuai aturan yang ditetapkan.
- Waktu absensi ditentukan oleh server.
- Waktu pulang tidak boleh lebih awal daripada waktu masuk.
- Permintaan duplikat harus ditolak atau ditangani secara idempoten.
- Zona waktu dan pergantian tanggal harus ditentukan secara eksplisit.
- Jika diperlukan, validasi geofence dan aturan radius lokasi diterapkan di backend.

Lokasi GPS hanya boleh digunakan apabila diperlukan oleh kebijakan PKL. Permintaan izin lokasi harus disertai penjelasan yang jelas kepada pengguna.

### 7.4 Offline-first

Aplikasi harus tetap menampilkan data terakhir yang berhasil dimuat ketika koneksi internet tidak tersedia.

Untuk transaksi absensi offline:

- Catatan lokal diberi status menunggu sinkronisasi.
- Pengguna diberi tahu bahwa absensi belum dikonfirmasi server.
- Data disimpan dalam antrean lokal yang persisten.
- Sinkronisasi dicoba kembali ketika koneksi tersedia.
- Backend melakukan deduplikasi dan validasi.
- Antrean tidak boleh kehilangan catatan akibat aplikasi ditutup.

**Catatan penting:** absensi offline tidak boleh langsung ditampilkan sebagai absensi server yang sudah terverifikasi. Waktu lokal dapat dimanipulasi. Jika aturan PKL mewajibkan waktu resmi, konfirmasi final harus berasal dari server atau kebijakan offline yang disetujui pembimbing.

### 7.5 Keamanan

- Aktifkan Row Level Security (RLS).
- Buat policy berdasarkan identitas pengguna yang terautentikasi.
- Jangan menyertakan service-role key Supabase di aplikasi Android.
- Validasi operasi sensitif di server.
- Batasi akses ke data lokasi.
- Jangan menyimpan kata sandi dalam bentuk plaintext.
- Gunakan logging yang tidak membocorkan token, kredensial, atau data pribadi.

## 8. Persyaratan Performa

Performa merupakan persyaratan inti, bukan pekerjaan tambahan setelah UI selesai.

### Optimasi Flutter

- Gunakan `const` pada widget yang memenuhi syarat.
- Kurangi rebuild yang tidak diperlukan.
- Pisahkan state UI dari operasi database dan layanan perangkat.
- Hindari permintaan jaringan berulang saat Home dibuka.
- Gunakan caching untuk ikon aplikasi.
- Hindari pemrosesan berat di main isolate.
- Hindari polling agresif untuk memperbarui data.
- Gunakan mekanisme sinkronisasi yang sesuai, termasuk pembaruan berbasis event jika tersedia.
- Hindari mempertahankan seluruh layar berat dalam memori tanpa kebutuhan yang jelas.

### Integrasi Android

- Inisialisasi kamera dan GPS hanya ketika diperlukan.
- Kelola izin secara bertahap.
- Pastikan listener, stream, dan resource dilepas ketika tidak lagi digunakan.
- Hindari service latar belakang permanen hanya untuk pengingat biasa.
- Uji konsumsi baterai, startup, dan responsivitas di perangkat fisik.

### Kriteria pengukuran

Sebelum dan sesudah optimasi, ukur:

- Waktu cold start.
- Waktu perpindahan Home ke App Drawer.
- Frame rendering dan dropped frames.
- Penggunaan RAM saat idle dan saat membuka App Drawer.
- Konsumsi baterai selama penggunaan normal.
- Waktu pemuatan data absensi.
- Perilaku aplikasi saat offline.

Target awal yang diusulkan, bukan hasil pengukuran yang sudah tercapai:

- Cold start persentil ke-95 sekitar 2,5 detik atau kurang pada perangkat uji yang ditentukan.
- Transisi halaman sekitar 300 ms atau kurang.
- Animasi mengikuti target refresh rate perangkat tanpa jank yang berarti.
- Tidak ada permintaan jaringan berulang tanpa alasan.
- Tidak ada crash atau freeze selama skenario pengujian utama.

Target harus dievaluasi berdasarkan perangkat uji dan baseline aktual.

## 9. Arsitektur dan Pemeliharaan

Sebelum implementasi, lakukan audit terhadap source code yang ada.

Prinsip:

- Pertahankan teknologi dan fitur yang masih relevan.
- Hindari migrasi framework tanpa alasan teknis.
- Pisahkan UI, state management, domain logic, dan data services sesuai pola proyek.
- Gunakan satu sumber kebenaran untuk status absensi.
- Definisikan model dan kontrak data yang konsisten.
- Hindari duplikasi logika validasi.
- Simpan konfigurasi yang tidak sensitif di environment configuration.
- Sediakan penanganan error yang konsisten.

Jika proyek sudah menggunakan Flutter dan Kotlin untuk integrasi Android native, pertahankan pendekatan tersebut kecuali audit menunjukkan hambatan yang nyata.

## 10. Aksesibilitas dan Responsivitas

- Area sentuh idealnya minimal 48 × 48 dp.
- Informasi penting tidak hanya dibedakan menggunakan warna.
- Kontras teks memenuhi pedoman aksesibilitas yang relevan.
- Tata letak tetap terbaca pada berbagai ukuran layar.
- Teks yang panjang tidak boleh merusak kartu atau memotong tombol.
- Ukuran font sistem harus tetap didukung.
- Ikon penting memiliki label aksesibilitas.
- Animasi harus singkat dan tidak menghambat penggunaan.

## 11. Ruang Lingkup

### Termasuk dalam versi ini

- Redesign Home dan App Drawer.
- Navigasi swipe horizontal.
- Pembaruan design system.
- Integrasi absensi online.
- Penanganan sinkronisasi offline.
- Jadwal dan tugas.
- Pengingat dan notifikasi.
- Statistik kehadiran dan tugas.
- Optimasi performa.
- Penanganan loading, error, dan empty states.
- Pengujian serta verifikasi build APK.

### Tidak termasuk secara default

- Sistem payroll.
- Pelacakan GPS terus-menerus.
- Pengawasan pengguna di latar belakang.
- Sistem administrasi perusahaan yang kompleks.
- Sinkronisasi dengan sistem HR eksternal yang belum ditentukan.
- Penggantian seluruh arsitektur aplikasi tanpa justifikasi.

## 12. Acceptance Criteria

Pekerjaan dinyatakan selesai jika kriteria berikut terpenuhi.

### UI/UX

- [ ] Home mengikuti komposisi visual referensi dengan konten PKL.
- [ ] Palet warna baru diterapkan melalui design tokens.
- [ ] Komponen dan radius kartu konsisten.
- [ ] Semua halaman memiliki loading, error, dan empty states yang sesuai.
- [ ] Light dan dark mode berjalan jika keduanya masuk cakupan implementasi.
- [ ] Tidak ada overflow atau layout rusak pada ukuran layar target.

### Navigasi

- [ ] Swipe kanan dari Home membuka App Drawer.
- [ ] Swipe kiri dari App Drawer kembali ke Home.
- [ ] Daftar aplikasi diambil dari sistem Android.
- [ ] Pencarian aplikasi berfungsi.
- [ ] Gesture tidak bentrok dengan navigasi sistem secara signifikan.

### Absensi

- [ ] Login dan sesi autentikasi berfungsi.
- [ ] Absensi masuk tersimpan di backend.
- [ ] Absensi pulang tersimpan pada catatan yang benar.
- [ ] Timestamp resmi ditentukan oleh backend.
- [ ] Absensi ganda ditangani dengan benar.
- [ ] RLS mencegah akses lintas pengguna.
- [ ] Status offline dan pending sync ditampilkan secara akurat.
- [ ] Sinkronisasi ulang tidak membuat data duplikat.
- [ ] Riwayat absensi menampilkan data aktual.

### Pengingat dan tugas

- [ ] Pengingat dapat dibuat, diubah, dan dihapus.
- [ ] Notifikasi diuji pada perangkat Android.
- [ ] Tugas dapat diselesaikan dan progres diperbarui.
- [ ] Data tetap tersedia sesuai kebijakan penyimpanan dan sinkronisasi.

### Performa dan kualitas

- [ ] Analisis statis tidak memiliki error yang belum terselesaikan.
- [ ] Build APK berhasil.
- [ ] Skenario utama diuji pada perangkat fisik.
- [ ] Tidak ada crash kritis pada alur utama.
- [ ] Hasil pengukuran performa sebelum dan sesudah tersedia.
- [ ] Semua konfigurasi sensitif diperiksa sebelum rilis.

## 13. Tahapan Implementasi

**Tahap 1 — Audit**
- Petakan struktur source code.
- Identifikasi fitur yang sudah bekerja, belum lengkap, dan bermasalah.
- Catat dependensi dan konfigurasi backend.
- Buat baseline performa.

**Tahap 2 — Design system**
- Definisikan warna, tipografi, spacing, radius, ikon, dan komponen.
- Implementasikan ulang komponen bersama.
- Buat Home dan App Drawer berdasarkan referensi.

**Tahap 3 — Navigasi**
- Implementasikan perpindahan horizontal.
- Integrasikan App Drawer dengan Android native.
- Uji konflik gesture dan responsivitas.

**Tahap 4 — Absensi**
- Selesaikan autentikasi.
- Validasi skema database dan RLS.
- Implementasikan transaksi absensi masuk dan pulang.
- Tambahkan status offline dan sinkronisasi.

**Tahap 5 — Produktivitas**
- Integrasikan jadwal, tugas, pengingat, dan statistik.
- Pastikan data UI bersumber dari model yang benar.
- Uji notifikasi dan penyimpanan persisten.

**Tahap 6 — Optimasi dan QA**
- Profiling dan optimasi.
- Uji jaringan tidak stabil, restart perangkat, dan sesi login.
- Jalankan analisis statis dan build.
- Dokumentasikan perubahan, hasil pengujian, dan batasan yang tersisa.

## 14. Instruksi Implementasi untuk AI Coding Agent

Gunakan PRD ini bersama source code SNOOP yang sudah tersedia.

1. Audit source code terlebih dahulu sebelum mengubah file.
2. Jangan mengganti proyek dengan mockup atau aplikasi baru yang tidak terhubung dengan implementasi lama.
3. Pertahankan fitur yang masih relevan dan jangan menghapus data atau migrasi database yang sudah ada.
4. Gunakan gambar referensi sebagai acuan layout, hierarki, dan bentuk komponen, bukan sebagai kewajiban menyalin warna.
5. Terapkan swipe horizontal untuk navigasi Home dan App Drawer.
6. Selesaikan integrasi absensi online dan verifikasi keamanan backend.
7. Prioritaskan performa nyata di perangkat Android, bukan hanya tampilan yang terlihat ringan.
8. Jangan mengklaim suatu fitur selesai sebelum implementasi dan pengujiannya berhasil.
9. Jalankan pemeriksaan kode dan build APK, lalu perbaiki error yang ditemukan.
10. Pada akhir pekerjaan, berikan ringkasan file yang diubah, fitur yang selesai, hasil pengujian, konfigurasi yang masih dibutuhkan, dan masalah yang belum terselesaikan.

## 15. Definisi Keberhasilan Produk

SNOOP berhasil jika pengguna dapat membuka launcher, memahami agenda hari ini, melakukan absensi dengan benar, mengakses aplikasi melalui swipe kanan, dan menerima pengingat tanpa harus berhadapan dengan UI yang rumit atau performa yang lambat.

**Prinsip utama:** desain harus menarik secara visual, tetapi setiap elemen harus memiliki fungsi. Performa, kejelasan status absensi, keamanan data, dan kemudahan penggunaan lebih penting daripada dekorasi visual yang berat.

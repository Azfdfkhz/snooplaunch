# Setup backend SNOOP (Supabase + Google Drive)

## 1. Database
1. Supabase Dashboard > SQL Editor: jalankan `schema.sql` (sekali), lalu `migration_002_server_time.sql`, lalu
   `migration_003_drive_storage.sql` (kolom Drive, trigger pelindung kolom Drive, klaim unggah atomik, penghapusan
   dokumentasi hanya lewat Edge Function). Migrasi aman dijalankan ulang.
2. Authentication > Providers > Email: aktif. Untuk uji cepat, matikan "Confirm email" (atau konfirmasi lewat email).
2b. Authentication > URL Configuration: isi **Site URL** dan tambahkan **Redirect URLs** dengan
   `com.snoop.snoop://login-callback` (jangan biarkan `http://localhost:3000`). Tautan konfirmasi email lalu
   membuka aplikasi dan langsung login. Email yang dikirim sebelum pengaturan ini tetap mengarah ke localhost.
3. Project Settings > API: salin **Project URL** dan **anon/publishable key** ke `lib/core/env.dart`
   (atau `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` saat `flutter run` / `flutter build apk`).
   Jangan pernah memakai service_role key di aplikasi.
4. Buka aplikasi > Profil > Pengaturan > Akun cloud > Daftar/Masuk. Kartu "Sinkronisasi" menampilkan
   status koneksi, akun, antrean, dan pesan error terakhir.

## 2. Google Drive (Edge Function `drive-upload`, `drive-photo`, `drive-delete`)
Foto disimpan permanen di folder Drive **privat**; kredensial Google hanya ada di Secrets server. Aplikasi hanya
menyimpan metadata (`drive_file_id`, `drive_file_url`) dan menampilkan foto lewat `drive-photo` (JWT wajib).
Folder tidak perlu, dan tidak boleh, dibagikan publik.

1. Google Cloud Console: buat project, aktifkan **Google Drive API**.
2. OAuth consent screen (External, tambahkan akun Google Anda sebagai Test user).
   Catatan: aplikasi berstatus *Testing* membuat refresh token kedaluwarsa dalam 7 hari. Untuk penggunaan nyata
   ubah ke *In production* (atau gunakan Google Workspace internal) agar token tidak mati.
3. Credentials > Create OAuth client ID > **Web application**; tambahkan redirect URI
   `https://developers.google.com/oauthplayground`. Catat Client ID dan Client Secret.
4. Buka https://developers.google.com/oauthplayground > ikon gerigi > centang "Use your own OAuth credentials"
   > isi ID/secret. Scope: `https://www.googleapis.com/auth/drive.file` > Authorize > Exchange authorization
   code > salin **Refresh token**.
5. Buat folder di Drive, buka foldernya, salin ID dari URL (`.../folders/<ID>`).
   (Dengan scope `drive.file`, folder harus dibuat oleh aplikasi OAuth yang sama; jika upload ke folder
   buatan manual ditolak, pakai scope `https://www.googleapis.com/auth/drive` pada langkah 4.)
6. Deploy (ketiga fungsi memakai `functions/_shared/drive.ts`):
   ```bash
   supabase login
   supabase link --project-ref <PROJECT_REF>
   supabase secrets set GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... GOOGLE_REFRESH_TOKEN=... DRIVE_FOLDER_ID=...
   supabase functions deploy drive-upload
   supabase functions deploy drive-photo
   supabase functions deploy drive-delete
   ```
   Jangan menaruh service-role key atau secret Google di aplikasi, repo, atau `--dart-define`.
7. Periksa: di aplikasi, Pengaturan > Sinkronisasi > **Periksa Google Drive**. Hasilnya menyebutkan secret yang
   belum terisi (hanya namanya), atau apakah server berhasil masuk ke Drive.
8. Uji: absensi dengan foto. Layar hasil menampilkan "Mengunggah foto…" lalu "Foto tersimpan di Drive".
   Jika gagal, pesan error tampil di layar hasil dan di Pengaturan > Sinkronisasi; log di
   Dashboard > Edge Functions.

### Kontrak fungsi
| Fungsi | Body | Sukses |
|---|---|---|
| `drive-upload` mode `upload` | `memory_id`, `file_name`, `mime_type`, `data_base64` | `{confirmed:true, drive_file_id, drive_file_url, size}` |
| `drive-upload` mode `verify` | `memory_id` | sama; 404 `not_uploaded` bila belum/ file hilang |
| `drive-upload` mode `status` | - | `{configured, reachable?, missing?}` |
| `drive-photo` | `memory_id`, `thumb?` | `{data_base64, mime, thumb}` |
| `drive-delete` | `memory_id` | `{deleted:true}` (idempoten) |

`confirmed:true` hanya dikirim setelah server membaca ulang file dari Drive (ukuran dan MD5 cocok, tanda
kepemilikan `appProperties` sesuai) dan baris `documentations` tersimpan. Aplikasi menghapus berkas lokal hanya
setelah menerima `confirmed:true`.

### Keamanan yang diberlakukan
- JWT pemanggil divalidasi; baris `documentations` harus milik pemanggil (RLS); `drive-photo` dan `drive-delete`
  juga mencocokkan `appProperties` file Drive dengan pengguna + dokumentasi.
- Tipe file ditentukan dari isi (magic bytes JPEG/PNG), bukan dari klaim klien; batas 5 MB.
- Klien tidak dapat menulis kolom Drive atau `upload_status` (trigger), dan tidak dapat menghapus baris langsung
  (policy hanya select/insert/update). Tanpa ini pengguna dapat mengisi `drive_file_id` milik orang lain.
- Unggahan ganda dicegah: klaim atomik `snoop_claim_upload` + pencarian file lama berdasarkan `appProperties`
  sebelum mengunggah. Jika unggah sukses tetapi database gagal, file yang baru dibuat dihapus kembali.
- Detail error internal tidak dikirim ke klien dan URL file tidak ditulis ke log.
- File di Drive tidak dibuat publik.

# Setup backend SNOOP (Supabase + Google Drive)

## 1. Database
1. Supabase Dashboard > SQL Editor: jalankan `schema.sql` (sekali), lalu `migration_002_server_time.sql`.
2. Authentication > Providers > Email: aktif. Untuk uji cepat, matikan "Confirm email" (atau konfirmasi lewat email).
3. Project Settings > API: salin **Project URL** dan **anon/publishable key** ke `lib/core/env.dart`
   (atau `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...` saat `flutter run` / `flutter build apk`).
   Jangan pernah memakai service_role key di aplikasi.
4. Buka aplikasi > Profil > Pengaturan > Akun cloud > Daftar/Masuk. Kartu "Sinkronisasi" menampilkan
   status koneksi, akun, antrean, dan pesan error terakhir.

## 2. Google Drive (Edge Function `drive-upload`)
Foto disimpan di folder Drive milik Anda; kredensial hanya ada di server.
1. Google Cloud Console: buat project, aktifkan **Google Drive API**.
2. OAuth consent screen (External, tambahkan akun Google Anda sebagai Test user).
3. Credentials > Create OAuth client ID > **Web application**; tambahkan redirect URI
   `https://developers.google.com/oauthplayground`. Catat Client ID dan Client Secret.
4. Buka https://developers.google.com/oauthplayground > ikon gerigi > centang "Use your own OAuth credentials"
   > isi ID/secret. Scope: `https://www.googleapis.com/auth/drive.file` > Authorize > Exchange authorization
   code > salin **Refresh token**.
5. Buat folder di Drive, buka foldernya, salin ID dari URL (`.../folders/<ID>`).
   (Dengan scope `drive.file`, folder harus dibuat oleh aplikasi OAuth yang sama; jika upload ke folder
   buatan manual ditolak, pakai scope `https://www.googleapis.com/auth/drive` pada langkah 4.)
6. Deploy:
   ```bash
   supabase login
   supabase link --project-ref <PROJECT_REF>
   supabase secrets set GOOGLE_CLIENT_ID=... GOOGLE_CLIENT_SECRET=... GOOGLE_REFRESH_TOKEN=... DRIVE_FOLDER_ID=...
   supabase functions deploy drive-upload
   ```
7. Uji: lakukan absensi dengan foto. Status unggah di detail Memories berubah menjadi "Terunggah".
   Jika gagal, pesan error ada di Pengaturan > Sinkronisasi dan log di Dashboard > Edge Functions > drive-upload.

Catatan keamanan: fungsi memverifikasi JWT, memastikan baris `documentations` milik pemanggil, membatasi
tipe (JPEG/PNG) dan ukuran (5 MB), dan idempoten (upload ulang tidak membuat file ganda).

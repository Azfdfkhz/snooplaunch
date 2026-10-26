#!/usr/bin/env bash
# Jalankan di root proyek setelah mengisi supabase/secrets.env
set -e
cd "$(dirname "$0")"
ENV_FILE="supabase/secrets.env"
echo "Membaca: $(pwd)/$ENV_FILE"
[ -f "$ENV_FILE" ] || { echo "File $ENV_FILE tidak ditemukan."; exit 1; }

bad=0
for k in GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN DRIVE_FOLDER_ID; do
  line=$(grep -E "^[[:space:]]*$k=" "$ENV_FILE" | tail -n1 || true)
  val="${line#*=}"; val="${val%\"}"; val="${val#\"}"
  if [ -z "$line" ] || [ -z "$val" ]; then echo "  KOSONG/TIDAK ADA: $k"; bad=1
  elif [[ "$val" == *GANTI_DENGAN* ]]; then echo "  MASIH PLACEHOLDER: $k (baris $(grep -nE "^[[:space:]]*$k=" "$ENV_FILE" | tail -n1 | cut -d: -f1))"; bad=1
  else echo "  OK: $k (${#val} karakter)"; fi
done
[ "$bad" = 0 ] || { echo "Perbaiki baris di atas pada $ENV_FILE (simpan file), lalu jalankan ulang."; exit 1; }

supabase login
supabase link --project-ref akryjpsockddgptbnlnm
supabase secrets set --env-file "$ENV_FILE"
supabase functions deploy drive-upload
supabase functions deploy drive-photo
supabase functions deploy drive-delete
echo "Selesai. Di aplikasi: Pengaturan > Sinkronisasi > Periksa Google Drive"

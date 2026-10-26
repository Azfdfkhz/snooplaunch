-- Update 1.0.0 — Penyimpanan foto permanen di Google Drive.
-- Jalankan sekali di SQL Editor setelah schema.sql dan migration_002_server_time.sql.
-- Aman dijalankan ulang.

alter table public.documentations
  add column if not exists drive_size bigint,
  add column if not exists drive_uploaded_at timestamptz,
  add column if not exists upload_error text,
  add column if not exists upload_claimed_at timestamptz;

-- Satu file Drive hanya boleh dimiliki satu dokumentasi.
create unique index if not exists documentations_drive_file_id_key
  on public.documentations (drive_file_id) where drive_file_id is not null;

-- Klien (role authenticated) tidak boleh menulis kolom Drive / status unggah.
-- Tanpa ini pengguna bisa mengisi drive_file_id dengan id file milik orang lain lalu
-- membacanya lewat fungsi drive-photo. Hanya Edge Function (service_role) yang boleh mengubahnya.
create or replace function public.documentations_guard_drive_fields()
returns trigger language plpgsql as $$
begin
  if coalesce(auth.role(), '') = 'service_role' or current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.drive_file_id := null;  new.drive_file_url := null;  new.drive_size := null;
    new.drive_uploaded_at := null;  new.upload_status := 'pending';
    new.upload_error := null;  new.upload_claimed_at := null;
  else
    new.drive_file_id := old.drive_file_id;  new.drive_file_url := old.drive_file_url;
    new.drive_size := old.drive_size;  new.drive_uploaded_at := old.drive_uploaded_at;
    new.upload_status := old.upload_status;  new.upload_error := old.upload_error;
    new.upload_claimed_at := old.upload_claimed_at;
  end if;
  return new;
end $$;

drop trigger if exists documentations_guard_drive on public.documentations;
create trigger documentations_guard_drive
  before insert or update on public.documentations
  for each row execute function public.documentations_guard_drive_fields();

-- Penghapusan hanya lewat Edge Function drive-delete (menghapus file Drive lebih dulu),
-- supaya baris tidak terhapus sementara file Drive tertinggal.
drop policy if exists "documentations_own" on public.documentations;
drop policy if exists "documentations_select_own" on public.documentations;
drop policy if exists "documentations_insert_own" on public.documentations;
drop policy if exists "documentations_update_own" on public.documentations;
create policy "documentations_select_own" on public.documentations for select using (user_id = auth.uid());
create policy "documentations_insert_own" on public.documentations for insert with check (user_id = auth.uid());
create policy "documentations_update_own" on public.documentations for update
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Klaim unggahan atomik: mencegah dua permintaan (retry/ketukan ganda) mengunggah bersamaan.
-- Klaim kedaluwarsa setelah 2 menit supaya unggahan yang mati tidak memblokir selamanya.
create or replace function public.snoop_claim_upload(p_id uuid, p_user uuid)
returns boolean language plpgsql security definer set search_path = public as $$
declare n int;
begin
  update public.documentations
     set upload_status = 'uploading', upload_claimed_at = now(), upload_error = null
   where id = p_id and user_id = p_user and drive_file_id is null
     and (upload_status <> 'uploading' or upload_claimed_at is null or upload_claimed_at < now() - interval '2 minutes');
  get diagnostics n = row_count;
  return n > 0;
end $$;
revoke all on function public.snoop_claim_upload(uuid, uuid) from public, anon, authenticated;
grant execute on function public.snoop_claim_upload(uuid, uuid) to service_role;

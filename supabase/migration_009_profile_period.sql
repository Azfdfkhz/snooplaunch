-- Update 1.5.1 — profil tersimpan di cloud supaya tidak kembali ke placeholder setelah update / pasang ulang.
-- Jalankan sekali di SQL Editor. Aman dijalankan ulang.

alter table public.profiles
  add column if not exists period text;

-- Pastikan pengguna hanya mengakses profilnya sendiri (kebijakan sudah ada di schema.sql; dibuat ulang bila hilang).
alter table public.profiles enable row level security;
do $$
begin
  if not exists (select 1 from pg_policies where schemaname = 'public' and tablename = 'profiles' and policyname = 'profiles_own') then
    create policy "profiles_own" on public.profiles for all
      using (id = auth.uid()) with check (id = auth.uid());
  end if;
end $$;

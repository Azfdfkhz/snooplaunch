-- Update 1.5.2 / SnoopDesk 1.0.2: jembatan data HP <-> SnoopDesk (Workspace).
-- Jalankan SEKALI di Supabase SQL Editor. Aman dijalankan ulang.
--
-- Isi:
--  1. workspace_items   : kegiatan (jadwal), pengingat, catatan mingguan dari HP (dibaca desktop).
--  2. bridge_devices    : rahasia perangkat HP (hash) supaya layanan native HP bisa melapor tanpa sesi login.
--  3. device_status     : baterai HP terakhir yang dilaporkan.
--  4. device_notifications : notifikasi HP terbaru (maks. 100 per pengguna).
-- Absensi dan dokumentasi TIDAK perlu tabel baru: desktop membaca attendance_records dan documentations.

create extension if not exists pgcrypto with schema extensions;

-- ------------------------------------------------------------------ 1. Workspace items
create table if not exists public.workspace_items (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  kind text not null check (kind in ('schedule', 'reminder', 'note')),
  id text not null,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (user_id, kind, id)
);
alter table public.workspace_items enable row level security;
drop policy if exists "workspace_items_own" on public.workspace_items;
create policy "workspace_items_own" on public.workspace_items for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Mengganti seluruh isi satu jenis (HP adalah sumber): baris yang sudah tidak ada di HP dihapus.
create or replace function public.workspace_replace(p_kind text, p_items jsonb)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare n integer;
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;
  if p_kind not in ('schedule', 'reminder', 'note') then raise exception 'bad_kind'; end if;
  if jsonb_typeof(p_items) <> 'array' then raise exception 'items_must_be_array'; end if;
  if jsonb_array_length(p_items) > 2000 then raise exception 'too_many_items'; end if;

  delete from public.workspace_items w
   where w.user_id = auth.uid() and w.kind = p_kind
     and w.id not in (select e ->> 'id' from jsonb_array_elements(p_items) e where e ->> 'id' is not null);

  insert into public.workspace_items (user_id, kind, id, payload, updated_at)
  select auth.uid(), p_kind, e ->> 'id', e - 'id', now()
    from jsonb_array_elements(p_items) e
   where e ->> 'id' is not null
  on conflict (user_id, kind, id) do update
    set payload = excluded.payload, updated_at = now()
    where public.workspace_items.payload is distinct from excluded.payload;

  get diagnostics n = row_count;
  return n;
end $$;
revoke all on function public.workspace_replace(text, jsonb) from public, anon;
grant execute on function public.workspace_replace(text, jsonb) to authenticated;

-- ------------------------------------------------------------------ 2. Perangkat HP
create table if not exists public.bridge_devices (
  user_id uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  secret_hash text not null,
  device_name text,
  created_at timestamptz not null default now()
);
alter table public.bridge_devices enable row level security;  -- tanpa policy: hanya lewat fungsi di bawah

create table if not exists public.device_status (
  user_id uuid primary key references auth.users(id) on delete cascade,
  device_name text,
  battery integer check (battery between 0 and 100),
  charging boolean,
  updated_at timestamptz not null default now()
);
alter table public.device_status enable row level security;
drop policy if exists "device_status_read_own" on public.device_status;
create policy "device_status_read_own" on public.device_status for select using (user_id = auth.uid());

create table if not exists public.device_notifications (
  id bigint generated always as identity primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  dedupe_key text not null,
  package_name text,
  app_name text,
  title text,
  body text,
  posted_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (user_id, dedupe_key)
);
create index if not exists device_notifications_user_idx on public.device_notifications (user_id, id desc);
alter table public.device_notifications enable row level security;
drop policy if exists "device_notifications_read_own" on public.device_notifications;
create policy "device_notifications_read_own" on public.device_notifications for select using (user_id = auth.uid());
drop policy if exists "device_notifications_delete_own" on public.device_notifications;
create policy "device_notifications_delete_own" on public.device_notifications for delete using (user_id = auth.uid());

-- HP mendaftarkan rahasia acak (32+ karakter). Hanya hash-nya disimpan. Satu HP aktif per akun (yang terbaru menang).
create or replace function public.bridge_register(p_secret text, p_device_name text default null)
returns void
language plpgsql
security definer
set search_path = public, extensions
as $$
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;
  if p_secret is null or length(p_secret) < 32 then raise exception 'secret_too_short'; end if;
  insert into public.bridge_devices (user_id, secret_hash, device_name)
  values (auth.uid(), encode(digest(p_secret, 'sha256'), 'hex'), left(coalesce(p_device_name, 'HP'), 60))
  on conflict (user_id) do update
    set secret_hash = excluded.secret_hash, device_name = excluded.device_name;
end $$;
revoke all on function public.bridge_register(text, text) from public, anon;
grant execute on function public.bridge_register(text, text) to authenticated;

-- Dipanggil layanan native HP (anon key + rahasia). Menulis baterai dan notifikasi milik pemilik rahasia saja.
create or replace function public.bridge_push(
  p_secret text,
  p_battery integer default null,
  p_charging boolean default null,
  p_notifications jsonb default '[]'::jsonb
) returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  uid uuid;
  dname text;
  n jsonb;
  added integer := 0;
begin
  if p_secret is null or length(p_secret) < 32 then raise exception 'invalid_secret'; end if;
  select b.user_id, b.device_name into uid, dname
    from public.bridge_devices b
   where b.secret_hash = encode(digest(p_secret, 'sha256'), 'hex');
  if uid is null then raise exception 'invalid_secret'; end if;

  if p_battery is not null then
    insert into public.device_status (user_id, device_name, battery, charging, updated_at)
    values (uid, dname, greatest(0, least(100, p_battery)), p_charging, now())
    on conflict (user_id) do update
      set device_name = excluded.device_name, battery = excluded.battery,
          charging = excluded.charging, updated_at = now();
  end if;

  if jsonb_typeof(p_notifications) = 'array' then
    for n in select * from jsonb_array_elements(p_notifications) limit 20 loop
      if coalesce(n ->> 'key', '') = '' then continue; end if;
      insert into public.device_notifications (user_id, dedupe_key, package_name, app_name, title, body, posted_at)
      values (
        uid, left(n ->> 'key', 200), left(n ->> 'pkg', 120), left(n ->> 'app', 80),
        left(n ->> 'title', 160), left(n ->> 'body', 500),
        coalesce(to_timestamp(nullif(n ->> 'at', '')::double precision / 1000.0), now())
      ) on conflict (user_id, dedupe_key) do nothing;
      if found then added := added + 1; end if;
    end loop;
    -- simpan 100 terbaru saja
    delete from public.device_notifications d
     where d.user_id = uid
       and d.id not in (select x.id from public.device_notifications x where x.user_id = uid order by x.id desc limit 100);
  end if;

  return jsonb_build_object('ok', true, 'added', added);
end $$;
revoke all on function public.bridge_push(text, integer, boolean, jsonb) from public;
grant execute on function public.bridge_push(text, integer, boolean, jsonb) to anon, authenticated;

-- Mencabut sambungan (keluar akun / matikan): hapus perangkat, status, dan notifikasi.
create or replace function public.bridge_unregister()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then raise exception 'unauthorized'; end if;
  delete from public.bridge_devices where user_id = auth.uid();
  delete from public.device_status where user_id = auth.uid();
  delete from public.device_notifications where user_id = auth.uid();
end $$;
revoke all on function public.bridge_unregister() from public, anon;
grant execute on function public.bridge_unregister() to authenticated;

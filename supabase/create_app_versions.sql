-- =============================================================
-- Tabel versi aplikasi untuk In-App Updater (tanpa Play Store)
-- =============================================================

create table if not exists public.app_versions (
  id            bigserial primary key,
  version_code  integer not null unique,          -- 4000 + buildNumber (lihat catatan di bawah)
  version_name  text    not null,                 -- mis. "1.0.1"
  changelog     text    default '',                -- catatan rilis
  apk_url       text    not null,                 -- URL publik file APK di bucket "app-releases"
  apk_size      bigint  default 0,                -- ukuran file dalam byte
  is_mandatory  boolean not null default false,   -- true = user tidak bisa skip update
  is_active     boolean not null default true,    -- false = riwayat / nonaktif
  apk_variants  jsonb   default '{}'::jsonb,       -- peta ABI -> URL APK (split-per-abi)
  created_at    timestamptz not null default now()
);

comment on table public.app_versions is 'Riwayat rilis aplikasi TenMu untuk mekanisme in-app update (sideload)';
comment on column public.app_versions.version_code is
  'Sentinel 4000 + buildNumber. Build split-per-abi memberi offset versionCode per ABI (1003/2003/4003), sehingga versi aplikasi lama yang membandingkan versionCode polos hanya terdeteksi bila angka DB lebih besar dari semua offset ABI.';

-- RLS: semua orang boleh baca versi aktif, hanya admin yang boleh tulis
alter table public.app_versions enable row level security;

drop policy if exists "public read active versions" on public.app_versions;
create policy "public read active versions"
  on public.app_versions for select
  using (is_active = true or auth.role() = 'authenticated');

drop policy if exists "authenticated manage versions" on public.app_versions;
create policy "authenticated manage versions"
  on public.app_versions for all
  to authenticated
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- Index untuk query "versi terbaru aktif"
create index if not exists idx_app_versions_active_code
  on public.app_versions (is_active, version_code desc);

-- =============================================================
-- Bucket penyimpanan file APK
-- =============================================================
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'app-releases',
  'app-releases',
  true,
  209715200,   -- 200 MB
  array['application/vnd.android.package-archive', 'application/octet-stream']
)
on conflict (id) do update
  set public             = excluded.public,
      file_size_limit    = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- APK boleh dibaca publik (user butuh unduh tanpa login Supabase)
drop policy if exists "public read app releases" on storage.objects;
create policy "public read app releases"
  on storage.objects for select
  using (bucket_id = 'app-releases');

-- Admin boleh upload/release APK
drop policy if exists "authenticated upload app releases" on storage.objects;
create policy "authenticated upload app releases"
  on storage.objects for insert
  to authenticated
  with check (bucket_id = 'app-releases');

drop policy if exists "authenticated manage app releases" on storage.objects;
create policy "authenticated manage app releases"
  on storage.objects for all
  to authenticated
  using (bucket_id = 'app-releases')
  with check (bucket_id = 'app-releases');

-- Rilis Android 1.0.3 (build 4)
-- APK di-upload ke bucket publik `app-releases`:
--   tenmu-1.0.3-arm64-v8a.apk, tenmu-1.0.3-armeabi-v7a.apk, tenmu-1.0.3-x86_64.apk
-- version_code memakai sentinel 4000 + buildNumber (lihat sync_version_code_sentinel.sql).

-- Nonaktifkan semua rilis lama
update public.app_versions
   set is_active = false
 where version_name <> '1.0.3';

insert into public.app_versions (
  version_name,
  version_code,
  apk_url,
  apk_size,
  apk_variants,
  is_active,
  is_mandatory,
  changelog,
  created_at
)
values (
  '1.0.3',
  4004,
  'https://axtkquxgojewinwdndtt.supabase.co/storage/v1/object/public/app-releases/tenmu-1.0.3-arm64-v8a.apk',
  37134378,
  jsonb_build_object(
    'arm64-v8a',   'https://axtkquxgojewinwdndtt.supabase.co/storage/v1/object/public/app-releases/tenmu-1.0.3-arm64-v8a.apk',
    'armeabi-v7a', 'https://axtkquxgojewinwdndtt.supabase.co/storage/v1/object/public/app-releases/tenmu-1.0.3-armeabi-v7a.apk',
    'x86_64',      'https://axtkquxgojewinwdndtt.supabase.co/storage/v1/object/public/app-releases/tenmu-1.0.3-x86_64.apk'
  ),
  true,
  false,
  'Notifikasi push (OneSignal) — pesan admin tetap masuk walau app ditutup. Menu Review & Rating dipisah dari Manajemen User. Navbar Konten & Promo dihapus. Perbaikan tampilan dashboard admin.',
  now()
)
on conflict (version_name) do update
  set version_code = excluded.version_code,
      apk_url      = excluded.apk_url,
      apk_size     = excluded.apk_size,
      apk_variants = excluded.apk_variants,
      changelog    = excluded.changelog,
      is_active    = true;

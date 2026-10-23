-- =============================================================
-- Sinkronisasi version_code sentinel untuk in-app updater
--
-- Latar belakang:
--   Build split-per-abi memberi OFFSET versionCode per ABI:
--     build 2 -> 1002 (armeabi-v7a), 2002 (arm64-v8a), 4002 (x86_64)
--     build 3 -> 1003, 2003, 4003
--   Aplikasi versi lama membandingkan versionCode polos:
--     latest.versionCode > PackageInfo.buildNumber
--   Bila DB menyimpan angka polos (mis. 3), perbandingan itu selalu
--   false di perangkat mana pun (3 > 2002 salah), sehingga dialog
--   pembaruan TIDAK PERNAH muncul.
--
-- Solusi:
--   Simpan version_code = 4000 + buildNumber.
--   Angka ini selalu lebih besar dari offset ABI mana pun
--   (4000 + 2 = 4002 > 4002? tidak, tapi build berikutnya 4003 > 4002),
--   sehingga versi lama tetap mendeteksi rilis baru.
--   Versi baru membandingkan version_name (tidak terpengaruh offset).
-- =============================================================

-- Naikkan baris 1.0.1 ke sentinel buildNumber 2 -> 4002
update public.app_versions
   set version_code = 4002
 where version_name = '1.0.1'
   and version_code = 2;

-- Naikkan baris 1.0.2 ke sentinel buildNumber 3 -> 4003
update public.app_versions
   set version_code = 4003
 where version_name = '1.0.2'
   and version_code = 3;

-- Hanya satu rilis aktif: 1.0.2 (akan diganti 1.0.3 setelah insert)
update public.app_versions
   set is_active = false
 where version_name <> '1.0.2';

-- Jaring pengaman: pastikan tidak ada baris dengan version_code polos
-- yang masih tertinggal (bisa bentrok dengan unique constraint).
select id, version_code, version_name, is_active
  from public.app_versions
 order by version_code desc;

-- Fix RLS artikel.
--
-- Policy lama memakai `auth.jwt() ->> 'role'`, yang isinya ROLE POSTGRES
-- ('authenticated'), bukan role aplikasi dari tabel profiles. Akibatnya
-- policy tidak pernah cocok: superadmin tidak bisa insert/update/delete
-- artikel, dan draft artikel tidak terlihat. UPDATE/DELETE yang kena 0 baris
-- tidak melempar error, jadi UI tampak "berhasil" padahal tidak ada perubahan.
--
-- Ganti ke public.is_admin() (baca profiles.role, SECURITY DEFINER).
-- Rollback: drop policy baru, jalankan ulang policy versi jwt di bawah.

drop policy if exists articles_select_admin on public.articles;
drop policy if exists articles_insert_admin on public.articles;
drop policy if exists articles_update_admin on public.articles;
drop policy if exists articles_delete_admin on public.articles;

create policy articles_select_admin on public.articles
  for select to authenticated using (public.is_admin());

create policy articles_insert_admin on public.articles
  for insert to authenticated with check (public.is_admin());

create policy articles_update_admin on public.articles
  for update to authenticated using (public.is_admin()) with check (public.is_admin());

create policy articles_delete_admin on public.articles
  for delete to authenticated using (public.is_admin());

-- Rollback:
--   drop policy if exists articles_select_admin on public.articles;
--   drop policy if exists articles_insert_admin on public.articles;
--   drop policy if exists articles_update_admin on public.articles;
--   drop policy if exists articles_delete_admin on public.articles;
--   create policy articles_select_admin on public.articles for select to authenticated
--     using ((auth.jwt() ->> 'role') = any (array['admin','superadmin']));
--   ... (policy insert/update/delete dengan ekspresi yang sama)
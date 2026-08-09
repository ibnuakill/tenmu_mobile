-- =============================================================================
-- RLS fix: profiles & places – urutan DROP lalu CREATE yang benar
-- =============================================================================
-- Migration sebelumnya (20260809130000) memiliki bug urutan:
--   CREATE POLICY ditulis lebih awal, lalu DO $$ DROP semua policy -> hilang.
-- Migration ini memastikan semua policy profiles & places benar.

-----------------------------------------------------------------------------
-- 1) HAPUS semua policy lama (profiles & places) terlebih dahulu
-----------------------------------------------------------------------------
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
  END LOOP;

  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'places'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.places', pol.policyname);
  END LOOP;
END $$;

-----------------------------------------------------------------------------
-- 2) Pastikan RLS aktif
-----------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.places   ENABLE ROW LEVEL SECURITY;

-----------------------------------------------------------------------------
-- 3) PROFILES policies
-----------------------------------------------------------------------------

-- SELECT: user bisa lihat profil sendiri
CREATE POLICY "profiles_select_self"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);

-- SELECT: profil publik (untuk info nama & role pemilik tempat, dsb.)
CREATE POLICY "profiles_select_public"
  ON public.profiles
  FOR SELECT
  TO anon, authenticated
  USING (role IS NOT NULL);

-- INSERT: buat profil sendiri saat signup / first login
CREATE POLICY "profiles_insert_own"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- UPDATE: hanya akun sendiri (bukan escalate role orang lain)
CREATE POLICY "profiles_update_self"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);

-----------------------------------------------------------------------------
-- 4) PLACES policies
-----------------------------------------------------------------------------

-- SELECT: semua bisa lihat yang sudah verified
CREATE POLICY "places_select_verified"
  ON public.places
  FOR SELECT
  TO anon, authenticated
  USING (verification_status = 'verified');

-- SELECT: owner lihat tempat miliknya sendiri (termasuk draft/pending)
CREATE POLICY "places_select_owner"
  ON public.places
  FOR SELECT
  TO authenticated
  USING (auth.uid() = owner_id);

-- SELECT: admin & superadmin lihat semua
CREATE POLICY "places_select_superadmin"
  ON public.places
  FOR SELECT
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- INSERT: owner tambah tempat baru
CREATE POLICY "places_insert_owner"
  ON public.places
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = owner_id);

-- UPDATE: owner edit tempatnya sendiri
CREATE POLICY "places_update_owner"
  ON public.places
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

-- UPDATE: admin/superadmin bisa update (verify/reject/dll.)
CREATE POLICY "places_update_admin"
  ON public.places
  FOR UPDATE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'))
  WITH CHECK (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- DELETE: hanya admin/superadmin
CREATE POLICY "places_delete_admin"
  ON public.places
  FOR DELETE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

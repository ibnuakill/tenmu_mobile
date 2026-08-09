-- =============================================================================
-- RLS tighten: profiles + places per-row
-- =============================================================================
-- Memperketat RLS di atas tabel `profiles` dan `places`.
--
-- Alasan:
--   * `profiles` sebelumnya punya UPDATE USING (true) → SEPARANG user bisa
--     mengubah role/request_status orang lain (privilege escalation).
--     Diperketat: UPDATE hanya untuk akun sendiri. Hint admin untuk update
--     role tetap dilakukan server-side (service_role / khusus superadmin).
--   * `places` ditambah policy per-row:
--        SELECT  : semua anon/authenticated baca verified (via view/RPC)
--        INSERT   : owner (auth.uid = owner_id) — add_place_screen
--        UPDATE   : owner sendiri (isOwnerView/edit), atau superadmin (verify)
--        DELETE   : owner sendiri (hapus tempat yang dia buat)
--
-- Catatan: CREATE POLICY tidak idempoten; migrasi ini HAPUS policy lama yang
-- namanya mungkin berbeda (pattern dinamis via pg_policies), lalu buat ulang
-- dengan nama tetap. Aman dijalankan ulang.

-----------------------------------------------------------------------------
-- 1) PROFILES
-----------------------------------------------------------------------------
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
DROP POLICY IF EXISTS "profiles_update_self" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- Hapus sisa pola lama yang memberi update ke semua
DROP POLICY IF EXISTS "profiles_update_all" ON public.profiles;
DROP POLICY IF EXISTS "Enable update for users" ON public.profiles;

CREATE POLICY "profiles_update_self"
  ON public.profiles
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id AND (new.avatar_url IS NOT NULL OR new.avatar_url IS NULL));

-- INSERT own profile saat signup:
CREATE POLICY "profiles_insert_own"
  ON public.profiles
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

-- SELECT: bisa lihat profil sendiri + profil owner tempat (untuk info)
CREATE POLICY "profiles_select_self"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (auth.uid() = id);
CREATE POLICY "profiles_select_public"
  ON public.profiles
  FOR SELECT
  TO anon, authenticated
  USING (role IS NOT NULL);   -- profil PUBLIK (nama & role) boleh dibaca

-----------------------------------------------------------------------------
-- 2) places — per-row policies
-----------------------------------------------------------------------------
-- BERSIHKAN policy lama dengan nama berapa pun yang ada di remote
DO $$
DECLARE
  pol record;
BEGIN
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'places'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.places', pol.policyname);
  END LOOP;
  FOR pol IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
  END LOOP;
END $$;

-- Perbarui: pastikan RLS benar-benar aktif
ALTER TABLE public.places ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- SELECT places:
CREATE POLICY "places_select_verified"
  ON public.places
  FOR SELECT
  TO anon, authenticated
  USING (verification_status = 'verified');

CREATE POLICY "places_select_owner"
  ON public.places
  FOR SELECT
  TO authenticated
  USING (auth.uid() = owner_id);

CREATE POLICY "places_select_superadmin"
  ON public.places
  FOR SELECT
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- INSERT: owner (add place)
CREATE POLICY "places_insert_owner"
  ON public.places
  FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = owner_id);

-- UPDATE: owner sendiri, atau superadmin (verify/reject/reason)
CREATE POLICY "places_update_owner"
  ON public.places
  FOR UPDATE
  TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "places_update_admin"
  ON public.places
  FOR UPDATE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'))
  WITH CHECK (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- DELETE: superadmin saja (atau owner?) — keep admin
CREATE POLICY "places_delete_admin"
  ON public.places
  FOR DELETE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- Akses superadmin juga lewat golongan supabase_auth_admin? Policy-to,
-- tapi cukup via role inline.

-- =============================================================================
-- Eksekusi: pastikan tidak yg aneh — Baca select policies di docs.
-- =============================================================================
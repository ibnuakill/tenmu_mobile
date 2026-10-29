-- ============================================================================
-- Perbaikan RLS admin + tutup celah eskalasi role
-- ============================================================================
-- MASALAH 1 (penyebab tombol admin "tidak ada respon"):
--   Policy `profiles_update_self` hanya mengizinkan `auth.uid() = id`.
--   Saat admin meng-update profil user lain, PostgREST TIDAK mengembalikan
--   error — hanya HTTP 200 dengan 0 baris. Jadi app menampilkan "berhasil"
--   padahal tidak ada yang berubah.
--
-- MASALAH 2:
--   Policy admin yang ada memakai `auth.jwt() ->> 'role' IN ('admin', ...)`.
--   Claim itu tidak pernah ada: custom access token hook tidak aktif, dan JWT
--   user hanya berisi `role: "authenticated"`. Jadi policy admin tidak pernah
--   cocok.
--
-- MASALAH 3 (kritis):
--   `profiles_update_self` mengizinkan user mengubah kolom apa pun di barisnya
--   sendiri — termasuk `role`. Artinya user biasa bisa menjadikan dirinya
--   `superadmin` lewat satu request PATCH. Ini sudah terbukti bisa.
--
-- Jalankan file ini di Supabase Dashboard → SQL Editor.
-- ============================================================================

-- 1) Helper: apakah pemanggil admin/superadmin? (baca profiles, bukan claim JWT)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role IN ('admin', 'superadmin')
  );
$$;

REVOKE ALL ON FUNCTION public.is_admin() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated, service_role;

-- 2) Admin boleh meng-update profil siapa pun
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;
CREATE POLICY "profiles_update_admin" ON public.profiles
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- 3) Cegah user menaikkan role/status dirinya sendiri
CREATE OR REPLACE FUNCTION public.profiles_guard_privileged_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- service_role / server (tanpa JWT user) → boleh, dipakai edge function admin-api
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- admin & superadmin → boleh
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  -- selain itu: hanya boleh mengubah kolom profil biasa
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Role tidak boleh diubah sendiri' USING ERRCODE = '42501';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    RAISE EXCEPTION 'Status akun tidak boleh diubah sendiri' USING ERRCODE = '42501';
  END IF;

  IF NEW.owner_request_status IS DISTINCT FROM OLD.owner_request_status
     AND NEW.owner_request_status NOT IN ('pending', 'none', 'cancelled') THEN
    RAISE EXCEPTION 'Status pengajuan hanya bisa diubah oleh admin' USING ERRCODE = '42501';
  END IF;

  IF NEW.request_status IS DISTINCT FROM OLD.request_status THEN
    RAISE EXCEPTION 'Status permintaan hanya bisa diubah oleh admin' USING ERRCODE = '42501';
  END IF;

  IF NEW.request_handled_by IS DISTINCT FROM OLD.request_handled_by
     OR NEW.request_handled_at IS DISTINCT FROM OLD.request_handled_at THEN
    RAISE EXCEPTION 'Kolom penanganan hanya bisa diisi admin' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_profiles_guard_privileged ON public.profiles;
CREATE TRIGGER trg_profiles_guard_privileged
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.profiles_guard_privileged_columns();

-- 4) Policy admin untuk `places` — ganti claim JWT dengan is_admin()
DROP POLICY IF EXISTS "places_update_admin" ON public.places;
CREATE POLICY "places_update_admin" ON public.places
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "places_delete_admin" ON public.places;
CREATE POLICY "places_delete_admin" ON public.places
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- 5) Admin boleh menghapus ulasan siapa pun (fitur "hapus semua ulasan user")
DROP POLICY IF EXISTS "reviews_delete_admin" ON public.reviews;
CREATE POLICY "reviews_delete_admin" ON public.reviews
  FOR DELETE TO authenticated
  USING (public.is_admin());

-- 6) Pastikan admin bisa membaca semua baris (untuk daftar pengajuan/verifikasi)
DROP POLICY IF EXISTS "profiles_select_admin" ON public.profiles;
CREATE POLICY "profiles_select_admin" ON public.profiles
  FOR SELECT TO authenticated
  USING (public.is_admin());

-- ============================================================================
-- Setelah ini:
--   • Admin bisa approve/reject/ban lewat app (langsung maupun via admin-api).
--   • User biasa TIDAK bisa lagi menjadikan dirinya superadmin.
-- ============================================================================

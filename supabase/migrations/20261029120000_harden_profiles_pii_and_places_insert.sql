-- ============================================================================
-- HARDENING: kebocoran data pribadi (PII) di tabel profiles
--            + siapa saja boleh insert places
-- ----------------------------------------------------------------------------
-- MASALAH YANG DITUTUP
--
-- 1) Policy `profiles_select_public` berbunyi:
--        USING (role IS NOT NULL)  TO anon, authenticated
--    Artinya SIAPA PUN yang memegang anon key (key ini ikut ter-bundle di
--    dalam APK, jadi bisa diambil siapa saja) bisa membaca SELURUH baris
--    profiles — termasuk `owner_request_phone` dan `owner_request_alamat`
--    milik semua user. Sudah diuji: tanpa login, 5 baris terbaca lengkap
--    dengan nomor HP dan alamat.
--
--    Perbaikan:
--      a) anon TIDAK boleh baca profiles sama sekali (harus login).
--      b) Data pengajuan (nama UMKM, alamat, no HP, catatan) otomatis
--         dikosongkan begitu pengajuan tidak lagi berstatus 'pending',
--         jadi PII tidak menumpuk di database.
--
-- 2) Policy `places_insert_owner` hanya memeriksa `auth.uid() = owner_id`,
--    tidak memeriksa role. Akibatnya user biasa (role='user') bisa
--    menyisipkan tempat dan membanjiri antrean verifikasi admin.
--    Perbaikan: insert hanya untuk role owner / superadmin.
--
-- CATATAN: untuk jangka panjang, PII pengajuan sebaiknya dipindah ke tabel
-- terpisah (`owner_requests`) dengan policy ketat, bukan menempel di profiles.
-- ============================================================================

-- ── 1. profiles: hanya user login yang boleh membaca ────────────────────────
DROP POLICY IF EXISTS "profiles_select_public" ON public.profiles;

CREATE POLICY "profiles_select_public"
  ON public.profiles
  FOR SELECT
  TO authenticated
  USING (role IS NOT NULL);

-- ── 2. Bersihkan PII pengajuan otomatis kalau sudah tidak pending ───────────
CREATE OR REPLACE FUNCTION public.scrub_owner_request_pii()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- PII hanya disimpan selama pengajuan masih menunggu keputusan.
  IF NEW.owner_request_status IS DISTINCT FROM 'pending' THEN
    NEW.owner_request_nama_umkm := NULL;
    NEW.owner_request_alamat    := NULL;
    NEW.owner_request_phone     := NULL;
    NEW.owner_request_note      := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_scrub_owner_request_pii ON public.profiles;

CREATE TRIGGER trg_scrub_owner_request_pii
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.scrub_owner_request_pii();

-- ── 3. places: insert hanya untuk owner / superadmin ────────────────────────
DROP POLICY IF EXISTS "places_insert_owner" ON public.places;

CREATE POLICY "places_insert_owner"
  ON public.places
  FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = owner_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('owner', 'superadmin')
    )
  );

-- ── Verifikasi ──────────────────────────────────────────────────────────────
-- Setelah dijalankan, cek dengan anon key (tanpa login) — harus balik kosong:
--   curl "https://<project>.supabase.co/rest/v1/profiles?select=id,nama" \
--        -H "apikey: <ANON_KEY>"
-- Ekspektasi: [] (sebelumnya berisi semua user).

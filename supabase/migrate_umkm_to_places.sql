-- ============================================================
-- MIGRATION: umkm → places + kategori baru
-- Deskripsi: Rename tabel umkm ke places, perluas kategori,
--            tambah kolom, update RLS policies
-- ============================================================

BEGIN;

-- ── 1. RENAME TABLE ─────────────────────────────────────────
-- PostgreSQL otomatis update FK references (reviews, favorites, dll)
ALTER TABLE IF EXISTS umkm RENAME TO places;

-- Rename indexes
ALTER INDEX IF EXISTS umkm_category_idx RENAME TO places_category_idx;
ALTER INDEX IF EXISTS umkm_price_range_idx RENAME TO places_price_range_idx;
ALTER INDEX IF EXISTS umkm_owner_id_idx RENAME TO places_owner_id_idx;
ALTER INDEX IF EXISTS umkm_verification_status_idx RENAME TO places_verification_status_idx;

-- Rename constraint
ALTER INDEX IF EXISTS price_range_valid RENAME TO places_price_range_valid;

-- ── 2. UPDATE FOREIGN KEY CONSTRAINT NAMES ──────────────────
-- reviews table references places.id now (auto-updated by PG)
-- Explicitly rename constraint for clarity
ALTER TABLE IF EXISTS reviews
  RENAME CONSTRAINT reviews_umkm_id_fkey TO reviews_place_id_fkey;

-- ── 3. ADD NEW COLUMNS ─────────────────────────────────────
-- Kolom yang sudah ada: id, nama_tempat, alamat, deskripsi, gambar_url,
--   image_urls, latitude, longitude, category, min_price, max_price,
--   owner_id, is_featured, fasilitas, jam_buka, jam_tutup, nomor_telepon,
--   verification_status, rejection_reason, verified_at, verified_by, created_at
--
-- Kolom yang PERLU ditambah:

-- Rating rata-rata (cache, biar gak perlu hitung tiap kali)
ALTER TABLE IF EXISTS places
  ADD COLUMN IF NOT EXISTS rating_cache FLOAT8 DEFAULT 0;

-- Total review count (cache)
ALTER TABLE IF EXISTS places
  ADD COLUMN IF NOT EXISTS review_count INTEGER DEFAULT 0;

-- Website / sosial media
ALTER TABLE IF EXISTS places
  ADD COLUMN IF NOT EXISTS website TEXT;

-- Harga dalam teks (untuk tempat yang gak punya range angka)
ALTER TABLE IF EXISTS places
  ADD COLUMN IF NOT EXISTS harga_teks TEXT;

-- Featured image (gambar_url sudah ada sebagai legacy, kita pakai image_urls[0])
-- Yang penting: update sequence name
ALTER SEQUENCE IF EXISTS umkm_id_seq RENAME TO places_id_seq;

-- ── 4. UPDATE RLS POLICIES ─────────────────────────────────
-- Drop old policies on places (formerly umkm)
DROP POLICY IF EXISTS "umkm_select_public" ON places;
DROP POLICY IF EXISTS "umkm_insert_auth" ON places;
DROP POLICY IF EXISTS "umkm_update_owner" ON places;
DROP POLICY IF EXISTS "umkm_delete_superadmin" ON places;
DROP POLICY IF EXISTS "umkm_update_superadmin" ON places;

-- Pastikan RLS aktif
ALTER TABLE places ENABLE ROW LEVEL SECURITY;

-- Policy: semua orang bisa baca places yang verified (untuk home screen)
CREATE POLICY "places_select_verified"
  ON places FOR SELECT
  USING (
    verification_status = 'verified'
    OR owner_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role IN ('superadmin')
    )
  );

-- Policy: user login bisa insert (jadi mitra/owner)
CREATE POLICY "places_insert_auth"
  ON places FOR INSERT
  WITH CHECK (auth.uid() IS NOT NULL);

-- Policy: owner bisa update tempat miliknya sendiri
CREATE POLICY "places_update_owner"
  ON places FOR UPDATE
  USING (owner_id = auth.uid())
  WITH CHECK (owner_id = auth.uid());

-- Policy: superadmin bisa update semua places
CREATE POLICY "places_update_superadmin"
  ON places FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'superadmin'
    )
  );

-- Policy: superadmin bisa delete
CREATE POLICY "places_delete_superadmin"
  ON places FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'superadmin'
    )
  );

-- Policy: owner bisa delete tempat miliknya sendiri
CREATE POLICY "places_delete_owner"
  ON places FOR DELETE
  USING (owner_id = auth.uid());

-- ── 5. UPDATE KATEGORI TABLE ──────────────────────────────
-- Hapus kategori lama yang gak dipake lagi
DELETE FROM kategori WHERE nama IN ('Warung', 'Toko', 'Restoran', 'Bakery', 'Fashion', 'Elektronik', 'Farmasi', 'Kecantikan');

-- Insert kategori POI baru (ON CONFLICT DO NOTHING biar aman)
INSERT INTO kategori (nama, emoji, deskripsi) VALUES
  ('Cafe', '☕', 'Kafe dan tempat ngopi'),
  ('Tempat Nongkrong', '🛋️', 'Tempat hangout dan bersantai'),
  ('Wisata', '🏖️', 'Tempat wisata dan destinasi'),
  ('Kuliner', '🍽️', 'Tempat makan dan kuliner'),
  ('Hotel', '🏨', 'Hotel dan penginapan'),
  ('Oleh-Oleh', '🎁', 'Pusat oleh-oleh dan souvenir'),
  ('UMKM', '🏪', 'Usaha Mikro Kecil Menengah'),
  ('Lainnya', '📍', 'Kategori lainnya')
ON CONFLICT (nama) DO NOTHING;

-- ── 6. UPDATE REVIEWS RLS (jika ada reference ke umkm) ────
-- Reviews sudah auto-update karena FK by OID
-- Tapi nama policy mungkin masih pake umkm, update aja
DROP POLICY IF EXISTS "reviews_select_public" ON reviews;
DROP POLICY IF EXISTS "reviews_insert_own" ON reviews;
DROP POLICY IF EXISTS "reviews_update_own" ON reviews;
DROP POLICY IF EXISTS "reviews_delete_own" ON reviews;

CREATE POLICY "reviews_select_public"
  ON reviews FOR SELECT
  USING (true);

CREATE POLICY "reviews_insert_own"
  ON reviews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reviews_update_own"
  ON reviews FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "reviews_delete_own"
  ON reviews FOR DELETE
  USING (auth.uid() = user_id);

-- ── 7. OTOMATIS SET VERIFICATION STATUS ────────────────────
-- Trigger: user biasa → pending, owner/admin → verified
-- Mencegah user mengaku verified di insert

CREATE OR REPLACE FUNCTION set_place_verification_status()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM profiles
    WHERE id = auth.uid()
      AND role IN ('owner', 'superadmin')
  ) THEN
    NEW.verification_status := 'verified';
    NEW.verified_at := NOW();
    NEW.verified_by := auth.uid();
  ELSE
    NEW.verification_status := 'pending';
    NEW.verified_at := NULL;
    NEW.verified_by := NULL;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_set_place_verification ON places;
CREATE TRIGGER trg_set_place_verification
  BEFORE INSERT ON places
  FOR EACH ROW
  EXECUTE FUNCTION set_place_verification_status();

-- ── 8. UPDATE TABLE ROLES ─────────────────────────────────
-- Update profiles check constraint (pake 'owner' bukan 'mitra')
ALTER TABLE profiles
  DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE profiles
  ADD CONSTRAINT profiles_role_check
  CHECK (role IN ('user', 'owner', 'superadmin'));

-- Jangan rename owner → mitra, biarkan owner di kode

COMMIT;

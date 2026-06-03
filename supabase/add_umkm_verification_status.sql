-- ============================================================
-- Migration: Add verification status to UMKM table
-- Deskripsi: Menambahkan field untuk tracking status verifikasi UMKM
-- ============================================================

-- Tambahkan kolom status verifikasi (pending, verified, rejected)
ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'pending'
  CHECK (verification_status IN ('pending', 'verified', 'rejected'));

-- Tambahkan kolom untuk alasan penolakan
ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- Tambahkan kolom verified_at untuk track kapan di-approve
ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;

-- Tambahkan kolom verified_by untuk track siapa yang verify
ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS verified_by UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- Create index untuk query UMKM yang verified
CREATE INDEX IF NOT EXISTS umkm_verification_status_idx
  ON umkm (verification_status);

-- Default existing UMKM ke verified (agar tidak break existing data)
UPDATE umkm
SET verification_status = 'verified', verified_at = NOW()
WHERE verification_status = 'pending' AND created_at < NOW() - INTERVAL '1 day';

-- ── ROW LEVEL SECURITY ──────────────────────────────────────
-- Update policy untuk user hanya bisa lihat verified UMKM (di home_screen)
-- Tapi owner bisa lihat UMKM miliknya sendiri (dalam list manage)

-- Existing policy untuk select, tambahkan kondisi verified
-- DROP POLICY IF EXISTS "umkm_select_public" ON umkm;
-- CREATE POLICY "umkm_select_public"
--   ON umkm FOR SELECT
--   USING (
--     verification_status = 'verified'
--     OR owner_id = auth.uid()  -- Owner bisa lihat UMKM miliknya
--   );

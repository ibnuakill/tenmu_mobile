-- ============================================================
-- Migration: Add role request fields to profiles
-- Deskripsi: Menambahkan kolom untuk request role (owner) di profiles
-- ============================================================

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS requested_role TEXT;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS request_message TEXT;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS request_status TEXT DEFAULT NULL;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS request_created_at TIMESTAMPTZ;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS request_handled_by UUID REFERENCES profiles(id) ON DELETE SET NULL;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS request_handled_at TIMESTAMPTZ;

-- Optional: index untuk request_status
CREATE INDEX IF NOT EXISTS profiles_request_status_idx ON profiles (request_status);

-- Policy: anyone can update their own profile to submit request (we rely on auth)
-- Admin will approve via UI by updating 'role' and setting request_status to 'approved' or 'rejected'.

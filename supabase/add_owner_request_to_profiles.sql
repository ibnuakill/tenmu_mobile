-- ============================================================
-- Migration: Add owner request fields to profiles
-- Deskripsi: Menambahkan kolom untuk pengajuan role owner/UMKM pada tabel profiles
-- Error Fix: column profiles.owner_request_status does not exist (42703)
-- ============================================================

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS owner_request_status TEXT DEFAULT NULL;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS owner_request_nama_umkm TEXT;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS owner_request_alamat TEXT;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS owner_request_phone TEXT;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS owner_request_note TEXT;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS owner_requested_at TIMESTAMPTZ;

ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS owner_request_rejection TEXT;

-- Index untuk mempercepat query admin saat memfilter status pending
CREATE INDEX IF NOT EXISTS profiles_owner_request_status_idx 
ON profiles (owner_request_status);

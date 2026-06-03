-- Migration: tambah role owner/superadmin dan relasi pemilik UMKM
-- Jalankan di Supabase SQL Editor

-- 1. Pastikan kolom role ada di profiles
ALTER TABLE IF EXISTS profiles
ADD COLUMN IF NOT EXISTS role TEXT DEFAULT 'user';

-- 2. Normalisasi role lama admin menjadi superadmin
UPDATE profiles
SET role = 'superadmin'
WHERE lower(coalesce(role, '')) = 'admin';

-- 3. Pastikan nilai role valid
ALTER TABLE profiles
DROP CONSTRAINT IF EXISTS profiles_role_check;

ALTER TABLE profiles
ADD CONSTRAINT profiles_role_check
CHECK (role IN ('user', 'owner', 'superadmin'));

-- 4. Tambahkan relasi pemilik ke tabel umkm
ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS owner_id UUID REFERENCES profiles(id) ON DELETE SET NULL;

-- 5. Kaitkan data UMKM lama ke superadmin yang ada bila memungkinkan
UPDATE umkm
SET owner_id = (
  SELECT id
  FROM profiles
  WHERE role = 'superadmin'
  ORDER BY created_at NULLS LAST
  LIMIT 1
)
WHERE owner_id IS NULL;

CREATE INDEX IF NOT EXISTS umkm_owner_id_idx ON umkm(owner_id);

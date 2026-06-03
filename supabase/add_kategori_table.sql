-- ============================================================
-- Migration: Create kategori table
-- Deskripsi: Tabel untuk manage kategori UMKM secara dinamis
-- ============================================================

-- Create tabel kategori
CREATE TABLE IF NOT EXISTS kategori (
  id BIGSERIAL PRIMARY KEY,
  nama TEXT NOT NULL UNIQUE,
  emoji TEXT DEFAULT '📍',
  deskripsi TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Insert data kategori default
INSERT INTO kategori (nama, emoji, deskripsi) VALUES
  ('Cafe', '☕', 'Tempat minum kopi dan minuman'),
  ('Warung', '🍜', 'Warung makan tradisional'),
  ('Toko', '🏪', 'Toko retail'),
  ('Restoran', '🍽️', 'Restoran'),
  ('Bakery', '🥐', 'Toko roti dan kue'),
  ('Fashion', '👗', 'Toko pakaian dan aksesori'),
  ('Elektronik', '📱', 'Toko elektronik'),
  ('Farmasi', '💊', 'Apotek dan toko obat'),
  ('Kecantikan', '💄', 'Salon dan toko kecantikan'),
  ('Lainnya', '📍', 'Kategori lainnya')
ON CONFLICT (nama) DO NOTHING;

-- Create index untuk search kategori
CREATE INDEX IF NOT EXISTS kategori_nama_idx ON kategori (nama);

-- ── ROW LEVEL SECURITY ──────────────────────────────────────
ALTER TABLE kategori ENABLE ROW LEVEL SECURITY;

-- Siapa saja bisa READ kategori
CREATE POLICY "kategori_select_public"
  ON kategori FOR SELECT
  USING (true);

-- Hanya superadmin yang bisa CREATE/UPDATE/DELETE kategori
CREATE POLICY "kategori_insert_superadmin"
  ON kategori FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'superadmin'
    )
  );

CREATE POLICY "kategori_update_superadmin"
  ON kategori FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'superadmin'
    )
  );

CREATE POLICY "kategori_delete_superadmin"
  ON kategori FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE profiles.id = auth.uid()
      AND profiles.role = 'superadmin'
    )
  );

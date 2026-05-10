-- ============================================================
-- Migration: Add category and price fields to UMKM table
-- Deskripsi: Menambahkan field kategori dan rentang harga ke tabel UMKM
-- ============================================================

-- Tambah kolom category (Cafe, Warung, Toko, Restoran, dll)
ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'Lainnya';

-- Tambah kolom min_price (harga minimum dari produk/layanan UMKM)
ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS min_price INTEGER DEFAULT 0;

-- Tambah kolom max_price (harga maksimum dari produk/layanan UMKM)
ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS max_price INTEGER DEFAULT 100000;

-- Buat index untuk kategori agar query lebih cepat
CREATE INDEX IF NOT EXISTS umkm_category_idx
  ON umkm (category);

-- Buat index untuk price range agar query filtering harga lebih cepat
CREATE INDEX IF NOT EXISTS umkm_price_range_idx
  ON umkm (min_price, max_price);

-- Optional: Buat check constraint untuk validasi harga
ALTER TABLE umkm
ADD CONSTRAINT price_range_valid
  CHECK (max_price >= min_price AND min_price >= 0);

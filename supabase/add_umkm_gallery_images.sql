-- Migration: Add gallery images to UMKM
-- Deskripsi: Menambahkan kolom image_urls agar 1 UMKM bisa punya beberapa foto

ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS image_urls JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Sinkronkan data lama supaya gambar_url lama tetap masuk ke galeri
UPDATE umkm
SET image_urls = jsonb_build_array(gambar_url)
WHERE gambar_url IS NOT NULL
  AND gambar_url <> ''
  AND (image_urls IS NULL OR image_urls = '[]'::jsonb);

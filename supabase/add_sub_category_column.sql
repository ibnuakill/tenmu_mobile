-- ⚠ DEPRECATED: migrasi lama (kategori 8 sektor / sub-kategori).
-- Sudah digantikan oleh supabase/migrate_to_5_sectors.sql + drop_sub_category.sql.
-- Jangan dijalankan ulang.
-- ============================================================
-- Migration: Add sub_category column to places table
-- Deskripsi: Menambahkan field sub_category untuk kategori
--            dua level (Kategori > Sub-kategori)
-- ============================================================

-- 1. Tambah kolom sub_category ke tabel places
ALTER TABLE IF EXISTS places
  ADD COLUMN IF NOT EXISTS sub_category TEXT;

-- 2. Index untuk sub_category (filter cepat)
CREATE INDEX IF NOT EXISTS places_sub_category_idx
  ON places (sub_category);

-- 3. Index gabungan kategori + sub_category
CREATE INDEX IF NOT EXISTS places_category_subcategory_idx
  ON places (category, sub_category);

-- 4. Recreate view places_with_ratings supaya sertakan sub_category
--    (DROP + CREATE, bukan CREATE OR REPLACE, karena tidak boleh
--     ganti nama/urutan kolom view yang sudah ada)
DROP VIEW IF EXISTS public.places_with_ratings CASCADE;
CREATE VIEW public.places_with_ratings
WITH (security_invoker = true) AS
SELECT
  p.id,
  p.nama_tempat,
  p.alamat,
  p.deskripsi,
  p.gambar_url,
  p.image_urls,
  p.category,
  p.sub_category,
  p.min_price,
  p.max_price,
  p.latitude,
  p.longitude,
  p.is_featured,
  p.fasilitas,
  p.jam_buka,
  p.jam_tutup,
  p.nomor_telepon,
  p.website,
  p.harga_teks,
  p.verification_status,
  p.created_at,
  COALESCE(ROUND(AVG(r.rating)::numeric, 2), 0)::float8 AS avg_rating,
  COUNT(r.id)::int AS review_count
FROM public.places p
LEFT JOIN public.reviews r ON r.umkm_id = p.id
GROUP BY p.id;

-- 5. Grant access
GRANT SELECT ON public.places_with_ratings TO anon;
GRANT SELECT ON public.places_with_ratings TO authenticated;

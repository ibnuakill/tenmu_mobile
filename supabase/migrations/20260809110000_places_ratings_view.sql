-- View: places_with_ratings
-- Menghitung rata-rata rating & jumlah review langsung di Postgres.
-- Menggantikan pola lama: fetch seluruh tabel `reviews` lalu hitung rata-rata di client
-- (O(N) reviews per fetch per user — tidak skala untuk user banyak).

CREATE OR REPLACE VIEW public.places_with_ratings
WITH (security_invoker = true) AS
SELECT
  p.id,
  p.nama_tempat,
  p.alamat,
  p.deskripsi,
  p.gambar_url,
  p.image_urls,
  p.category,
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

-- Index pendukung: join reviews->places dan filter verification_status
CREATE INDEX IF NOT EXISTS idx_reviews_umkm_id ON public.reviews (umkm_id);
CREATE INDEX IF NOT EXISTS idx_places_verification_status ON public.places (verification_status);

-- Akses untuk role anon & authenticated (RLS view mengikuti tabel dasar;
-- pastikan SELECT policy pada `places` sudah mengizinkan baca verified rows).
GRANT SELECT ON public.places_with_ratings TO anon;
GRANT SELECT ON public.places_with_ratings TO authenticated;

-- ============================================================
-- Hapus data non-UMKM (scope app = UMKM only)
-- 34 row: uidang 2026-10-21, category lama 'Wisata & Budaya' +
-- 'Penginapan & Hotel' (isinya Mostly masjid & hotel).
-- Backup penuh dulu supaya masih bisa dibalikin.
-- ============================================================

-- 1. Backup penuh 34 row (bisa di-restore kapan saja)
DROP TABLE IF EXISTS public.places_full_backup_20261021;
CREATE TABLE public.places_full_backup_20261021 AS
SELECT * FROM public.places WHERE verification_status = 'rejected';

-- 2. Hapus baris anak dulu (review / favorit / post) supaya nggak ada yatim
DELETE FROM public.reviews
WHERE umkm_id IN (SELECT id FROM places WHERE verification_status = 'rejected');

DELETE FROM public.favorites
WHERE umkm_id IN (SELECT id FROM places WHERE verification_status = 'rejected');

DELETE FROM public.place_posts
WHERE place_id IN (SELECT id FROM places WHERE verification_status = 'rejected');

DELETE FROM public.place_videos
WHERE place_id IN (SELECT id FROM places WHERE verification_status = 'rejected');

-- 3. Hapus 34 row non-UMKM
DELETE FROM public.places WHERE verification_status = 'rejected';

-- 4. Verifikasi
SELECT category,
       coalesce(sub_category, '(tanpa sub-kategori)') AS sub,
       verification_status,
       count(*) AS n
FROM public.places
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

SELECT count(*) AS total_tempat FROM public.places;
SELECT count(*) AS backup_rows FROM public.places_full_backup_20261021;

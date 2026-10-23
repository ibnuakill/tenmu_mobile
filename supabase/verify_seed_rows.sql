-- ============================================================
-- Verifikasi 12 row pending biar list app lebih berisi
-- 2026-10-21. Dipilih: 2 row punya gambar sungguhan, sisanya
-- menutup sektor yang tadinya kosong. Row tanpa gambar tetap
-- is_featured = false supaya carousel utama bersih.
-- 2026-10-22: sub-kategori dihapus → query verifikasi disederhanakan.
-- ============================================================

-- 1. Perbaiki deskripsi test
UPDATE public.places
SET    deskripsi = 'Kedai empal gentong khas Cirebon di Jalan Insinyur Haji Juanda, Pilangsari, Kabupaten Cirebon. Menyajikan empal gentong khas yang lembut dan gurih.'
WHERE id = 86;

-- 2. Verifikasi 12 row
UPDATE public.places
SET verification_status = 'verified',
    verified_at = now(),
    verified_by = (SELECT id FROM profiles WHERE role = 'superadmin' LIMIT 1)
WHERE id IN (86, 106, 123, 166, 119, 176, 127, 136, 134, 99, 100, 150);

-- 3. Row tanpa gambar jangan jadi featured (carousel utama tetap rapi)
UPDATE public.places
SET is_featured = false
WHERE id IN (123, 166, 119, 176, 127, 136, 134, 99, 100, 150);

-- 4. Verifikasi
SELECT category,
       count(*) FILTER (WHERE verification_status = 'verified') AS verified,
       count(*) FILTER (WHERE verification_status = 'pending')  AS pending
FROM public.places
GROUP BY 1
ORDER BY 1;

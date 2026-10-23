-- ⚠ DEPRECATED: migrasi lama (kategori 8 sektor / sub-kategori).
-- Sudah digantikan oleh supabase/migrate_to_5_sectors.sql + drop_sub_category.sql.
-- Jangan dijalankan ulang.
-- ============================================================
-- Migration: pemetaan kategori 2-level + scope UMKM
-- Tanggal: 2026-10-21
-- Context: app dipersempit ke scope UMKM. Kategori lama (6 nama)
-- di-map ke 8 sektor baru, dan tiap row dapat sub-kategori
-- yang sesuai jenis usahanya (bukan asal dibuang ke 'Lainnya').
-- ============================================================

-- 1. Backup nilai lama (biar bisa di-rollback 1 query)
DROP TABLE IF EXISTS public.places_category_backup_20261021;
CREATE TABLE public.places_category_backup_20261021 AS
SELECT id,
       nama_tempat,
       category       AS old_category,
       COALESCE(sub_category, '') AS old_sub_category,
       verification_status AS old_status
FROM public.places;

-- 2. Scope UMKM:_non-UMKM disembunyikan dari app user.
--    RPC get_places_paged hanya mengambil verification_status='verified'.
--    Row non-UMKM -> 'rejected' (tidak muncul di app, masih kelihatan di panel admin).
UPDATE public.places
SET verification_status = 'rejected'
WHERE category IN ('Wisata & Budaya', 'Penginapan & Hotel');

-- 3. Mapping per-row: sektor + sub-kategori
WITH m(id, cat, sub) AS (
  VALUES
    -- ############ JASA & LAYANAN ############
    (95,  'Jasa & Servis', 'Laundry'),
    (96,  'Jasa & Servis', 'Laundry'),
    -- ############ KULINER & CAFE ############
    (6,   'Kuliner', 'Rumah Makan'),
    (9,   'Kuliner', 'Kafe & Warkop'),
    (84,  'Kuliner', 'Kafe & Warkop'),
    (85,  'Kuliner', 'Jajanan Pasar'),
    (103, 'Kuliner', 'Jajanan Pasar'),
    (113, 'Kuliner', 'Jajanan Pasar'),
    (114, 'Kuliner', 'Jajanan Pasar'),
    -- ############ OLEH-OLEH & KERJINAN ############
    (69,  'Kriya & Kerajinan Tangan', 'Batik & Tenun Lokal'),
    (99,  'Kriya & Kerajinan Tangan', 'Anyaman'),
    (105, 'Kriya & Kerajinan Tangan', 'Anyaman'),
    (111, 'Kriya & Kerajinan Tangan', 'Batik & Tenun Lokal'),
    -- ############ PERTOKOAN & UMKM ############
    (86,  'Kuliner', 'Jajanan Pasar'),
    (93,  'Kriya & Kerajinan Tangan', 'Souvenir'),
    (94,  'Kelontong & Ritel Mini', 'Warung Sembako'),
    (97,  'Kecantikan & Kesehatan', 'Klinik Kecantikan'),
    (100, 'Kriya & Kerajinan Tangan', 'Souvenir'),
    (102, 'Kelontong & Ritel Mini', 'Warung Sembako'),
    (104, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (106, 'Kelontong & Ritel Mini', 'Warung Sembako'),
    (107, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (109, 'Kelontong & Ritel Mini', 'Warung Sembako'),
    (110, 'Kelontong & Ritel Mini', 'Warung Sembako'),
    (115, 'Kriya & Kerajinan Tangan', 'Souvenir'),
    (117, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (118, 'Kuliner', 'Jajanan Pasar'),
    (119, 'Agribisnis & Peternakan', 'Daging & Ikan Segar'),
    (120, 'Kecantikan & Kesehatan', 'Klinik Kecantikan'),
    (121, 'Kuliner', 'Jajanan Pasar'),
    (122, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (123, 'Kelontong & Ritel Mini', 'Agen Pulsa & PPOB'),
    (124, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (125, 'Kelontong & Ritel Mini', 'Agen Pulsa & PPOB'),
    (126, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (127, 'Kecantikan & Kesehatan', 'Salon & Barbershop'),
    (128, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (129, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (130, 'Kuliner', 'Jajanan Pasar'),
    (131, 'Kuliner', 'Jajanan Pasar'),
    (132, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (133, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (134, 'Kecantikan & Kesehatan', 'Klinik Kecantikan'),
    (135, 'Kelontong & Ritel Mini', 'Warung Sembako'),
    (136, 'Kecantikan & Kesehatan', 'Salon & Barbershop'),
    (137, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (138, 'Kecantikan & Kesehatan', 'Salon & Barbershop'),
    (139, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (140, 'Kuliner', 'Jajanan Pasar'),
    (141, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (142, 'Jasa & Servis', 'Pengiriman & Logistik Lokal'),
    (143, 'Kecantikan & Kesehatan', 'Salon & Barbershop'),
    (144, 'Kecantikan & Kesehatan', 'Salon & Barbershop'),
    (145, 'Kuliner', 'Jajanan Pasar'),
    (146, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (147, 'Kecantikan & Kesehatan', 'Klinik Kecantikan'),
    (148, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (149, 'Kuliner', 'Rumah Makan'),
    (150, 'Jasa & Servis', 'Jasa Fotografi'),
    (151, 'Jasa & Servis', 'Jasa Fotografi'),
    (152, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (153, 'Kriya & Kerajinan Tangan', 'Batik & Tenun Lokal'),
    (154, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (155, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (156, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (157, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (159, 'Kuliner', 'Jajanan Pasar'),
    (160, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (161, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (164, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (165, 'Kuliner', 'Rumah Makan'),
    (166, 'Fashion & Pakaian', 'Konveksi / Penjahit'),
    (167, 'Kuliner', 'Rumah Makan'),
    (168, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (169, 'Jasa & Servis', 'Bengkel Kendaraan'),
    (170, 'Kecantikan & Kesehatan', 'Kosmetik & Skincare'),
    (171, 'Kelontong & Ritel Mini', 'Toko Kelontong'),
    (172, 'Jasa & Servis', 'Jasa Fotografi'),
    (173, 'Kelontong & Ritel Mini', 'Toko Mainan'),
    (174, 'Kuliner', 'Rumah Makan'),
    (175, 'Kuliner', 'Jajanan Pasar'),
    (176, 'Agribisnis & Peternakan', 'Sayur Organik')
)
UPDATE public.places p
SET category     = m.cat,
    sub_category = m.sub
FROM m
WHERE p.id = m.id;

-- 4. Fallback: row yang belum ter-mapping (nama kategori lama)
--    -> 'Lainnya' + sub-kategori null
UPDATE public.places
SET category     = 'Lainnya',
    sub_category = NULL
WHERE category NOT IN ('Kuliner', 'Fashion & Pakaian', 'Kecantikan & Kesehatan',
                       'Kriya & Kerajinan Tangan', 'Kelontong & Ritel Mini',
                       'Jasa & Servis', 'Agribisnis & Peternakan',
                       'Elektronik & Gadget', 'Lainnya');

-- 5. Sanity: sub_category harus milik kategorinya, kalau tidak -> null
UPDATE public.places
SET sub_category = NULL
WHERE sub_category IS NOT NULL
  AND (category, sub_category) NOT IN (
    ('Kuliner','Rumah Makan'), ('Kuliner','Kafe & Warkop'), ('Kuliner','Jajanan Pasar'),
    ('Kuliner','Katering'), ('Kuliner','Frozen Food'), ('Kuliner','Bahan Pokok'),
    ('Fashion & Pakaian','Pakaian Pria & Wanita'), ('Fashion & Pakaian','Hijab & Busana Muslim'),
    ('Fashion & Pakaian','Sepatu & Sandal'), ('Fashion & Pakaian','Tas & Aksesoris'),
    ('Fashion & Pakaian','Konveksi / Penjahit'),
    ('Kecantikan & Kesehatan','Kosmetik & Skincare'), ('Kecantikan & Kesehatan','Salon & Barbershop'),
    ('Kecantikan & Kesehatan','Apotek Mandiri'), ('Kecantikan & Kesehatan','Jamu Tradisional'),
    ('Kecantikan & Kesehatan','Klinik Kecantikan'),
    ('Kriya & Kerajinan Tangan','Souvenir'), ('Kriya & Kerajinan Tangan','Anyaman'),
    ('Kriya & Kerajinan Tangan','Batik & Tenun Lokal'), ('Kriya & Kerajinan Tangan','Dekorasi Rumah'),
    ('Kriya & Kerajinan Tangan','Gerabah & Keramik'),
    ('Kelontong & Ritel Mini','Toko Kelontong'), ('Kelontong & Ritel Mini','Warung Sembako'),
    ('Kelontong & Ritel Mini','Agen Pulsa & PPOB'), ('Kelontong & Ritel Mini','Toko Mainan'),
    ('Jasa & Servis','Laundry'), ('Jasa & Servis','Bengkel Kendaraan'),
    ('Jasa & Servis','Jasa Fotografi'), ('Jasa & Servis','Pengiriman & Logistik Lokal'),
    ('Jasa & Servis','Les Privat'),
    ('Agribisnis & Peternakan','Toko Tanaman & Pupuk'), ('Agribisnis & Peternakan','Daging & Ikan Segar'),
    ('Agribisnis & Peternakan','Sayur Organik'), ('Agribisnis & Peternakan','Peternakan Lokal'),
    ('Elektronik & Gadget','Servis HP & Laptop'), ('Elektronik & Gadget','Aksesoris Gadget'),
    ('Elektronik & Gadget','Elektronik Rumah Tangga Kecil')
  );

-- 6. Verifikasi
SELECT category,
       COALESCE(sub_category, '(null)') AS sub_category,
       verification_status,
       count(*) AS n
FROM public.places
GROUP BY 1,2,3
ORDER BY 3, 1, 2;

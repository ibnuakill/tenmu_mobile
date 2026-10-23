-- =============================================================================
-- Seed data — kategori POI (referensi)
-- 5 sektor universal UMKM. Idempoten: ON CONFLICT (nama) DO NOTHING.
-- Tidak berisi data user / credential apa pun.
-- =============================================================================

INSERT INTO public.kategori (nama, emoji, deskripsi)
VALUES
  ('Kuliner (Makanan & Olahan)',        '🍽️', 'Usaha makanan dan olahan: rumah makan, kafe, jajanan pasar, katering, frozen food.'),
  ('Kerajinan & Manufaktur Tradisional', '🎨', 'Batik, tenun, anyaman, gerabah, meubel, konveksi dan kerajinan tangan khas Cirebon.'),
  ('Perdagangan & Retail',               '🏪', 'Warung, toko, pasar dan penjualan barang: kelontong, elektronik, pakaian, aksesoris.'),
  ('Agribisnis',                         '🌾', 'Pertanian, perikanan dan peternakan: sayur organik, daging dan ikan segar, tanaman dan ternak lokal.'),
  ('Jasa',                               '🔧', 'Layanan harian: bengkel, laundry, pengiriman, fotografi, beauty care dan kesehatan.')
ON CONFLICT (nama) DO NOTHING;
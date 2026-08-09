-- =============================================================================
-- Seed data — kategori POI (referensi)
-- Idempoten: menggunakan INSERT ... ON CONFLICT (nama) DO NOTHING.
-- Tidak berisi data user / credential apa pun.
-- =============================================================================

INSERT INTO public.kategori (nama, emoji, deskripsi)
VALUES
  ('Wisata & Budaya',        '🏰', 'Tempat wisata, budaya, dan situs sejarah'),
  ('Kuliner & Cafe',         '🍜', 'Restoran, warung, cafe, dan destinasi kuliner lainnya'),
  ('Oleh-oleh & Kerajinan',  '🛍️', 'Toko oleh-oleh, gerai kerajinan, batik, rotan, gerabah'),
  ('Penginapan & Hotel',     '🏨', 'Hotel, villa, homestay, guest house, dan penginapan'),
  ('Pertokoan & UMKM',       '🛒', 'Toko, kios, dan unit usaha mikro, kecil, dan menengah'),
  ('Jasa & Layanan',         '🔧', 'Jasa perbaikan, layanan publik, servis dan lainnya'),
  ('Lainnya',                '✨', 'Kategori lainnya yang tidak termasuk kategori umum')
ON CONFLICT (nama) DO NOTHING;
-- ═══════════════════════════════════════════════════════════════════
-- Migrasi: padatkan 8 kategori menjadi 5 sektor universal
-- Sumber: "14 jenis UMKM Kabupaten Cirebon" -> 5 sektor utama
--   1. Kuliner (Makanan & Olahan)
--   2. Kerajinan & Manufaktur Tradisional
--   3. Perdagangan & Retail
--   4. Agribisnis
--   5. Jasa
-- Sub-kategori (15) dibuang: app sekarang hanya 5 kategori.
-- ═══════════════════════════════════════════════════════════════════

-- 1. Backup data sebelum diubah
create table if not exists places_backup_5sektor_20261022 as
select * from public.places;

create table if not exists kategori_backup_5sektor_20261022 as
select * from public.kategori;

-- 2. Mapping kategori lama -> sektor baru, dipecah per sub-kategori
--    (Fashion & Pakaian + Elektronik & Gadget campur barang & jasa)
create or replace function public.map_to_5_sektor(cat text, sub text)
returns text
language sql
immutable
as $$
  select case
    -- 1. Kuliner (Makanan & Olahan)
    when cat = 'Kuliner' and sub in (
      'Rumah Makan', 'Kafe & Warkop', 'Jajanan Pasar', 'Katering', 'Frozen Food'
    ) then 'Kuliner (Makanan & Olahan)'
    when cat = 'Kuliner' then 'Kuliner (Makanan & Olahan)'

    -- 2. Kerajinan & Manufaktur Tradisional
    when cat = 'Kriya & Kerajinan Tangan' then 'Kerajinan & Manufaktur Tradisional'
    when cat = 'Fashion & Pakaian' and sub = 'Konveksi / Penjahit'
      then 'Kerajinan & Manufaktur Tradisional'
    when cat = 'Fashion & Pakaian' and sub in (
      'Dekorasi Rumah', 'Gerabah & Keramik', 'Batik & Tenun Lokal', 'Anyaman', 'Souvenir'
    ) then 'Kerajinan & Manufaktur Tradisional'

    -- 3. Perdagangan & Retail
    when cat = 'Kelontong & Ritel Mini' then 'Perdagangan & Retail'
    when cat = 'Fashion & Pakaian' then 'Perdagangan & Retail'
    when cat = 'Elektronik & Gadget' and sub in (
      'Aksesoris Gadget', 'Elektronik Rumah Tangga Kecil', 'Toko HP & Konter'
    ) then 'Perdagangan & Retail'
    when cat = 'Elektronik & Gadget' and sub = 'Servis HP & Laptop'
      then 'Jasa'
    when cat = 'Elektronik & Gadget' then 'Perdagangan & Retail'

    -- 4. Agribisnis
    when cat = 'Agribisnis & Peternakan' then 'Agribisnis'

    -- 5. Jasa
    when cat = 'Jasa & Servis' then 'Jasa'
    when cat = 'Kecantikan & Kesehatan' then 'Jasa'

    else 'Perdagangan & Retail'
  end;
$$;

-- 3. Terapkan ke places: category -> sektor, sub_category dibuang
update public.places
set
  category = public.map_to_5_sektor(category, sub_category),
  sub_category = null
where category is distinct from public.map_to_5_sektor(category, sub_category)
   or sub_category is not null;

-- 4. Samakan tabel kategori (menu Admin) -> 5 sektor
delete from public.kategori;

insert into public.kategori (nama, emoji, deskripsi) values
  ('Kuliner (Makanan & Olahan)', '🍽️',
   'Usaha makanan dan olahan: rumah makan, kafe, jajanan pasar, katering, frozen food.'),
  ('Kerajinan & Manufaktur Tradisional', '🎨',
   'Batik, tenun, anyaman, gerabah, meubel, koneksi dan kerajinan tangan khas Cirebon.'),
  ('Perdagangan & Retail', '🏪',
   'Warung, toko, pasar dan penjualan barang: kelontong, elektronik, pakaian, aksesoris.'),
  ('Agribisnis', '🌾',
   'Pertanian, perikanan dan peternakan: sayur organik, daging dan ikan segar, tanaman dan ternak lokal.'),
  ('Jasa', '🔧',
   'Layanan harian: bengkel, laundry, pengiriman, fotografi, beauty care dan kesehatan.');

-- 5. RPC: sub-kategori dihapus dari signature & query
--    Struktur asli (view places_with_ratings + haversine_distance) dipertahankan.
drop function if exists public.get_places_paged(text, text[], text[], boolean, double precision, double precision, text, timestamp with time zone, bigint, double precision, integer);

create or replace function public.get_places_paged(
  p_search text default null,
  p_categories text[] default null,
  p_featured boolean default null,
  p_user_lat double precision default null,
  p_user_lng double precision default null,
  p_sort text default 'newest',
  p_cursor_created_at timestamp with time zone default null,
  p_cursor_id bigint default null,
  p_cursor_value double precision default null,
  p_page_size integer default 30
)
returns setof public.places_with_ratings
language plpgsql
as $function$
declare
  v_limit integer := greatest(p_page_size, 1) + 1;
begin
  if p_sort = 'distance' then
    return query
      select v.*
      from public.places_with_ratings v
      where v.verification_status = 'verified'
        and (p_search is null
             or v.nama_tempat ilike '%' || p_search || '%'
             or v.alamat ilike '%' || p_search || '%')
        and (p_categories is null or v.category = any(p_categories))
        and (p_featured is null or v.is_featured = p_featured)
        and (p_cursor_created_at is null
             or haversine_distance(p_user_lat, p_user_lng,
                                   v.latitude, v.longitude) > p_cursor_value
             or (haversine_distance(p_user_lat, p_user_lng,
                                    v.latitude, v.longitude) = p_cursor_value
                 and (v.created_at < p_cursor_created_at
                      or (v.created_at = p_cursor_created_at
                          and v.id < p_cursor_id))))
      order by haversine_distance(p_user_lat, p_user_lng,
                                  v.latitude, v.longitude) asc,
               v.created_at desc, v.id desc
      limit v_limit;
  elsif p_sort = 'rating' then
    return query
      select v.*
      from public.places_with_ratings v
      where v.verification_status = 'verified'
        and (p_search is null
             or v.nama_tempat ilike '%' || p_search || '%'
             or v.alamat ilike '%' || p_search || '%')
        and (p_categories is null or v.category = any(p_categories))
        and (p_featured is null or v.is_featured = p_featured)
        and (p_cursor_created_at is null
             or v.avg_rating < p_cursor_value
             or ((v.avg_rating is not distinct from p_cursor_value)
                 and (v.created_at < p_cursor_created_at
                      or (v.created_at = p_cursor_created_at
                          and v.id < p_cursor_id))))
      order by v.avg_rating desc nulls last,
               v.created_at desc, v.id desc
      limit v_limit;
  else -- 'newest' (default)
    return query
      select v.*
      from public.places_with_ratings v
      where v.verification_status = 'verified'
        and (p_search is null
             or v.nama_tempat ilike '%' || p_search || '%'
             or v.alamat ilike '%' || p_search || '%')
        and (p_categories is null or v.category = any(p_categories))
        and (p_featured is null or v.is_featured = p_featured)
        and (p_cursor_created_at is null
             or v.created_at < p_cursor_created_at
             or (v.created_at = p_cursor_created_at
                 and v.id < p_cursor_id))
      order by v.created_at desc, v.id desc
      limit v_limit;
  end if;
end;
$function$;

-- 6. Bersihkan fungsi mapping (sudah tertanam di data)
drop function if exists public.map_to_5_sektor(text, text);


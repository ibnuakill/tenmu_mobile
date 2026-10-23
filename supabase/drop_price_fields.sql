-- =============================================================
--  Migration: buang kolom harga (min_price, max_price, harga_teks)
--  Harga tidak pernah dipakai di UI user (tidak ada filter/sort/
--  display harga). Cuma ada form edit yang mengisi — dibuang juga.
--  Backup data: places_backup_5sektor_20261022
-- =============================================================

-- 1) RPC drop dulu (return type SETOF places_with_ratings).
drop function if exists public.get_places_paged(
  p_search text,
  p_categories text[],
  p_featured boolean,
  p_user_lat double precision,
  p_user_lng double precision,
  p_sort text,
  p_cursor_created_at timestamp with time zone,
  p_cursor_id bigint,
  p_cursor_value double precision,
  p_page_size integer
);

-- 2) Constraint harga di tabel utama.
alter table public.places
  drop constraint if exists price_range_valid;

-- 3) View lama drop (kolom harga ikut hilang dari definisinya).
drop view if exists public.places_with_ratings;

-- 4) Kolom harga dibuang dari tabel utama.
alter table public.places drop column if exists min_price;
alter table public.places drop column if exists max_price;
alter table public.places drop column if exists harga_teks;

-- 5) View rebuilt tanpa kolom harga.
create view public.places_with_ratings as
  select
    p.id,
    p.nama_tempat,
    p.alamat,
    p.deskripsi,
    p.gambar_url,
    p.image_urls,
    p.category,
    p.latitude,
    p.longitude,
    p.is_featured,
    p.fasilitas,
    p.jam_buka,
    p.jam_tutup,
    p.nomor_telepon,
    p.website,
    p.verification_status,
    p.created_at,
    coalesce(round(avg(r.rating), 2), 0::numeric)::double precision as avg_rating,
    count(r.id)::integer as review_count
  from places p
  left join reviews r on r.umkm_id = p.id
  group by p.id;

-- 6) RPC rebuilt (tanpa kolom harga).
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
as $$
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
$$;

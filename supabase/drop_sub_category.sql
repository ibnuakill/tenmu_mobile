-- =============================================================
--  Migration: buang kolom places.sub_category (migrasi 5 sektor)
--  Sub-kategori sudah dibuang dari data (semua NULL) dan dari
--  aplikasi Flutter. Kolom fisik + view + RPC ikut dirapikan.
--  Backup data: places_backup_5sektor_20261022
-- =============================================================

-- 1) RPC harus drop dulu (return type-nya SETOF places_with_ratings,
--    composite type view ikut berubah kalau kolom view berubah).
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

-- 2) View: kolom sub_category dihapus.
drop view if exists public.places_with_ratings;

create view public.places_with_ratings as
  select
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
    coalesce(round(avg(r.rating), 2), 0::numeric)::double precision as avg_rating,
    count(r.id)::integer as review_count
  from places p
  left join reviews r on r.umkm_id = p.id
  group by p.id;

-- 3) Kolom fisik di tabel utama dibuang.
alter table public.places drop column if exists sub_category;

-- 4) RPC rebuilt tanpa parameter p_sub_categories.
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

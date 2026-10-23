-- ⚠ DEPRECATED: migrasi lama (kategori 8 sektor / sub-kategori).
-- Sudah digantikan oleh supabase/migrate_to_5_sectors.sql + drop_sub_category.sql.
-- Jangan dijalankan ulang.
-- ============================================================
-- Migration: Update get_places_paged RPC with sub_category filter
-- Deskripsi: Menambahkan parameter p_sub_categories untuk filter
--            dua level (Kategori > Sub-kategori)
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_places_paged(
  p_search text DEFAULT NULL,
  p_categories text[] DEFAULT NULL,
  p_sub_categories text[] DEFAULT NULL,
  p_featured boolean DEFAULT NULL,
  p_user_lat double precision DEFAULT NULL,
  p_user_lng double precision DEFAULT NULL,
  p_sort text DEFAULT 'newest',
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL,
  p_cursor_value double precision DEFAULT NULL,
  p_page_size integer DEFAULT 30
)
RETURNS SETOF public.places_with_ratings
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
AS $$
DECLARE
  v_limit integer := GREATEST(p_page_size, 1) + 1;
BEGIN
  IF p_sort = 'distance' THEN
    RETURN QUERY
      SELECT v.*
      FROM public.places_with_ratings v
      WHERE v.verification_status = 'verified'
        AND (p_search IS NULL
             OR v.nama_tempat ILIKE '%' || p_search || '%'
             OR v.alamat          ILIKE '%' || p_search || '%')
        AND (p_categories IS NULL OR v.category = ANY(p_categories))
        AND (p_sub_categories IS NULL OR v.sub_category = ANY(p_sub_categories))
        AND (p_featured  IS NULL OR v.is_featured = p_featured)
        AND (p_cursor_created_at IS NULL
             OR haversine_distance(p_user_lat, p_user_lng,
                                   v.latitude, v.longitude) > p_cursor_value
             OR (haversine_distance(p_user_lat, p_user_lng,
                                    v.latitude, v.longitude) = p_cursor_value
                 AND (v.created_at < p_cursor_created_at
                      OR (v.created_at = p_cursor_created_at
                          AND v.id < p_cursor_id))))
      ORDER BY haversine_distance(p_user_lat, p_user_lng,
                                  v.latitude, v.longitude) ASC,
               v.created_at DESC, v.id DESC
      LIMIT v_limit;
  ELSIF p_sort = 'rating' THEN
    RETURN QUERY
      SELECT v.*
      FROM public.places_with_ratings v
      WHERE v.verification_status = 'verified'
        AND (p_search IS NULL
             OR v.nama_tempat ILIKE '%' || p_search || '%'
             OR v.alamat          ILIKE '%' || p_search || '%')
        AND (p_categories IS NULL OR v.category = ANY(p_categories))
        AND (p_sub_categories IS NULL OR v.sub_category = ANY(p_sub_categories))
        AND (p_featured  IS NULL OR v.is_featured = p_featured)
        AND (p_cursor_created_at IS NULL
             OR v.avg_rating < p_cursor_value
             OR ((v.avg_rating IS NOT DISTINCT FROM p_cursor_value)
                 AND (v.created_at < p_cursor_created_at
                      OR (v.created_at = p_cursor_created_at
                          AND v.id < p_cursor_id))))
      ORDER BY v.avg_rating DESC NULLS LAST,
               v.created_at DESC, v.id DESC
      LIMIT v_limit;
  ELSE -- 'newest' (default)
    RETURN QUERY
      SELECT v.*
      FROM public.places_with_ratings v
      WHERE v.verification_status = 'verified'
        AND (p_search IS NULL
             OR v.nama_tempat ILIKE '%' || p_search || '%'
             OR v.alamat          ILIKE '%' || p_search || '%')
        AND (p_categories IS NULL OR v.category = ANY(p_categories))
        AND (p_sub_categories IS NULL OR v.sub_category = ANY(p_sub_categories))
        AND (p_featured  IS NULL OR v.is_featured = p_featured)
        AND (p_cursor_created_at IS NULL
             OR v.created_at < p_cursor_created_at
             OR (v.created_at = p_cursor_created_at
                 AND v.id < p_cursor_id))
      ORDER BY v.created_at DESC, v.id DESC
      LIMIT v_limit;
  END IF;
END;
$$;

-- Grant execute (signature berubah karena ada parameter baru)
GRANT EXECUTE ON FUNCTION public.get_places_paged(
  text, text[], text[], boolean, double precision, double precision,
  text, timestamptz, bigint, double precision, integer
) TO anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_places_paged(
  text, text[], text[], boolean, double precision, double precision,
  text, timestamptz, bigint, double precision, integer
) FROM PUBLIC;

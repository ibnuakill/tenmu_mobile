-- =============================================================================
-- get_places_paged: RPC untuk pagination + filter + sort SERVER-SIDE
-- =============================================================================
-- Menggantikan pola lama: fetch seluruh `places_with_ratings` lalu
-- search/kategori/sort semuanya di client (O(N) transfer per user).
--
-- Fitur:
--   * Wajib filter verification_status = 'verified' (defense-in-depth; akses
--     tetap diatur RLS places_select_verified).
--   * Search: ILIKE pada nama_tempat / alamat
--   * Kategori: exact match via text[] (mendukung multi-pilih)
--   * is_featured: NULL = dua-duanya
--   * Sort  : 'newest' (created_at DESC)
--             'distance' (haversine ASC, butuh p_user_lat/lng)
--             'rating' (avg_rating DESC NULLS LAST)
--   * Pagination CURSOR-BASED (created_at, id) + tiebreak nilai sort;
--     menghindari offset drift saat ada insert/update di tengah scroll.
--     Return LIMIT page_size + 1 row → caller tahu hasMore & me-truncate.
--
-- SECURITY INVOKER: view memakai security_invoker=true sehingga RLS tetap
-- dijalankan terhadap role pemanggil (anon/authenticated). Bukan definer.

CREATE OR REPLACE FUNCTION public.get_places_paged(
  p_search text DEFAULT NULL,
  p_categories text[] DEFAULT NULL,
  p_featured boolean DEFAULT NULL,
  p_user_lat double precision DEFAULT NULL,
  p_user_lng double precision DEFAULT NULL,
  p_sort text DEFAULT 'newest',            -- 'newest' | 'distance' | 'rating'
  p_cursor_created_at timestamptz DEFAULT NULL,
  p_cursor_id bigint DEFAULT NULL,
  p_cursor_value double precision DEFAULT NULL,  -- km (distance) / rating (rating)
  p_page_size integer DEFAULT 30
)
RETURNS SETOF public.places_with_ratings
LANGUAGE plpgsql
VOLATILE
SECURITY INVOKER
AS $$
DECLARE
  v_limit integer := GREATEST(p_page_size, 1) + 1;  -- probe +1 row utk has_more
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

-- Akses: anon read verified, authenticated juga. Revoke dari PUBLIC agar
-- hanya role eksplisit (defense).
GRANT EXECUTE ON FUNCTION public.get_places_paged(
  text, text[], boolean, double precision, double precision,
  text, timestamptz, bigint, double precision, integer
) TO anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.get_places_paged(
  text, text[], boolean, double precision, double precision,
  text, timestamptz, bigint, double precision, integer
) FROM PUBLIC;

-- Index pendukung:
--  1) filter kategori = {verification_status, category}
--  2) cursor 'newest' index-only: (verification_status, created_at DESC, id)
--     (fnc filter status + ORDER created_at/id)
--  3) featured carousel: partial index tempat is_featured=true
CREATE INDEX IF NOT EXISTS idx_places_verif_category
  ON public.places (verification_status, category);
CREATE INDEX IF NOT EXISTS idx_places_cursor_desc
  ON public.places (verification_status, created_at DESC, id);
CREATE INDEX IF NOT EXISTS idx_places_featured
  ON public.places (is_featured) WHERE is_featured = true;
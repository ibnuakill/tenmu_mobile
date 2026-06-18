-- ============================================================
-- Haversine Formula — PostgreSQL Function
-- Menghitung jarak (km) antara dua koordinat geografis
-- ============================================================

CREATE OR REPLACE FUNCTION haversine_distance(
  lat1 FLOAT8,
  lng1 FLOAT8,
  lat2 FLOAT8,
  lng2 FLOAT8
) RETURNS FLOAT8 AS $$
DECLARE
  dlat FLOAT8;
  dlng FLOAT8;
  a FLOAT8;
  c FLOAT8;
  r FLOAT8 = 6371; -- Radius bumi dalam km
BEGIN
  -- Convert degrees to radians
  dlat := radians(lat2 - lat1);
  dlng := radians(lng2 - lng1);

  a := sin(dlat / 2) * sin(dlat / 2)
       + cos(radians(lat1)) * cos(radians(lat2))
       * sin(dlng / 2) * sin(dlng / 2);

  c := 2 * asin(sqrt(a));

  RETURN r * c; -- Jarak dalam kilometer
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Contoh penggunaan:
-- SELECT *,
--   haversine_distance(-6.200000, 106.816666, latitude, longitude) AS jarak_km
-- FROM places
-- WHERE verification_status = 'verified'
-- ORDER BY jarak_km ASC;

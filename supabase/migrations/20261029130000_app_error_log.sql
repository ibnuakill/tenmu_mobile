-- ============================================================================
-- TABEL LOG ERROR APLIKASI (crash reporting gratis, tanpa layanan pihak ketiga)
-- ----------------------------------------------------------------------------
-- Kenapa: tanpa log, error di HP user tidak pernah sampai ke developer.
-- Aplikasi mengirim error ke tabel ini lewat `lib/core/error_reporter.dart`.
--
-- Aturan akses:
--   INSERT : boleh anon + authenticated (error bisa terjadi sebelum login)
--   SELECT : hanya admin / superadmin
--   UPDATE / DELETE : tidak ada (log bersifat append-only)
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.app_errors (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID,
  message     TEXT NOT NULL,
  stack       TEXT,
  context     TEXT,
  platform    TEXT,
  app_version TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS app_errors_created_at_idx
  ON public.app_errors (created_at DESC);

CREATE INDEX IF NOT EXISTS app_errors_user_id_idx
  ON public.app_errors (user_id);

ALTER TABLE public.app_errors ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "app_errors_insert_any" ON public.app_errors;
CREATE POLICY "app_errors_insert_any"
  ON public.app_errors
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

DROP POLICY IF EXISTS "app_errors_select_admin" ON public.app_errors;
CREATE POLICY "app_errors_select_admin"
  ON public.app_errors
  FOR SELECT
  TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('admin', 'superadmin')
    )
  );

-- Bersihkan log lebih tua dari 30 hari (jalankan manual / via pg_cron).
CREATE OR REPLACE FUNCTION public.prune_app_errors()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.app_errors WHERE created_at < now() - interval '30 days';
$$;

COMMENT ON TABLE public.app_errors IS
  'Log error dari aplikasi (crash reporting). Ditulis client, dibaca admin.';

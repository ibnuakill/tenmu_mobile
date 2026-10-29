-- ============================================================================
-- HARDENING KEAMANAN TENMU — SATU FILE SEMUA PERUBAHAN
-- ============================================================================
-- Copy-paste ke Supabase Dashboard → SQL Editor → Run
-- ============================================================================

-- 0. HELPER FUNCTION: cek admin (bypass RLS via SECURITY DEFINER)
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'superadmin')
  );
$$;


-- 1. PROFILES: anon tidak dapat SELECT semua
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "profiles_select_public" ON public.profiles;
DROP POLICY IF EXISTS "profiles_select" ON public.profiles;

CREATE POLICY "profiles_select_own"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (auth.uid() = id OR public.is_admin());


-- 2. PII owner_request_* bersih otomatis bila status bukan 'pending'
CREATE OR REPLACE FUNCTION public.update_owner_request_pii()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.owner_request_status != 'pending' THEN
    NEW.owner_request_phone := NULL;
    NEW.owner_request_alamat := NULL;
    NEW.owner_request_nama_umkm := NULL;
    NEW.owner_request_note := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS clear_owner_request_pii ON public.profiles;
CREATE TRIGGER clear_owner_request_pii
  AFTER UPDATE OF owner_request_status ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_owner_request_pii();


-- 3. PLACES INSERT hanya owner/superadmin
DROP POLICY IF EXISTS "places_insert_owner" ON public.places;

CREATE POLICY "places_insert_owner"
  ON public.places FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = owner_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid() AND p.role IN ('owner', 'superadmin')
    )
  );


-- 4. TABEL APP_ERRORS — logging crash ringan
CREATE TABLE IF NOT EXISTS public.app_errors (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID,
  message     TEXT,
  stack       TEXT,
  context     TEXT,
  platform    TEXT,
  app_version TEXT,
  created_at  TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS app_errors_created_at_idx ON public.app_errors (created_at DESC);
CREATE INDEX IF NOT EXISTS app_errors_user_id_idx ON public.app_errors (user_id);

ALTER TABLE public.app_errors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "app_errors_insert_any" ON public.app_errors FOR INSERT TO public USING (true);
CREATE POLICY "app_errors_select_admin" ON public.app_errors FOR SELECT USING (public.is_admin());


-- 5. KUOTA CHAT AI PER USER (tahan restart & multi-instance)
CREATE TABLE IF NOT EXISTS public.chat_usage (
  user_id    UUID NOT NULL,
  day        DATE NOT NULL DEFAULT ((now() AT TIME ZONE 'utc')::date),
  count      INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, day)
);

ALTER TABLE public.chat_usage ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.bump_chat_usage(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE current_count INTEGER;
BEGIN
  INSERT INTO public.chat_usage (user_id, day, count)
  VALUES (p_user_id, (now() AT TIME ZONE 'utc')::date, 1)
  ON CONFLICT (user_id, day)
  DO UPDATE SET count = chat_usage.count + 1, updated_at = now()
  RETURNING count INTO current_count;
  RETURN current_count;
END;
$$;

REVOKE ALL ON FUNCTION public.bump_chat_usage(UUID) FROM PUBLIC, anon, authenticated;


-- 6. NOTIFICATIONS — hanya owner masing-masing + admin broadcast
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'notifications'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.notifications', pol.policyname);
  END LOOP;
END;
$$;

CREATE POLICY "notifications_select_own"
  ON public.notifications FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "notifications_insert_own"
  ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notifications_insert_admin"
  ON public.notifications FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "notifications_update_own"
  ON public.notifications FOR UPDATE TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notifications_delete_own"
  ON public.notifications FOR DELETE TO authenticated
  USING (auth.uid() = user_id);


-- 7. PINGGAL DATA UJI (jalankan separuh ini bila perlu)
-- DELETE FROM public.profiles WHERE nama ILIKE '%qa.%' OR nama ILIKE '%test%' OR nama IN ('Barou Kennedy', 'Sarah Sloan', 'Rey Ji', 'Ibnu Akil');
-- DELETE FROM public.favorites WHERE user_id NOT IN (SELECT id FROM public.profiles);
-- DELETE FROM public.reviews WHERE user_id NOT IN (SELECT id FROM public.profiles);
-- DELETE FROM public.places WHERE owner_id NOT IN (SELECT id FROM public.profiles);


-- ============================================================================
-- SELAMAI DEPLOY!
-- Lepas: 1) supabase functions deploy send-notification
--        2) flutter build apk / flutter run (refresh)
-- ============================================================================
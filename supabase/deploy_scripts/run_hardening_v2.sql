-- ============================================================================
-- HARDENING KEAMANAN TENMU — VERSI FINAL (perbaikan error USING/WITH CHECK)
-- ============================================================================
-- CARA PAKAI: Supabase Dashboard → SQL Editor → New query → paste semua → Run
--
-- Kenapa versi sebelumnya error "only WITH CHECK expression allowed for INSERT":
--   policy INSERT memakai USING. Untuk INSERT hanya boleh WITH CHECK.
-- ============================================================================


-- ---------------------------------------------------------------------------
-- 0. HELPER: cek admin/superadmin tanpa kena RLS (hindari infinite recursion)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role IN ('admin', 'superadmin')
  );
$$;


-- ---------------------------------------------------------------------------
-- 1. PROFILES — anon TIDAK boleh baca sama sekali (ini kebocoran PII)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DO $$
DECLARE pol RECORD;
BEGIN
  FOR pol IN
    SELECT policyname FROM pg_policies
    WHERE schemaname = 'public' AND tablename = 'profiles'
  LOOP
    EXECUTE format('DROP POLICY IF EXISTS %I ON public.profiles', pol.policyname);
  END LOOP;
END $$;

-- User login boleh baca profil (dibutuhkan nama penulis posting, daftar user
-- di admin, dll). Anon tidak punya policy = tidak bisa baca sama sekali.
CREATE POLICY "profiles_select_authenticated"
  ON public.profiles FOR SELECT
  TO authenticated
  USING (true);

CREATE POLICY "profiles_insert_own"
  ON public.profiles FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = id);

CREATE POLICY "profiles_update_self"
  ON public.profiles FOR UPDATE
  TO authenticated
  USING (auth.uid() = id)
  WITH CHECK (auth.uid() = id);


-- ---------------------------------------------------------------------------
-- 2. PII pengajuan owner otomatis dibersihkan kalau status bukan 'pending'
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.update_owner_request_pii()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.owner_request_status IS DISTINCT FROM 'pending' THEN
    NEW.owner_request_phone     := NULL;
    NEW.owner_request_alamat    := NULL;
    NEW.owner_request_nama_umkm := NULL;
    NEW.owner_request_note      := NULL;
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS clear_owner_request_pii ON public.profiles;
CREATE TRIGGER clear_owner_request_pii
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.update_owner_request_pii();


-- ---------------------------------------------------------------------------
-- 3. PLACES — hanya owner/superadmin boleh insert
-- ---------------------------------------------------------------------------
DROP POLICY IF EXISTS "places_insert_owner" ON public.places;

CREATE POLICY "places_insert_owner"
  ON public.places FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = owner_id
    AND EXISTS (
      SELECT 1 FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role IN ('owner', 'superadmin')
    )
  );


-- ---------------------------------------------------------------------------
-- 4. APP_ERRORS — log crash dari aplikasi
-- ---------------------------------------------------------------------------
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
CREATE INDEX IF NOT EXISTS app_errors_user_id_idx    ON public.app_errors (user_id);

ALTER TABLE public.app_errors ENABLE ROW LEVEL SECURITY;

-- INSERT: siapa saja (error bisa muncul sebelum login) → WAJIB WITH CHECK
CREATE POLICY "app_errors_insert_any"
  ON public.app_errors FOR INSERT
  TO public
  WITH CHECK (true);

CREATE POLICY "app_errors_select_admin"
  ON public.app_errors FOR SELECT
  TO authenticated
  USING (public.is_admin());


-- ---------------------------------------------------------------------------
-- 5. CHAT_USAGE — kuota chat AI harian, tahan restart & multi-instance
-- ---------------------------------------------------------------------------
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

REVOKE ALL ON FUNCTION public.bump_chat_usage(UUID) FROM PUBLIC;


-- ---------------------------------------------------------------------------
-- 6. NOTIFICATIONS — hanya milik sendiri, admin boleh broadcast
-- ---------------------------------------------------------------------------
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
END $$;

CREATE POLICY "notifications_select_own"
  ON public.notifications FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "notifications_insert_own"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notifications_insert_admin"
  ON public.notifications FOR INSERT
  TO authenticated
  WITH CHECK (public.is_admin());

CREATE POLICY "notifications_update_own"
  ON public.notifications FOR UPDATE
  TO authenticated
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "notifications_delete_own"
  ON public.notifications FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);


-- ---------------------------------------------------------------------------
-- 7. SELESAI. Cek hasil:
--    SELECT tablename, policyname, cmd, roles FROM pg_policies
--    WHERE tablename IN ('profiles','notifications','places')
--    ORDER BY tablename, cmd;
-- ---------------------------------------------------------------------------

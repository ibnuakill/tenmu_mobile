-- ============================================================
-- MIGRATION: place_videos + video_likes (short video UMKM)
-- Deskripsi: Fitur video pendek promosi UMKM (gaya Shopee Video).
--   * place_videos : video per tempat (upload oleh owner tempat)
--   * video_likes  : like/unlike per user
--   * bucket storage 'videos' (public read, upload authenticated)
-- Jalankan via: supabase db push  (atau paste di SQL Editor)
-- ============================================================

BEGIN;

-- ── 1. TABEL place_videos ───────────────────────────────────
CREATE TABLE IF NOT EXISTS public.place_videos (
  id             BIGSERIAL PRIMARY KEY,
  place_id       BIGINT      NOT NULL REFERENCES public.places(id) ON DELETE CASCADE,
  owner_id       UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  video_path     TEXT        NOT NULL,              -- path di bucket 'videos' (bukan URL penuh)
  thumbnail_path TEXT,                              -- opsional: frame/jpg path
  caption        TEXT,                              -- teks promosi singkat
  views          INTEGER     NOT NULL DEFAULT 0,    -- counter view (via RPC)
  is_active      BOOLEAN     NOT NULL DEFAULT TRUE, -- FALSE = takedown (admin) / belum aktif
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS place_videos_place_idx
  ON public.place_videos (place_id, created_at DESC);
CREATE INDEX IF NOT EXISTS place_videos_owner_idx
  ON public.place_videos (owner_id);

-- ── 2. TABEL video_likes ────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.video_likes (
  id         BIGSERIAL PRIMARY KEY,
  video_id   BIGINT      NOT NULL REFERENCES public.place_videos(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (video_id, user_id)   -- 1 like per user per video
);

-- ── 3. RLS: place_videos ───────────────────────────────────
ALTER TABLE public.place_videos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.video_likes  ENABLE ROW LEVEL SECURITY;

-- SELECT: publik (video aktif saja)
CREATE POLICY "place_videos_select_public"
  ON public.place_videos FOR SELECT
  TO anon, authenticated
  USING (is_active);

-- SELECT: owner boleh lihat video sendiri walau non-aktif
CREATE POLICY "place_videos_select_owner"
  ON public.place_videos FOR SELECT
  TO authenticated
  USING (auth.uid() = owner_id);

-- INSERT: owner, DAN hanya untuk tempat miliknya sendiri
CREATE POLICY "place_videos_insert_owner"
  ON public.place_videos FOR INSERT
  TO authenticated
  WITH CHECK (
    auth.uid() = owner_id
    AND EXISTS (
      SELECT 1 FROM public.places p
      WHERE p.id = place_id AND p.owner_id = auth.uid()
    )
  );

-- UPDATE: owner (caption/aktif), admin (takedown)
CREATE POLICY "place_videos_update_owner"
  ON public.place_videos FOR UPDATE
  TO authenticated
  USING (auth.uid() = owner_id)
  WITH CHECK (auth.uid() = owner_id);

CREATE POLICY "place_videos_update_admin"
  ON public.place_videos FOR UPDATE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'))
  WITH CHECK (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- DELETE: owner & admin
CREATE POLICY "place_videos_delete_owner"
  ON public.place_videos FOR DELETE
  TO authenticated
  USING (auth.uid() = owner_id);

CREATE POLICY "place_videos_delete_admin"
  ON public.place_videos FOR DELETE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- ── 4. RLS: video_likes ────────────────────────────────────
-- SELECT publik (bisa lihat siapa like; atau hitung count per video)
CREATE POLICY "video_likes_select_public"
  ON public.video_likes FOR SELECT
  TO anon, authenticated
  USING (true);

-- INSERT: user hanya like untuk dirinya sendiri
CREATE POLICY "video_likes_insert_own"
  ON public.video_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- DELETE: unlike untuk like sendiri
CREATE POLICY "video_likes_delete_own"
  ON public.video_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ── 5. RPC increment views ─────────────────────────────────
-- Dipanggil FE saat video diputar; aman karena disetujui server
-- (user biasa TIDAK boleh UPDATE kolom views langsung).
CREATE OR REPLACE FUNCTION public.increment_video_views(p_video_id BIGINT)
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  UPDATE public.place_videos
  SET views = views + 1
  WHERE id = p_video_id;
$$;

REVOKE ALL ON FUNCTION public.increment_video_views(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.increment_video_views(BIGINT) TO authenticated, anon;

-- ── 6. STORAGE bucket 'videos' ─────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('videos', 'videos', true)
ON CONFLICT (id) DO NOTHING;

-- Read publik: semua orang bisa stream video
CREATE POLICY "videos_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'videos');

-- Upload: hanya authenticated (owner), path bebas di bucket videos
CREATE POLICY "videos_auth_upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'videos' AND auth.role() = 'authenticated');

-- Update/hapus: pemilik object saja (Supabase set owner_id = auth.uid())
-- catatan: storage.objects.owner_id bertipe text di remote; cast dua sisi biar
-- kompatibel dgn tipe uuid/text (text = uuid akan error 42883).
CREATE POLICY "videos_owner_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'videos' AND owner_id::text = auth.uid()::text);

CREATE POLICY "videos_owner_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'videos' AND owner_id::text = auth.uid()::text);

COMMIT;

-- ============================================================
-- Catatan skripsi:
--   * Durasi/ukuran dibatasi di sisi client (max 60 detik, ~20MB)
--     karena Supabase tidak transcode; video di-stream MP4 progressive.
--   * is_active=false = takedown manual admin; verifikasi video per
--     tempat otomatis mengikuti places.verification_status.
-- ============================================================
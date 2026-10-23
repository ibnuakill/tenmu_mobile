-- ============================================================
-- MIGRATION: place_posts + post_likes (Postingan foto potensi lokal)
-- Deskripsi: Fitur "Postingan" — pengguna mengunggah FOTO terkait
--   tempat/potensi lokal, disertai caption, like, dan komentar.
--   * place_posts : postingan foto (dibuat oleh user mana pun)
--   * post_likes  : like/unlike per user
--   * post_comments: komentar per postingan
--   * bucket storage 'posts' (public read, upload authenticated)
-- Jalankan via: supabase db push  (atau paste di SQL Editor)
-- ============================================================

BEGIN;

-- ── 1. TABEL place_posts ────────────────────────────────────
-- place_id OPSIONAL (NULL = postingan bebas tanpa tautan tempat).
CREATE TABLE IF NOT EXISTS public.place_posts (
  id          BIGSERIAL PRIMARY KEY,
  place_id    BIGINT      REFERENCES public.places(id) ON DELETE SET NULL,
  author_id   UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  image_path  TEXT        NOT NULL,
  caption     TEXT,
  is_active   BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Jika tabel sudah terlanjur dibuat dengan place_id NOT NULL:
ALTER TABLE public.place_posts ALTER COLUMN place_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS place_posts_place_idx
  ON public.place_posts (place_id, created_at DESC);
CREATE INDEX IF NOT EXISTS place_posts_author_idx
  ON public.place_posts (author_id);
CREATE INDEX IF NOT EXISTS place_posts_feed_idx
  ON public.place_posts (is_active, created_at DESC);

-- ── 2. TABEL post_likes ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.post_likes (
  id         BIGSERIAL PRIMARY KEY,
  post_id    BIGINT      NOT NULL REFERENCES public.place_posts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (post_id, user_id)   -- 1 like per user per postingan
);

CREATE INDEX IF NOT EXISTS post_likes_post_idx ON public.post_likes (post_id);

-- ── 3. TABEL post_comments ──────────────────────────────────
CREATE TABLE IF NOT EXISTS public.post_comments (
  id         BIGSERIAL PRIMARY KEY,
  post_id    BIGINT      NOT NULL REFERENCES public.place_posts(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  body       TEXT        NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS post_comments_post_idx
  ON public.post_comments (post_id, created_at ASC);

-- ── 4. RLS: place_posts ─────────────────────────────────────
ALTER TABLE public.place_posts  ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

-- SELECT: publik (postingan aktif saja)
CREATE POLICY "place_posts_select_public"
  ON public.place_posts FOR SELECT
  TO anon, authenticated
  USING (is_active);

-- SELECT: penulis boleh lihat postingannya sendiri walau non-aktif
CREATE POLICY "place_posts_select_author"
  ON public.place_posts FOR SELECT
  TO authenticated
  USING (auth.uid() = author_id);

-- INSERT: SEMUA user terautentikasi boleh membuat postingan
--   (syarat: postingan milik dirinya sendiri).
CREATE POLICY "place_posts_insert_any_user"
  ON public.place_posts FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = author_id);

-- UPDATE: penulis sendiri
CREATE POLICY "place_posts_update_author"
  ON public.place_posts FOR UPDATE
  TO authenticated
  USING (auth.uid() = author_id)
  WITH CHECK (auth.uid() = author_id);

-- UPDATE: admin (sembunyikan postingan)
CREATE POLICY "place_posts_update_admin"
  ON public.place_posts FOR UPDATE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'))
  WITH CHECK (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- DELETE: penulis sendiri & admin
CREATE POLICY "place_posts_delete_author"
  ON public.place_posts FOR DELETE
  TO authenticated
  USING (auth.uid() = author_id);

CREATE POLICY "place_posts_delete_admin"
  ON public.place_posts FOR DELETE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- ── 5. RLS: post_likes ──────────────────────────────────────
CREATE POLICY "post_likes_select_public"
  ON public.post_likes FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "post_likes_insert_own"
  ON public.post_likes FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "post_likes_delete_own"
  ON public.post_likes FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ── 6. RLS: post_comments ───────────────────────────────────
CREATE POLICY "post_comments_select_public"
  ON public.post_comments FOR SELECT
  TO anon, authenticated
  USING (true);

CREATE POLICY "post_comments_insert_own"
  ON public.post_comments FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "post_comments_delete_own"
  ON public.post_comments FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

CREATE POLICY "post_comments_delete_admin"
  ON public.post_comments FOR DELETE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- ── 7. STORAGE bucket 'posts' ───────────────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('posts', 'posts', true)
ON CONFLICT (id) DO NOTHING;

-- Read publik: semua orang bisa melihat foto postingan
CREATE POLICY "posts_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'posts');

-- Upload: hanya authenticated
CREATE POLICY "posts_auth_upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'posts' AND auth.role() = 'authenticated');

-- Update/hapus: pemilik object saja (cast text/uuid agar kompatibel)
CREATE POLICY "posts_owner_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'posts' AND owner_id::text = auth.uid()::text);

CREATE POLICY "posts_owner_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'posts' AND owner_id::text = auth.uid()::text);

COMMIT;

-- ============================================================
-- Catatan skripsi:
--   * Fitur Postingan = FOTO saja (tidak ada video).
--   * Semua pengguna (bukan hanya owner) boleh membuat postingan
--     yang terkait dengan tempat/potensi lokal yang ada.
--   * Interaksi: Like (post_likes) + Komentar (post_comments).
-- ============================================================

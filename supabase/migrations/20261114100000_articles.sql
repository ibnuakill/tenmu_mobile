-- ============================================================
-- MIGRATION: articles + article_bookmarks (Portal UMKM Cirebon)
-- Deskripsi: Ganti fitur Postingan (place_posts) dengan Portal Artikel UMKM.
--   * articles : artikel kurasi UMKM (dikelola superadmin)
--   * article_bookmarks : bookmark user per artikel
--   * bucket storage 'article_covers' (public read, upload authenticated)
-- Jalankan via: supabase db push  (atau paste di SQL Editor)
-- ============================================================

BEGIN;

-- ── 1. TABEL articles ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.articles (
  id            BIGSERIAL PRIMARY KEY,
  title         TEXT        NOT NULL,
  slug          TEXT        NOT NULL UNIQUE,
  excerpt       TEXT,
  content       TEXT        NOT NULL,      -- Markdown/HTML content
  cover_image_path TEXT,                   -- path di storage bucket article_covers
  category      TEXT        NOT NULL,      -- kuliner, wisata, hidden_gem, tips, event
  kecamatan     TEXT,                      -- nullable: Kejaksan, Pekalipan, Harjamukti, Lemahwungkuk, Kesambi
  is_published  BOOLEAN     NOT NULL DEFAULT FALSE,
  published_at  TIMESTAMPTZ,
  author_id     UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  view_count    INTEGER     NOT NULL DEFAULT 0,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS articles_published_idx
  ON public.articles (is_published, published_at DESC);
CREATE INDEX IF NOT EXISTS articles_category_idx
  ON public.articles (category, is_published, published_at DESC);
CREATE INDEX IF NOT EXISTS articles_kecamatan_idx
  ON public.articles (kecamatan, is_published, published_at DESC);
CREATE INDEX IF NOT EXISTS articles_author_idx
  ON public.articles (author_id);
CREATE INDEX IF NOT EXISTS articles_slug_idx
  ON public.articles (slug);

-- ── 2. TABEL article_bookmarks ───────────────────────────────
CREATE TABLE IF NOT EXISTS public.article_bookmarks (
  id         BIGSERIAL PRIMARY KEY,
  article_id BIGINT      NOT NULL REFERENCES public.articles(id) ON DELETE CASCADE,
  user_id    UUID        NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE (article_id, user_id)
);

CREATE INDEX IF NOT EXISTS article_bookmarks_user_idx
  ON public.article_bookmarks (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS article_bookmarks_article_idx
  ON public.article_bookmarks (article_id);

-- ── 3. RLS: articles ─────────────────────────────────────────
ALTER TABLE public.articles ENABLE ROW LEVEL SECURITY;

-- SELECT: publik bisa baca artikel yang published
CREATE POLICY "articles_select_published"
  ON public.articles FOR SELECT
  TO anon, authenticated
  USING (is_published = true);

-- SELECT: superadmin bisa baca semua (termasuk draft)
CREATE POLICY "articles_select_admin"
  ON public.articles FOR SELECT
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- INSERT: hanya superadmin
CREATE POLICY "articles_insert_admin"
  ON public.articles FOR INSERT
  TO authenticated
  WITH CHECK (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- UPDATE: hanya superadmin
CREATE POLICY "articles_update_admin"
  ON public.articles FOR UPDATE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'))
  WITH CHECK (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- DELETE: hanya superadmin
CREATE POLICY "articles_delete_admin"
  ON public.articles FOR DELETE
  TO authenticated
  USING (auth.jwt()->>'role' IN ('admin', 'superadmin'));

-- ── 4. RLS: article_bookmarks ────────────────────────────────
ALTER TABLE public.article_bookmarks ENABLE ROW LEVEL SECURITY;

-- SELECT: user lihat bookmark sendiri
CREATE POLICY "bookmarks_select_own"
  ON public.article_bookmarks FOR SELECT
  TO authenticated
  USING (auth.uid() = user_id);

-- INSERT: user bookmark sendiri
CREATE POLICY "bookmarks_insert_own"
  ON public.article_bookmarks FOR INSERT
  TO authenticated
  WITH CHECK (auth.uid() = user_id);

-- DELETE: user hapus bookmark sendiri
CREATE POLICY "bookmarks_delete_own"
  ON public.article_bookmarks FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);

-- ── 5. TRIGGER updated_at untuk articles ─────────────────────
CREATE OR REPLACE FUNCTION public.update_articles_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS articles_updated_at ON public.articles;
CREATE TRIGGER articles_updated_at
  BEFORE UPDATE ON public.articles
  FOR EACH ROW EXECUTE FUNCTION public.update_articles_updated_at();

-- ── 6. STORAGE bucket 'article_covers' ───────────────────────
INSERT INTO storage.buckets (id, name, public)
VALUES ('article_covers', 'article_covers', true)
ON CONFLICT (id) DO NOTHING;

-- Read publik: semua orang bisa melihat cover artikel
CREATE POLICY "article_covers_public_read"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'article_covers');

-- Upload: hanya authenticated (superadmin via app)
CREATE POLICY "article_covers_auth_upload"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'article_covers' AND auth.role() = 'authenticated');

-- Update/hapus: pemilik object saja
CREATE POLICY "article_covers_owner_update"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'article_covers' AND owner_id::text = auth.uid()::text);

CREATE POLICY "article_covers_owner_delete"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'article_covers' AND owner_id::text = auth.uid()::text);

COMMIT;

-- ============================================================
-- CATATAN SKRIPSI:
--   * Portal UMKM Cirebon = artikel kurasi (bukan user-generated).
--   * Hanya superadmin yang bisa CRUD artikel.
--   * User: baca, filter kategori/kecamatan, bookmark, push notif.
--   * Real-time via Supabase Realtime subscribe ke articles (filter is_published=true).
-- ============================================================
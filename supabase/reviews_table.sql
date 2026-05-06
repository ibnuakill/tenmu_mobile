-- ============================================================
-- Tabel: reviews
-- Deskripsi: Menyimpan rating & komentar dari user terhadap UMKM
-- ============================================================

CREATE TABLE IF NOT EXISTS reviews (
  id          BIGSERIAL PRIMARY KEY,
  umkm_id     BIGINT    NOT NULL REFERENCES umkm(id) ON DELETE CASCADE,
  user_id     UUID      NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  rating      SMALLINT  NOT NULL CHECK (rating BETWEEN 1 AND 5),
  komentar    TEXT,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Satu user hanya boleh 1 review per UMKM
CREATE UNIQUE INDEX IF NOT EXISTS reviews_umkm_user_unique
  ON reviews (umkm_id, user_id);

-- Index untuk query cepat per umkm
CREATE INDEX IF NOT EXISTS reviews_umkm_id_idx
  ON reviews (umkm_id);

-- ── ROW LEVEL SECURITY ──────────────────────────────────────
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;

-- Siapa saja (termasuk anonymous) bisa BACA semua review
CREATE POLICY "reviews_select_public"
  ON reviews FOR SELECT
  USING (true);

-- User yang login hanya bisa INSERT review miliknya sendiri
CREATE POLICY "reviews_insert_own"
  ON reviews FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- User hanya bisa UPDATE review miliknya sendiri
CREATE POLICY "reviews_update_own"
  ON reviews FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- User hanya bisa DELETE review miliknya sendiri
CREATE POLICY "reviews_delete_own"
  ON reviews FOR DELETE
  USING (auth.uid() = user_id);

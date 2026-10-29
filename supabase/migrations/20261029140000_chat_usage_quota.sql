-- ============================================================================
-- KUOTA CHAT AI PERSISTEN
-- ----------------------------------------------------------------------------
-- Kenapa: `chat-bot` sudah punya limiter, tapi hanya in-memory per instance.
-- Setiap cold start / instance baru → hitungan kembali nol, jadi kuota gratis
-- Gemini/Groq bisa habis oleh satu orang. Tabel ini menyimpan hitungan harian
-- yang tahan restart dan dibagi semua instance.
--
-- Tabel tidak punya policy RLS apa pun → hanya service_role (dipakai edge
-- function) yang bisa membaca/menulis.
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.chat_usage (
  user_id    UUID NOT NULL,
  day        DATE NOT NULL DEFAULT ((now() AT TIME ZONE 'utc')::date),
  count      INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, day)
);

ALTER TABLE public.chat_usage ENABLE ROW LEVEL SECURITY;

-- Naikkan hitungan hari ini, kembalikan nilai setelah kenaikan.
CREATE OR REPLACE FUNCTION public.bump_chat_usage(p_user_id UUID)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_count INTEGER;
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

-- Bersihkan baris lama (jalankan manual / pg_cron).
CREATE OR REPLACE FUNCTION public.prune_chat_usage()
RETURNS void
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  DELETE FROM public.chat_usage WHERE day < (now() AT TIME ZONE 'utc')::date - 30;
$$;

COMMENT ON TABLE public.chat_usage IS
  'Kuota harian chat AI per user — dipakai edge function chat-bot.';

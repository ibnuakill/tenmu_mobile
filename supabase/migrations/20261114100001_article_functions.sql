-- Function untuk increment view count artikel
CREATE OR REPLACE FUNCTION public.increment_article_view(article_id BIGINT)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
  UPDATE public.articles
  SET view_count = view_count + 1
  WHERE id = article_id;
END;
$$;
-- ============================================================
-- Fix Trigger handle_new_user() untuk mencegah Database error saving new user
-- ============================================================

-- 1. Buat atau perbarui fungsi handle_new_user agar aman saat user baru mendaftar
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  INSERT INTO public.profiles (
    id, 
    nama, 
    role, 
    status, 
    created_at
  )
  VALUES (
    new.id,
    COALESCE(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1),
      'User'
    ),
    'user',
    'active',
    NOW()
  )
  ON CONFLICT (id) DO UPDATE
  SET 
    nama = EXCLUDED.nama,
    updated_at = NOW()
  WHERE profiles.nama IS NULL OR profiles.nama = 'User';

  RETURN new;
EXCEPTION
  WHEN OTHERS THEN
    -- Mencegah Auth gagal jika ada constraint unik/tipe data yang bermasalah pada profiles
    RAISE WARNING 'handle_new_user error: %', SQLERRM;
    RETURN new;
END;
$$;

-- 2. Pasang kembali trigger pada auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Pastikan kolom yang dibutuhkan ada pada public.profiles dengan default value yang aman
ALTER TABLE IF EXISTS public.profiles
ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'active';

ALTER TABLE IF EXISTS public.profiles
ADD COLUMN IF NOT EXISTS created_at TIMESTAMPTZ DEFAULT NOW();

ALTER TABLE IF EXISTS public.profiles
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

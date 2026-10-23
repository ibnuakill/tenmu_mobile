-- ============================================================
-- SOLUSI UTAMA: Hapus Trigger on_auth_user_created
-- ============================================================
-- Aplikasi Tenmu sudah memiliki pembuatan profil otomatis di kode Flutter 
-- (lib/screen/auth/role_checker.dart). Trigger pada auth.users menyebabkan 
-- kegagalan "Database error saving new user" saat user baru dibuat via Supabase Auth.

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
DROP FUNCTION IF EXISTS public.handle_new_user();

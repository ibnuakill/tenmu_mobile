-- Nonaktifkan rilis lama agar hanya 1.0.2 yang aktif dilayani ke app.
update public.app_versions set is_active = false where version_code = 2;

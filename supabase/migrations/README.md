# Supabase Migrations

Semua perubahan skema/RLS/fungsi DB masuk ke folder ini. Tidak ada perubahan
skema yang dilakukan lewat Dashboard tanpa file migrasi di sini.

## Konvensi nama

```
YYYYMMDDHHMMSS_nama_singkat.sql
```

- 14 digit timestamp (UTC), lalu `_`, lalu nama snake_case.
- Timestamp harus unik. Dua file dengan timestamp sama membuat urutan apply
  tidak deterministik.
- Satu file = satu perubahan yang bisa dijelaskan dalam satu baris commit.

Cek cepat (dijalankan juga oleh CI):

```bash
ls supabase/migrations/*.sql | sed 's|.*/||' | cut -d_ -f1 | sort | uniq -d
# output kosong = aman
```

## Urutan & status di hosted project

Migrasi di-apply berurutan sesuai timestamp. Yang sudah terpasang di project
`axtkquxgojewinwdndtt`:

| Timestamp | File | Isi |
|---|---|---|
| 20261028130000 | `fix_admin_rls_and_role_escalation.sql` | RLS admin + cegah eskalasi role |
| 20261029120000 | `harden_profiles_pii...sql` | Tutup kebocoran PII di `profiles` |
| 20261114100000 | `articles.sql` | Tabel `articles` + `article_bookmarks` + index |
| 20261114100001 | `article_functions.sql` | `increment_article_view()`, trigger `updated_at` |
| 20261114100002 | `seed_articles.sql` | 5 artikel contoh (published) |
| 20261115120000 | `articles_rls_is_admin.sql` | **Fix**: policy `articles` pakai `public.is_admin()` |
| (fix typo) | `fix_typo_seed_artikel_sunyaragi.sql` | Perbaikan teks seed |

## Aturan RLS yang mudah salah

1. **Jangan pakai `auth.jwt() ->> 'role'` untuk cek admin.** Di Supabase claim
   `role` berisi `'authenticated'`, bukan role aplikasi. Pakai
   `public.is_admin()` (SECURITY DEFINER yang membaca `profiles.role`).
   Gejala kalau salah: write dari superadmin balas 0 baris walau UI bilang sukses.
2. Policy tulis harus `to authenticated` + `with check`, bukan cuma `using`.
   Tanpa `with check`, user bisa insert baris yang tidak boleh dia baca.
3. Setiap migrasi yang menambah policy sebaiknya menutup dengan komentar
   rollback (`-- rollback:` + statement `drop policy ...`).

## Cara apply

```bash
# lokal
supabase db reset

# hosted (pilih salah satu)
supabase db push
# atau jalankan isi file lewat SQL editor Dashboard
```

## Cek sesudah apply

```sql
-- pastikan policy benar-benar ada
select policyname, cmd, qual, with_check
from pg_policies where tablename = 'articles';

-- pastikan fungsi admin bisa dipanggil role authenticated
select has_function_privilege('authenticated', 'public.is_admin()', 'EXECUTE');
```

-- ============================================================================
-- Isolasi PII pengajuan owner UMKM ke tabel terpisah
-- ----------------------------------------------------------------------------
-- Masalah: profiles bisa dibaca semua user login (dibutuhkan untuk nama penulis
-- review & daftar admin), sehingga owner_request_phone / _alamat / _nama_umkm /
-- _note milik pendaftar lain ikut terbaca.
--
-- Solusi: pindahkan 4 kolom PII itu ke tabel public.owner_requests yang punya
-- policy ketat (hanya pemilik baris + admin). profiles tetap menyimpan
-- owner_request_status sebagai penanda ringan untuk badge/daftar.
-- ============================================================================

-- 1) Tabel baru ---------------------------------------------------------------
create table if not exists public.owner_requests (
  user_id      uuid primary key references public.profiles(id) on delete cascade,
  nama_umkm    text not null,
  alamat       text not null,
  phone        text not null,
  note         text,
  status       text not null default 'pending'
               check (status in ('pending', 'approved', 'rejected')),
  requested_at timestamptz not null default now(),
  rejection    text,
  handled_by   uuid,
  handled_at   timestamptz,
  updated_at   timestamptz not null default now()
);

create index if not exists owner_requests_status_idx
  on public.owner_requests (status, requested_at desc);

-- 2) Pindahkan data lama ------------------------------------------------------
insert into public.owner_requests
  (user_id, nama_umkm, alamat, phone, note, status, requested_at, rejection)
select
  p.id,
  coalesce(nullif(p.owner_request_nama_umkm, ''), '-'),
  coalesce(nullif(p.owner_request_alamat, ''), '-'),
  coalesce(nullif(p.owner_request_phone, ''), '-'),
  p.owner_request_note,
  case
    when p.owner_request_status in ('pending', 'approved', 'rejected')
      then p.owner_request_status
    else 'pending'
  end,
  coalesce(p.owner_requested_at, now()),
  p.owner_request_rejection
from public.profiles p
where p.owner_request_nama_umkm is not null
   or p.owner_request_phone is not null
   or p.owner_request_alamat is not null
on conflict (user_id) do nothing;

-- 3) Arsip kolom lama sebelum dihapus (tertutup total, hanya service_role) ----
create table if not exists public.profiles_owner_request_backup as
select
  id,
  owner_request_status,
  owner_request_nama_umkm,
  owner_request_alamat,
  owner_request_phone,
  owner_request_note,
  owner_requested_at,
  owner_request_rejection
from public.profiles;

alter table public.profiles_owner_request_backup enable row level security;
revoke all on public.profiles_owner_request_backup from anon, authenticated;

-- 4) RLS tabel baru -----------------------------------------------------------
alter table public.owner_requests enable row level security;

drop policy if exists "owner_requests_select_own" on public.owner_requests;
create policy "owner_requests_select_own"
  on public.owner_requests for select to authenticated
  using (auth.uid() = user_id or public.is_admin());

-- User hanya boleh membuat pengajuan atas namanya sendiri, status wajib pending
drop policy if exists "owner_requests_insert_own" on public.owner_requests;
create policy "owner_requests_insert_own"
  on public.owner_requests for insert to authenticated
  with check (auth.uid() = user_id and status = 'pending');

-- User boleh memperbarui pengajuannya sendiri, tapi hasil akhirnya wajib
-- pending (tidak bisa menaikkan dirinya jadi approved).
drop policy if exists "owner_requests_update_own" on public.owner_requests;
create policy "owner_requests_update_own"
  on public.owner_requests for update to authenticated
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id and status = 'pending');

-- Admin (lewat service_role di admin-api, policy ini untuk jaga-jaga)
drop policy if exists "owner_requests_admin_all" on public.owner_requests;
create policy "owner_requests_admin_all"
  on public.owner_requests for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 5) Sinkronkan status ringan ke profiles ------------------------------------
create or replace function public.sync_owner_request_status()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    -- Hanya batalkan penanda kalau memang masih menunggu (user membatalkan).
    update public.profiles
       set owner_request_status = 'none'
     where id = old.user_id
       and owner_request_status = 'pending';
    return old;
  end if;

  update public.profiles
     set owner_request_status = new.status
   where id = new.user_id;

  return new;
end;
$$;

drop trigger if exists trg_sync_owner_request on public.owner_requests;
create trigger trg_sync_owner_request
  after insert or update of status or delete on public.owner_requests
  for each row execute function public.sync_owner_request_status();

-- 6) Hapus PII dari profiles --------------------------------------------------
-- Trigger pembersih lama tidak relevan lagi karena kolomnya hilang.
drop trigger if exists clear_owner_request_pii on public.profiles;
drop function if exists public.update_owner_request_pii();
drop function if exists public.clear_owner_request_pii();

alter table public.profiles
  drop column if exists owner_request_nama_umkm,
  drop column if exists owner_request_alamat,
  drop column if exists owner_request_phone,
  drop column if exists owner_request_note;

-- Kolom legacy "request_*" (mekanisme pengajuan lama, sudah tidak dipakai app)
alter table public.profiles
  drop column if exists requested_role,
  drop column if exists request_message,
  drop column if exists request_status,
  drop column if exists request_created_at,
  drop column if exists request_handled_by,
  drop column if exists request_handled_at;

-- 7) Perbarui guard kolom sensitif (tidak lagi merujuk kolom yang dihapus) ---
create or replace function public.profiles_guard_privileged_columns()
returns trigger
language plpgsql
security definer
set search_path to 'public'
as $function$
BEGIN
  -- service_role / server (tanpa JWT user) -> boleh, dipakai edge function admin-api
  IF auth.uid() IS NULL THEN
    RETURN NEW;
  END IF;

  -- admin & superadmin -> boleh
  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF NEW.role IS DISTINCT FROM OLD.role THEN
    RAISE EXCEPTION 'Role tidak boleh diubah sendiri' USING ERRCODE = '42501';
  END IF;

  IF NEW.status IS DISTINCT FROM OLD.status THEN
    RAISE EXCEPTION 'Status akun tidak boleh diubah sendiri' USING ERRCODE = '42501';
  END IF;

  IF NEW.owner_request_status IS DISTINCT FROM OLD.owner_request_status
     AND NEW.owner_request_status NOT IN ('pending', 'none', 'cancelled') THEN
    RAISE EXCEPTION 'Status pengajuan hanya bisa diubah oleh admin' USING ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$function$;

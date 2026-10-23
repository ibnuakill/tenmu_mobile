-- Constraint: places.category hanya boleh 5 sektor universal
alter table public.places
  drop constraint if exists places_category_sector_check;

alter table public.places
  add constraint places_category_sector_check
  check (
    category in (
      'Kuliner (Makanan & Olahan)',
      'Kerajinan & Manufaktur Tradisional',
      'Perdagangan & Retail',
      'Agribisnis',
      'Jasa'
    )
  );

-- Nama kategori pada tabel kategori harus sama dengan 5 sektor
alter table public.kategori
  drop constraint if exists kategori_nama_sector_check;

alter table public.kategori
  add constraint kategori_nama_sector_check
  check (
    nama in (
      'Kuliner (Makanan & Olahan)',
      'Kerajinan & Manufaktur Tradisional',
      'Perdagangan & Retail',
      'Agribisnis',
      'Jasa'
    )
  );

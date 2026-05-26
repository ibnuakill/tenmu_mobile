-- Migration: Add contact and operating hours fields to UMKM
-- Deskripsi: Menambahkan nomor telepon dan jam operasional ke tabel umkm

ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS nomor_telepon TEXT;

ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS jam_buka TEXT;

ALTER TABLE IF EXISTS umkm
ADD COLUMN IF NOT EXISTS jam_tutup TEXT;

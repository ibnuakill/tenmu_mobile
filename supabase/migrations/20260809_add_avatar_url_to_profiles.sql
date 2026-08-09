-- Add avatar_url column to profiles table
-- Migration generated on 2026-08-09

alter table profiles
  add column if not exists avatar_url text;

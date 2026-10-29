#!/bin/bash
# ============================================================================
# Deploy ulang semua Edge Function TenMu
# Cara pakai (Git Bash):
#   cd /c/Users/CG/Videos/Coding/tenmuv1.0
#   bash deploy.sh
# ============================================================================
set -e

echo "== 1. Cek Supabase CLI =="
if ! command -v supabase >/dev/null 2>&1; then
  echo "Supabase CLI belum terpasang."
  echo "Windows:  scoop install supabase   (atau)  npm i -g supabase"
  exit 1
fi
supabase --version

echo
echo "== 2. Login (buka browser, approve) =="
supabase login

echo
echo "== 3. Deploy fungsi =="
# send-notification: sekarang wajib JWT + cek admin/owner
supabase functions deploy send-notification
# delete-self: hapus akun sendiri (Play Store requirement)
supabase functions deploy delete-self
# chat-bot: kuota harian persisten; JWT diverifikasi manual di dalam fungsi
supabase functions deploy chat-bot --no-verify-jwt
# admin-api: aksi admin pakai service role
supabase functions deploy admin-api

echo
echo "== 4. Selesai =="
echo "Langkah berikutnya: jalankan supabase/deploy_scripts/run_hardening_v2.sql"
echo "di Supabase Dashboard -> SQL Editor, lalu rebuild app (flutter run)."

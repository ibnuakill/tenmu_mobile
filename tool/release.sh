#!/usr/bin/env bash
# =============================================================================
# Rilis aplikasi TenMu (in-app update / sideload, tanpa Play Store)
#
# Alur:
#   1. Bump version di pubspec.yaml (opsional, pakai --bump)
#   2. Build APK release
#   3. Upload APK ke bucket Supabase Storage "app-releases"
#   4. Insert baris ke tabel app_versions supaya app mendeteksi versi baru
#
# Pemakaian:
#   ./tool/release.sh --bump patch --changelog "Perbaikan bug login"
#   ./tool/release.sh --changelog "Tambah fitur X"          (tanpa bump)
# =============================================================================
set -euo pipefail

BUMP=""
CHANGELOG=""
MANDATORY="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump)      BUMP="$2"; shift 2 ;;
    --changelog) CHANGELOG="$2"; shift 2 ;;
    --mandatory) MANDATORY="true"; shift ;;
    *) echo "Argumen tidak dikenal: $1"; exit 1 ;;
  esac
done

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
PUBSPEC="pubspec.yaml"

# --- Ambil versi saat ini --------------------------------------------------
CURRENT_LINE=$(grep -E "^version:" "$PUBSPEC")
CURRENT_VERSION=$(echo "$CURRENT_LINE" | sed -E 's/^version:[[:space:]]*//')
NAME_PART=${CURRENT_VERSION%%+*}
CODE_PART=${CURRENT_VERSION##*+}
echo ">> Versi saat ini: $CURRENT_VERSION"

# --- Bump version -----------------------------------------------------------
if [[ -n "$BUMP" ]]; then
  IFS='.' read -r MAJOR MINOR PATCH <<< "$NAME_PART"
  case "$BUMP" in
    major) MAJOR=$((MAJOR+1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR+1)); PATCH=0 ;;
    patch) PATCH=$((PATCH+1)) ;;
    *) echo "Bump harus major|minor|patch"; exit 1 ;;
  esac
  NEW_NAME="$MAJOR.$MINOR.$PATCH"
  NEW_CODE=$((CODE_PART+1))
  NEW_VERSION="$NEW_NAME+$NEW_CODE"

  sed -i.bak -E "s/^version:[[:space:]]*.*/version: $NEW_VERSION/" "$PUBSPEC"
  rm -f "$PUBSPEC.bak"
  echo ">> Versi baru: $NEW_VERSION"
else
  NEW_NAME="$NAME_PART"
  NEW_CODE="$CODE_PART"
  NEW_VERSION="$CURRENT_VERSION"
fi

# --- Build ------------------------------------------------------------------
echo ">> Build APK release (split per-ABI)..."
flutter build apk --release --split-per-abi
APK_DIR="build/app/outputs/flutter-apk"
[[ -d "$APK_DIR" ]] || { echo "Direktori APK tidak ditemukan: $APK_DIR"; exit 1; }

# --- Upload ke Supabase Storage --------------------------------------------
# Free tier Supabase Storage membatasi ukuran objek 50 MB, sementara APK
# universal bisa >90 MB karena membawa 3 ABI. Karena itu rilis memakai
# build split-per-abi: tiap file < 50 MB, dan aplikasi mengunduh varian
# yang cocok dengan ABI perangkat.
echo ">> Upload ke bucket app-releases..."
SUPABASE_URL=$(grep -E "^SUPABASE_URL=" .env | cut -d= -f2- | tr -d '\r"')
BASE_URL="$SUPABASE_URL/storage/v1/object/public/app-releases"

VARIANTS_JSON="{"
APK_URL=""
APK_SIZE=0
FIRST=1

for abi in arm64-v8a armeabi-v7a x86_64; do
  APK_PATH="$APK_DIR/app-$abi-release.apk"
  [[ -f "$APK_PATH" ]] || { echo "APK $abi tidak ditemukan: $APK_PATH"; exit 1; }

  OBJ_NAME="tenmu-$NEW_NAME-$abi.apk"
  python tool/storage_upload.py "$APK_PATH" app-releases "$OBJ_NAME" \
    "application/vnd.android.package-archive"

  SIZE=$(wc -c < "$APK_PATH" | tr -d ' ')
  URL="$BASE_URL/$OBJ_NAME"

  if [[ $FIRST -eq 0 ]]; then VARIANTS_JSON="$VARIANTS_JSON,"; fi
  FIRST=0
  VARIANTS_JSON="$VARIANTS_JSON\"$abi\":\"$URL\""

  # APK arm64-v8a dipakai sebagai default (kebanyakan HP modern).
  if [[ "$abi" == "arm64-v8a" ]]; then
    APK_URL="$URL"
    APK_SIZE="$SIZE"
  fi
done
VARIANTS_JSON="$VARIANTS_JSON}"

echo ">> URL APK (default arm64-v8a): $APK_URL"

# --- Insert ke app_versions -------------------------------------------------
# CATATAN: version_code yang disimpan ke DB bukan buildNumber polos.
# Build split-per-abi memberi offset versionCode per ABI
# (build 3 -> 2003 arm64-v8a, 1003 armeabi-v7a, 4003 x86_64).
# Aplikasi versi lama membandingkan versionCode polos, jadi angka DB
# harus lebih besar dari semua offset ABI: 4000 + buildNumber.
DB_CODE=$((4000 + NEW_CODE))

echo ">> Insert ke app_versions (version_code $DB_CODE)..."
python tool/insert_version.py \
"$DB_CODE" "$NEW_NAME" "$APK_URL" "$APK_SIZE" "$CHANGELOG" "$MANDATORY" \
"$VARIANTS_JSON"

echo ""
echo "=== RILIS SELESAI ==="
echo "Versi    : $NEW_NAME (buildNumber $NEW_CODE, versionCode DB $DB_CODE)"
echo "APK      : $APK_PATH"
echo "URL      : $APK_URL"
echo ""
echo "Pengguna yang sudah install akan melihat dialog update saat membuka app."

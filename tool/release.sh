#!/usr/bin/env bash
# =============================================================================
# Rilis aplikasi TenMu (in-app update / sideload, tanpa Play Store)
#
# Satu perintah: naikkan versi -> build APK -> upload -> daftarkan di server.
#
#   ./tool/release.sh --version 1.2.0 --notes-file tool/notes.txt --mandatory
#   ./tool/release.sh --bump patch --changelog "Perbaikan bug login" --mandatory
#   ./tool/release.sh --bump minor --changelog "Fitur baru" --optional --yes
#
# Butuh token Supabase (yang login/deploy):
#   export SUPABASE_ACCESS_TOKEN=sbp_xxx
# =============================================================================
set -euo pipefail

BUMP=""
VERSION=""
CHANGELOG=""
NOTES_INLINE=""
NOTES_FILE=""
PUBLIC_NOTES=""
MANDATORY="false"
ASSUME_YES="false"
SKIP_BUILD="false"

usage() {
  cat <<'EOF'
Pemakaian: ./tool/release.sh [opsi]

Versi (pilih salah satu, kalau tidak diisi versi pubspec dipakai apa adanya):
  --bump major|minor|patch   Naikkan versi dari versi sekarang
  --version X.Y.Z            Set nama versi eksplisit (buildNumber tetap +1)

Catatan rilis:
  --notes "teks"             Catatan INTERNAL (detail, tidak dikirim ke app)
  --notes-file file.txt      Catatan internal dari file (multi-baris)
  --public-notes "teks"      Teks yang dilihat user di layar update.
                             Default: "Perbaikan bug dan peningkatan performa."

  PENTING: catatan internal hanya disimpan di repo (tool/notes/), TIDAK pernah
  dikirim ke database. Aplikasi hanya menampilkan --public-notes.

Perilaku:
  --mandatory                Update wajib: user tidak bisa masuk app sebelum update
  --optional                 Update opsional (bisa di-skip). Default.
  --yes, -y                  Lewati konfirmasi
  --skip-build               Pakai APK yang sudah ada di build/app/outputs
  -h, --help                 Tampilkan bantuan ini

Contoh:
  ./tool/release.sh --bump patch --notes "Tutup celah RLS owner_requests" --mandatory
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bump)        BUMP="${2:-}"; shift 2 ;;
    --version)     VERSION="${2:-}"; shift 2 ;;
    --changelog|--notes) NOTES_INLINE="${2:-}"; shift 2 ;;
    --public-notes) PUBLIC_NOTES="${2:-}"; shift 2 ;;
    --notes-file)  NOTES_FILE="${2:-}"; shift 2 ;;
    --mandatory)   MANDATORY="true"; shift ;;
    --optional)    MANDATORY="false"; shift ;;
    --yes|-y)      ASSUME_YES="true"; shift ;;
    --skip-build)  SKIP_BUILD="true"; shift ;;
    -h|--help)     usage; exit 0 ;;
    *) echo "Argumen tidak dikenal: $1"; echo; usage; exit 1 ;;
  esac
done

cd "$(dirname "$0")/.."
ROOT="$(pwd)"
PUBSPEC="pubspec.yaml"
PROJECT_REF="${SUPABASE_PROJECT_REF:-axtkquxgojewinwdndtt}"
APK_DIR="build/app/outputs/flutter-apk"

step() { echo; echo ">> $*"; }
fail() { echo; echo "GAGAL: $*" >&2; exit 1; }

# --- 0. Pemeriksaan awal ----------------------------------------------------
step "Pemeriksaan awal"
command -v flutter >/dev/null || fail "flutter tidak ada di PATH"
command -v python  >/dev/null || fail "python tidak ada di PATH"
[[ -f "$PUBSPEC" ]] || fail "$PUBSPEC tidak ditemukan"
[[ -f ".env" ]] || fail ".env tidak ditemukan (butuh SUPABASE_URL)"

SUPABASE_URL=$(grep -E "^SUPABASE_URL=" .env | head -1 | cut -d= -f2- | tr -d '\r"')
SUPABASE_ANON=$(grep -E "^SUPABASE_ANON_KEY=" .env | head -1 | cut -d= -f2- | tr -d '\r"')
[[ -n "$SUPABASE_URL" ]] || fail "SUPABASE_URL kosong di .env"

PAT="${SUPABASE_ACCESS_TOKEN:-}"
if [[ -z "$PAT" && -f "$HOME/.supabase/profile" ]]; then
  PAT=$(tr -d '\r\n' < "$HOME/.supabase/profile")
fi
[[ "$PAT" == sbp_* ]] || fail "Token Supabase tidak ada. Jalankan: export SUPABASE_ACCESS_TOKEN=sbp_xxx"
export SUPABASE_ACCESS_TOKEN="$PAT"
export SUPABASE_PROJECT_REF="$PROJECT_REF"

echo "   project : $PROJECT_REF"
echo "   .env    : ${SUPABASE_URL}"
echo "   token   : ${PAT:0:8}… (${#PAT} karakter)"

# --- 1. Hitung versi --------------------------------------------------------
step "Versi aplikasi"
CURRENT=$(grep -E "^version:" "$PUBSPEC" | head -1 | sed -E 's/^version:[[:space:]]*//' | tr -d '\r')
NAME_PART="${CURRENT%%+*}"
CODE_PART="${CURRENT##*+}"
[[ "$CODE_PART" =~ ^[0-9]+$ ]] || fail "format version di pubspec harus 'x.y.z+n' (sekarang: $CURRENT)"
echo "   sekarang: $CURRENT"

NEW_NAME="$NAME_PART"
NEW_CODE="$CODE_PART"
CHANGED="false"

if [[ -n "$VERSION" ]]; then
  [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "--version harus format X.Y.Z (contoh 1.2.0)"
  NEW_NAME="$VERSION"
  NEW_CODE=$((CODE_PART + 1))
  CHANGED="true"
elif [[ -n "$BUMP" ]]; then
  IFS='.' read -r MAJOR MINOR PATCH <<< "$NAME_PART"
  case "$BUMP" in
    major) MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0 ;;
    minor) MINOR=$((MINOR + 1)); PATCH=0 ;;
    patch) PATCH=$((PATCH + 1)) ;;
    *) fail "--bump harus major|minor|patch" ;;
  esac
  NEW_NAME="$MAJOR.$MINOR.$PATCH"
  NEW_CODE=$((CODE_PART + 1))
  CHANGED="true"
fi

NEW_VERSION="$NEW_NAME+$NEW_CODE"
DB_CODE=$((4000 + NEW_CODE))

if [[ "$CHANGED" == "true" ]]; then
  sed -i.bak -E "s/^version:[[:space:]]*.*/version: $NEW_VERSION/" "$PUBSPEC"
  rm -f "$PUBSPEC.bak"
  echo "   baru    : $NEW_VERSION (versionCode DB: $DB_CODE)"
else
  echo "   dipakai : $NEW_VERSION (tidak berubah)"
  echo "   PERINGATAN: versi tidak naik. User yang sudah punya versi ini TIDAK akan"
  echo "   melihat update. Pakai --bump atau --version kalau ini rilis baru."
fi

# --- 2. Catatan rilis (internal vs publik) ----------------------------------
# Catatan internal berisi detail teknis/keamanan: hanya untuk repo, TIDAK
# pernah dikirim ke database. User hanya melihat teks generik di layar update.
PRIVATE_NOTES=""
if [[ -n "$NOTES_FILE" ]]; then
  [[ -f "$NOTES_FILE" ]] || fail "$NOTES_FILE tidak ditemukan"
  PRIVATE_NOTES=$(cat "$NOTES_FILE")
elif [[ -n "$NOTES_INLINE" ]]; then
  PRIVATE_NOTES="$NOTES_INLINE"
fi

if [[ -z "$PUBLIC_NOTES" ]]; then
  PUBLIC_NOTES="Perbaikan bug dan peningkatan performa."
fi

if [[ -n "$PRIVATE_NOTES" ]]; then
  mkdir -p tool/notes
  ARCHIVE="tool/notes/$NEW_NAME.txt"
  if [[ -f "$ARCHIVE" ]]; then
    printf '\n--- rilis ulang %s ---\n%s\n' "$(date '+%Y-%m-%d %H:%M')" "$PRIVATE_NOTES" >> "$ARCHIVE"
  else
    printf '%s\n' "$PRIVATE_NOTES" > "$ARCHIVE"
  fi
  echo "   internal : $ARCHIVE (tidak dikirim ke app)"
fi
echo "   publik   : $PUBLIC_NOTES"

# --- 3. Konfirmasi ----------------------------------------------------------
if [[ "$ASSUME_YES" != "true" ]]; then
  echo
  echo "================ RINGKASAN RILIS ================"
  echo "Versi        : $NEW_NAME (build $NEW_CODE, versionCode DB $DB_CODE)"
  echo "Wajib update : $MANDATORY"
  echo "Build ulang  : $([[ "$SKIP_BUILD" == "true" ]] && echo tidak || echo ya)"
  echo "Catatan publik (dilihat user):"
  echo "               $PUBLIC_NOTES"
  if [[ -n "$PRIVATE_NOTES" ]]; then
    echo "Catatan internal (hanya repo):"
    echo "$PRIVATE_NOTES" | sed 's/^/               /'
  fi
  echo "================================================="
  read -r -p "Lanjutkan? (y/N) " ANSWER
  [[ "$ANSWER" =~ ^[yY]$ ]] || { echo "Dibatalkan."; exit 0; }
fi

# --- 4. Build ---------------------------------------------------------------
if [[ "$SKIP_BUILD" == "true" ]]; then
  step "Build dilewati (--skip-build), memakai APK yang ada"
else
  step "Build APK release (split per-ABI)"
  flutter build apk --release --split-per-abi
fi

[[ -d "$APK_DIR" ]] || fail "direktori APK tidak ada: $APK_DIR"

# --- 5. Pengaman tanda tangan ----------------------------------------------
# Kalau sertifikat berubah, Android menolak install dan SEMUA user terkunci
# (tidak bisa update, tidak bisa masuk). Ini dicek sebelum upload.
step "Cek tanda tangan APK"
SIGN_FILE="tool/apk_signature.txt"
APKSIGNER=""
if command -v apksigner >/dev/null 2>&1; then
  APKSIGNER="apksigner"
else
  SDK="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
  if [[ -z "$SDK" && -n "${LOCALAPPDATA:-}" ]]; then
    SDK="$(command -v cygpath >/dev/null && cygpath -u "$LOCALAPPDATA" || echo "$LOCALAPPDATA")/Android/Sdk"
  fi
  if [[ -n "$SDK" && -d "$SDK/build-tools" ]]; then
    APKSIGNER=$(ls -1 "$SDK"/build-tools/*/apksigner* 2>/dev/null | sort -V | tail -1 || true)
  fi
fi

if [[ -z "$APKSIGNER" ]]; then
  echo "   apksigner tidak ditemukan — cek tanda tangan DILEWATI."
  echo "   Pastikan android/key.properties & keystore sama seperti rilis sebelumnya."
else
  FP=$("$APKSIGNER" verify --print-certs "$APK_DIR/app-arm64-v8a-release.apk" 2>/dev/null \
        | grep -i "SHA-256 digest" | head -1 | sed -E 's/.*digest:[[:space:]]*//' | tr -d ':\r' | tr 'A-F' 'a-f')
  if [[ -z "$FP" ]]; then
    echo "   tidak bisa membaca sertifikat APK — cek dilewati."
  elif [[ -f "$SIGN_FILE" ]]; then
    EXPECTED=$(tr -d ':\r\n ' < "$SIGN_FILE" | tr 'A-F' 'a-f')
    if [[ "$FP" != "$EXPECTED" ]]; then
      echo
      echo "   sertifikat APK BERBEDA dari rilis sebelumnya!" >&2
      echo "   sekarang : $FP" >&2
      echo "   seharusnya: $EXPECTED" >&2
      fail "update akan GAGAL dipasang di HP user (signature mismatch). Perbaiki keystore dulu."
    fi
    echo "   sertifikat cocok: ${FP:0:16}…"
  else
    echo "$FP" > "$SIGN_FILE"
    echo "   baseline disimpan ke $SIGN_FILE: ${FP:0:16}…"
  fi
fi

# --- 6. Cek versi di dalam APK ---------------------------------------------
AAPT=""
SDK2="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-}}"
if [[ -z "$SDK2" && -n "${LOCALAPPDATA:-}" ]]; then
  SDK2="$(command -v cygpath >/dev/null && cygpath -u "$LOCALAPPDATA" || echo "$LOCALAPPDATA")/Android/Sdk"
fi
if [[ -n "$SDK2" && -d "$SDK2/build-tools" ]]; then
  AAPT=$(ls -1 "$SDK2"/build-tools/*/aapt2* 2>/dev/null | sort -V | tail -1 || true)
fi
if [[ -n "$AAPT" ]]; then
  APK_VER=$("$AAPT" dump badging "$APK_DIR/app-arm64-v8a-release.apk" 2>/dev/null \
            | grep -o "versionName='[^']*'" | head -1 | cut -d"'" -f2)
  if [[ -n "$APK_VER" && "$APK_VER" != "$NEW_NAME" ]]; then
    fail "APK berisi versi $APK_VER, bukan $NEW_NAME. Build ulang tanpa --skip-build."
  fi
  echo "   versi di dalam APK: ${APK_VER:-?}"
fi

# --- 7. Upload --------------------------------------------------------------
step "Upload ke bucket app-releases"
BASE_URL="$SUPABASE_URL/storage/v1/object/public/app-releases"
VARIANTS_JSON="{"
APK_URL=""
APK_SIZE=0
FIRST=1
LIMIT=52428800  # 50 MB — batas objek Supabase free tier

for abi in arm64-v8a armeabi-v7a x86_64; do
  APK_PATH="$APK_DIR/app-$abi-release.apk"
  [[ -f "$APK_PATH" ]] || fail "APK $abi tidak ditemukan: $APK_PATH"

  SIZE=$(wc -c < "$APK_PATH" | tr -d ' ')
  (( SIZE < LIMIT )) || fail "APK $abi $((SIZE / 1048576)) MB melebihi batas 50 MB Supabase"

  OBJ="tenmu-$NEW_NAME-$abi.apk"
  python tool/storage_upload.py "$APK_PATH" app-releases "$OBJ" \
    "application/vnd.android.package-archive" \
    || fail "upload $abi gagal"

  URL="$BASE_URL/$OBJ"
  [[ $FIRST -eq 0 ]] && VARIANTS_JSON="$VARIANTS_JSON,"
  FIRST=0
  VARIANTS_JSON="$VARIANTS_JSON\"$abi\":\"$URL\""

  if [[ "$abi" == "arm64-v8a" ]]; then
    APK_URL="$URL"
    APK_SIZE="$SIZE"
  fi
done
VARIANTS_JSON="$VARIANTS_JSON}"

# --- 8. Daftarkan di app_versions ------------------------------------------
step "Daftarkan versi ke app_versions (version_code $DB_CODE)"
python tool/insert_version.py \
  "$DB_CODE" "$NEW_NAME" "$APK_URL" "$APK_SIZE" "$PUBLIC_NOTES" "$MANDATORY" \
  "$VARIANTS_JSON" || fail "insert app_versions gagal"

# --- 9. Verifikasi ----------------------------------------------------------
step "Verifikasi"

echo "   cek link APK..."
for abi in arm64-v8a armeabi-v7a x86_64; do
  # catatan: curl -I di Git Bash kadang keluar dengan status non-nol walau
  # respons 200, jadi jangan pakai "|| echo 000" (hasilnya jadi "200000").
  CODE=$(curl -sS -o /dev/null -w '%{http_code}' -I "$BASE_URL/tenmu-$NEW_NAME-$abi.apk" 2>/dev/null | tr -d '[:space:]' || true)
  [[ -n "$CODE" ]] || CODE="000"
  [[ "$CODE" == "200" ]] || fail "APK $abi tidak bisa diunduh publik (HTTP $CODE)"
  echo "     $abi: HTTP $CODE"
done

echo "   cek yang dilihat aplikasi..."
LATEST=$(curl -sS "$SUPABASE_URL/rest/v1/app_versions?select=version_name,is_mandatory&is_active=eq.true&order=version_code.desc&limit=1" \
  -H "apikey: $SUPABASE_ANON" -H "Authorization: Bearer $SUPABASE_ANON" 2>/dev/null || true)
[[ "$LATEST" == *"$NEW_NAME"* ]] || fail "aplikasi tidak melihat versi $NEW_NAME sebagai versi aktif (respon: $LATEST)"
echo "     $LATEST"

# --- 10. Ringkasan ----------------------------------------------------------
echo
echo "================= RILIS SELESAI ================="
echo "Versi       : $NEW_NAME (build $NEW_CODE)"
echo "Wajib update: $MANDATORY"
echo "APK utama   : $APK_URL"
echo "APK 32-bit  : $BASE_URL/tenmu-$NEW_NAME-armeabi-v7a.apk"
echo "APK emulator: $BASE_URL/tenmu-$NEW_NAME-x86_64.apk"
echo "================================================="
if [[ "$MANDATORY" == "true" ]]; then
  echo "User yang membuka app versi lama akan TERKUNCI di layar update sampai"
  echo "memasang versi ini."
else
  echo "User akan melihat dialog update yang bisa ditunda."
fi

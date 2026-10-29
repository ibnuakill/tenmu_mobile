"""Insert baris rilis ke tabel `app_versions` (Supabase Project TenMu).

Dipakai oleh tool/release.sh. Token dibaca dari env `SUPABASE_ACCESS_TOKEN`,
fallback ke `~/.supabase/profile`.

Baris rilis lain otomatis dinonaktifkan (`is_active = false`) supaya aplikasi
hanya pernah melihat satu versi aktif.
"""
import json, os, sys, urllib.request, urllib.error

PROJECT = os.environ.get("SUPABASE_PROJECT_REF", "axtkquxgojewinwdndtt")
PROFILE = os.path.expanduser("~/.supabase/profile")


def get_pat():
    pat = os.environ.get("SUPABASE_ACCESS_TOKEN", "").strip()
    if not pat and os.path.exists(PROFILE):
        pat = open(PROFILE, encoding="utf-8").read().strip()
    if not pat.startswith("sbp_"):
        raise SystemExit(
            "Token Supabase tidak ditemukan.\n"
            "  export SUPABASE_ACCESS_TOKEN=sbp_xxx\n"
            "  (ambil di https://supabase.com/dashboard/account/tokens)"
        )
    return pat


def insert_version(version_code, version_name, apk_url, apk_size,
                   changelog="", is_mandatory=False, apk_variants=None):
    pat = get_pat()

    safe_changelog = changelog.replace("'", "''")
    safe_url = apk_url.replace("'", "''")
    safe_name = version_name.replace("'", "''")

    variants_json = "null"
    if apk_variants:
        variants_json = "'" + apk_variants.replace("'", "''") + "'::jsonb"

    sql = f"""
update public.app_versions
   set is_active = false
 where is_active = true and version_code <> {int(version_code)};

insert into public.app_versions
  (version_code, version_name, apk_url, apk_size, changelog, is_mandatory,
   is_active, apk_variants)
values
  ({int(version_code)}, '{safe_name}', '{safe_url}', {int(apk_size)},
   '{safe_changelog}', {'true' if is_mandatory else 'false'}, true,
   {variants_json})
on conflict (version_code) do update set
  version_name  = excluded.version_name,
  apk_url       = excluded.apk_url,
  apk_size      = excluded.apk_size,
  changelog     = excluded.changelog,
  is_mandatory  = excluded.is_mandatory,
  is_active     = true,
  apk_variants  = excluded.apk_variants;
"""

    req = urllib.request.Request(
        f"https://api.supabase.com/v1/projects/{PROJECT}/database/query",
        data=json.dumps({"query": sql}).encode("utf-8"),
        headers={"Authorization": "Bearer " + pat, "Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=180) as r:
            return r.status, r.read().decode("utf-8", "replace")[:500]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:1500]


if __name__ == "__main__":
    code, name, url, size = sys.argv[1:5]
    changelog = sys.argv[5] if len(sys.argv) > 5 else ""
    mandatory = (sys.argv[6].lower() == "true") if len(sys.argv) > 6 else False
    variants = sys.argv[7] if len(sys.argv) > 7 else None
    status, body = insert_version(code, name, url, size, changelog, mandatory, variants)
    print("HTTP", status, body)
    sys.exit(0 if status in (200, 201, 204) else 1)

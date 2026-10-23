"""Insert baris rilis ke tabel `app_versions` (Supabase Project TenMu).

Dipakai oleh tool/release.sh. PAT dibaca dari ~/.supabase/profile.
"""
import json, os, sys, urllib.request, urllib.error

PROJECT = "axtkquxgojewinwdndtt"
PROFILE = os.path.expanduser("~/.supabase/profile")


def insert_version(version_code, version_name, apk_url, apk_size,
                   changelog="", is_mandatory=False, apk_variants=None):
    pat = open(PROFILE, encoding="utf-8").read().strip()
    if not pat.startswith("sbp_"):
        raise SystemExit("PAT di ~/.supabase/profile tidak valid")

    safe_changelog = changelog.replace("'", "''")
    safe_url = apk_url.replace("'", "''")
    safe_name = version_name.replace("'", "''")

    variants_json = "null"
    if apk_variants:
        variants_json = "'" + apk_variants.replace("'", "''") + "'::jsonb"

    sql = f"""
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
    sys.exit(0 if status == 201 else 1)

"""Jalankan file SQL ke Supabase via Management API query endpoint.

PAT diambil dari ~/.supabase/profile (tidak disimpan di repo).
Usage: python tool/apply_sql.py supabase/drop_sub_category.sql
"""
import json, os, sys, urllib.request, urllib.error

PROJECT = "axtkquxgojewinwdndtt"
PROFILE = os.path.expanduser("~/.supabase/profile")


def get_pat():
    pat = open(PROFILE, encoding="utf-8").read().strip()
    if not pat.startswith("sbp_"):
        raise SystemExit("PAT di ~/.supabase/profile tidak valid")
    return pat


def run_sql(sql):
    url = f"https://api.supabase.com/v1/projects/{PROJECT}/database/query"
    req = urllib.request.Request(
        url,
        data=json.dumps({"query": sql}).encode("utf-8"),
        headers={
            "Authorization": "Bearer " + get_pat(),
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=300) as r:
            return r.status, r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")


if __name__ == "__main__":
    path = sys.argv[1]
    sql = open(path, encoding="utf-8").read()
    print(f"apply {path} ({len(sql.encode('utf-8'))} bytes)")
    code, body = run_sql(sql)
    print("HTTP", code, body[:1500])
    sys.exit(0 if code in (200, 201) else 1)

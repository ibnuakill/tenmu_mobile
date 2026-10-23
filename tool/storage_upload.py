"""Upload file ke Supabase Storage memakai service_role key.

service_role key diambil on-the-fly dari Management API (PAT di ~/.supabase/profile)
sehingga tidak perlu disimpan di repo maupun di .env.
"""
import json, os, sys, urllib.request, urllib.error

PROJECT = "axtkquxgojewinwdndtt"
PROFILE = os.path.expanduser("~/.supabase/profile")


def get_service_role_key():
    pat = open(PROFILE, encoding="utf-8").read().strip()
    if not pat.startswith("sbp_"):
        raise SystemExit("PAT di ~/.supabase/profile tidak valid")
    url = f"https://api.supabase.com/v1/projects/{PROJECT}/api-keys"
    req = urllib.request.Request(url, headers={"Authorization": "Bearer " + pat})
    with urllib.request.urlopen(req, timeout=60) as r:
        keys = json.loads(r.read().decode("utf-8"))
    for k in keys:
        if k.get("id") == "service_role" or k.get("type") == "service_role":
            return k["api_key"]
    raise SystemExit("service_role key tidak ditemukan")


def upload(local_path, bucket, remote_path, content_type="application/octet-stream"):
    key = get_service_role_key()
    data = open(local_path, "rb").read()
    url = f"https://{PROJECT}.supabase.co/storage/v1/object/{bucket}/{remote_path}"
    req = urllib.request.Request(
        url,
        data=data,
        headers={
            "Authorization": "Bearer " + key,
            "Content-Type": content_type,
            "x-upsert": "true",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            return r.status, r.read().decode("utf-8", "replace")[:300]
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode("utf-8", "replace")[:800]


if __name__ == "__main__":
    local, bucket, remote = sys.argv[1], sys.argv[2], sys.argv[3]
    ctype = sys.argv[4] if len(sys.argv) > 4 else "application/octet-stream"
    size = os.path.getsize(local)
    print(f"upload {local} ({size} bytes) -> {bucket}/{remote}")
    code, body = upload(local, bucket, remote, ctype)
    print("HTTP", code, body)
    sys.exit(0 if code in (200, 201) else 1)

"""Hapus file dari Supabase Storage (untuk cleanup file uji)."""
import json, os, sys, urllib.request, urllib.error
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from storage_upload import get_service_role_key, PROJECT

bucket, remote = sys.argv[1], sys.argv[2]
key = get_service_role_key()
url = f"https://{PROJECT}.supabase.co/storage/v1/object/{bucket}/{remote}"
req = urllib.request.Request(url, headers={"Authorization": "Bearer " + key}, method="DELETE")
try:
    with urllib.request.urlopen(req, timeout=60) as r:
        print("HTTP", r.status, r.read().decode()[:200])
except urllib.error.HTTPError as e:
    print("HTTP", e.code, e.read().decode()[:300])

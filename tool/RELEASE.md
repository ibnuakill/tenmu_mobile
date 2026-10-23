# Rilis Aplikasi TenMu (In-App Update / Sideload)

Mekanisme pembaruan **tanpa Play Store**. Aplikasi memeriksa versi terbaru
saat dibuka, mengunduh APK baru, lalu membuka installer Android.

## Cara Kerja

```
[App dibuka]
     │
     ├─ AppUpdateGate → AppUpdateProvider.checkForUpdate()
     │        │
     │        └─ SELECT * FROM app_versions WHERE is_active ORDER BY version_code DESC LIMIT 1
     │                 bandingkan version_name (semantik) dgn versionName terpasang
     │
     ├─ Ada versi baru? → dialog "Pembaruan Tersedia"
     │        ├─ [Unduh] → streaming download ke app cache dir + progress bar
     │        └─ [Pasang Sekarang] → OpenFilex → installer Android
     │
     └─ Tidak ada / sama → diam, tidak mengganggu user
```

## Komponen

| File | Peran |
|------|-------|
| `lib/core/app_update_service.dart` | Service: cek versi, download APK, buka installer |
| `lib/core/app_update_provider.dart` | `ChangeNotifier` — state (`UpdateStatus`, progress, error) |
| `lib/core/widgets/update_dialog.dart` | Dialog pembaruan (changelog, progress, tombol) |
| `lib/core/widgets/update_gate.dart` | Pemicu pengecekan otomatis saat app dibuka |
| `supabase/create_app_versions.sql` | Tabel `app_versions` + bucket `app-releases` + RLS |
| `tool/release.sh` | Script rilis 1-perintah |
| `tool/storage_upload.py` | Upload APK ke Supabase Storage |
| `tool/insert_version.py` | Insert baris ke `app_versions` |
| `tool/storage_delete.py` | Hapus file dari storage (cleanup) |

## Rilis — Perintah Satu Baris

```bash
./tool/release.sh --bump patch --changelog "Perbaikan bug login"
```

Opsi:
- `--bump major|minor|patch` — naikkan `version:` di `pubspec.yaml` (wajib naik!)
- `--changelog "..."` — catatan rilis yang tampil di dialog
- `--mandatory` — user tidak bisa skip update

Script melakukan:
1. Bump `version:` di `pubspec.yaml` (versionCode +1)
2. `flutter build apk --release --split-per-abi`
3. Upload 3 APK (arm64-v8a, armeabi-v7a, x86_64) → bucket `app-releases`
4. Insert baris ke `app_versions` dengan `apk_variants` (peta ABI → URL)

Tanpa `--bump`, script memakai versi yang ada di `pubspec.yaml`.

## Kenapa Split-per-ABI

Free tier Supabase Storage membatasi ukuran objek **50 MB**. APK universal
TenMu ±93 MB (3 ABI × `libflutter.so` + `libmaplibre.so` + `libapp.so`).
Upload universal gagal dengan `413 Payload too large`.

Solusinya `flutter build apk --release --split-per-abi` → 3 file ±30–45 MB.
Aplikasi memakai `device_info_plus` untuk membaca `supportedAbis` device
lalu mengunduh varian yang cocok. Kolom `apk_variants` (jsonb) menyimpan
peta `{abi: url}`; `apk_url` berisi default `arm64-v8a`.

## Catatan Penting

0. **`version_code` di DB = `4000 + buildNumber`, bukan buildNumber polos.**
   Build split-per-abi meng-offset `versionCode` per ABI:
   build 2 → `1002` (armeabi-v7a), `2002` (arm64-v8a), `4002` (x86_64);
   build 3 → `1003`, `2003`, `4003`.

   Aplikasi **versi lama** membandingkan `versionCode` polos:
   `latest.versionCode > PackageInfo.buildNumber`.
   Bila DB menyimpan angka polos (`3`), perbandingan itu selalu false
   (`3 > 2002` salah) → dialog pembaruan **tidak pernah muncul** di HP user.

   Karena itu DB menyimpan sentinel `4000 + buildNumber` (`4003` untuk
   build 3) — selalu lebih besar dari offset ABI mana pun, sehingga
   aplikasi versi lama pun tetap mendeteksi rilis baru.
   `tool/release.sh` sudah otomatis memakai `4000 + buildNumber`.

   Aplikasi **versi baru** membandingkan `version_name` secara semantik
   (`compareVersions('1.0.2', '1.0.1')`), yang tidak terpengaruh offset ABI.
1. **`versionCode` harus naik** setiap rilis. `version:` di `pubspec.yaml` =
   `name+code`, contoh `1.0.1+2`. Kode = `buildNumber` Android.
   Kalau tidak naik, `checkForUpdate()` tidak mendeteksi apa-apa.
2. **Signing key harus sama** dengan build sebelumnya. Kalau berubah,
   Android menolak instalasi ("app not installed" / signature mismatch).
   Key release TenMu:
   - `android/app/tenmu-release.jks` (PKCS12, alias `tenmu`)
   - `android/key.properties` (isi password — **jangan di-commit**)

   kedua file sudah masuk `.gitignore`. **Backup keduanya** di tempat aman
   (mis. cloud drive). Kalau hilang, semua update selanjutnya mustahil.

   Fingerprint SHA-256 certificate saat ini:
   `01:56:5A:8E:C0:55:6B:7A:37:68:01:2C:3F:39:D3:77:9F:2B:C3:3D:EF:D3:9D:FF:DA:FA:2A:EF:55:5D:E5:F8`

   Cek signature APK:
   ```bash
   python -c "import subprocess,glob,os;apk=sorted(glob.glob('build/app/outputs/flutter-apk/app-*-release.apk'))[0];print(subprocess.run([r'%LOCALAPPDATA%\Android\Sdk\build-tools\37.0.0\apksigner.bat','verify','--print-certs',apk],capture_output=True,text=True).stdout)"
   ```

   Untuk rilis pertama, install APK 1.0.1 ke HP secara manual — setelah itu
   semua update berikutnya cukup lewat dialog dalam aplikasi.
3. **Izin install**: Android 8+ minta izin "install unknown apps" saat
   installer dibuka. User pertama kali akan diarahkan ke pengaturan.
   Manifest sudah punya `REQUEST_INSTALL_PACKAGES`.
4. **Bucket harus publik** supaya APK bisa diunduh tanpa login Supabase
   (RLS: `public read app releases`).
5. **`service_role` key tidak disimpan di repo.** `tool/storage_upload.py`
   mengambilnya on-the-fly dari Management API memakai PAT di
   `~/.supabase/profile`.

## Cek Manual

```bash
# Lihat versi terdaftar
python tool/insert_version.py  # (untuk insert)
# atau langsung via SQL:
# select version_code, version_name, apk_url, is_active from app_versions order by version_code desc;

# Cek APK bisa diunduh publik
curl -I "$SUPABASE_URL/storage/v1/object/public/app-releases/tenmu-<version>.apk"
```

## Tabel `app_versions`

| Kolom | Tipe | Arti |
|-------|------|------|
| `version_code` | int | WAJIB unik. Nilai = `4000 + buildNumber` (lihat Catatan 0) |
| `version_name` | text | mis. `1.0.1` (display) |
| `changelog` | text | catatan rilis, tampil di dialog |
| `apk_url` | text | URL publik file APK di storage |
| `apk_size` | bigint | ukuran file (untuk progress) |
| `is_mandatory` | bool | `true` = user tak bisa skip |
| `is_active` | bool | `false` = nonaktifkan rilis ini |
| `apk_variants` | jsonb | peta `{abi: url}` untuk build split-per-ABI |

## Kenapa Tetap Harus Build?

Build mengompilasi Dart → native binary. Tidak ada cara "push source code"
ke HP user. Yang berubah hanya **cara distribusinya**:

- Manual (sekarang): `flutter build apk` → kirim file → user install manual
- In-app update: `flutter build apk` → upload ke server → user klik "Unduh"
- Play Store: `flutter build appbundle` → upload ke Play Console

Ketiganya tetap build. In-app update jadi yang paling praktis untuk
skripsi/UMKM: user cukup buka app, klik "Unduh", lalu restart.

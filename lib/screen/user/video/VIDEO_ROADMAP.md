# Fitur Video Pendek UMKM — Roadmap Implementasi

Struktur folder mengikuti pola feature-first seperti folder user lainnya.
Status: **tahap persiapan** — file di bawah belum ditulis, ini peta kerja.

```
lib/screen/user/video/
├── video_models.dart          # PlaceVideo + VideoLike (fromJson/toJson)
├── video_provider.dart        # ChangeNotifier: fetch feed, like/unlike, upload,
│                              #   increment views (via RPC)
├── video_feed_screen.dart     # Feed vertikal (PageView) autoplay + entry point
└── widgets/
    ├── video_feed_item.dart   # 1 kartu video: player, caption, like, views,
    │                          #   link ke detail tempat
    └── video_upload_sheet.dart # Bottom sheet upload (owner): pilih video,
                               #   batasi 60s + ukuran, upload ke Storage
```

## Ketergantungan baru (pubspec)

- `video_player` — playback (Android/iOS/web)
- `chewie` — kontrol player (play/pause, fullscreen)
- (opsional) `media_kit` — hanya kalau mau video jalan di Windows desktop

## Kontrak data

### `PlaceVideo` (dari tabel `place_videos`)

```dart
class PlaceVideo {
  final int id;
  final int placeId;
  final String ownerId;
  final String videoPath;      // path di bucket 'videos'
  final String? thumbnailPath;
  final String? caption;
  final int views;
  final bool isActive;
  final DateTime createdAt;
  String get videoUrl => // Supabase storage getPublicUrl(bucket: 'videos', path: videoPath)
}
```

### Query feed (user)

```dart
supabase.from('place_videos').select('''
  *, place:places!inner(name, category, gambar_url, verification_status)
''')
  .eq('is_active', true)
  .eq('place.verification_status', 'verified')  // join: hanya tempat terverifikasi
  .order('created_at', ascending: false)
```

### like/unlike + views

```dart
// like
supabase.from('video_likes').insert({'video_id': id, 'user_id': uid});
// unlike
supabase.from('video_likes').delete().match({'video_id': id, 'user_id': uid});
// views (RPC — user TIDAK boleh update kolom views langsung)
supabase.rpc('increment_video_views', params: {'p_video_id': id});
// count like per video
supabase.from('video_likes').select('video_id').eq('video_id', id); // length
```

### Upload (owner)

1. `ImagePicker().pickVideo(source: gallery, maxDuration: 60s)`
2. Cek ukuran file ≤ ~20MB (reject + snackbar)
3. `supabase.storage.from('videos').upload(path, bytes)` — path: `{ownerId}/{timestamp}.mp4`
4. `supabase.from('place_videos').insert({...})` (RLS menolak jika tempat bukan miliknya)

## Perilaku feed (pola TikTok/Shopee)

- `PageView.builder(scrollDirection: vertical)` — 1 video per halaman
- Autoplay saat halaman aktif (`onPageChanged`), `pause()` saat tidak
- Satu instance player aktif saja; dispose player di luar viewport
- Preview thumbnail dulu, video dimuat saat halaman aktif (lazy load)
- `increment_video_views` dipanggil sekali saat video mulai diputar

## Entry point UI

- Home user: tab/chip "Video" baru (atau ikon di header) → `VideoFeedScreen`
- Detail tempat: section "Video Promosi" → daftar `place_videos` tempat tsb
- Owner: tombol "Upload Video" di `manage_place_screen` → `VideoUploadSheet`

## Di-skip untuk MVP (jangan dikerjakan dulu)

- Komentar, share, edit video, feed algoritma/personalized
- Transcoding/HLS (stream MP4 langsung)
- Verifikasi video oleh admin (cukup takedown via `is_active`)
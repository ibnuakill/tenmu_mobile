# Spec: Portal UMKM Cirebon (Replace Postingan)

## Problem Statement
Fitur "Postingan" (user-generated photo feed dengan like/komentar) tidak sesuai visi aplikasi. User ingin portal konten kurasi UMKM Cirebon (hidden gems, review kuliner, spots menarik) yang dikelola **superadmin saja** via form in-app rich text + gambar. Konten bersumber dari kurasi IG/blog, bukan user-generated.

## Solution
Ganti fitur Postingan dengan **Portal UMKM Cirebon**:
- Superadmin CRUD artikel via admin panel (rich text editor + upload gambar)
- User lihat daftar artikel, detail, filter kategori & kecamatan Cirebon
- Real-time update via Supabase Realtime
- Bookmark/simpan artikel
- Push notifikasi artikel baru
- Home strip menampilkan artikel terbaru (ganti postingan strip)

## User Stories
1. As a **superadmin**, I want to create/edit/delete articles with rich text and images in-app, so I can publish curated UMKM content without leaving the app.
2. As a **superadmin**, I want to categorize articles (kuliner, wisata, hidden gem, tips, event) and tag kecamatan Cirebon, so users can filter relevant content.
3. As a **user**, I want to browse articles in a clean list with thumbnail, title, category, kecamatan, so I can discover UMKM gems.
4. As a **user**, I want to read full article with formatted content and images, so I get complete info.
5. As a **user**, I want to filter articles by category and kecamatan, so I find content relevant to my location/interest.
6. As a **user**, I want to bookmark articles, so I can read later.
7. As a **user**, I want to receive push notification when new article published, so I don't miss updates.
8. As a **user**, I want to see latest articles strip on home screen (replacing old Postingan strip), so I discover content passively.

## Implementation Decisions

### Database (Supabase)
- **New table**: `articles` (replace `place_posts`, `post_likes`, `post_comments`)
  - `id` BIGSERIAL PK
  - `title` TEXT NOT NULL
  - `slug` TEXT UNIQUE NOT NULL (auto from title)
  - `excerpt` TEXT (ringkasan untuk list)
  - `content` TEXT NOT NULL (HTML dari rich text editor)
  - `cover_image_path` TEXT (Storage path)
  - `category` TEXT NOT NULL (kuliner, wisata, hidden_gem, tips, event)
  - `kecamatan` TEXT (nullable, untuk filter lokasi)
  - `is_published` BOOLEAN DEFAULT FALSE
  - `published_at` TIMESTAMPTZ
  - `author_id` UUID REFERENCES auth.users
  - `view_count` INT DEFAULT 0
  - `created_at`, `updated_at` TIMESTAMPTZ
- **New table**: `article_bookmarks` (user bookmarks)
  - `id` BIGSERIAL PK
  - `article_id` BIGINT REFERENCES articles(id) CASCADE
  - `user_id` UUID REFERENCES auth.users CASCADE
  - `created_at` TIMESTAMPTZ
  - UNIQUE (article_id, user_id)
- **Storage bucket**: `article_covers` (public read, authenticated upload)
- **RLS**: Public read published articles; superadmin full CRUD; users bookmark own.

### Admin Panel
- New tab "Artikel UMKM" di AdminHomeScreen (index baru di bottom nav/rail)
- Screen: `ManageArticlesScreen` — list + create/edit form
- Form: rich text editor (flutter_quill atau simple toolbar), cover image picker, category dropdown, kecamatan dropdown, publish toggle
- Reuse `AdminShell`, `AdminDesign` components

### User-Facing
- **New provider**: `ArticlesProvider` (stream articles via Supabase Realtime, filter, bookmark)
- **New screens**: `ArticleListScreen`, `ArticleDetailScreen`
- **Home strip**: `HomeArticlesStrip` (replace `HomePostsStrip`) — horizontal scroll latest published articles
- **Filter bottom sheet**: category chips + kecamatan chips
- **Bookmark**: heart/icon button di list & detail, persist ke `article_bookmarks`
- **Push notification**: `NotificationService.sendNewArticleNotification()` via Edge Function `send-notification`

### Routing
- `/articles` → ArticleListScreen
- `/articles/:slug` → ArticleDetailScreen
- Admin: `/admin/articles` → ManageArticlesScreen

### Migration
- Drop `place_posts`, `post_likes`, `post_comments` tables (data lama tidak dipindahkan, user agreed hapus total)
- Drop storage bucket `posts`
- Run new migration for `articles`, `article_bookmarks`, bucket `article_covers`

## Testing Decisions
- Unit: ArticlesProvider (filter, bookmark toggle, realtime subscription)
- Widget: ArticleListScreen (filter chips, list render), ArticleDetailScreen (rich text render), HomeArticlesStrip
- Integration: Admin create→publish→realtime appears in user app
- E2E: Superadmin login → create article → user sees in home strip → bookmark → push received

## Out of Scope
- User-generated content (komentar, like, submit artikel)
- Multi-author workflow (hanya superadmin)
- SEO/meta tags untuk web (mobile-only)
- Analytics per artikel (view_count basic saja)
- Offline-first/caching artikel (online only)

## Further Notes
- Rich text: pakai `flutter_quill` (sudah di pubspec? cek) atau simple HTML sanitizer + render via `flutter_html`
- Kecamatan Cirebon: hardcode list 5 kecamatan (Kejaksan, Pekalipan, Harjamukti, Lemahwungkuk, Kesambi)
- Kategori: enum konstan di `core/article_category.dart`
- Realtime: subscribe ke `articles` table filter `is_published=true`
- Push: Edge Function `send-notification` sudah ada, tambah payload type `new_article`
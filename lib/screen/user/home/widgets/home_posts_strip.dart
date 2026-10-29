import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/lucide_icons.dart';
import '../../post/post_models.dart';
import '../../post/post_provider.dart';

/// Strip "Postingan terbaru" di beranda.
///
/// Fungsi: memberi eksposur konten komunitas tanpa memindahkan fokus beranda
/// dari pencarian tempat. Isinya ringkas (horizontal), bukan feed penuh —
/// feed penuh tetap punya layar sendiri lewat tombol "Lihat semua".
///
/// Widget ini otomatis tidak menampilkan apa pun bila belum ada postingan
/// atau masih memuat, supaya beranda tidak "melompat" saat data datang.
class HomePostsStrip extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final PostProvider provider;
  final VoidCallback onSeeAll;
  final void Function(PlacePost post) onTapPost;

  const HomePostsStrip({
    super.key,
    required this.theme,
    required this.accent,
    required this.provider,
    required this.onSeeAll,
    required this.onTapPost,
  });

  static const int _maxCards = 8;

  @override
  Widget build(BuildContext context) {
    final posts = provider.posts;
    if (posts.isEmpty) return const SizedBox.shrink();

    final shown = posts.take(_maxCards).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Postingan terbaru',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onSeeAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Lihat semua',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: accent,
                        ),
                      ),
                      const SizedBox(width: 2),
                      LucideIcon('chevron-right', size: 14, color: accent),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 176,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: shown.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) => _PostThumb(
              post: shown[i],
              theme: theme,
              accent: accent,
              likes: provider.likeCount(shown[i].id),
              onTap: () => onTapPost(shown[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _PostThumb extends StatelessWidget {
  final PlacePost post;
  final ThemeProvider theme;
  final Color accent;
  final int likes;
  final VoidCallback onTap;

  const _PostThumb({
    required this.post,
    required this.theme,
    required this.accent,
    required this.likes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = Supabase.instance.client.storage
        .from('posts')
        .getPublicUrl(post.imagePath);
    final label = post.hasPlace
        ? post.placeName
        : (post.caption?.trim().isNotEmpty ?? false)
        ? post.caption!.trim()
        : 'Postingan';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 140,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 200),
                placeholder: (_, __) => Container(color: theme.bgSurface),
                errorWidget: (_, __, ___) => Container(
                  color: theme.bgSurface,
                  child: Center(
                    child: LucideIcon(
                      'image-off',
                      size: 20,
                      color: theme.textHint,
                    ),
                  ),
                ),
              ),
              // Gradien bawah agar teks selalu terbaca di atas foto apa pun.
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xB3000000)],
                    stops: [0.45, 1.0],
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (likes > 0)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const LucideIcon(
                          'heart',
                          size: 11,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '$likes',
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

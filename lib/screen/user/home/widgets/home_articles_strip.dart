import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/lucide_icons.dart';
import '../../../../core/article_models.dart';
import '../../../../core/articles_provider.dart';

/// Strip "Artikel terbaru" di beranda.
///
/// Menampilkan artikel Portal UMKM terbaru secara horizontal. Otomatis
/// tidak menampilkan apa pun bila belum ada artikel atau masih memuat,
/// supaya beranda tidak "melompat" saat data datang.
class HomeArticlesStrip extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final ArticlesProvider provider;
  final VoidCallback onSeeAll;
  final void Function(Article article) onTapArticle;

  const HomeArticlesStrip({
    super.key,
    required this.theme,
    required this.accent,
    required this.provider,
    required this.onSeeAll,
    required this.onTapArticle,
  });

  static const int _maxCards = 8;

  @override
  Widget build(BuildContext context) {
    final articles = provider.articles;
    if (articles.isEmpty) return const SizedBox.shrink();

    final shown = articles.take(_maxCards).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Artikel terbaru',
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
            itemBuilder: (context, i) => _ArticleThumb(
              article: shown[i],
              theme: theme,
              accent: accent,
              onTap: () => onTapArticle(shown[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class _ArticleThumb extends StatelessWidget {
  final Article article;
  final ThemeProvider theme;
  final Color accent;
  final VoidCallback onTap;

  const _ArticleThumb({
    required this.article,
    required this.theme,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = article.getCoverUrl();

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
              if (url != null)
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
                )
              else
                Container(
                  color: theme.bgSurface,
                  child: Center(
                    child: LucideIcon(
                      'notebook-text',
                      size: 22,
                      color: theme.textHint,
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
                    stops: [0.35, 1.0],
                  ),
                ),
              ),
              // Badge kategori di atas.
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${article.category.emoji} ${article.category.label}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Text(
                  article.title,
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
            ],
          ),
        ),
      ),
    );
  }
}

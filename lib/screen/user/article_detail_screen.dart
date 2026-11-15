import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/articles_provider.dart';
import '../../core/article_models.dart';
import '../../core/theme_provider.dart';
import '../../core/lucide_icons.dart';

/// Screen detail artikel Portal UMKM.
class ArticleDetailScreen extends StatefulWidget {
  final Article article;

  const ArticleDetailScreen({super.key, required this.article});

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late ArticlesProvider _provider;
  bool _isBookmarked = false;
  bool _incrementedView = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ArticlesProvider>();
    _isBookmarked = _provider.isBookmarked(widget.article.id);
    _incrementViewCount();
  }

  Future<void> _incrementViewCount() async {
    if (_incrementedView) return;
    await _provider.incrementViewCount(widget.article.id);
    _incrementedView = true;
  }

  Future<void> _toggleBookmark() async {
    await _provider.toggleBookmark(widget.article.id);
    setState(() {
      _isBookmarked = _provider.isBookmarked(widget.article.id);
    });
  }

  Future<void> _shareArticle() async {
    final url = 'https://tenmu.app/articles/${widget.article.slug}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final article = widget.article;
    final coverUrl = article.getCoverUrl();

    return Scaffold(
      backgroundColor: theme.bgBase,
      body: CustomScrollView(
        slivers: [
          // App bar with cover image
          SliverAppBar(
            expandedHeight: coverUrl != null ? 280 : 120,
            pinned: true,
            stretch: true,
            backgroundColor: theme.bgBase,
            surfaceTintColor: Colors.transparent,
            iconTheme: IconThemeData(color: theme.textPrimary),
            actionsIconTheme: IconThemeData(color: theme.textPrimary),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [StretchMode.zoomBackground],
              background: coverUrl != null
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Container(color: theme.bgSurface),
                        ),
                        // Gradient overlay
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Colors.transparent, Color(0xB3000000)],
                              stops: [0.5, 1.0],
                            ),
                          ),
                        ),
                        // Category badge
                        Positioned(
                          top: 60,
                          left: 16,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: article.category.color,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  article.category.icon,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  article.category.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            article.category.color.withValues(alpha: 0.2),
                            article.category.color.withValues(alpha: 0.05),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          article.category.icon,
                          size: 64,
                          color: article.category.color.withValues(alpha: 0.5),
                        ),
                      ),
                    ),
            ),
            actions: [
              // Bookmark
              IconButton(
                icon: Icon(
                  _isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                ),
                color: _isBookmarked ? Colors.amber : theme.textPrimary,
                onPressed: _toggleBookmark,
                tooltip: _isBookmarked ? 'Hapus bookmark' : 'Simpan artikel',
              ),
              // Share
              IconButton(
                icon: LucideIcon('share-2', size: 22),
                color: theme.textPrimary,
                onPressed: _shareArticle,
                tooltip: 'Bagikan',
              ),
            ],
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Meta row
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: [
                      if (article.kecamatan != null)
                        _MetaChip(
                          icon: Icons.location_on_outlined,
                          label: article.kecamatan!.label,
                          color: article.category.color,
                        ),
                      _MetaChip(
                        icon: Icons.visibility_outlined,
                        label: '${article.viewCount} dilihat',
                        color: theme.textHint,
                      ),
                      _MetaChip(
                        icon: Icons.timer_outlined,
                        label: '${article.readingTimeMinutes} min baca',
                        color: theme.textHint,
                      ),
                      if (article.publishedAt != null)
                        _MetaChip(
                          icon: Icons.calendar_today_outlined,
                          label: _formatDate(article.publishedAt!),
                          color: theme.textHint,
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Divider
                  Divider(color: theme.border, thickness: 1),
                  const SizedBox(height: 16),
                  // Content (Markdown)
                  MarkdownBody(
                    data: article.content,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                        .copyWith(
                          p: TextStyle(
                            fontSize: 15,
                            height: 1.7,
                            color: theme.textPrimary,
                          ),
                          h1: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                          h2: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                          h3: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: theme.textPrimary,
                          ),
                          a: TextStyle(
                            color: article.category.color,
                            fontWeight: FontWeight.w600,
                          ),
                          blockquote: TextStyle(
                            fontSize: 15,
                            height: 1.6,
                            color: theme.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                          code: TextStyle(
                            fontSize: 13,
                            fontFamily: 'monospace',
                            color: article.category.color,
                            backgroundColor: article.category.color.withValues(
                              alpha: 0.1,
                            ),
                          ),
                          codeblockDecoration: BoxDecoration(
                            color: theme.bgElevated,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                    imageBuilder: (uri, title, alt) => Container(
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.border),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          uri.toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            color: theme.bgSurface,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  LucideIcon(
                                    'image-off',
                                    size: 40,
                                    color: theme.textHint,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Gambar tidak dapat dimuat',
                                    style: TextStyle(color: theme.textHint),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        await launchUrl(
                          Uri.parse(href),
                          mode: LaunchMode.externalApplication,
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 32),
                  // Divider
                  Divider(color: theme.border, thickness: 1),
                  const SizedBox(height: 16),
                  // Related articles placeholder
                  Text(
                    'Artikel Terkait',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _RelatedArticles(
                    theme: theme,
                    accentColor: article.category.color,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month]} ${date.year}';
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _RelatedArticles extends StatelessWidget {
  final ThemeProvider theme;
  final Color accentColor;

  const _RelatedArticles({required this.theme, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    // Placeholder - akan diisi dengan query articles by category
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: 3,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) => Container(
          width: 200,
          decoration: BoxDecoration(
            color: theme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.article_outlined,
                    size: 40,
                    color: accentColor.withValues(alpha: 0.5),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Artikel Terkait ${i + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ringkasan artikel terkait...',
                      style: TextStyle(fontSize: 11, color: theme.textHint),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

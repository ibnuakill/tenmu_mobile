import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/articles_provider.dart';
import '../../core/article_models.dart';
import '../../core/article_category.dart';
import '../../core/theme_provider.dart';
import '../../core/lucide_icons.dart';
import '../user/article_detail_screen.dart';

/// Screen daftar artikel Portal UMKM Cirebon.
class ArticleListScreen extends StatefulWidget {
  const ArticleListScreen({super.key});

  @override
  State<ArticleListScreen> createState() => _ArticleListScreenState();
}

class _ArticleListScreenState extends State<ArticleListScreen> {
  late ArticlesProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = context.read<ArticlesProvider>();
    _provider.loadArticles();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilterBottomSheet(provider: _provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.btnPrimary;

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Portal UMKM Cirebon',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: theme.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: LucideIcon('search', size: 22, color: theme.textPrimary),
            onPressed: () => _showSearchSheet(),
          ),
          IconButton(
            icon: LucideIcon('filter', size: 22, color: theme.textPrimary),
            onPressed: _openFilterSheet,
          ),
        ],
      ),
      body: _provider.isLoading && _provider.allArticles.isEmpty
          ? Center(child: CircularProgressIndicator(color: accent))
          : _provider.error != null
          ? _ErrorState(
              theme: theme,
              message: _provider.error!,
              onRetry: () => _provider.loadArticles(force: true),
            )
          : _provider.articles.isEmpty
          ? _EmptyState(
              theme: theme,
              hasFilter: _provider.hasActiveFilter,
              onClear: _provider.clearFilters,
            )
          : RefreshIndicator(
              onRefresh: () => _provider.loadArticles(force: true),
              color: accent,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _provider.articles.length,
                itemBuilder: (ctx, i) => _ArticleListTile(
                  article: _provider.articles[i],
                  theme: theme,
                  accent: accent,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          ArticleDetailScreen(article: _provider.articles[i]),
                    ),
                  ),
                  onBookmarkToggle: () =>
                      _provider.toggleBookmark(_provider.articles[i].id),
                  isBookmarked: _provider.isBookmarked(
                    _provider.articles[i].id,
                  ),
                ),
              ),
            ),
    );
  }

  void _showSearchSheet() {
    final ctrl = TextEditingController(text: _provider.searchQuery);
    final theme = context.read<ThemeProvider>();
    final accent = theme.btnPrimary;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.bgBase,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Cari Artikel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Cari judul, ringkasan, atau konten...',
                  prefixIcon: LucideIcon(
                    'search',
                    size: 20,
                    color: theme.textHint,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: theme.bgSurface,
                ),
                onSubmitted: (v) {
                  _provider.setSearchQuery(v);
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _provider.setSearchQuery('');
                        Navigator.pop(ctx);
                      },
                      child: const Text('Bersihkan'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        _provider.setSearchQuery(ctrl.text);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: accent),
                      child: const Text('Cari'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile artikel di list.
class _ArticleListTile extends StatelessWidget {
  final Article article;
  final ThemeProvider theme;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;
  final bool isBookmarked;

  const _ArticleListTile({
    required this.article,
    required this.theme,
    required this.accent,
    required this.onTap,
    required this.onBookmarkToggle,
    required this.isBookmarked,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = article.getCoverUrl();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            if (coverUrl != null)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          color: theme.bgElevated,
                          child: Center(
                            child: LucideIcon(
                              'image-off',
                              size: 40,
                              color: theme.textHint,
                            ),
                          ),
                        ),
                      ),
                      // Category badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
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
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                article.category.label,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Bookmark button
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onBookmarkToggle,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Icon(
                                isBookmarked
                                    ? Icons.bookmark
                                    : Icons.bookmark_outline,
                                size: 20,
                                color: isBookmarked
                                    ? Colors.amber
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (article.excerpt != null &&
                      article.excerpt!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      article.excerpt!,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Meta row
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (article.kecamatan != null)
                        _MetaChip(
                          icon: Icons.location_on_outlined,
                          label: article.kecamatan!.label,
                          color: accent,
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
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        Icon(icon, size: 13, color: color),
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

/// Filter bottom sheet.
class _FilterBottomSheet extends StatefulWidget {
  final ArticlesProvider provider;

  const _FilterBottomSheet({required this.provider});

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late ArticleCategory? _tempCategory;
  late KecamatanCirebon? _tempKecamatan;

  @override
  void initState() {
    super.initState();
    _tempCategory = widget.provider.selectedCategory;
    _tempKecamatan = widget.provider.selectedKecamatan;
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgBase,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Filter Artikel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  setState(() {
                    _tempCategory = null;
                    _tempKecamatan = null;
                  });
                },
                child: Text('Reset', style: TextStyle(color: theme.btnPrimary)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Kategori',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Semua',
                selected: _tempCategory == null,
                onTap: () => setState(() => _tempCategory = null),
              ),
              ...ArticleCategory.values.map(
                (c) => _FilterChip(
                  label: c.label,
                  icon: c.icon,
                  color: c.color,
                  selected: _tempCategory == c,
                  onTap: () => setState(() => _tempCategory = c),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Kecamatan',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChip(
                label: 'Semua',
                selected: _tempKecamatan == null,
                onTap: () => setState(() => _tempKecamatan = null),
              ),
              ...KecamatanCirebon.values.map(
                (k) => _FilterChip(
                  label: k.label,
                  icon: Icons.location_on_outlined,
                  color: theme.btnPrimary,
                  selected: _tempKecamatan == k,
                  onTap: () => setState(() => _tempKecamatan = k),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                widget.provider.setCategoryFilter(_tempCategory);
                widget.provider.setKecamatanFilter(_tempKecamatan);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.btnPrimary,
              ),
              child: const Text(
                'Terapkan',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color? color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    this.icon,
    this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final c = color ?? theme.btnPrimary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : c.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: selected ? Colors.white : c),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final ThemeProvider theme;
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.theme,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon('alert-triangle', size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Gagal Memuat',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: LucideIcon('refresh-cw', size: 18),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final ThemeProvider theme;
  final bool hasFilter;
  final VoidCallback onClear;

  const _EmptyState({
    required this.theme,
    required this.hasFilter,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon('notebook-text', size: 64, color: theme.textHint),
            const SizedBox(height: 16),
            Text(
              hasFilter ? 'Tidak ada artikel' : 'Belum ada artikel',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hasFilter
                  ? 'Coba ubah filter atau kata kunci pencarian'
                  : 'Artikel akan muncul di sini saat admin mempublikasikan',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary),
            ),
            if (hasFilter) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: onClear,
                icon: LucideIcon('x', size: 18),
                label: const Text('Hapus Filter'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

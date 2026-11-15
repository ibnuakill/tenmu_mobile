import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/article_category.dart';
import '../../../core/article_models.dart';
import '../../../core/articles_provider.dart';
import '../../../core/notification_center.dart';
import '../../../core/theme_provider.dart';
import '../dashboard/widgets/admin_design.dart';

/// Screen admin untuk kelola artikel Portal UMKM.
class ManageArticlesScreen extends StatefulWidget {
  const ManageArticlesScreen({super.key});

  @override
  State<ManageArticlesScreen> createState() => _ManageArticlesScreenState();
}

class _ManageArticlesScreenState extends State<ManageArticlesScreen> {
  final ArticlesProvider _provider = ArticlesProvider();
  bool _isLoading = true;
  String? _error;
  List<Article> _articles = [];

  @override
  void initState() {
    super.initState();
    _loadArticles();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _loadArticles() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('articles')
          .select()
          .order('created_at', ascending: false)
          .limit(100);

      _articles = (response as List)
          .map((e) => Article.fromMap(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openEditor({Article? article}) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ArticleEditorSheet(article: article),
    );

    if (result == true && mounted) {
      _loadArticles();
    }
  }

  Future<void> _deleteArticle(Article article) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        title: Text('Hapus Artikel', style: TextStyle(color: kTextPrimary)),
        content: Text(
          'Yakin hapus "${article.title}"? Tindakan ini tidak bisa dibatalkan.',
          style: TextStyle(color: kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: TextStyle(color: kTextMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final err = await _provider.deleteArticle(article.id);
    if (err != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(err), backgroundColor: Colors.red));
    } else if (mounted) {
      _loadArticles();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Artikel dihapus'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Kelola Artikel UMKM',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: theme.textPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.btnPrimary))
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: TextStyle(color: theme.snackErrorBorder),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _loadArticles,
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Toolbar
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: theme.bgSurface,
                    border: Border(bottom: BorderSide(color: theme.border)),
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total: ${_articles.length} artikel',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _openEditor(),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text(
                              'Tambah Artikel',
                              style: TextStyle(fontSize: 13),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.btnPrimary,
                              foregroundColor: theme.btnLabel,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // List
                Expanded(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: _articles.isEmpty
                          ? Center(
                              child: Text(
                                'Belum ada artikel.\nTambahkan artikel pertama!',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: theme.textHint,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(
                                16,
                                12,
                                16,
                                24,
                              ),
                              itemCount: _articles.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 6),
                              itemBuilder: (ctx, i) => _ArticleAdminTile(
                                article: _articles[i],
                                theme: theme,
                                onEdit: () =>
                                    _openEditor(article: _articles[i]),
                                onDelete: () => _deleteArticle(_articles[i]),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// Tile artikel di daftar admin.
class _ArticleAdminTile extends StatelessWidget {
  final Article article;
  final ThemeProvider theme;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ArticleAdminTile({
    required this.article,
    required this.theme,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final coverUrl = article.getCoverUrl();
    final statusColor = article.isPublished ? Colors.green : Colors.orange;
    final statusText = article.isPublished ? 'Published' : 'Draft';

    // Layout baris: thumbnail kecil di kiri, teks di kanan. Versi lama pakai
    // cover 16:9 selebar container sehingga di desktop jadi raksasa.
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.border),
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 72,
              height: 72,
              child: coverUrl == null
                  ? Container(
                      color: theme.bgElevated,
                      child: Icon(
                        Icons.image_outlined,
                        size: 20,
                        color: theme.textHint,
                      ),
                    )
                  : Image.network(
                      coverUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: theme.bgElevated,
                        child: Icon(
                          Icons.image_not_supported,
                          size: 18,
                          color: theme.textHint,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        article.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _ChipLabel(
                      label: article.category.label,
                      icon: article.category.icon,
                      color: article.category.color,
                    ),
                    if (article.kecamatan != null)
                      _ChipLabel(
                        label: article.kecamatan!.label,
                        icon: Icons.location_on_outlined,
                        color: theme.btnPrimary,
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      'Views: ${article.viewCount}',
                      style: TextStyle(fontSize: 11, color: theme.textHint),
                    ),
                    const Spacer(),
                    _MiniAction(
                      label: 'Edit',
                      icon: Icons.edit_outlined,
                      color: theme.btnPrimary,
                      onTap: onEdit,
                    ),
                    const SizedBox(width: 4),
                    _MiniAction(
                      label: 'Hapus',
                      icon: Icons.delete_outline,
                      color: Colors.red,
                      onTap: onDelete,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tombol aksi kecil (Edit/Hapus) supaya tingginya tidak memakan ruang.
class _MiniAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipLabel extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _ChipLabel({
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet editor untuk create/edit artikel.
class _ArticleEditorSheet extends StatefulWidget {
  final Article? article;

  const _ArticleEditorSheet({this.article});

  @override
  State<_ArticleEditorSheet> createState() => _ArticleEditorSheetState();
}

class _ArticleEditorSheetState extends State<_ArticleEditorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _excerptCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();
  ArticleCategory _category = ArticleCategory.kuliner;
  KecamatanCirebon? _kecamatan;
  bool _isPublished = false;
  bool _isSaving = false;
  String? _coverImagePath;
  Uint8List? _coverImageBytes;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    if (widget.article != null) {
      final a = widget.article!;
      _titleCtrl.text = a.title;
      _excerptCtrl.text = a.excerpt ?? '';
      _contentCtrl.text = a.content;
      _category = a.category;
      _kecamatan = a.kecamatan;
      _isPublished = a.isPublished;
      _coverImagePath = a.coverImagePath;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _excerptCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCoverImage() async {
    final xFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (xFile == null) return;

    final bytes = await xFile.readAsBytes();
    setState(() {
      _coverImageBytes = bytes;
      // Generate path
      final ext = xFile.name.split('.').last;
      _coverImagePath = 'covers/${DateTime.now().millisecondsSinceEpoch}.$ext';
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = ArticlesProvider();
    String? err;

    // Upload cover image if new
    String? finalCoverPath = _coverImagePath;
    if (_coverImageBytes != null && _coverImagePath != null) {
      err = await provider.uploadCoverImage(
        _coverImagePath!,
        _coverImageBytes!,
      );
      if (err != null) {
        _showError(err);
        return;
      }
      finalCoverPath = _coverImagePath;
    }

    if (widget.article == null) {
      // Create
      err = await provider.createArticle(
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        excerpt: _excerptCtrl.text.trim().isEmpty
            ? null
            : _excerptCtrl.text.trim(),
        coverImagePath: finalCoverPath,
        category: _category,
        kecamatan: _kecamatan,
        isPublished: _isPublished,
      );
    } else {
      // Update
      err = await provider.updateArticle(
        id: widget.article!.id,
        title: _titleCtrl.text.trim(),
        content: _contentCtrl.text.trim(),
        excerpt: _excerptCtrl.text.trim().isEmpty
            ? null
            : _excerptCtrl.text.trim(),
        coverImagePath: finalCoverPath,
        category: _category,
        kecamatan: _kecamatan,
        isPublished: _isPublished,
      );
    }

    if (err != null) {
      _showError(err);
      return;
    }

    // Broadcast push kalau artikel baru dipublikasikan (baru dibuat atau
    // berubah dari draft → published).
    final wasPublished = widget.article?.isPublished ?? false;
    if (_isPublished && !wasPublished) {
      unawaited(
        notifyNewArticle(
          articleId: widget.article?.id ?? 0,
          title: _titleCtrl.text.trim(),
          excerpt: _excerptCtrl.text.trim(),
        ),
      );
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  void _showError(String msg) {
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.article != null;
    final size = MediaQuery.of(context).size;
    final isWide = size.width >= 900;
    final theme = context.watch<ThemeProvider>();

    // Di desktop sheet dibatasi 880px & diberi radius penuh, supaya input
    // tidak melar selebar monitor.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Container(
          height: size.height * (isWide ? 0.86 : 0.9),
          decoration: BoxDecoration(
            color: theme.bgBase,
            borderRadius: isWide
                ? BorderRadius.circular(16)
                : const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.border)),
                ),
                child: Row(
                  children: [
                    Text(
                      isEdit ? 'Edit Artikel' : 'Artikel Baru',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: theme.textPrimary),
                    ),
                  ],
                ),
              ),
              // Form
              Expanded(
                child: Form(
                  key: _formKey,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        children: [
                          // Cover image
                          Align(
                            alignment: Alignment.centerLeft,
                            child: GestureDetector(
                              onTap: _pickCoverImage,
                              child: Container(
                                height: isWide ? 150 : 180,
                                width: isWide ? 280 : double.infinity,
                                decoration: BoxDecoration(
                                  color: theme.bgElevated,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: theme.border),
                                ),
                                child: _coverImageBytes != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.memory(
                                          _coverImageBytes!,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : _coverImagePath != null
                                    ? FutureBuilder<String?>(
                                        future: Supabase.instance.client.storage
                                            .from('article_covers')
                                            .createSignedUrl(
                                              _coverImagePath!,
                                              60,
                                            ),
                                        builder: (ctx, snap) {
                                          if (snap.hasData &&
                                              snap.data != null) {
                                            return ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              child: Image.network(
                                                snap.data!,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    _placeholder(theme),
                                              ),
                                            );
                                          }
                                          return _placeholder(theme);
                                        },
                                      )
                                    : _placeholder(theme),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Title
                          TextFormField(
                            controller: _titleCtrl,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: _deco(
                              theme,
                              label: 'Judul *',
                              hint: 'Contoh: Hidden Gem Kopi di Kejaksan',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Judul wajib diisi'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Excerpt
                          TextFormField(
                            controller: _excerptCtrl,
                            maxLines: 2,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: _deco(
                              theme,
                              label: 'Ringkasan (opsional)',
                              hint: 'Ringkasan singkat untuk preview di list',
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Content (markdown)
                          TextFormField(
                            controller: _contentCtrl,
                            maxLines: 10,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: _deco(
                              theme,
                              label: 'Konten (Markdown) *',
                              hint:
                                  '# Judul\n\nTulis konten di sini...\n\n## Subjudul\n\n- List item\n- Item lain\n\n![Alt text](url_gambar)',
                              alignLabel: true,
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Konten wajib diisi'
                                : null,
                          ),
                          const SizedBox(height: 12),

                          // Markdown preview toggle
                          _MarkdownPreview(contentCtrl: _contentCtrl),
                          const SizedBox(height: 16),

                          // Category dropdown
                          DropdownButtonFormField<ArticleCategory>(
                            value: _category,
                            dropdownColor: theme.bgSurface,
                            iconEnabledColor: theme.textSecondary,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: _deco(theme, label: 'Kategori *'),
                            items: ArticleCategory.values
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Row(
                                      children: [
                                        Icon(c.icon, size: 18, color: c.color),
                                        const SizedBox(width: 8),
                                        Text(
                                          c.label,
                                          style: TextStyle(
                                            color: theme.textPrimary,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setState(() => _category = v!),
                          ),
                          const SizedBox(height: 12),

                          // Kecamatan dropdown
                          DropdownButtonFormField<KecamatanCirebon>(
                            value: _kecamatan,
                            dropdownColor: theme.bgSurface,
                            iconEnabledColor: theme.textSecondary,
                            style: TextStyle(color: theme.textPrimary),
                            decoration: _deco(
                              theme,
                              label: 'Kecamatan (opsional)',
                            ),
                            items: [
                              DropdownMenuItem<KecamatanCirebon>(
                                value: null,
                                child: Text(
                                  '— Tanpa kecamatan —',
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ...KecamatanCirebon.values.map(
                                (k) => DropdownMenuItem(
                                  value: k,
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 18,
                                        color: theme.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        k.label,
                                        style: TextStyle(
                                          color: theme.textPrimary,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (v) => setState(() => _kecamatan = v),
                          ),
                          const SizedBox(height: 16),

                          // Published toggle
                          SwitchListTile(
                            title: Text(
                              'Publish sekarang',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              _isPublished
                                  ? 'Artikel akan langsung muncul di aplikasi'
                                  : 'Artikel disimpan sebagai draft',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            value: _isPublished,
                            onChanged: (v) => setState(() => _isPublished = v),
                            activeThumbColor: theme.btnPrimary,
                          ),
                          const SizedBox(height: 24),

                          // Save button
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SizedBox(
                              width: isWide ? 240 : double.infinity,
                              height: isWide ? 44 : 48,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _save,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.btnPrimary,
                                  foregroundColor: theme.btnLabel,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSaving
                                    ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: theme.btnLabel,
                                        ),
                                      )
                                    : Text(
                                        isEdit
                                            ? 'Simpan Perubahan'
                                            : 'Publikasikan',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(ThemeProvider theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 36,
          color: theme.textHint,
        ),
        const SizedBox(height: 8),
        Text(
          'Klik untuk pilih cover',
          style: TextStyle(color: theme.textSecondary, fontSize: 12.5),
        ),
      ],
    );
  }

  /// Dekorasi input standar yang mengikuti tema (gelap/terang).
  InputDecoration _deco(
    ThemeProvider theme, {
    required String label,
    String? hint,
    bool alignLabel = false,
  }) {
    final radius = BorderRadius.circular(10);
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabel,
      labelStyle: TextStyle(color: theme.textSecondary),
      hintStyle: TextStyle(color: theme.textHint, fontSize: 13),
      filled: true,
      fillColor: theme.bgSurface,
      enabledBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: theme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: theme.borderFocus),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: theme.snackErrorBorder),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(color: theme.snackErrorBorder),
      ),
    );
  }
}

/// Preview markdown sederhana.
class _MarkdownPreview extends StatefulWidget {
  final TextEditingController contentCtrl;

  const _MarkdownPreview({required this.contentCtrl});

  @override
  State<_MarkdownPreview> createState() => _MarkdownPreviewState();
}

class _MarkdownPreviewState extends State<_MarkdownPreview> {
  bool _showPreview = false;

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Preview',
              style: TextStyle(fontSize: 13, color: theme.textSecondary),
            ),
            const Spacer(),
            Switch(
              value: _showPreview,
              onChanged: (v) => setState(() => _showPreview = v),
              activeThumbColor: theme.btnPrimary,
            ),
          ],
        ),
        if (_showPreview)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.bgSurface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.border),
            ),
            child: MarkdownBody(
              data: widget.contentCtrl.text,
              styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                  .copyWith(
                    p: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: theme.textPrimary,
                    ),
                    h1: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                    h2: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                    h3: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                    listBullet: TextStyle(color: theme.textPrimary),
                    strong: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
          ),
      ],
    );
  }
}

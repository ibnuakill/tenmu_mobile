import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/articles_repository.dart';
import '../core/article_models.dart';
import '../core/article_category.dart';

/// Provider untuk state artikel Portal UMKM Cirebon.
///
/// Semua akses data lewat [ArticlesRepository] — provider tidak lagi query
/// lewat `Supabase.instance.client`. Channel realtime tetap di sini karena
/// sifatnya infrastruktur, bukan query.
class ArticlesProvider extends ChangeNotifier {
  final ArticlesRepository _repo;
  final SupabaseClient _client = Supabase.instance.client;

  List<Article> _articles = [];
  List<Article> _filteredArticles = [];
  bool _isLoading = false;
  String? _error;
  RealtimeChannel? _realtimeChannel;

  // Filter state
  ArticleCategory? _selectedCategory;
  KecamatanCirebon? _selectedKecamatan;
  String _searchQuery = '';

  // Bookmarks (cached per user)
  Set<int> _bookmarkedArticleIds = {};

  // Getters
  List<Article> get articles => _filteredArticles;
  List<Article> get allArticles => _articles;
  bool get isLoading => _isLoading;
  String? get error => _error;
  ArticleCategory? get selectedCategory => _selectedCategory;
  KecamatanCirebon? get selectedKecamatan => _selectedKecamatan;
  String get searchQuery => _searchQuery;
  Set<int> get bookmarkedArticleIds => _bookmarkedArticleIds;
  bool get hasActiveFilter =>
      _selectedCategory != null ||
      _selectedKecamatan != null ||
      _searchQuery.isNotEmpty;

  /// [repo] bisa di-inject untuk test; default pakai client global.
  ArticlesProvider({ArticlesRepository? repo})
      : _repo = repo ?? ArticlesRepository(Supabase.instance.client) {
    _initRealtime();
    _loadBookmarks();
  }

  @override
  void dispose() {
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  /// Initialize Supabase Realtime subscription untuk articles.
  void _initRealtime() {
    _realtimeChannel = _client
        .channel('public:articles')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'articles',
          callback: (payload) {
            _handleRealtimeChange(payload);
          },
        )
        .subscribe();
  }

  /// Handle realtime changes dari Supabase.
  void _handleRealtimeChange(PostgresChangePayload payload) {
    final record = payload.newRecord;
    final oldRecord = payload.oldRecord;

    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final article = Article.fromMap(record);
        _articles.insert(0, article);
        _applyFilters();
        break;
      case PostgresChangeEvent.update:
        final article = Article.fromMap(record);
        final index = _articles.indexWhere((a) => a.id == article.id);
        if (index != -1) {
          _articles[index] = article;
        } else {
          _articles.insert(0, article);
        }
        _applyFilters();
        break;
      case PostgresChangeEvent.delete:
        final id = oldRecord['id'] as int;
        _articles.removeWhere((a) => a.id == id);
        _bookmarkedArticleIds.remove(id);
        _applyFilters();
        break;
      default:
        break;
    }
    notifyListeners();
  }

  /// Load all published articles dari Supabase.
  Future<void> loadArticles({bool force = false}) async {
    if (_isLoading && !force) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final maps = await _repo.fetchPublished();
      _articles = maps.map(Article.fromMap).toList();

      _applyFilters();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = 'Gagal memuat artikel: $e';
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load article by slug (untuk detail screen).
  Future<Article?> getArticleBySlug(String slug) async {
    try {
      final map = await _repo.fetchBySlug(slug);
      if (map == null) return null;
      return Article.fromMap(map);
    } catch (e) {
      debugPrint('Error getArticleBySlug: $e');
      return null;
    }
  }

  /// Increment view count (fire and forget).
  Future<void> incrementViewCount(int articleId) async {
    try {
      await _repo.incrementViewRpc(articleId);
    } catch (e) {
      debugPrint('Error incrementViewCount: $e');
    }
  }

  /// Apply filters ke daftar artikel.
  void _applyFilters() {
    var filtered = _articles.where((a) => a.isPublished).toList();

    if (_selectedCategory != null) {
      filtered = filtered.where((a) => a.category == _selectedCategory).toList();
    }
    if (_selectedKecamatan != null) {
      filtered = filtered
          .where((a) => a.kecamatan == _selectedKecamatan)
          .toList();
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (a) =>
                a.title.toLowerCase().contains(q) ||
                (a.excerpt?.toLowerCase().contains(q) ?? false) ||
                a.content.toLowerCase().contains(q),
          )
          .toList();
    }

    _filteredArticles = filtered;
  }

  /// Set filter kategori.
  void setCategoryFilter(ArticleCategory? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Set filter kecamatan.
  void setKecamatanFilter(KecamatanCirebon? kecamatan) {
    _selectedKecamatan = kecamatan;
    _applyFilters();
    notifyListeners();
  }

  /// Set search query.
  void setSearchQuery(String query) {
    _searchQuery = query.trim();
    _applyFilters();
    notifyListeners();
  }

  /// Clear semua filter.
  void clearFilters() {
    _selectedCategory = null;
    _selectedKecamatan = null;
    _searchQuery = '';
    _applyFilters();
    notifyListeners();
  }

  // ─── BOOKMARKS ───

  /// Load bookmark user saat ini.
  Future<void> _loadBookmarks() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final maps = await _repo.fetchBookmarks(user.id);
      _bookmarkedArticleIds = maps
          .map((e) => (e as Map)['article_id'] as int)
          .toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loadBookmarks: $e');
    }
  }

  /// Toggle bookmark artikel.
  Future<void> toggleBookmark(int articleId) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final isBookmarked = _bookmarkedArticleIds.contains(articleId);

    try {
      await _repo.toggleBookmark(
        userId: user.id,
        articleId: articleId,
        bookmarked: isBookmarked,
      );
      if (isBookmarked) {
        _bookmarkedArticleIds.remove(articleId);
      } else {
        _bookmarkedArticleIds.add(articleId);
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error toggleBookmark: $e');
    }
  }

  bool isBookmarked(int articleId) => _bookmarkedArticleIds.contains(articleId);

  // ─── ADMIN CRUD (hanya superadmin) ───

  /// Create artikel baru (admin only).
  Future<String?> createArticle({
    required String title,
    required String content,
    String? excerpt,
    String? coverImagePath,
    required ArticleCategory category,
    KecamatanCirebon? kecamatan,
    bool isPublished = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return 'User tidak login';

    final slug = Article.generateSlug(title);
    final now = DateTime.now();

    try {
      await _repo.insertArticle({
        'title': title,
        'slug': slug,
        'excerpt': excerpt,
        'content': content,
        'cover_image_path': coverImagePath,
        'category': category.name,
        'kecamatan': kecamatan?.name,
        'is_published': isPublished,
        'published_at': isPublished ? now.toIso8601String() : null,
        'author_id': user.id,
      });
      return null;
    } catch (e) {
      return 'Gagal membuat artikel: $e';
    }
  }

  /// Update artikel (admin only). Error kalau 0 baris berubah.
  Future<String?> updateArticle({
    required int id,
    required String title,
    required String content,
    String? excerpt,
    String? coverImagePath,
    required ArticleCategory category,
    KecamatanCirebon? kecamatan,
    required bool isPublished,
  }) async {
    try {
      await _repo.updateArticle(
        id: id,
        title: title,
        content: content,
        excerpt: excerpt,
        coverImagePath: coverImagePath,
        category: category,
        kecamatan: kecamatan,
        isPublished: isPublished,
        slug: Article.generateSlug(title),
      );
      return null;
    } catch (e) {
      return 'Gagal update artikel: $e';
    }
  }

  /// Delete artikel (admin only). Error kalau 0 baris terhapus.
  Future<String?> deleteArticle(int id) async {
    try {
      await _repo.deleteArticle(id);
      return null;
    } catch (e) {
      return 'Gagal hapus artikel: $e';
    }
  }

  /// Upload cover image ke storage.
  Future<String?> uploadCoverImage(String path, Uint8List bytes) async {
    try {
      await _repo.uploadCover(path, bytes);
      return path;
    } catch (e) {
      return 'Gagal upload gambar: $e';
    }
  }
}
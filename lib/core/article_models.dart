import 'package:supabase_flutter/supabase_flutter.dart';
import 'article_category.dart';

/// Model untuk artikel Portal UMKM Cirebon.
class Article {
  final int id;
  final String title;
  final String slug;
  final String? excerpt;
  final String content;
  final String? coverImagePath;
  final ArticleCategory category;
  final KecamatanCirebon? kecamatan;
  final bool isPublished;
  final DateTime? publishedAt;
  final String authorId;
  final int viewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Article({
    required this.id,
    required this.title,
    required this.slug,
    this.excerpt,
    required this.content,
    this.coverImagePath,
    required this.category,
    this.kecamatan,
    required this.isPublished,
    this.publishedAt,
    required this.authorId,
    required this.viewCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Article.fromMap(Map<String, dynamic> map) {
    return Article(
      id: map['id'] as int,
      title: map['title'] as String,
      slug: map['slug'] as String,
      excerpt: map['excerpt'] as String?,
      content: map['content'] as String,
      coverImagePath: map['cover_image_path'] as String?,
      category: ArticleCategory.fromString(map['category'] as String),
      kecamatan: map['kecamatan'] != null
          ? KecamatanCirebon.fromString(map['kecamatan'] as String)
          : null,
      isPublished: map['is_published'] as bool? ?? false,
      publishedAt: map['published_at'] != null
          ? DateTime.parse(map['published_at'] as String)
          : null,
      authorId: map['author_id'] as String,
      viewCount: map['view_count'] as int? ?? 0,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'slug': slug,
      'excerpt': excerpt,
      'content': content,
      'cover_image_path': coverImagePath,
      'category': category.name,
      'kecamatan': kecamatan?.name,
      'is_published': isPublished,
      'published_at': publishedAt?.toIso8601String(),
      'author_id': authorId,
      'view_count': viewCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Article copyWith({
    int? id,
    String? title,
    String? slug,
    String? excerpt,
    String? content,
    String? coverImagePath,
    ArticleCategory? category,
    KecamatanCirebon? kecamatan,
    bool? isPublished,
    DateTime? publishedAt,
    String? authorId,
    int? viewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Article(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      excerpt: excerpt ?? this.excerpt,
      content: content ?? this.content,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      category: category ?? this.category,
      kecamatan: kecamatan ?? this.kecamatan,
      isPublished: isPublished ?? this.isPublished,
      publishedAt: publishedAt ?? this.publishedAt,
      authorId: authorId ?? this.authorId,
      viewCount: viewCount ?? this.viewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Generate slug from title (lowercase, hyphenated, no special chars)
  static String generateSlug(String title) {
    return title
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .trim();
  }

  /// Get public URL for cover image
  String? getCoverUrl() {
    if (coverImagePath == null || coverImagePath!.isEmpty) return null;
    // Izinkan URL absolut (mis. konten contoh / CDN) tanpa lewat storage bucket.
    if (coverImagePath!.startsWith('http://') ||
        coverImagePath!.startsWith('https://')) {
      return coverImagePath;
    }
    return Supabase.instance.client.storage
        .from('article_covers')
        .getPublicUrl(coverImagePath!);
  }

  /// Estimated reading time in minutes
  int get readingTimeMinutes {
    final wordCount = content.split(RegExp(r'\s+')).length;
    return (wordCount / 200).ceil().clamp(1, 99);
  }
}

/// Model untuk bookmark artikel.
class ArticleBookmark {
  final int id;
  final int articleId;
  final String userId;
  final DateTime createdAt;

  ArticleBookmark({
    required this.id,
    required this.articleId,
    required this.userId,
    required this.createdAt,
  });

  factory ArticleBookmark.fromMap(Map<String, dynamic> map) {
    return ArticleBookmark(
      id: map['id'] as int,
      articleId: map['article_id'] as int,
      userId: map['user_id'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
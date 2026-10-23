/// Model untuk fitur Postingan (tabel `place_posts`).
/// Postingan berupa FOTO terkait tempat/potensi lokal, dengan caption,
/// like, dan komentar. Semua pengguna boleh membuat postingan.
class PlacePost {
  final int id;
  final int? placeId;
  final String authorId;
  final String imagePath; // path di bucket 'posts'
  final String? caption;
  final bool isActive;
  final DateTime createdAt;
  final Map<String, dynamic>? place; // hasil join `place:places`
  final Map<String, dynamic>? author; // hasil join `author:profiles`
  final int likeCount;
  final int commentCount;

  const PlacePost({
    required this.id,
    this.placeId,
    required this.authorId,
    required this.imagePath,
    this.caption,
    this.isActive = true,
    required this.createdAt,
    this.place,
    this.author,
    this.likeCount = 0,
    this.commentCount = 0,
  });

  factory PlacePost.fromJson(Map<String, dynamic> json) {
    return PlacePost(
      id: (json['id'] as num).toInt(),
      placeId: (json['place_id'] as num?)?.toInt(),
      authorId: json['author_id'] as String,
      imagePath: json['image_path'] as String,
      caption: json['caption'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      place: json['place'] as Map<String, dynamic>?,
      author: json['author'] as Map<String, dynamic>?,
      likeCount: (json['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (json['comment_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// Apakah postingan ini ditautkan ke sebuah tempat.
  bool get hasPlace => place != null || placeId != null;

  String get placeName {
    final p = place;
    if (p == null) return '';
    final n = (p['nama_tempat'] as String?) ?? '';
    return n;
  }

  String get placeCategory => place?['category'] as String? ?? '';

  String get authorName {
    final a = author;
    if (a == null) return 'Pengguna';
    final n = (a['nama'] as String?)?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final f = (a['full_name'] as String?)?.trim() ?? '';
    return f.isNotEmpty ? f : 'Pengguna';
  }

  String? get authorAvatar => author?['avatar_url'] as String?;
}

/// Satu komentar pada sebuah postingan.
class PostComment {
  final int id;
  final int postId;
  final String userId;
  final String body;
  final DateTime createdAt;
  final Map<String, dynamic>? author;

  const PostComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.body,
    required this.createdAt,
    this.author,
  });

  factory PostComment.fromJson(Map<String, dynamic> json) {
    return PostComment(
      id: (json['id'] as num).toInt(),
      postId: (json['post_id'] as num).toInt(),
      userId: json['user_id'] as String,
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      author: json['author'] as Map<String, dynamic>?,
    );
  }

  String get authorName {
    final a = author;
    if (a == null) return 'Pengguna';
    final n = (a['nama'] as String?)?.trim() ?? '';
    if (n.isNotEmpty) return n;
    final f = (a['full_name'] as String?)?.trim() ?? '';
    return f.isNotEmpty ? f : 'Pengguna';
  }

  String? get authorAvatar => author?['avatar_url'] as String?;
}

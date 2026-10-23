import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'post_models.dart';

/// State feed Postingan: daftar postingan foto, like/unlike, komentar, upload.
/// Semua pengguna terautentikasi boleh membuat postingan.
class PostProvider extends ChangeNotifier {
  List<PlacePost> _posts = [];
  bool _loading = false;
  String? _error;

  /// post_id → true jika user sedang like.
  final Map<int, bool> _likedByMe = {};
  /// post_id → jumlah like.
  final Map<int, int> _likeCounts = {};
  /// post_id → jumlah komentar.
  final Map<int, int> _commentCounts = {};

  List<PlacePost> get posts => _posts;
  bool get loading => _loading;
  String? get error => _error;
  bool isLiked(int postId) => _likedByMe[postId] ?? false;
  int likeCount(int postId) => _likeCounts[postId] ?? 0;
  int commentCount(int postId) => _commentCounts[postId] ?? 0;

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';
  bool get isAuthenticated => _userId.isNotEmpty;

  /// Feed: postingan aktif pada tempat terverifikasi, terbaru dulu.
  Future<void> fetchFeed() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final client = Supabase.instance.client;
      final data = await client
          .from('place_posts')
          .select('''
            id, place_id, author_id, image_path, caption, is_active, created_at,
            place:places!place_posts_place_id_fkey(nama_tempat, category, verification_status)
          ''')
          .eq('is_active', true)
          .order('created_at', ascending: false);

      final list = data
          .map((e) => PlacePost.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      // Ambil profil penulis (merge terpisah agar tak bergantung FK).
      final authorIds = list.map((p) => p.authorId).toSet().toList();
      Map<String, Map<String, dynamic>> profiles = {};
      if (authorIds.isNotEmpty) {
        final prof = await client
            .from('profiles')
            .select('id, nama, avatar_url')
            .inFilter('id', authorIds);
        for (final row in prof) {
          profiles[row['id'] as String] = Map<String, dynamic>.from(row);
        }
      }
      _posts = list
          .map((p) => PlacePost(
                id: p.id,
                placeId: p.placeId,
                authorId: p.authorId,
                imagePath: p.imagePath,
                caption: p.caption,
                isActive: p.isActive,
                createdAt: p.createdAt,
                place: p.place,
                author: profiles[p.authorId],
              ))
          .toList();

      if (_posts.isNotEmpty) {
        await _loadEngagement();
      }
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = 'Gagal memuat postingan: $e';
      notifyListeners();
    }
  }

  /// Hitung like & komentar per postingan + like milik user.
  Future<void> _loadEngagement() async {
    _likeCounts.clear();
    _likedByMe.clear();
    _commentCounts.clear();

    final ids = _posts.map((p) => p.id).toList();
    if (ids.isEmpty) return;
    final client = Supabase.instance.client;

    if (isAuthenticated) {
      final mine = await client
          .from('post_likes')
          .select('post_id')
          .eq('user_id', _userId)
          .inFilter('post_id', ids);
      for (final row in mine) {
        _likedByMe[(row['post_id'] as num).toInt()] = true;
      }
    }

    final likes = await client
        .from('post_likes')
        .select('post_id')
        .inFilter('post_id', ids);
    final likeTally = <int, int>{};
    for (final row in likes) {
      final pid = (row['post_id'] as num).toInt();
      likeTally[pid] = (likeTally[pid] ?? 0) + 1;
    }

    final comments = await client
        .from('post_comments')
        .select('post_id')
        .inFilter('post_id', ids);
    final commentTally = <int, int>{};
    for (final row in comments) {
      final pid = (row['post_id'] as num).toInt();
      commentTally[pid] = (commentTally[pid] ?? 0) + 1;
    }

    for (final p in _posts) {
      _likeCounts[p.id] = likeTally[p.id] ?? 0;
      _commentCounts[p.id] = commentTally[p.id] ?? 0;
    }
  }

  Future<bool> toggleLike(PlacePost post) async {
    if (!isAuthenticated) return false;
    final currentlyLiked = isLiked(post.id);
    try {
      final client = Supabase.instance.client;
      if (currentlyLiked) {
        await client
            .from('post_likes')
            .delete()
            .match({'post_id': post.id, 'user_id': _userId});
        _likedByMe[post.id] = false;
        _likeCounts[post.id] = math.max(0, (_likeCounts[post.id] ?? 0) - 1);
      } else {
        await client
            .from('post_likes')
            .insert({'post_id': post.id, 'user_id': _userId});
        _likedByMe[post.id] = true;
        _likeCounts[post.id] = (_likeCounts[post.id] ?? 0) + 1;
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Tambah komentar ke sebuah postingan. Kembalikan pesan error (null = sukses).
  Future<String?> addComment(int postId, String body) async {
    if (!isAuthenticated) return 'Login diperlukan untuk berkomentar.';
    final text = body.trim();
    if (text.isEmpty) return 'Komentar tidak boleh kosong.';
    try {
      await Supabase.instance.client.from('post_comments').insert({
        'post_id': postId,
        'user_id': _userId,
        'body': text,
      });
      _commentCounts[postId] = (_commentCounts[postId] ?? 0) + 1;
      notifyListeners();
      return null;
    } catch (e) {
      return 'Gagal mengirim komentar: $e';
    }
  }

  /// Upload FOTO postingan ke Storage + insert baris place_posts.
  /// [placeId] OPSIONAL — boleh null jika tidak menautkan ke tempat tertentu.
  /// Kembalikan pesan error (null = sukses).
  Future<String?> uploadPost({
    int? placeId,
    required XFile image,
    String? caption,
  }) async {
    if (!isAuthenticated) return 'Login diperlukan.';
    final bytes = await image.readAsBytes();
    if (bytes.length > 8 * 1024 * 1024) {
      return 'Ukuran foto melebihi 8MB. Pilih foto yang lebih kecil.';
    }

    final client = Supabase.instance.client;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rawExt = image.name.split('.').last.toLowerCase();
    final ext = (rawExt.isEmpty || rawExt.length > 5) ? 'jpg' : rawExt;
    final path = '$_userId/$ts.$ext';

    try {
      await client.storage.from('posts').uploadBinary(path, bytes);
    } catch (e) {
      return 'Gagal upload foto: $e';
    }

    try {
      await client.from('place_posts').insert({
        'place_id': placeId,
        'author_id': _userId,
        'image_path': path,
        'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
      });
      await fetchFeed();
      return null;
    } catch (e) {
      return 'Gagal menyimpan postingan: $e';
    }
  }
}

/// Postingan aktif milik satu tempat (untuk section di halaman detail).
Future<List<PlacePost>> fetchPlacePosts(int placeId) async {
  final client = Supabase.instance.client;
  final data = await client
      .from('place_posts')
      .select('id, place_id, author_id, image_path, caption, is_active, created_at')
      .eq('place_id', placeId)
      .eq('is_active', true)
      .order('created_at', ascending: false);
  return data
      .map((e) => PlacePost.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

/// Ambil komentar sebuah postingan (terlama dulu) + profil penulis.
Future<List<PostComment>> fetchPostComments(int postId) async {
  final client = Supabase.instance.client;
  final data = await client
      .from('post_comments')
      .select('id, post_id, user_id, body, created_at')
      .eq('post_id', postId)
      .order('created_at', ascending: true);
  final list = data
      .map((e) => PostComment.fromJson(Map<String, dynamic>.from(e)))
      .toList();

  final ids = list.map((c) => c.userId).toSet().toList();
  Map<String, Map<String, dynamic>> profiles = {};
  if (ids.isNotEmpty) {
    final prof = await client
        .from('profiles')
        .select('id, nama, avatar_url')
        .inFilter('id', ids);
    for (final row in prof) {
      profiles[row['id'] as String] = Map<String, dynamic>.from(row);
    }
  }
  return list
      .map((c) => PostComment(
            id: c.id,
            postId: c.postId,
            userId: c.userId,
            body: c.body,
            createdAt: c.createdAt,
            author: profiles[c.userId],
          ))
      .toList();
}

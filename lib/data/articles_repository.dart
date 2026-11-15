/// Repository untuk domain Artikel (Portal UMKM Cirebon).
///
/// Memusatkan semua akses tabel `articles`, `article_bookmarks`, dan bucket
/// `article_covers` supaya provider/screen tidak menyentuh Supabase langsung.
/// Write divalidasi lewat [verifiedWrite] → 0 baris berubah = exception.

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/article_category.dart';
import 'write_helpers.dart';

class ArticlesRepository {
  final SupabaseClient _client;
  ArticlesRepository(this._client);

  /// Semua artikel (published) untuk list publik.
  Future<List<Map<String, dynamic>>> fetchPublished() async {
    final res = await _client
        .from('articles')
        .select()
        .eq('is_published', true)
        .order('published_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Semua artikel termasuk draft (admin).
  Future<List<Map<String, dynamic>>> fetchAllForAdmin() async {
    final res = await _client
        .from('articles')
        .select()
        .order('created_at', ascending: false);
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Ambil satu artikel published by slug (detail screen).
  Future<Map<String, dynamic>?> fetchBySlug(String slug) async {
    final res = await _client
        .from('articles')
        .select()
        .eq('slug', slug)
        .eq('is_published', true)
        .maybeSingle();
    return res;
  }

  /// Increment view lewat RPC (atomik, hindari race).
  Future<void> incrementViewRpc(int articleId) async {
    await _client.rpc(
      'increment_article_view',
      params: {'article_id': articleId},
    );
  }

  Future<List<Map<String, dynamic>>> fetchBookmarks(String userId) async {
    final res = await _client
        .from('article_bookmarks')
        .select('article_id')
        .eq('user_id', userId);
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Insert artikel baru (admin). Return id yang dibuat.
  Future<int> insertArticle(Map<String, dynamic> payload) async {
    final rows = await verifiedInsert(
      _client.from('articles').insert(payload),
      label: 'insertArticle',
    );
    return rows.first['id'] as int;
  }

  /// Update artikel (admin). Lempar [EmptyWriteException] kalau 0 baris
  /// berubah — mis. id tidak ada atau RLS menolak.
  Future<void> updateArticle({
    required int id,
    required String title,
    String? excerpt,
    required String content,
    String? coverImagePath,
    required ArticleCategory category,
    KecamatanCirebon? kecamatan,
    required bool isPublished,
    required String slug,
    DateTime? now,
  }) async {
    final ts = now ?? DateTime.now();
    await verifiedUpdate(
      _client
          .from('articles')
          .update({
            'title': title,
            'slug': slug,
            'excerpt': excerpt,
            'content': content,
            'cover_image_path': coverImagePath,
            'category': category.name,
            'kecamatan': kecamatan?.name,
            'is_published': isPublished,
            'published_at': isPublished ? ts.toIso8601String() : null,
            'updated_at': ts.toIso8601String(),
          })
          .eq('id', id),
      label: 'updateArticle:$id',
    );
  }

  /// Delete artikel (admin). Wajib menghapus ≥1 baris.
  Future<void> deleteArticle(int id) async {
    await verifiedDelete(
      _client.from('articles').delete().eq('id', id),
      label: 'deleteArticle:$id',
      requireRows: true,
    );
  }

  Future<void> toggleBookmark({
    required String userId,
    required int articleId,
    required bool bookmarked,
  }) async {
    if (bookmarked) {
      await verifiedInsert(
        _client.from('article_bookmarks').insert({
          'user_id': userId,
          'article_id': articleId,
        }),
        label: 'toggleBookmark:insert',
      );
    } else {
      await verifiedDelete(
        _client
            .from('article_bookmarks')
            .delete()
            .eq('user_id', userId)
            .eq('article_id', articleId),
        label: 'toggleBookmark:delete',
        requireRows: true,
      );
    }
  }

  Future<void> incrementViewCount(int id, int current) async {
    // Best-effort: view counter bukan data kritis, jangan ganggu UI.
    try {
      await _client.from('articles').update({
        'view_count': current + 1,
      }).eq('id', id);
    } catch (_) {
      // diabaikan
    }
  }

  /// Upload cover image ke bucket `article_covers` (upsert).
  Future<void> uploadCover(String path, Uint8List bytes) async {
    await _client.storage.from('article_covers').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(upsert: true),
    );
  }

  /// Hapus cover lama (best-effort — jangan gagalkan simpan artikel).
  Future<void> removeCover(String path) async {
    try {
      await _client.storage.from('article_covers').remove([path]);
    } catch (_) {
      // diabaikan
    }
  }
}
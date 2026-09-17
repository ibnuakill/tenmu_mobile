import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'video_models.dart';

/// State feed video pendek: daftar, like/unlike, views, upload.
class VideoProvider extends ChangeNotifier {
  List<PlaceVideo> _videos = [];
  bool _loading = false;
  String? _error;
  /// video_id → true jika user sedang like.
  final Map<int, bool> _likedByMe = {};
  /// video_id → jumlah like.
  final Map<int, int> _likeCounts = {};
  /// video_id → true hanya dicatat views sekali per session.
  final Set<int> _viewed = {};

  List<PlaceVideo> get videos => _videos;
  bool get loading => _loading;
  String? get error => _error;
  bool isLiked(int videoId) => _likedByMe[videoId] ?? false;
  int likeCount(int videoId) => _likeCounts[videoId] ?? 0;

  String get _userId => Supabase.instance.client.auth.currentUser?.id ?? '';
  bool get isAuthenticated => _userId.isNotEmpty;

  /// Feed: video aktif milik tempat yang sudah terverifikasi, terbaru dulu.
  Future<void> fetchFeed() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final data = await Supabase.instance.client
          .from('place_videos')
          .select('''
            id, place_id, owner_id, video_path, thumbnail_path, caption,
            views, is_active, created_at,
            place:places!place_videos_place_id_fkey(nama_tempat, category, verification_status)
          ''')
          .eq('is_active', true)
          .eq('place.verification_status', 'verified')
          .order('created_at', ascending: false);

      _videos = data
          .map((e) => PlaceVideo.fromJson(Map<String, dynamic>.from(e)))
          .toList();

      if (_videos.isNotEmpty) {
        await _loadLikes();
      }
      _loading = false;
      notifyListeners();
    } catch (e) {
      _loading = false;
      _error = 'Gagal memuat video: $e';
      notifyListeners();
    }
  }

  /// Ambil like milik user (semua) + hitung like per video di feed.
  Future<void> _loadLikes() async {
    _likeCounts.clear();
    _likedByMe.clear();

    final ids = _videos.map((v) => v.id).toList();
    if (isAuthenticated) {
      final mine = await Supabase.instance.client
          .from('video_likes')
          .select('video_id')
          .eq('user_id', _userId);
      for (final row in mine) {
        _likedByMe[(row['video_id'] as num).toInt()] = true;
      }
    }

    // Count per video: satu query dengan IN.
    final counts = await Supabase.instance.client
        .from('video_likes')
        .select('video_id')
        .inFilter('video_id', ids);
    final tally = <int, int>{};
    for (final row in counts) {
      final vid = (row['video_id'] as num).toInt();
      tally[vid] = (tally[vid] ?? 0) + 1;
    }
    for (final v in _videos) {
      _likeCounts[v.id] = tally[v.id] ?? 0;
    }
  }

  Future<bool> toggleLike(PlaceVideo video) async {
    if (!isAuthenticated) return false;
    final currentlyLiked = isLiked(video.id);
    try {
      final client = Supabase.instance.client;
      if (currentlyLiked) {
        await client
            .from('video_likes')
            .delete()
            .match({'video_id': video.id, 'user_id': _userId});
        _likedByMe[video.id] = false;
        _likeCounts[video.id] = math.max(0, (_likeCounts[video.id] ?? 0) - 1);
      } else {
        await client
            .from('video_likes')
            .insert({'video_id': video.id, 'user_id': _userId});
        _likedByMe[video.id] = true;
        _likeCounts[video.id] = (_likeCounts[video.id] ?? 0) + 1;
      }
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Panggil sekali per video per session (RPC di sisi server).
  Future<void> recordView(int videoId) async {
    if (_viewed.contains(videoId)) return;
    _viewed.add(videoId);
    try {
      await Supabase.instance.client
          .rpc('increment_video_views', params: {'p_video_id': videoId});
      final idx = _videos.indexWhere((v) => v.id == videoId);
      if (idx >= 0) {
        _videos[idx] = PlaceVideo(
          id: _videos[idx].id,
          placeId: _videos[idx].placeId,
          ownerId: _videos[idx].ownerId,
          videoPath: _videos[idx].videoPath,
          thumbnailPath: _videos[idx].thumbnailPath,
          caption: _videos[idx].caption,
          views: _videos[idx].views + 1,
          isActive: _videos[idx].isActive,
          createdAt: _videos[idx].createdAt,
          place: _videos[idx].place,
        );
        notifyListeners();
      }
    } catch (_) {}
  }

  /// Upload video milik owner ke Storage + insert baris place_videos.
  /// Kembalikan pesan error (null = sukses).
  Future<String?> uploadVideo({
    required int placeId,
    required XFile video,
    String? caption,
  }) async {
    if (!isAuthenticated) return 'Login diperlukan.';
    final bytes = await video.readAsBytes();
    if (bytes.length > 20 * 1024 * 1024) {
      return 'Ukuran video melebihi 20MB. Pilih video yang lebih pendek.';
    }

    final client = Supabase.instance.client;
    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = video.name.split('.').last.isEmpty
        ? 'mp4'
        : video.name.split('.').last;
    final path = '$_userId/$ts.$ext';

    try {
      await client.storage.from('videos').uploadBinary(path, bytes);
    } catch (e) {
      return 'Gagal upload video: $e';
    }

    try {
      await client.from('place_videos').insert({
        'place_id': placeId,
        'owner_id': _userId,
        'video_path': path,
        'caption': caption?.trim().isEmpty == true ? null : caption?.trim(),
      });
      if (_videos.any((v) => v.placeId == placeId)) await fetchFeed();
      return null;
    } catch (e) {
      return 'Gagal menyimpan data video: $e';
    }
  }
}

/// Video aktif milik satu tempat (untuk section di halaman detail).
Future<List<PlaceVideo>> fetchPlaceVideos(int placeId) async {
  final data = await Supabase.instance.client
      .from('place_videos')
      .select(
        'id, place_id, owner_id, video_path, thumbnail_path, caption, '
        'views, is_active, created_at',
      )
      .eq('place_id', placeId)
      .eq('is_active', true)
      .order('created_at', ascending: false);
  return data
      .map((e) => PlaceVideo.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}
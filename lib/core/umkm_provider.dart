import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider untuk data tempat (dulu `umkm` table, kini aktif dari `places`).
/// Tabel `umkm` sudah di-rename menjadi `places` (lihat migrate_umkm_to_places.sql),
/// jadi provider ini membaca tabel `places` yang TELAH verified — setara UMKM.
///
/// Perubahan utama:
///  * membaca dari view `places_with_ratings` (avg_rating & review_count dihitung
///    server-side oleh Postgres) — menghapus pola lama `fetchRatings()` yang
///    menarik SELURUH baris tabel `reviews` lalu menghitung rata-rata di client
///    (O(N) reviews per pengguna; tidak skala).
///  * pagination dipersiapkan (limit tambahan; cukup 60 pertama untuk yg umum).
class UMKMProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _umkmList = [];
  Map<int, double> _ratings = {};
  bool _isLoading = false;
  DateTime? _lastFetch;
  String? _error;

  List<Map<String, dynamic>> get umkmList => _umkmList;
  Map<int, double> get ratings => _ratings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Cache duration: 5 minutes
  bool get _shouldRefresh =>
      _lastFetch == null ||
      DateTime.now().difference(_lastFetch!) > const Duration(minutes: 5);

  static const _columns =
      'id, nama_tempat, alamat, deskripsi, gambar_url, image_urls, category, min_price, max_price, latitude, longitude, is_featured, fasilitas, jam_buka, jam_tutup, nomor_telepon, avg_rating, review_count';

  Future<void> fetchUMKM({bool force = false}) async {
    if (!force && !_shouldRefresh && _umkmList.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // optimization: fetch only necessary fields + FIX filter verified → dari view
      final data = await Supabase.instance.client
          .from('places_with_ratings')
          .select(_columns)
          .eq('verification_status', 'verified')
          .order('created_at', ascending: false)
          .limit(60); // cap — list lengkap via fetchMore/pagination bila perlu

      _umkmList = List<Map<String, dynamic>>.from(data);
      _buildRatingsFromView(_umkmList);
      _lastFetch = DateTime.now();
      _error = null;
    } catch (e) {
      debugPrint('Error fetching UMKM: $e');
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Bangun map rating dari kolom `avg_rating` view — TANPA query seluruh reviews.
  void _buildRatingsFromView(List<Map<String, dynamic>> rows) {
    final map = <int, double>{};
    for (final row in rows) {
      final id = row['id'];
      final avg = row['avg_rating'];
      if (id is int && avg is num) map[id] = avg.toDouble();
    }
    _ratings = map;
    notifyListeners();
  }
}
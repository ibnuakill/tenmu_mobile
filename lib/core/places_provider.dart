import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'haversine.dart';
import 'places_cache.dart';

/// Mode urutan / sort tempat.
import '../data/places_repository.dart';
import '../data/places_sort.dart';

export '../data/places_sort.dart' show SortMode;

/// Parameter query server-side. `==` & `hashCode` di-override agar cache 5-menit
/// per-query berfungsi (query berbeda = list berbeda, tak boleh berbagi cache).
@immutable
class PlaceQuery {
  final String search; // lowercase, sudah di-trim
  final List<String>
  categories; // di-normalisasi (PoiCategory.normalizeCategory)
  final SortMode sort;
  final double? userLat;
  final double? userLng;
  final bool featured;

  const PlaceQuery({
    this.search = '',
    this.categories = const [],
    this.sort = SortMode.terbaru,
    this.userLat,
    this.userLng,
    this.featured = false,
  });

  PlaceQuery copyWith({
    String? search,
    List<String>? categories,
    SortMode? sort,
    double? Function()? userLat,
    double? Function()? userLng,
    bool? featured,
  }) {
    return PlaceQuery(
      search: search ?? this.search,
      categories: categories ?? this.categories,
      sort: sort ?? this.sort,
      userLat: userLat != null ? userLat() : this.userLat,
      userLng: userLng != null ? userLng() : this.userLng,
      featured: featured ?? this.featured,
    );
  }

  String get cacheKey =>
      '$search|${categories.join(',')}|${sort.name}|$userLat,$userLng|$featured';

  @override
  bool operator ==(Object other) =>
      other is PlaceQuery && other.cacheKey == cacheKey;

  @override
  int get hashCode => cacheKey.hashCode;
}

class PlacesProvider extends ChangeNotifier {
  /// Semua query lewat repository (bukan `Supabase.instance.client` langsung),
  /// supaya bisa diuji dengan repository palsu dan aturan query ada di satu file.
  PlacesProvider({PlacesRepository? repo})
    : _repo = repo ?? PlacesRepository(Supabase.instance.client);

  final PlacesRepository _repo;

  List<Map<String, dynamic>> _placesList = [];
  List<Map<String, dynamic>> _featuredList = [];
  final Map<int, double> _ratings = {};
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isFetchingFeatured = false;
  bool _hasMore = true;
  DateTime? _lastFetch;
  String? _error;
  bool _isOffline = false;

  PlaceQuery _query = const PlaceQuery();
  DateTime? _cursorCreatedAt; // created_at baris terakhir halaman sebelumnya
  int? _cursorId; // id baris terakhir
  double? _cursorValue; // km (distance) / avg_rating — utk sort distance/rating

  /// Jumlah tempat per halaman. Naikkan/turunkan sesuai kebutuhan UI.
  static const int pageSize = 30;

  PlaceQuery get query => _query;
  List<Map<String, dynamic>> get placesList => _placesList;
  List<Map<String, dynamic>> get featuredList => _featuredList;
  Map<int, double> get ratings => _ratings;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;

  /// True kalau daftar yang tampil berasal dari cache (koneksi gagal).
  bool get isOffline => _isOffline;

  bool get _shouldRefresh =>
      _lastFetch == null ||
      DateTime.now().difference(_lastFetch!) > const Duration(minutes: 5);

  static const _columns =
      'id, nama_tempat, alamat, deskripsi, gambar_url, image_urls, category, latitude, longitude, is_featured, fasilitas, jam_buka, jam_tutup, nomor_telepon, website, created_at, avg_rating, review_count';

  /// Ganti kueri → fetch ulang halaman 1 (reset cursor). [force] memaksa fetch
  /// meski cache 5 menit masih hangat (dipakai pull-to-refresh / retry).
  Future<void> setQuery(PlaceQuery next, {bool force = false}) async {
    if (!force && !_shouldRefresh && next == _query && _placesList.isNotEmpty) {
      return;
    }
    _query = next;
    _cursorCreatedAt = null;
    _cursorId = null;
    _cursorValue = null;
    _hasMore = true;
    await _fetchPage(reset: true, force: force);
  }

  /// Ambil halaman berikutnya (cursor-based). Dipanggil dari infinite scroll.
  Future<void> fetchMore() async {
    if (_isLoading || _isLoadingMore || !_hasMore) return;
    await _fetchPage(reset: false);
  }

  /// Fetch featured untuk carousel — ringan (limit 30, is_featured=true),
  /// independen dari query utama; cache 5 menit sendiri.
  Future<void> fetchFeatured({bool force = false}) async {
    if (!force && !_shouldRefresh && _featuredList.isNotEmpty) return;
    // Jangan pakai `_isLoading` di sini: `setQuery()` sudah menyalakannya secara
    // sinkron, jadi pemanggilan paralel dari home akan langsung balik dan
    // carousel featured tidak pernah terisi. Guard khusus, terpisah.
    if (_isFetchingFeatured) return;
    _isFetchingFeatured = true;
    try {
      final data = await _repo.fetchFeatured(columns: _columns);
      _featuredList = data;
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching featured: $e');
    } finally {
      _isFetchingFeatured = false;
    }
  }

  Future<void> _fetchPage({required bool reset, bool force = false}) async {
    _isLoading = reset;
    _isLoadingMore = !reset;
    _error = null;
    notifyListeners();

    try {
      final rows = await _repo.fetchPaged(
        search: _query.search,
        categories: _query.categories,
        featured: _query.featured,
        sort: _query.sort,
        userLat: _query.userLat,
        userLng: _query.userLng,
        cursorCreatedAt: _cursorCreatedAt,
        cursorId: _cursorId,
        cursorValue: _cursorValue,
        pageSize: PlacesProvider.pageSize,
      );

      final hasMore = rows.length > PlacesProvider.pageSize;
      final page = hasMore ? rows.sublist(0, PlacesProvider.pageSize) : rows;

      if (reset) {
        _placesList = page;
      } else {
        _placesList = [..._placesList, ...page];
      }

      if (page.isNotEmpty) {
        final last = page.last;
        // created_at dari Supabase selalu String (ISO8601), bukan DateTime.
        // Tanpa parsing ini cursor selalu null → fetchMore ulang halaman 1 → duplikat.
        final rawTs = last['created_at'];
        _cursorCreatedAt = rawTs is DateTime
            ? rawTs
            : (rawTs is String ? DateTime.tryParse(rawTs) : null);
        _cursorId = (last['id'] as num?)?.toInt();
        _cursorValue = _computeCursorValue(last);
      }
      _hasMore = hasMore;
      _lastFetch = DateTime.now();
      _rebuildRatings(page);

      // Simpan untuk mode offline — hanya daftar utama tanpa filter,
      // supaya cache tidak tertukar dengan hasil pencarian/kategori.
      if (reset &&
          _query.search.isEmpty &&
          _query.categories.isEmpty &&
          !_query.featured) {
        unawaited(PlacesCache.save(_placesList));
      }
      _isOffline = false;
    } catch (e) {
      debugPrint('Error fetching places: $e');
      if (reset) {
        // Koneksi gagal → coba tampilkan data terakhir yang tersimpan.
        final cached = await PlacesCache.load();
        if (cached != null && cached.isNotEmpty) {
          _placesList = cached;
          _isOffline = true;
          _error = 'Kamu sedang offline. Menampilkan data tersimpan.';
          _rebuildRatings(_placesList);
        } else {
          _error = 'Gagal memuat tempat. Periksa koneksi internet.';
        }
      }
      // Halaman tambahan gagal → biarkan list yg sudah ada tetap tampil.
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Nilai cursor untuk sort 'distance'/'rating'. Untuk distance dihitung ulang
  /// client-side (Haversine) agar konsisten dgn urutan ORDER BY SQL.
  double? _computeCursorValue(Map<String, dynamic> last) {
    switch (_query.sort) {
      case SortMode.terdekat:
        return Haversine.distance(
          _query.userLat ?? 0,
          _query.userLng ?? 0,
          (last['latitude'] as num?)?.toDouble() ?? 0,
          (last['longitude'] as num?)?.toDouble() ?? 0,
        );
      case SortMode.rating:
        return (last['avg_rating'] as num?)?.toDouble();
      case SortMode.terbaru:
        return null;
    }
  }

  /// Bangun map rating dari kolom avg_rating yang sudah dihitung Postgres.
  void _rebuildRatings(List<Map<String, dynamic>> rows) {
    for (final row in rows) {
      final id = row['id'];
      final avg = row['avg_rating'];
      if (id is int && avg is num) _ratings[id] = avg.toDouble();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Kompatibilitas pemanggil lama — query default halaman 1 (newest, tanpa filter).
  @Deprecated('Gunakan setQuery untuk mengontrol filter/sort')
  Future<void> fetchPlaces({bool force = false}) =>
      setQuery(const PlaceQuery(), force: force);

  /// Kompatibilitas — rating kini berasal dari view.
  @Deprecated('Ratings dihitung server-side via places_with_ratings')
  Future<void> fetchRatings() async => _rebuildRatings(_placesList);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tenmu/core/places_provider.dart';
import 'package:tenmu/data/places_repository.dart';

/// Repository palsu: mengembalikan baris yang kita tentukan, dan merekam
/// parameter cursor yang dikirim provider pada panggilan berikutnya.
class _FakePlacesRepository extends PlacesRepository {
  _FakePlacesRepository({required this.pages, required this.recordeds})
    : super(SupabaseClient('https://example.supabase.co', 'anon-key'));

  /// Halaman ke-n yang akan dikembalikan (index 0 = panggilan pertama).
  final List<List<Map<String, dynamic>>> pages;

  /// Setiap panggilan fetchPaged dicatat di sini.
  final List<Map<String, Object?>> recordeds;

  @override
  Future<List<Map<String, dynamic>>> fetchPaged({
    required String search,
    required List<String> categories,
    required SortMode sort,
    bool featured = false,
    double? minPrice,
    double? maxPrice,
    double? userLat,
    double? userLng,
    double? maxDistanceKm,
    DateTime? cursorCreatedAt,
    int? cursorId,
    double? cursorValue,
    int pageSize = 20,
  }) async {
    recordeds.add({
      'cursorCreatedAt': cursorCreatedAt,
      'cursorId': cursorId,
      'cursorValue': cursorValue,
      'pageSize': pageSize,
      'sort': sort,
      'featured': featured,
    });
    final index = recordeds.length - 1;
    if (index >= pages.length) return const [];
    return pages[index];
  }
}

Map<String, dynamic> _row(int id, {double? rating}) => {
  'id': id,
  'nama_tempat': 'Tempat $id',
  'created_at': '2026-11-15T10:${id.toString().padLeft(2, '0')}:00Z',
  'latitude': -6.7,
  'longitude': 108.5,
  if (rating != null) 'avg_rating': rating,
};

void main() {
  setUp(() {
    // PlacesCache menulis lewat SharedPreferences.
    SharedPreferences.setMockInitialValues({});
  });

  test('halaman penuh dipecah ke pageSize dan hasMore = true', () async {
    final pageSize = PlacesProvider.pageSize; // 30
    final recordeds = <Map<String, Object?>>[];
    final repo = _FakePlacesRepository(
      // 31 baris → 1 baris kelebihan dipakai sebagai penanda "masih ada lagi".
      pages: [
        [for (var i = 1; i <= pageSize + 1; i++) _row(i)],
      ],
      recordeds: recordeds,
    );
    final provider = PlacesProvider(repo: repo);

    await provider.setQuery(const PlaceQuery(), force: true);

    expect(provider.placesList, hasLength(pageSize));
    expect(provider.hasMore, isTrue);
    expect(provider.isLoading, isFalse);
    expect(provider.error, isNull);
  });

  test('cursor dikirim dari baris terakhir halaman sebelumnya', () async {
    final pageSize = PlacesProvider.pageSize;
    final recordeds = <Map<String, Object?>>[];
    final repo = _FakePlacesRepository(
      pages: [
        [for (var i = 1; i <= pageSize + 1; i++) _row(i)],
        [_row(99)],
      ],
      recordeds: recordeds,
    );
    final provider = PlacesProvider(repo: repo);

    await provider.setQuery(const PlaceQuery(), force: true);
    // Panggilan pertama tanpa cursor.
    expect(recordeds.first['cursorCreatedAt'], isNull);
    expect(recordeds.first['cursorId'], isNull);

    await provider.fetchMore();

    // Panggilan kedua memakai cursor baris terakhir halaman 1 (id = pageSize).
    expect(recordeds, hasLength(2));
    expect(recordeds[1]['cursorId'], pageSize);
    expect(recordeds[1]['cursorCreatedAt'], isA<DateTime>());
    // Sisanya di-append, bukan menimpa.
    expect(provider.placesList, hasLength(pageSize + 1));
    expect(provider.hasMore, isFalse);
  });

  test('sort terdekat mengisi cursorValue dengan jarak (bukan null)', () async {
    final pageSize = PlacesProvider.pageSize;
    final recordeds = <Map<String, Object?>>[];
    final repo = _FakePlacesRepository(
      pages: [
        [for (var i = 1; i <= pageSize + 1; i++) _row(i)],
        [_row(99)],
      ],
      recordeds: recordeds,
    );
    final provider = PlacesProvider(repo: repo);

    await provider.setQuery(
      const PlaceQuery(
        sort: SortMode.terdekat,
        userLat: -6.7,
        userLng: 108.5,
      ),
      force: true,
    );
    // Panggilan pertama selalu tanpa cursor (cursor baru dihitung setelah
    // halaman pertama datang).
    expect(recordeds.first['sort'], SortMode.terdekat);
    expect(recordeds.first['cursorValue'], isNull);

    await provider.fetchMore();

    // Panggilan kedua: cursor jarak (km, hasil Haversine) terisi — kalau null,
    // paging sort "terdekat" akan mengulang halaman 1.
    expect(recordeds[1]['cursorValue'], isA<double>());
    expect(recordeds[1]['cursorId'], pageSize);
  });

  test('gagal fetch → error diisi, tidak melempar', () async {
    final repo = _ThrowingPlacesRepository(
      SupabaseClient('https://example.supabase.co', 'anon-key'),
    );
    final provider = PlacesProvider(repo: repo);

    await provider.setQuery(const PlaceQuery(), force: true);

    expect(provider.error, isNotNull);
    expect(provider.isLoading, isFalse);
    expect(provider.placesList, isEmpty);
  });
}

class _ThrowingPlacesRepository extends PlacesRepository {
  _ThrowingPlacesRepository(super.client);

  @override
  Future<List<Map<String, dynamic>>> fetchPaged({
    required String search,
    required List<String> categories,
    required SortMode sort,
    bool featured = false,
    double? minPrice,
    double? maxPrice,
    double? userLat,
    double? userLng,
    double? maxDistanceKm,
    DateTime? cursorCreatedAt,
    int? cursorId,
    double? cursorValue,
    int pageSize = 20,
  }) async {
    throw StateError('koneksi putus');
  }
}

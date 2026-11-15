/// Repository untuk domain Places.
///
/// Menggabungkan read & write agar caller (provider, screens) tidak akses
/// `Supabase.instance.client` langsung. Semua write memakai `verifiedWrite`
/// → gagal cepat kalau 0 baris berubah.

import 'package:supabase_flutter/supabase_flutter.dart';

import 'places_sort.dart';
import 'write_helpers.dart';

class PlacesRepository {
  final SupabaseClient _client;
  PlacesRepository(this._client);

  /// Insert tempat baru (owner). Return id tempat yang dibuat.
  Future<int> insertPlace(Map<String, dynamic> payload) async {
    final rows = await verifiedInsert(
      _client.from('places').insert(payload),
      label: 'insertPlace',
    );
    if (rows.isEmpty) throw EmptyWriteException('insertPlace');
    return rows.first['id'] as int;
  }

  /// Update tempat milik owner (edit). `ownerId` untuk verifikasi —
  /// query memakai `owner_id = ownerId` agar owner tidak ubah tempat orang lain.
  /// Jika [allowAdmin] true (admin via service_role), owner check di-skip.
  Future<void> updatePlace({
    required int placeId,
    required Map<String, dynamic> payload,
    required String ownerId,
    bool allowAdmin = false,
  }) async {
    var query = _client.from('places').update(payload);
    if (!allowAdmin) query = query.eq('owner_id', ownerId);
    await verifiedUpdate(
      query.eq('id', placeId),
      label: 'updatePlace:$placeId',
    );
  }

  /// Delete tempat. Owner hanya hapus milik sendiri (owner_id check).
  Future<void> deletePlace({
    required int placeId,
    required String ownerId,
    bool allowAdmin = false,
  }) async {
    var query = _client.from('places').delete();
    if (!allowAdmin) query = query.eq('owner_id', ownerId);
    await verifiedDelete(
      query.eq('id', placeId),
      label: 'deletePlace:$placeId',
      requireRows: true, // admin/owner mengharapkan row terhapus
    );
  }

  /// Fetch featured (verified + featured) untuk carousel home.
  ///
  /// Filter harus sama dengan yang dipakai provider: `verification_status =
  /// 'verified'` DAN `is_featured = true`. (Kolom `is_verified`/`featured` di
  /// tempat lain bukan yang dipakai `places_with_ratings`.)
  Future<List<Map<String, dynamic>>> fetchFeatured({
    int limit = 30,
    String columns = '*',
  }) async {
    final res = await _client
        .from('places_with_ratings')
        .select(columns)
        .eq('verification_status', 'verified')
        .eq('is_featured', true)
        .order('created_at', ascending: false)
        .limit(limit)
        .timeout(const Duration(seconds: 20));
    return (res as List).cast<Map<String, dynamic>>();
  }

  /// Fetch paged places via RPC `get_places_paged`.
  ///
  /// Semua parameter yang bernilai null dihapus dari payload supaya SQL-nya
  /// memakai default (bukan filter "= null").
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
    final params = <String, dynamic>{
      'p_search': search.isEmpty ? null : search,
      'p_categories': categories.isEmpty ? null : categories,
      'p_featured': featured ? true : null,
      'p_min_price': minPrice,
      'p_max_price': maxPrice,
      'p_sort': sqlSortFor(sort),
      'p_user_lat': userLat,
      'p_user_lng': userLng,
      'p_max_distance_km': maxDistanceKm,
      'p_cursor_created_at': cursorCreatedAt?.toIso8601String(),
      'p_cursor_id': cursorId,
      'p_cursor_value': cursorValue,
      'p_page_size': pageSize,
    };
    // hapus null values
    params.removeWhere((_, v) => v == null);

    final res = await _client
        .rpc('get_places_paged', params: params)
        .timeout(const Duration(seconds: 20));
    return (res as List).cast<Map<String, dynamic>>();
  }
}
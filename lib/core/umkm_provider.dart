import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UMKMProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _umkmList = [];
  Map<int, double> _ratings = {};
  bool _isLoading = false;
  DateTime? _lastFetch;

  List<Map<String, dynamic>> get umkmList => _umkmList;
  Map<int, double> get ratings => _ratings;
  bool get isLoading => _isLoading;

  // Cache duration: 5 minutes
  bool get _shouldRefresh =>
    _lastFetch == null ||
    DateTime.now().difference(_lastFetch!) > const Duration(minutes: 5);

  Future<void> fetchUMKM({bool force = false}) async {
    if (!force && !_shouldRefresh && _umkmList.isNotEmpty) return;

    _isLoading = true;
    notifyListeners();

    try {
      // optimization: fetch only necessary fields for listing
      final data = await Supabase.instance.client
          .from('umkm')
          .select('id, nama_tempat, alamat, gambar_url, category, min_price, max_price, latitude, longitude, is_featured')
          .order('created_at', ascending: false);

      _umkmList = List<Map<String, dynamic>>.from(data);
      _lastFetch = DateTime.now();
      await fetchRatings();
    } catch (e) {
      debugPrint('Error fetching UMKM: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchRatings() async {
    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select('umkm_id, rating');

      final Map<int, List<int>> ratingsMap = {};
      for (var row in response) {
        final umkmId = row['umkm_id'] as int;
        final rating = row['rating'] as int;
        if (!ratingsMap.containsKey(umkmId)) {
          ratingsMap[umkmId] = [];
        }
        ratingsMap[umkmId]!.add(rating);
      }

      final Map<int, double> avgRatings = {};
      ratingsMap.forEach((id, ratings) {
        final avg = ratings.reduce((a, b) => a + b) / ratings.length;
        avgRatings[id] = avg;
      });

      _ratings = avgRatings;
    } catch (e) {
      debugPrint('Error fetching ratings: $e');
    }
  }
}

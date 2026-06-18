import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PlacesProvider extends ChangeNotifier {
  List<Map<String, dynamic>> _placesList = [];
  Map<int, double> _ratings = {};
  bool _isLoading = false;
  DateTime? _lastFetch;
  String? _error;

  List<Map<String, dynamic>> get placesList => _placesList;
  Map<int, double> get ratings => _ratings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool get _shouldRefresh =>
      _lastFetch == null ||
      DateTime.now().difference(_lastFetch!) > const Duration(minutes: 5);

  Future<void> fetchPlaces({bool force = false}) async {
    if (!force && !_shouldRefresh && _placesList.isNotEmpty) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await Supabase.instance.client
          .from('places')
          .select(
            'id, nama_tempat, alamat, deskripsi, gambar_url, image_urls, category, min_price, max_price, latitude, longitude, is_featured, fasilitas, jam_buka, jam_tutup, nomor_telepon, website, harga_teks',
          )
          .eq('verification_status', 'verified')
          .order('created_at', ascending: false);

      _placesList = List<Map<String, dynamic>>.from(data);
      _lastFetch = DateTime.now();
      _error = null;
      await fetchRatings();
    } catch (e) {
      debugPrint('Error fetching places: $e');
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

  Future<void> fetchRatings() async {
    try {
      final response = await Supabase.instance.client
          .from('reviews')
          .select('umkm_id, rating');

      final Map<int, List<int>> ratingsMap = {};
      for (var row in response) {
        final placeId = row['umkm_id'] as int;
        final rating = row['rating'] as int;
        if (!ratingsMap.containsKey(placeId)) {
          ratingsMap[placeId] = [];
        }
        ratingsMap[placeId]!.add(rating);
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

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/haversine.dart';
import '../../../core/theme_provider.dart';

/// State + side-effects untuk PoiDetailScreen — favorite, distance/duration,
/// rating average, address, hours. UI lihat ini via AnimatedBuilder.
class PoiDetailController extends ChangeNotifier {
  PoiDetailController({
    required this.context,
    required this.place,
  });

  final BuildContext context;
  final Map<String, dynamic> place;

  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  String? _distanceText; // e.g. "3.2 km"
  String? _durationText; // e.g. "15 mnt"
  double _avgRating = 0.0;
  int _reviewCount = 0;

  bool get isFavorite => _isFavorite;
  bool get isLoadingFavorite => _isLoadingFavorite;
  String? get distanceText => _distanceText;
  String? get durationText => _durationText;
  double get avgRating => _avgRating;
  int get reviewCount => _reviewCount;

  bool get isFeatured => place['is_featured'] == true;
  String? get address => place['alamat']?.toString();
  String get placeName => (place['nama_tempat'] ?? 'Tanpa Nama').toString();
  String? get phoneNumber => place['nomor_telepon']?.toString();
  bool get hasPhone => phoneNumber != null && phoneNumber!.isNotEmpty;
  String? get jamBuka => place['jam_buka']?.toString();
  String? get jamTutup => place['jam_tutup']?.toString();

  double? get lat => _maybeDouble(place['latitude']);
  double? get lng => _maybeDouble(place['longitude']);
  bool get hasLocation => lat != null && lng != null;

  double? _maybeDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  bool get isOpenNow {
    if (jamBuka == null || jamTutup == null) return false;
    try {
      final now = TimeOfDay.now();
      final cur = now.hour * 60 + now.minute;
      final op = jamBuka!.split(':');
      final cl = jamTutup!.split(':');
      final openMin = int.parse(op[0]) * 60 + int.parse(op[1]);
      final closeMin = int.parse(cl[0]) * 60 + int.parse(cl[1]);
      return closeMin < openMin
          ? (cur >= openMin || cur <= closeMin)
          : (cur >= openMin && cur <= closeMin);
    } catch (_) {
      return false;
    }
  }

  // ═══════════════════════════════════════
  // Bootstrap
  // ═══════════════════════════════════════

  Future<void> bootstrap(ThemeProvider theme) async {
    await checkFavoriteStatus();
    await Future.wait([
      fetchDistance(),
      fetchReviewStats(),
    ]);
  }

  // ═══════════════════════════════════════
  // Favorite
  // ═══════════════════════════════════════

  Future<void> checkFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _isLoadingFavorite = false;
      notifyListeners();
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('umkm_id', place['id'])
          .maybeSingle();
      _isFavorite = response != null;
      _isLoadingFavorite = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      _isLoadingFavorite = false;
      notifyListeners();
    }
  }

  Future<void> toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      final messenger = ScaffoldMessenger.of(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Silakan login untuk menyimpan favorit.'),
        ),
      );
      return;
    }
    _isFavorite = !_isFavorite;
    notifyListeners();
    try {
      if (_isFavorite) {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': user.id,
          'umkm_id': place['id'],
        });
      } else {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('umkm_id', place['id']);
      }
    } catch (e) {
      _isFavorite = !_isFavorite;
      notifyListeners();
      if (context.mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final theme = Provider.of<ThemeProvider>(context, listen: false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal memperbarui favorit: $e'),
            backgroundColor: theme.snackError,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════
  // Distance / duration
  // ═══════════════════════════════════════

  Future<void> fetchDistance() async {
    try {
      final toLat = lat;
      final toLng = lng;
      if (toLat == null || toLng == null) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // Default fallback (Haversine)
      final fallbackDistKm =
          Haversine.distance(pos.latitude, pos.longitude, toLat, toLng);
      String dist = Haversine.formatDistance(fallbackDistKm);
      final fallbackMins = (fallbackDistKm / 40.0 * 60).round();
      String durText = fallbackMins < 60
          ? '${fallbackMins > 0 ? fallbackMins : 1} mnt'
          : '${fallbackMins ~/ 60} jam ${fallbackMins % 60 > 0 ? '${fallbackMins % 60} mnt' : ''}'
              .trim();

      // Try OSRM actual route
      try {
        final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
          '${pos.longitude},${pos.latitude};$toLng,$toLat?overview=false',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
            final route = data['routes'][0];
            final double distanceMeters =
                (route['distance'] as num).toDouble();
            final double durationSeconds =
                (route['duration'] as num).toDouble();

            final routeDistKm = distanceMeters / 1000.0;
            dist = Haversine.formatDistance(routeDistKm);

            final minutes = (durationSeconds / 60.0).round();
            if (minutes < 60) {
              durText = '${minutes > 0 ? minutes : 1} mnt';
            } else {
              final hours = minutes ~/ 60;
              final mins = minutes % 60;
              durText = mins > 0 ? '$hours jam $mins mnt' : '$hours jam';
            }
          }
        }
      } catch (e) {
        debugPrint('OSRM fetch fallback to Haversine: $e');
      }

      _distanceText = dist;
      _durationText = durText;
      notifyListeners();
    } catch (_) {
      // GPS unavailable
    }
  }

  // ═══════════════════════════════════════
  // Reviews stats
  // ═══════════════════════════════════════

  Future<void> fetchReviewStats() async {
    try {
      final id = place['id'];
      if (id == null) return;
      final data = await Supabase.instance.client
          .from('reviews')
          .select('rating')
          .eq('umkm_id', id);
      final list = List<Map<String, dynamic>>.from(data);
      if (list.isEmpty) {
        notifyListeners();
        return;
      }
      final avg = list
              .map((r) => (r['rating'] as num).toDouble())
              .reduce((a, b) => a + b) /
          list.length;
      _avgRating = avg;
      _reviewCount = list.length;
      notifyListeners();
    } catch (_) {}
  }
}

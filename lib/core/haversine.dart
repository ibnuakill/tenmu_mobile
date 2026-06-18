/// Haversine formula untuk menghitung jarak geografis antar koordinat (km)
///
/// Implementasi metode utama penelitian:
/// Location Based Service + Haversine Formula
library;

import 'dart:math' show cos, sin, asin, sqrt, pi;

class Haversine {
  /// Radius bumi dalam kilometer
  static const double earthRadiusKm = 6371.0;

  /// Hitung jarak (km) antara dua titik koordinat menggunakan Haversine formula
  ///
  /// [lat1], [lng1] — Koordinat titik pertama
  /// [lat2], [lng2] — Koordinat titik kedua
  ///
  /// Returns jarak dalam kilometer (double)
  static double distance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    _validateCoordinate(lat1, 'lat1');
    _validateCoordinate(lng1, 'lng1');
    _validateCoordinate(lat2, 'lat2');
    _validateCoordinate(lng2, 'lng2');

    final dlat = _toRadians(lat2 - lat1);
    final dlng = _toRadians(lng2 - lng1);

    final a = sin(dlat / 2) * sin(dlat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dlng / 2) *
            sin(dlng / 2);

    final c = 2 * asin(sqrt(a));

    return earthRadiusKm * c;
  }

  /// Hitung jarak (meter) — lebih presisi untuk jarak pendek
  static double distanceInMeters(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return distance(lat1, lng1, lat2, lng2) * 1000;
  }

  /// Format jarak untuk ditampilkan di UI
  ///
  /// < 1 km → "X m"
  /// ≥ 1 km → "X.X km"
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();
      return '$meters m';
    } else {
      return '${distanceKm.toStringAsFixed(1)} km';
    }
  }

  /// Sort list of places by distance from user location
  ///
  /// [places] — List of Map dengan key 'latitude' & 'longitude'
  /// [userLat], [userLng] — Posisi user
  /// [latKey], [lngKey] — Nama key di map (default: 'latitude', 'longitude')
  ///
  /// Returns sorted list (termutasi langsung, return untuk chaining)
  static List<Map<String, dynamic>> sortByDistance({
    required List<Map<String, dynamic>> places,
    required double userLat,
    required double userLng,
    String latKey = 'latitude',
    String lngKey = 'longitude',
  }) {
    places.sort((a, b) {
      final latA = (a[latKey] as num?)?.toDouble() ?? 0.0;
      final lngA = (a[lngKey] as num?)?.toDouble() ?? 0.0;
      final latB = (b[latKey] as num?)?.toDouble() ?? 0.0;
      final lngB = (b[lngKey] as num?)?.toDouble() ?? 0.0;

      // Tempat tanpa koordinat diurutkan ke belakang
      if (latA == 0.0 && latB != 0.0) return 1;
      if (latB == 0.0 && latA != 0.0) return -1;
      if (latA == 0.0 && latB == 0.0) return 0;

      final distA = distance(userLat, userLng, latA, lngA);
      final distB = distance(userLat, userLng, latB, lngB);

      return distA.compareTo(distB);
    });

    return places;
  }

  /// Cari jarak dari user ke suatu tempat, return format teks (nullable)
  ///
  /// Returns null jika koordinat tidak valid (0,0)
  static String? getDistanceText(
    double userLat,
    double userLng,
    double? placeLat,
    double? placeLng,
  ) {
    if (placeLat == null || placeLng == null) return null;
    if (placeLat == 0 && placeLng == 0) return null;

    final d = distance(userLat, userLng, placeLat, placeLng);
    return formatDistance(d);
  }

  // ── Private helpers ──

  static double _toRadians(double degree) => degree * pi / 180;

  static void _validateCoordinate(double value, String name) {
    if (value.isNaN || value.isInfinite) {
      throw ArgumentError('$name tidak valid: $value');
    }
  }
}

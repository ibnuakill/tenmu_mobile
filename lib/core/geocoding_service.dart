/// Geocoding Service — Nominatim OSM
///
/// - Forward: alamat → lat/lng
/// - Reverse: lat/lng → alamat
///
/// Digunakan di form tambah tempat & detail tempat.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'TenMuMobileApp/1.0';

  /// Reverse geocoding: lat/lng → alamat
  ///
  /// [lat], [lng] — Koordinat
  /// Returns display_name atau null
  static Future<String?> reverse(double lat, double lng) async {
    final url = Uri.parse(
      '$_baseUrl/reverse?lat=$lat&lon=$lng&format=json',
    );

    final response = await http.get(url, headers: {'User-Agent': _userAgent});

    if (response.statusCode != 200) return null;

    final data = json.decode(response.body);
    return data['display_name'] as String?;
  }
}

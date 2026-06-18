/// Geocoding Service — Nominatim OSM
///
/// - Forward: alamat → lat/lng
/// - Reverse: lat/lng → alamat
///
/// Digunakan di form tambah tempat & detail tempat.
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

class GeocodingResult {
  final String name;
  final String displayName;
  final double latitude;
  final double longitude;

  const GeocodingResult({
    required this.name,
    required this.displayName,
    required this.latitude,
    required this.longitude,
  });

  factory GeocodingResult.fromJson(Map<String, dynamic> json) {
    return GeocodingResult(
      name: json['name'] ?? '',
      displayName: json['display_name'] ?? '',
      latitude: double.parse(json['lat'] ?? '0'),
      longitude: double.parse(json['lon'] ?? '0'),
    );
  }
}

class GeocodingService {
  static const String _baseUrl = 'https://nominatim.openstreetmap.org';
  static const String _userAgent = 'TenMuMobileApp/1.0';

  /// Cari lokasi berdasarkan teks alamat / nama tempat
  ///
  /// [query] — Nama tempat atau alamat
  /// [limit] — Maksimal hasil (default 5)
  static Future<List<GeocodingResult>> search(String query, {int limit = 5}) async {
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      '$_baseUrl/search?q=${Uri.encodeComponent(query)}&format=json&limit=$limit',
    );

    final response = await http.get(url, headers: {'User-Agent': _userAgent});

    if (response.statusCode != 200) {
      throw Exception('Gagal mencari lokasi (${response.statusCode})');
    }

    final List data = json.decode(response.body);
    return data.map((j) => GeocodingResult.fromJson(j)).toList();
  }

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

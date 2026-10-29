import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache daftar tempat di disk — supaya aplikasi tetap menampilkan sesuatu
/// saat koneksi mati.
///
/// Kenapa: sebelumnya hanya gambar yang di-cache (`cached_network_image`),
/// daftar tempatnya tidak. Begitu internet mati, beranda kosong dan aplikasi
/// terlihat rusak padahal cuma offline.
class PlacesCache {
  PlacesCache._();

  static const String _key = 'places_cache_v1';
  static const int _maxRows = 60;
  static const Duration _maxAge = Duration(days: 7);

  /// Simpan hasil fetch terbaru (hanya daftar utama, tanpa filter pencarian).
  static Future<void> save(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> trimmed =
          rows.length > _maxRows ? rows.sublist(0, _maxRows) : rows;
      await prefs.setString(
        _key,
        jsonEncode(<String, dynamic>{
          'saved_at': DateTime.now().toIso8601String(),
          'rows': trimmed,
        }),
      );
    } catch (e) {
      debugPrint('[PlacesCache] gagal simpan: $e');
    }
  }

  /// Baca cache. Mengembalikan null kalau kosong, rusak, atau sudah kedaluwarsa.
  static Future<List<Map<String, dynamic>>?> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_key);
      if (raw == null || raw.isEmpty) return null;

      final Map<String, dynamic> decoded =
          jsonDecode(raw) as Map<String, dynamic>;

      final DateTime? savedAt =
          DateTime.tryParse(decoded['saved_at']?.toString() ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > _maxAge) {
        return null;
      }

      final List<dynamic> rows = decoded['rows'] as List<dynamic>? ?? <dynamic>[];
      return rows
          .whereType<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (e) {
      debugPrint('[PlacesCache] gagal baca: $e');
      return null;
    }
  }

  /// Hapus cache (mis. saat logout supaya data user lama tidak tertinggal).
  static Future<void> clear() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      debugPrint('[PlacesCache] gagal hapus: $e');
    }
  }
}

/// POI Category Constants
/// Kategori POI (Point of Interest) & Wisata / UMKM Tenmu App
library;

import 'package:flutter/material.dart';

class PoiCategory {
  static const String wisataBudaya = 'Wisata & Budaya';
  static const String kulinerCafe = 'Kuliner & Cafe';
  static const String olehOlehKerajinan = 'Oleh-oleh & Kerajinan';
  static const String penginapanHotel = 'Penginapan & Hotel';
  static const String pertokoanUmkm = 'Pertokoan & UMKM';
  static const String jasaLayanan = 'Jasa & Layanan';
  static const String lainnya = 'Lainnya';

  // Backward compatibility constants (supaya data/pencarian lama tetap kompatibel)
  static const String makanan = 'Kuliner & Cafe';
  static const String perdagangan = 'Pertokoan & UMKM';
  static const String konfeksi = 'Pertokoan & UMKM';
  static const String jasa = 'Jasa & Layanan';
  static const String pertanian = 'Wisata & Budaya';
  static const String perikanan = 'Wisata & Budaya';
  static const String peternakan = 'Wisata & Budaya';
  static const String batik = 'Oleh-oleh & Kerajinan';
  static const String rotan = 'Oleh-oleh & Kerajinan';
  static const String meubel = 'Oleh-oleh & Kerajinan';
  static const String gerabah = 'Oleh-oleh & Kerajinan';
  static const String kerajinan = 'Oleh-oleh & Kerajinan';
  static const String olahanBuah = 'Oleh-oleh & Kerajinan';
  static const String olahanPertanian = 'Oleh-oleh & Kerajinan';

  static const List<String> allCategories = [
    wisataBudaya,
    kulinerCafe,
    olehOlehKerajinan,
    penginapanHotel,
    pertokoanUmkm,
    jasaLayanan,
    lainnya,
  ];

  static bool isValidCategory(String category) {
    return allCategories.contains(category) ||
        _legacyMapping.containsKey(category);
  }

  static final Map<String, String> _legacyMapping = {
    'Makanan': kulinerCafe,
    'Perdagangan': pertokoanUmkm,
    'Konfeksi': pertokoanUmkm,
    'Jasa': jasaLayanan,
    'Pertanian': wisataBudaya,
    'Perikanan': wisataBudaya,
    'Peternakan': wisataBudaya,
    'Batik': olehOlehKerajinan,
    'Rotan': olehOlehKerajinan,
    'Meubel': olehOlehKerajinan,
    'Gerabah': olehOlehKerajinan,
    'Kerajinan': olehOlehKerajinan,
    'Olahan Buah': olehOlehKerajinan,
    'Olahan Pertanian': olehOlehKerajinan,
  };

  /// Memetakan kategori lama di database Supabase ke kategori baru
  static String normalizeCategory(String category) {
    if (allCategories.contains(category)) return category;
    return _legacyMapping[category] ?? lainnya;
  }

  static String getCategoryEmoji(String category) {
    final cat = normalizeCategory(category);
    switch (cat) {
      case wisataBudaya:
        return '🏰';
      case kulinerCafe:
        return '🍜';
      case olehOlehKerajinan:
        return '🛍️';
      case penginapanHotel:
        return '🏨';
      case pertokoanUmkm:
        return '🛒';
      case jasaLayanan:
        return '🔧';
      default:
        return '📍';
    }
  }

  static IconData getCategoryIcon(String category) {
    final cat = normalizeCategory(category);
    switch (cat) {
      case wisataBudaya:
        return Icons.landscape_outlined;
      case kulinerCafe:
        return Icons.restaurant_outlined;
      case olehOlehKerajinan:
        return Icons.palette_outlined;
      case penginapanHotel:
        return Icons.hotel_outlined;
      case pertokoanUmkm:
        return Icons.storefront_outlined;
      case jasaLayanan:
        return Icons.build_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  /// Path SVG custom icon untuk tiap kategori (jika tersedia)
  static String? getCategorySvgPath(String category) {
    final cat = normalizeCategory(category);
    switch (cat) {
      case wisataBudaya:
        return 'assets/icons/categories/travel-explore-rounded.svg';
      case kulinerCafe:
        return 'assets/icons/categories/cup-hot-fill.svg';
      case olehOlehKerajinan:
        return 'assets/icons/categories/gift-fill.svg';
      case penginapanHotel:
        return 'assets/icons/categories/hotel-fill.svg';
      case pertokoanUmkm:
        return 'assets/icons/categories/shopping-cart-fill.svg';
      case jasaLayanan:
        return 'assets/icons/categories/wrench-fill.svg';
      default:
        return 'assets/icons/categories/shop.svg';
    }
  }

  /// Warna representasi tiap kategori (menggunakan warna utama Tenmu yang konsisten)
  static Color getCategoryColor(String category) {
    return const Color(0xFF1ED760); // Hijau utama Tenmu
  }
}

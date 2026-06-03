import 'package:flutter/material.dart';

/// UMKM Category Constants
/// File ini mendefinisikan semua kategori UMKM yang tersedia
class UmkmCategory {
  static const String cafe = 'Cafe';
  static const String warung = 'Warung';
  static const String toko = 'Toko';
  static const String restoran = 'Restoran';
  static const String bakery = 'Bakery';
  static const String fashion = 'Fashion';
  static const String elektronik = 'Elektronik';
  static const String farmasi = 'Farmasi';
  static const String kecantikan = 'Kecantikan';
  static const String lainnya = 'Lainnya';

  /// List semua kategori untuk ditampilkan di UI
  static const List<String> allCategories = [
    cafe,
    warung,
    toko,
    restoran,
    bakery,
    fashion,
    elektronik,
    farmasi,
    kecantikan,
    lainnya,
  ];

  /// Fungsi helper untuk validasi kategori
  static bool isValidCategory(String category) {
    return allCategories.contains(category);
  }

  /// Mendapatkan emoji untuk setiap kategori (untuk UI yang lebih menarik)
  static String getCategoryEmoji(String category) {
    switch (category) {
      case cafe:
        return '☕';
      case warung:
        return '🍜';
      case toko:
        return '🏪';
      case restoran:
        return '🍽️';
      case bakery:
        return '🥐';
      case fashion:
        return '👗';
      case elektronik:
        return '📱';
      case farmasi:
        return '💊';
      case kecantikan:
        return '💄';
      default:
        return '📍';
    }
  }

  /// Ikon Material untuk marker dan elemen UI berdasarkan kategori
  static IconData getCategoryIcon(String category) {
    switch (category) {
      case cafe:
        return Icons.local_cafe_outlined;
      case warung:
        return Icons.ramen_dining_outlined;
      case toko:
        return Icons.storefront_outlined;
      case restoran:
        return Icons.restaurant_outlined;
      case bakery:
        return Icons.bakery_dining_outlined;
      case fashion:
        return Icons.checkroom_outlined;
      case elektronik:
        return Icons.devices_outlined;
      case farmasi:
        return Icons.local_pharmacy_outlined;
      case kecantikan:
        return Icons.content_cut_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

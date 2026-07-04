/// POI Category Constants
/// Kategori UMKM berdasarkan jenis_usaha dataset Kabupaten Cirebon 2021-2022
/// Sumber: Dinas Koperasi Dan Usaha Kecil Dan Menengah Kab. Cirebon
library;

import 'package:flutter/material.dart';

class PoiCategory {
  static const String makanan           = 'Makanan';
  static const String perdagangan       = 'Perdagangan';
  static const String konfeksi          = 'Konfeksi';
  static const String jasa              = 'Jasa';
  static const String pertanian         = 'Pertanian';
  static const String perikanan         = 'Perikanan';
  static const String peternakan        = 'Peternakan';
  static const String batik             = 'Batik';
  static const String rotan             = 'Rotan';
  static const String meubel            = 'Meubel';
  static const String gerabah           = 'Gerabah';
  static const String kerajinan         = 'Kerajinan';
  static const String olahanBuah        = 'Olahan Buah';
  static const String olahanPertanian   = 'Olahan Pertanian';
  static const String lainnya           = 'Lainnya';

  static const List<String> allCategories = [
    makanan,
    perdagangan,
    konfeksi,
    jasa,
    pertanian,
    perikanan,
    peternakan,
    batik,
    rotan,
    meubel,
    gerabah,
    kerajinan,
    olahanBuah,
    olahanPertanian,
    lainnya,
  ];

  static bool isValidCategory(String category) {
    return allCategories.contains(category);
  }

  static String getCategoryEmoji(String category) {
    switch (category) {
      case makanan:
        return '🍽️';
      case perdagangan:
        return '🛒';
      case konfeksi:
        return '👗';
      case jasa:
        return '🔧';
      case pertanian:
        return '🌾';
      case perikanan:
        return '🐟';
      case peternakan:
        return '🐄';
      case batik:
        return '🎨';
      case rotan:
        return '🧺';
      case meubel:
        return '🪑';
      case gerabah:
        return '🏺';
      case kerajinan:
        return '🪡';
      case olahanBuah:
        return '🍊';
      case olahanPertanian:
        return '🌽';
      default:
        return '📍';
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case makanan:
        return Icons.restaurant_outlined;
      case perdagangan:
        return Icons.storefront_outlined;
      case konfeksi:
        return Icons.checkroom_outlined;
      case jasa:
        return Icons.build_outlined;
      case pertanian:
        return Icons.grass_outlined;
      case perikanan:
        return Icons.set_meal_outlined;
      case peternakan:
        return Icons.pets_outlined;
      case batik:
        return Icons.palette_outlined;
      case rotan:
        return Icons.inventory_2_outlined;
      case meubel:
        return Icons.chair_outlined;
      case gerabah:
        return Icons.circle_outlined;
      case kerajinan:
        return Icons.handyman_outlined;
      case olahanBuah:
        return Icons.local_florist_outlined;
      case olahanPertanian:
        return Icons.eco_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  /// Warna representasi tiap kategori (untuk pie chart & marker)
  static Color getCategoryColor(String category) {
    switch (category) {
      case makanan:
        return const Color(0xFFE74C3C);
      case perdagangan:
        return const Color(0xFF3498DB);
      case konfeksi:
        return const Color(0xFFE91E63);
      case jasa:
        return const Color(0xFF9B59B6);
      case pertanian:
        return const Color(0xFF27AE60);
      case perikanan:
        return const Color(0xFF1ABC9C);
      case peternakan:
        return const Color(0xFF8BC34A);
      case batik:
        return const Color(0xFFFF5722);
      case rotan:
        return const Color(0xFF795548);
      case meubel:
        return const Color(0xFF607D8B);
      case gerabah:
        return const Color(0xFFFF8F00);
      case kerajinan:
        return const Color(0xFFAB47BC);
      case olahanBuah:
        return const Color(0xFFFF7043);
      case olahanPertanian:
        return const Color(0xFF66BB6A);
      default:
        return const Color(0xFF90A4AE);
    }
  }
}

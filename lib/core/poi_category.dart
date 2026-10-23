/// POI Category Constants — 5 sektor universal UMKM Kabupaten Cirebon
///
/// Struktur: satu tingkat kategori saja (5 sektor). Sub-kategori dihapus
/// pada migrasi 5-sektor (lihat `supabase/migrate_to_5_sectors.sql`).
library;

import 'package:flutter/material.dart';

class PoiCategory {
  // ══════════════════════════════════════════════════════════════════
  // 5 sektor universal
  // ══════════════════════════════════════════════════════════════════
  static const String kuliner = 'Kuliner (Makanan & Olahan)';
  static const String kriya = 'Kerajinan & Manufaktur Tradisional';
  static const String ritel = 'Perdagangan & Retail';
  static const String agribisnis = 'Agribisnis';
  static const String jasa = 'Jasa';

  /// Semua kategori (urutan tampil di UI).
  static const List<String> allCategories = [
    kuliner,
    kriya,
    ritel,
    agribisnis,
    jasa,
  ];

  static bool isValidCategory(String category) =>
      allCategories.contains(category);

  /// Memetakan kategori lama di database Supabase ke sektor baru.
  /// Kategori yang tidak dikenal → sektor ritel.
  static String normalizeCategory(String category) {
    if (allCategories.contains(category)) return category;
    return ritel;
  }

  // ══════════════════════════════════════════════════════════════════
  // Emoji / Lucide icon / Material Icon / SVG / Warna
  // ══════════════════════════════════════════════════════════════════
  static String getCategoryEmoji(String category) {
    switch (normalizeCategory(category)) {
      case kuliner:
        return '🍽️';
      case kriya:
        return '🎨';
      case ritel:
        return '🏪';
      case agribisnis:
        return '🌾';
      case jasa:
        return '🔧';
      default:
        return '📍';
    }
  }

  static String getCategoryLucide(String category) {
    switch (normalizeCategory(category)) {
      case kuliner:
        return 'utensils';
      case kriya:
        return 'gift';
      case ritel:
        return 'shopping-cart';
      case agribisnis:
        return 'tag';
      case jasa:
        return 'wrench';
      default:
        return 'map-pin';
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (normalizeCategory(category)) {
      case kuliner:
        return Icons.restaurant_outlined;
      case kriya:
        return Icons.palette_outlined;
      case ritel:
        return Icons.storefront_outlined;
      case agribisnis:
        return Icons.grass_outlined;
      case jasa:
        return Icons.build_outlined;
      default:
        return Icons.place_outlined;
    }
  }

  static String? getCategorySvgPath(String category) {
    switch (normalizeCategory(category)) {
      case kuliner:
        return 'assets/icons/categories/cup-hot-fill.svg';
      case kriya:
        return 'assets/icons/categories/gift-fill.svg';
      case ritel:
        return 'assets/icons/categories/shopping-cart-fill.svg';
      case agribisnis:
        return 'assets/icons/categories/shop.svg';
      case jasa:
        return 'assets/icons/categories/wrench-fill.svg';
      default:
        return 'assets/icons/categories/shop.svg';
    }
  }

  static Color getCategoryColor(String category) {
    return const Color(0xFF1ED760); // Hijau utama Tenmu
  }
}

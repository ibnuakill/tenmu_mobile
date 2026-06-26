/// POI Category Constants
/// Kategori Point of Interest (Cafe, Wisata, Kuliner, Hotel, dll)
library;

import 'package:flutter/material.dart';

class PoiCategory {
  static const String cafe = 'Cafe';
  static const String fashion = 'Fashion';
  static const String wisata = 'Wisata';
  static const String kuliner = 'Kuliner';
  static const String hotel = 'Hotel';
  static const String olehOleh = 'Oleh-Oleh';
  static const String umkm = 'UMKM';
  static const String lainnya = 'Lainnya';

  static const List<String> allCategories = [
    cafe,
    fashion,
    wisata,
    kuliner,
    hotel,
    olehOleh,
    umkm,
    lainnya,
  ];

  static bool isValidCategory(String category) {
    return allCategories.contains(category);
  }

  static String getCategoryEmoji(String category) {
    switch (category) {
      case cafe:
        return '☕';
      case fashion:
        return '👗';
      case wisata:
        return '🏖️';
      case kuliner:
        return '🍽️';
      case hotel:
        return '🏨';
      case olehOleh:
        return '🎁';
      case umkm:
        return '🏪';
      default:
        return '📍';
    }
  }

  static IconData getCategoryIcon(String category) {
    switch (category) {
      case cafe:
        return Icons.local_cafe_outlined;
      case fashion:
        return Icons.checkroom_outlined;
      case wisata:
        return Icons.flight_outlined;
      case kuliner:
        return Icons.restaurant_outlined;
      case hotel:
        return Icons.hotel_outlined;
      case olehOleh:
        return Icons.card_giftcard_outlined;
      case umkm:
        return Icons.storefront_outlined;
      default:
        return Icons.place_outlined;
    }
  }
}

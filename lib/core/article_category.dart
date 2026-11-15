import 'package:flutter/material.dart';

/// Kategori artikel Portal UMKM Cirebon.
enum ArticleCategory {
  kuliner('Kuliner', '🍜', Icons.restaurant_rounded, Color(0xFF1ED760)),
  wisata('Wisata', '🏞️', Icons.park_rounded, Color(0xFF1ED760)),
  hiddenGem('Hidden Gem', '✨', Icons.diamond_rounded, Color(0xFF1ED760)),
  tips('Tips & Info', '💡', Icons.lightbulb_rounded, Color(0xFF1ED760)),
  event('Event', '🎪', Icons.event_rounded, Color(0xFF1ED760));

  const ArticleCategory(this.label, this.emoji, this.icon, this.color);

  final String label;
  final String emoji;
  final IconData icon;
  final Color color;

  static ArticleCategory fromString(String value) {
    return ArticleCategory.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ArticleCategory.kuliner,
    );
  }

  String get name => toString().split('.').last;
}

/// Daftar kecamatan Kota Cirebon untuk filter lokasi artikel.
enum KecamatanCirebon {
  kejaksan('Kejaksan'),
  pekalipan('Pekalipan'),
  harjamukti('Harjamukti'),
  lemahwungkuk('Lemahwungkuk'),
  kesambi('Kesambi');

  const KecamatanCirebon(this.label);
  final String label;

  static KecamatanCirebon? fromString(String value) {
    try {
      return KecamatanCirebon.values.firstWhere(
        (e) => e.name == value.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  static List<String> get allLabels => values.map((e) => e.label).toList();
  static List<String> get allNames => values.map((e) => e.name).toList();

  String get name => toString().split('.').last;
}
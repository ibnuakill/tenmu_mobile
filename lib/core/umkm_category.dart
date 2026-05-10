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
}

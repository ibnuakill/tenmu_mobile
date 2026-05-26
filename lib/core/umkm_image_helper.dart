class UmkmImageHelper {
  static List<String> extractImageUrls(Map<String, dynamic> umkm) {
    final rawList = umkm['image_urls'];
    final urls = <String>[];

    if (rawList is List) {
      for (final item in rawList) {
        final value = item?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          urls.add(value);
        }
      }
    }

    final cover = umkm['gambar_url']?.toString().trim() ?? '';
    if (cover.isNotEmpty && !urls.contains(cover)) {
      urls.insert(0, cover);
    }

    return urls;
  }

  static String? primaryImageUrl(Map<String, dynamic> umkm) {
    final urls = extractImageUrls(umkm);
    if (urls.isEmpty) return null;
    return urls.first;
  }
}

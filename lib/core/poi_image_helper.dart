/// Helper untuk ekstrak URL gambar dari data place
library;

class PoiImageHelper {
  static List<String> extractImageUrls(Map<String, dynamic> place) {
    final rawList = place['image_urls'];
    final urls = <String>[];

    if (rawList is List) {
      for (final item in rawList) {
        final value = item?.toString().trim() ?? '';
        if (value.isNotEmpty) {
          urls.add(value);
        }
      }
    }

    final cover = place['gambar_url']?.toString().trim() ?? '';
    if (cover.isNotEmpty && !urls.contains(cover)) {
      urls.insert(0, cover);
    }

    return urls;
  }

  static String? primaryImageUrl(Map<String, dynamic> place) {
    final urls = extractImageUrls(place);
    if (urls.isEmpty) return null;
    return urls.first;
  }
}

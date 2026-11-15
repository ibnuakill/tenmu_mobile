import 'package:flutter_test/flutter_test.dart';
import 'package:tenmu/data/places_sort.dart';

void main() {
  group('sqlSortFor', () {
    test('memetakan tiap SortMode ke nilai yang dikenal SQL', () {
      // Kontrak RPC get_places_paged hanya menerima:
      // 'distance' | 'rating' | 'newest'. Kalau nama enum dikirim apa adanya,
      // 'terdekat' tidak dikenal SQL dan diam-diam jatuh ke pengurutan
      // default — bug yang pernah terjadi di produksi.
      expect(sqlSortFor(SortMode.terdekat), 'distance');
      expect(sqlSortFor(SortMode.rating), 'rating');
      expect(sqlSortFor(SortMode.terbaru), 'newest');
    });

    test('nama enum yang tidak dikenal SQL tidak dikirim mentah', () {
      // 'terdekat'/'terbaru' bukan nilai yang dikenal get_places_paged —
      // keduanya harus dipetakan. (rating memang sama, jadi dikecualikan.)
      expect(sqlSortFor(SortMode.terdekat), isNot('terdekat'));
      expect(sqlSortFor(SortMode.terbaru), isNot('terbaru'));
    });

    test('hasilnya selalu salah satu dari kontrak SQL', () {
      const allowed = {'distance', 'rating', 'newest'};
      for (final mode in SortMode.values) {
        expect(allowed, contains(sqlSortFor(mode)));
      }
    });
  });

  group('labelForSort', () {
    test('memberi label Indonesia yang berbeda satu sama lain', () {
      final labels = SortMode.values.map(labelForSort).toList();
      expect(labels.toSet().length, SortMode.values.length);
      expect(labels, contains('Terdekat'));
      expect(labels, contains('Rating tertinggi'));
      expect(labels, contains('Terbaru'));
    });
  });
}

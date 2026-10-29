import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tenmu/core/places_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('save lalu load mengembalikan baris yang sama', () async {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'nama_tempat': 'Kopi Senja'},
      <String, dynamic>{'id': 2, 'nama_tempat': 'Bakso Pak Slamet'},
    ];

    await PlacesCache.save(rows);
    final List<Map<String, dynamic>>? loaded = await PlacesCache.load();

    expect(loaded, isNotNull);
    expect(loaded!.length, 2);
    expect(loaded.first['nama_tempat'], 'Kopi Senja');
  });

  test('cache kosong mengembalikan null', () async {
    expect(await PlacesCache.load(), isNull);
  });

  test('clear menghapus cache', () async {
    await PlacesCache.save(<Map<String, dynamic>>[
      <String, dynamic>{'id': 1, 'nama_tempat': 'A'},
    ]);
    await PlacesCache.clear();
    expect(await PlacesCache.load(), isNull);
  });

  test('cache kedaluwarsa (>7 hari) diabaikan', () async {
    // Simulasikan data lama dengan menulis langsung ke prefs.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'places_cache_v1':
          '{"saved_at":"2020-01-01T00:00:00.000","rows":[{"id":1}]}',
    });

    expect(await PlacesCache.load(), isNull);
  });
}

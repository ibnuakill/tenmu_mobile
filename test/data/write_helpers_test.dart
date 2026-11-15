import 'package:flutter_test/flutter_test.dart';
import 'package:tenmu/data/write_helpers.dart';

void main() {
  group('verifiedWrite', () {
    test('lolos kalau ada baris yang berubah', () async {
      final rows = await verifiedWrite(
        Future.value([
          {'id': 1},
        ]),
        label: 'test-ok',
      );
      expect(rows, hasLength(1));
      expect(rows.first['id'], 1);
    });

    test('melempar EmptyWriteException kalau 0 baris (RLS / id hilang)', () {
      // PostgREST membalas HTTP 200 walau 0 baris terkena. Tanpa cek ini,
      // UI akan bilang "berhasil" padahal tidak ada yang tersimpan.
      expect(
        () => verifiedWrite(Future.value(<Map<String, dynamic>>[]), label: 'test-empty'),
        throwsA(isA<EmptyWriteException>()),
      );
    });

    test('requireRows: false mengizinkan 0 baris', () async {
      final rows = await verifiedWrite(
        Future.value(<Map<String, dynamic>>[]),
        label: 'test-optional',
        requireRows: false,
      );
      expect(rows, isEmpty);
    });

    test('null dianggap 0 baris', () {
      expect(
        () => verifiedWrite(Future.value(), label: 'test-null'),
        throwsA(isA<EmptyWriteException>()),
      );
    });

    test('error dari PostgREST diteruskan apa adanya', () {
      expect(
        () => verifiedWrite(
          Future.error(StateError('boom')),
          label: 'test-error',
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  test('EmptyWriteException menyebut labelnya supaya bisa dilacak', () {
    final e = EmptyWriteException('updatePlace:42');
    expect(e.toString(), contains('updatePlace:42'));
    expect(e.toString(), contains('0 rows'));
  });
}

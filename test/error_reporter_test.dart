import 'package:flutter_test/flutter_test.dart';
import 'package:tenmu/core/account_service.dart';
import 'package:tenmu/core/error_reporter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ErrorReporter', () {
    test('report tidak melempar exception walau Supabase belum siap', () async {
      // Tanpa markReady(), reporter hanya mencatat di memori & console.
      await expectLater(
        ErrorReporter.report(
          StateError('contoh error'),
          stack: StackTrace.current.toString(),
          context: 'unit-test',
        ),
        completes,
      );
    });

    test('recentErrors menyimpan error terakhir', () async {
      await ErrorReporter.report(
        Exception('gagal muat data'),
        context: 'unit-test',
      );
      expect(
        ErrorReporter.recentErrors.any(
          (String line) => line.contains('gagal muat data'),
        ),
        isTrue,
      );
    });

    test('pesan sangat panjang dipotong, tidak membuat baris raksasa', () async {
      final String huge = 'x' * 5000;
      await ErrorReporter.report(Exception(huge), context: 'unit-test');
      final String last = ErrorReporter.recentErrors.last;
      expect(last.length, lessThan(1500));
    });
  });

  group('AccountServiceException', () {
    test('toString mengembalikan pesan yang bisa ditampilkan ke user', () {
      final AccountServiceException e =
          AccountServiceException('Gagal menghapus akun.');
      expect(e.toString(), 'Gagal menghapus akun.');
    });
  });
}

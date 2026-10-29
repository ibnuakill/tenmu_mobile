import 'package:supabase_flutter/supabase_flutter.dart';

import 'error_reporter.dart';

/// Layanan akun: hapus akun sendiri (syarat kebijakan Play Store).
///
/// Penghapusan butuh service_role, jadi dijalankan lewat edge function
/// `delete-self` yang memverifikasi JWT pemanggil lalu menghapus:
/// review, favorit, data pengajuan pemilik, dan baris auth user.
class AccountService {
  AccountService._();

  static Future<void> deleteMyAccount() async {
    try {
      await Supabase.instance.client.functions.invoke('delete-self');
    } on FunctionException catch (e) {
      throw AccountServiceException(
        _messageFromFunction(e) ?? 'Gagal menghapus akun (kode ${e.status}).',
      );
    } catch (e, s) {
      ErrorReporter.reportCaught(e, s, 'AccountService.deleteMyAccount');
      throw AccountServiceException(
        'Tidak bisa menghubungi server. Periksa koneksi internet lalu coba lagi.',
      );
    }
  }

  static String? _messageFromFunction(FunctionException e) {
    final Object? details = e.details;
    if (details is Map && details['error'] is String) {
      return details['error'] as String;
    }
    return null;
  }
}

class AccountServiceException implements Exception {
  AccountServiceException(this.message);
  final String message;

  @override
  String toString() => message;
}

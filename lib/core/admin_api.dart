import 'package:supabase_flutter/supabase_flutter.dart';

/// Error dari `admin-api` yang sudah ramah dibaca user.
class AdminApiException implements Exception {
  final String message;
  AdminApiException(this.message);

  @override
  String toString() => message;
}

/// Semua aksi admin lewat edge function `admin-api` (service role di server).
///
/// Kenapa tidak `.from('profiles').update(...)` langsung?
/// Policy RLS `profiles_update_self` hanya mengizinkan `auth.uid() = id`.
/// Update admin ke baris user lain tidak error, tapi PostgREST membalas
/// HTTP 200 dengan 0 baris berubah — jadi UI terlihat "berhasil" padahal
/// tidak terjadi apa-apa. Edge function memakai service_role sehingga
/// lolos RLS, tapi memverifikasi sendiri bahwa pemanggil benar-benar admin.
class AdminApi {
  AdminApi._();

  static SupabaseClient get _client => Supabase.instance.client;

  /// Panggil aksi admin. Melempar [AdminApiException] bila gagal.
  static Future<void> call(String action, Map<String, dynamic> payload) async {
    try {
      final res = await _client.functions.invoke(
        'admin-api',
        body: {'action': action, ...payload},
      );

      final data = res.data;
      if (data is Map && data['ok'] == true) return;
      if (data is Map && data['error'] != null) {
        throw AdminApiException(data['error'].toString());
      }
      throw AdminApiException('Aksi gagal diproses server.');
    } on FunctionException catch (e) {
      throw AdminApiException(_describe(e));
    }
  }

  static String _describe(FunctionException e) {
    final details = e.details;
    if (details is Map && details['error'] != null) {
      return details['error'].toString();
    }
    switch (e.status) {
      case 401:
        return 'Sesi kamu sudah berakhir. Login ulang dulu ya.';
      case 403:
        return 'Akun ini bukan admin, jadi tidak bisa melakukan aksi tersebut.';
      case 404:
        return 'Fungsi admin belum aktif di server. Hubungi developer.';
      default:
        return 'Server menolak aksi (HTTP ${e.status}). Coba lagi.';
    }
  }
}

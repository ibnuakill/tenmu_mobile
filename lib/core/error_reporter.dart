import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Pelapor error sederhana — pengganti crash reporting berbayar.
///
/// Kenapa perlu: tanpa ini, error di HP user tidak pernah sampai ke developer.
/// Semua bug yang dilaporkan user ("tombol tidak bereaksi", "AI offline")
/// ditemukan karena user iseng menekan, bukan karena ada log.
///
/// Cara kerja:
///   1. `install()` memasang tiga penangkap: FlutterError, PlatformDispatcher
///      (error async yang tidak tertangkap), dan zona di `main()`.
///   2. `report()` menyimpan ke tabel `app_errors` di Supabase (fire-and-forget,
///      tidak pernah melempar exception ke alur aplikasi).
///
/// Batasan: maksimal [_maxPerSession] error per sesi supaya tidak membanjiri
/// database kalau ada error berulang di dalam loop.
class ErrorReporter {
  ErrorReporter._();

  static const int _maxPerSession = 30;
  static const int _maxMessageLength = 1000;
  static const int _maxStackLength = 4000;

  static bool _handlersInstalled = false;
  static bool _canSend = false;
  static int _sentCount = 0;

  static String? _appVersion;
  static String? _device;

  /// Error terakhir — berguna untuk layar debug / laporan manual.
  static final List<String> recentErrors = <String>[];

  /// Pasang handler sedini mungkin (sebelum Supabase siap sekalipun).
  static void install() {
    if (_handlersInstalled) return;
    _handlersInstalled = true;

    final FlutterExceptionHandler? previous = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      previous?.call(details); // tetap muncul di console saat debug
      report(
        details.exceptionAsString(),
        stack: details.stack?.toString(),
        context: details.context?.toString() ?? 'FlutterError',
      );
    };

    // Error async yang lolos dari try/catch (mis. dari plugin native).
    // Return true = jangan matikan aplikasi.
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      report(error, stack: stack.toString(), context: 'PlatformDispatcher');
      return true;
    };
  }

  /// Dipanggil setelah Supabase siap — mulai dari sini error boleh dikirim.
  static Future<void> markReady() async {
    _canSend = true;
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (e) {
      debugPrint('[ErrorReporter] versi app tidak terbaca: $e');
    }
    try {
      _device = '${Platform.operatingSystem} ${Platform.operatingSystemVersion}';
    } catch (e) {
      debugPrint('[ErrorReporter] info device tidak terbaca: $e');
    }
  }

  /// Kirim satu error ke tabel `app_errors`. Tidak pernah melempar exception.
  static Future<void> report(
    Object error, {
    String? stack,
    String context = 'unknown',
    String? userId,
  }) async {
    final String message = _trim(error.toString(), _maxMessageLength);
    final String trace = _trim(stack ?? '', _maxStackLength);

    // Simpan juga di memori supaya bisa ditampilkan tanpa jaringan.
    recentErrors.add('[$context] $message');
    if (recentErrors.length > 20) recentErrors.removeAt(0);

    debugPrint('[ErrorReporter] $context: $message');

    if (!_canSend || _sentCount >= _maxPerSession) return;
    _sentCount++;

    try {
      final SupabaseClient client = Supabase.instance.client;
      await client.from('app_errors').insert(<String, dynamic>{
        'user_id': userId ?? client.auth.currentUser?.id,
        'message': message,
        'stack': trace.isEmpty ? null : trace,
        'context': _trim(context, 120),
        'platform': _device,
        'app_version': _appVersion,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      // Kalau pelapor error gagal, cukup diamkan — jangan sampai jadi error baru.
      debugPrint('[ErrorReporter] gagal kirim: $e');
    }
  }

  /// Dipakai di blok catch untuk melaporkan error yang sudah ditangani.
  static void reportCaught(Object error, StackTrace stack, String context) {
    unawaited(report(error, stack: stack.toString(), context: context));
  }

  static String _trim(String value, int max) {
    if (value.length <= max) return value;
    return '${value.substring(0, max)}…';
  }
}

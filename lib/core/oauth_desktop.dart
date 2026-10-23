library tenmu.core.oauth_desktop;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// OAuth loopback server untuk desktop (Windows/macOS/Linux).
///
/// Google OAuth dialihkan melalui Supabase kembali ke
/// http://127.0.0.1:8976/auth/callback?code=...
/// Server ini menangkap code, menukarkannya menjadi session melalui PKCE
/// (`exchangeCodeForSession` mengambil code_verifier dari local storage yang
/// disimpan saat `signInWithOAuth` dipanggil), lalu menutup diri.
///
/// Harus dipanggil `start()` SEBELUM `signInWithOAuth` agar server siap
/// ketika browser kembali ke loopback.
class DesktopOAuthService {
  static final _host = InternetAddress.loopbackIPv4;
  static const _port = 8976;
  static const _path = '/auth/callback';
  static const _timeout = Duration(minutes: 5);

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _sub;
  Timer? _timeoutTimer;

  /// Mulai mendengarkan callback loopback.
  Future<void> start() async {
    _server = await HttpServer.bind(_host, _port);
    // Otomatis matikan server jika callback tidak datang dalam waktu waktu.
    _timeoutTimer = Timer(_timeout, () => unawaited(stop()));
    _sub = _server!.listen((req) => unawaited(_handleRequest(req)));
  }

  Future<void> _handleRequest(HttpRequest req) async {
    _timeoutTimer?.cancel();

    if (req.uri.path != _path) {
      _respond(req, 404, '<h1>404 Not Found</h1>');
      return;
    }

    final code = req.uri.queryParameters['code'];
    if (code == null || code.isEmpty) {
      _respond(req, 400, '<h1>Login Gagal</h1><p>Code tidak diterima dari Google.</p>');
      await stop();
      return;
    }

    try {
      // PKCE verifier diambil otomatis dari local storage (simpan saat signInWithOAuth).
      await Supabase.instance.client.auth.exchangeCodeForSession(code);
      _respond(req, 200, _successHtml());
    } on AuthException catch (e) {
      _respond(req, 500, '<h1>Login Gagal</h1><p>${e.message}</p>');
    } catch (e) {
      _respond(req, 500, '<h1>Login Gagal</h1><p>$e</p>');
    } finally {
      await stop();
    }
  }

  void _respond(HttpRequest req, int status, String body) {
    final bytes = utf8.encode(body);
    req.response
      ..statusCode = status
      ..headers.contentType = ContentType.html
      ..contentLength = bytes.length
      ..add(bytes)
      ..close();
  }

  String _successHtml() => '''
<!DOCTYPE html>
<html lang="id">
<head><meta charset="UTF-8"><title>Login Berhasil - TenMu</title>
<style>
body{font-family:sans-serif;background:#121212;color:#eee;display:flex;flex-direction:column;align-items:center;justify-content:center;height:100vh;margin:0}
h1{color:#1ED760;margin-bottom:8px}
p{margin:0}
</style>
</head>
<body>
<h1>Login Berhasil!</h1>
<p>Anda dapat menutup halaman ini dan kembali ke aplikasi TenMu.</p>
</body>
</html>
''';

  Future<void> stop() async {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    await _sub?.cancel();
    _sub = null;
    await _server?.close(force: true);
    _server = null;
  }
}

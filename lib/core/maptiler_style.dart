import 'package:flutter_dotenv/flutter_dotenv.dart';

/// MapTiler style URLs + key loader from .env.
/// MapTiler key is stored in .env as MAPTILER_KEY.
class MapTilerStyle {
  static const String _keyEnvName = 'MAPTILER_KEY';

  // ponytail: hardcoded preset list. Add variants (satellite, outdoor, etc.) on demand.
  static const String streets =
      'https://api.maptiler.com/maps/streets/style.json';
  static const String satellite =
      'https://api.maptiler.com/maps/satellite/style.json';
  static const String outdoor =
      'https://api.maptiler.com/maps/outdoor/style.json';

  /// Reads key from .env. Throws if missing — caller must guard with [hasKey].
  static String get key {
    final v = dotenv.env[_keyEnvName];
    if (v == null || v.isEmpty) {
      throw StateError(
        'MAPTILER_KEY missing in .env. Add MAPTILER_KEY=<your_key>.',
      );
    }
    return v;
  }

  static bool get hasKey {
    final v = dotenv.env[_keyEnvName];
    return v != null && v.isNotEmpty;
  }

  /// Appends ?key= to a style URL.
  static String url(String styleBase) {
    final sep = styleBase.contains('?') ? '&' : '?';
    return '$styleBase${sep}key=$key';
  }
}

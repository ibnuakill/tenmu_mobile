/// Helper versi aplikasi yang dibaca dari build (bukan hardcode).
///
/// Panggil [AppInfo.load] sekali di awal program (di `main`), setelah itu
/// [AppInfo.label] aman dipakai di widget mana pun.
///
/// Catatan penamaan: sengaja bukan `AppVersion` — nama itu sudah dipakai
/// model rilis di `core/app_update_service.dart`.
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  AppInfo._();

  static String _version = '';
  static String _buildNumber = '';

  /// Muat versi dari APK/iOS bundle. Aman dipanggil berkali-kali.
  static Future<void> load() async {
    if (_version.isNotEmpty) return;
    try {
      final info = await PackageInfo.fromPlatform();
      _version = info.version;
      _buildNumber = info.buildNumber;
    } catch (_) {
      _version = '1.0.0';
      _buildNumber = '0';
    }
  }

  /// Versi rilis, misal `1.2.3`.
  static String get version => _version.isEmpty ? '1.0.0' : _version;

  /// Build number, misal `9`.
  static String get buildNumber => _buildNumber.isEmpty ? '0' : _buildNumber;

  /// `v1.2.3`
  static String get label => 'v$version';

  /// `v1.2.3 (9)`
  static String get fullLabel => 'v$version ($buildNumber)';
}

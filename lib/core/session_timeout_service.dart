import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SessionTimeoutService {
  static const String _keyLastActive = 'last_active_time_ms';
  static const int _maxInactivityDays = 3;

  /// Memeriksa apakah session sudah kadaluarsa (tidak aktif > 3 hari).
  /// Mengembalikan true jika session di-logout karena kadaluarsa.
  static Future<bool> checkAndEnforceTimeout() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastActiveMs = prefs.getInt(_keyLastActive);
    final now = DateTime.now();

    if (lastActiveMs != null) {
      final lastActive = DateTime.fromMillisecondsSinceEpoch(lastActiveMs);
      final difference = now.difference(lastActive);

      if (difference.inDays >= _maxInactivityDays) {
        // Sudah lebih dari 3 hari tidak aktif -> force logout
        await prefs.remove(_keyLastActive);
        await Supabase.instance.client.auth.signOut();
        return true;
      }
    }

    // Update timestamp ke sekarang karena user aktif
    await touchActivity();
    return false;
  }

  /// Memperbarui timestamp aktivitas terakhir user ke waktu saat ini
  static Future<void> touchActivity() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastActive, DateTime.now().millisecondsSinceEpoch);
  }

  /// Menghapus data timestamp saat user logout manual
  static Future<void> clearActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLastActive);
  }
}

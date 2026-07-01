import 'package:shared_preferences/shared_preferences.dart';

class AuthRateLimit {
  // Login: 5 gagal → lock 3 jam
  static const int _maxLoginAttempts = 5;
  static const Duration _loginLockDuration = Duration(hours: 3);

  // Forgot password: 3 gagal → lock 6 jam
  static const int _maxForgotAttempts = 3;
  static const Duration _forgotLockDuration = Duration(hours: 6);

  // ── Login ────────────────────────────────────────────────────────────

  static Future<bool> isLoginLocked(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntil = prefs.getInt('login_locked_until_$email');
    if (lockedUntil == null) return false;
    if (DateTime.now().millisecondsSinceEpoch >= lockedUntil) {
      await prefs.remove('login_locked_until_$email');
      await prefs.remove('login_attempts_$email');
      return false;
    }
    return true;
  }

  static Future<int> incrementLoginAttempt(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'login_attempts_$email';
    final attempts = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, attempts);

    if (attempts >= _maxLoginAttempts) {
      final until = DateTime.now().millisecondsSinceEpoch +
          _loginLockDuration.inMilliseconds;
      await prefs.setInt('login_locked_until_$email', until);
    }
    return attempts;
  }

  static Future<void> resetLoginAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('login_attempts_$email');
    await prefs.remove('login_locked_until_$email');
  }

  static Future<int> getLoginRemainingLockSeconds(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntil = prefs.getInt('login_locked_until_$email');
    if (lockedUntil == null) return 0;
    final remaining = (lockedUntil - DateTime.now().millisecondsSinceEpoch) ~/ 1000;
    return remaining > 0 ? remaining : 0;
  }

  // ── Forgot Password ──────────────────────────────────────────────────

  static Future<bool> isForgotLocked(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final lockedUntil = prefs.getInt('forgot_locked_until_$email');
    if (lockedUntil == null) return false;
    if (DateTime.now().millisecondsSinceEpoch >= lockedUntil) {
      await prefs.remove('forgot_locked_until_$email');
      await prefs.remove('forgot_attempts_$email');
      return false;
    }
    return true;
  }

  static Future<int> incrementForgotAttempt(String email) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'forgot_attempts_$email';
    final attempts = (prefs.getInt(key) ?? 0) + 1;
    await prefs.setInt(key, attempts);

    if (attempts >= _maxForgotAttempts) {
      final until = DateTime.now().millisecondsSinceEpoch +
          _forgotLockDuration.inMilliseconds;
      await prefs.setInt('forgot_locked_until_$email', until);
    }
    return attempts;
  }

  static Future<void> resetForgotAttempts(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('forgot_attempts_$email');
    await prefs.remove('forgot_locked_until_$email');
  }

  // ── Helper ───────────────────────────────────────────────────────────

  static String formatDuration(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) return '$hours jam $minutes menit';
    if (minutes > 0) return '$minutes menit $seconds detik';
    return '$seconds detik';
  }
}

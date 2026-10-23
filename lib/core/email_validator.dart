/// Validasi email "ketat" untuk TenMu.
///
/// Dipakai di layar Login, Daftar, dan OTP supaya email asal-asalan
/// (format salah, domain sekali-pakai, atau typo umum) ditolak SEBELUM
/// request dikirim ke Supabase.
///
/// Catatan: ini validasi client-side (UX + hemat kuota SMTP). Untuk
/// pertahanan sebenarnya tetap mengandalkan rate limit di sisi server
/// (Supabase) dan `AuthRateLimit` di sisi app.
class EmailValidator {
  EmailValidator._();

  /// Format email yang wajar: ada local-part, '@', domain, dan TLD >= 2 huruf.
  /// Lebih ketat dari regex lama (yang meloloskan "a@b.c" tanpa batas jelas).
  static final RegExp _regex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?'
    r'(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*'
    r'\.[a-zA-Z]{2,}$',
  );

  /// Panjang maksimal email sesuai RFC 5321.
  static const int _maxLength = 254;

  /// Domain email sekali-pakai / sementara yang umum dipakai untuk spam.
  /// Daftar ringkas — cukup untuk menangkal mayoritas "email asal".
  static const Set<String> _disposableDomains = {
    'mailinator.com',
    'guerrillamail.com',
    'guerrillamail.net',
    '10minutemail.com',
    '10minutemail.net',
    'tempmail.com',
    'temp-mail.org',
    'tempmail.net',
    'throwawaymail.com',
    'yopmail.com',
    'yopmail.fr',
    'trashmail.com',
    'sharklasers.com',
    'getnada.com',
    'maildrop.cc',
    'dispostable.com',
    'fakeinbox.com',
    'mailnesia.com',
    'mintemail.com',
    'mohmal.com',
    'emailondeck.com',
    'moakt.com',
    'tempr.email',
    'discard.email',
    'spam4.me',
    'grr.la',
    'mailcatch.com',
    'mail-temporaire.fr',
    'tempinbox.com',
    'mytemp.email',
    'luxusmail.org',
    'inboxkitten.com',
    'burnermail.io',
    '33mail.com',
    'anonbox.net',
    'harakirimail.com',
  };

  /// Domain yang sering salah ketik (typo) → saran koreksi.
  static const Map<String, String> _typoDomains = {
    'gmial.com': 'gmail.com',
    'gmai.com': 'gmail.com',
    'gmail.co': 'gmail.com',
    'gmail.con': 'gmail.com',
    'gmail.cm': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'gnail.com': 'gmail.com',
    'gmail.comm': 'gmail.com',
    'yahoo.co': 'yahoo.com',
    'yaho.com': 'yahoo.com',
    'yahoo.con': 'yahoo.com',
    'yhaoo.com': 'yahoo.com',
    'hotmial.com': 'hotmail.com',
    'hotmai.com': 'hotmail.com',
    'hotmail.con': 'hotmail.com',
    'outlok.com': 'outlook.com',
    'outlook.con': 'outlook.com',
    'iclod.com': 'icloud.com',
    'icloud.con': 'icloud.com',
  };

  /// Mengembalikan pesan error bila email tidak valid, atau `null` bila OK.
  static String? validate(String rawEmail) {
    final email = rawEmail.trim();

    if (email.isEmpty) return 'Email tidak boleh kosong';
    if (email.length > _maxLength) return 'Email terlalu panjang';
    if (email.contains(' ')) return 'Email tidak boleh mengandung spasi';
    if (!email.contains('@')) return 'Email harus mengandung tanda @';
    if (!_regex.hasMatch(email)) {
      return 'Format email tidak valid (contoh: nama@gmail.com)';
    }

    final domain = _domainOf(email);
    if (_disposableDomains.contains(domain)) {
      return 'Email sementara/sekali-pakai tidak diizinkan. Pakai email aktif.';
    }

    return null;
  }

  /// Saran perbaikan bila domain adalah typo yang dikenal, atau `null`.
  static String? suggestFix(String rawEmail) {
    final email = rawEmail.trim();
    final domain = _domainOf(email);
    final fixed = _typoDomains[domain];
    if (fixed == null) return null;

    final at = email.lastIndexOf('@');
    if (at <= 0) return null;
    return '${email.substring(0, at)}@$fixed';
  }

  /// `true` bila domain termasuk daftar sekali-pakai.
  static bool isDisposable(String rawEmail) =>
      _disposableDomains.contains(_domainOf(rawEmail.trim()));

  static String _domainOf(String email) {
    final at = email.lastIndexOf('@');
    if (at < 0 || at == email.length - 1) return '';
    return email.substring(at + 1).toLowerCase();
  }
}

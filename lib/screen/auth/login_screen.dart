import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/auth_rate_limit.dart';
import 'auth_gate.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';

// ── Palet kunci putih–hitam untuk layar login ──
const Color _white = Colors.white;
const Color _ink = Color(0xFF111111);
const Color _grey = Color(0xFF8A8A8A);
const Color _hint = Color(0xFFBDBDBD);
const Color _toggleBg = Color(0xFFF0F0F5);
const Color _border = Color(0xFFE5E5E5);
const Color _divider = Color(0xFFEEEEEE);
const Color _btn = Color(0xFF000000);
const Color _btnLabel = Colors.white;

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  static const int _maxLoginAttempts = 5;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    // Dengarkan auth state (misal saat login Google selesai via deep link)
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && data.session != null) {
        _showSuccessSheet();
      }
    });
  }

  void _navigateHome() {
    if (!mounted) return;
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  }

  /// Bottom sheet ala referensi kanan: "Login Successful".
  /// Dipanggil setelah login email maupun Google berhasil.
  void _showSuccessSheet() {
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      isDismissible: false,
      enableDrag: false,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: _white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _divider,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 28),
            const _SuccessIcon(size: 110),
            const SizedBox(height: 20),
            const Text(
              'Login Successful',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: _ink,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Everything looks good, moving\nyou ahead',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.5,
                color: _grey,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _navigateHome();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _btn,
                  foregroundColor: _btnLabel,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Got it',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        // Mobile wajib pakai deep link agar token dikembalikan ke app setelah OAuth
        redirectTo: kIsWeb ? Uri.base.origin : 'tenmu://login-callback',
      );
      // Saat browser kembali via deep link, _authSub di atas akan otomatis
      // menampilkan success sheet.
    } on AuthException catch (e) {
      _showErrorDialog(
        title: 'Login Google Gagal',
        message: e.message,
        icon: Icons.g_mobiledata_rounded,
      );
    } catch (_) {
      _showErrorDialog(
        title: 'Login Google Gagal',
        message:
            'Tidak dapat masuk dengan Google. Periksa koneksi internetmu lalu coba lagi.',
        icon: Icons.g_mobiledata_rounded,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signIn() async {
    if (_isLoading) return;

    // Validasi form dulu — error tampil inline di bawah field
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final email = _emailController.text.trim();

    // Cek rate limit lock
    final locked = await AuthRateLimit.isLoginLocked(email);
    if (locked) {
      final remaining = await AuthRateLimit.getLoginRemainingLockSeconds(email);
      _showErrorDialog(
        title: 'Akun Terkunci Sementara',
        message:
            'Terlalu banyak percobaan login gagal.\n\nKamu bisa mencoba lagi setelah ${AuthRateLimit.formatDuration(remaining)}.',
        icon: Icons.lock_clock_outlined,
      );
      return;
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: _passwordController.text.trim(),
      );

      // Login berhasil — reset attempt counter
      await AuthRateLimit.resetLoginAttempts(email);

      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSuccessSheet();
    } on AuthException catch (e) {
      final attempts = await AuthRateLimit.incrementLoginAttempt(email);
      final remaining = _maxLoginAttempts - attempts;
      if (!mounted) return;

      void goToForgot() {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
        );
      }

      if (remaining <= 0) {
        _showErrorDialog(
          title: 'Akun Terkunci Sementara',
          message:
              'Terlalu banyak percobaan gagal.\n\nDemi keamanan, login dikunci selama 3 jam. Silakan coba lagi nanti atau reset password.',
          icon: Icons.lock_outline_rounded,
          actionLabel: 'Lupa Password?',
          onAction: goToForgot,
        );
      } else if (_isCredentialError(e.message)) {
        _showErrorDialog(
          title: 'Email atau Password Salah',
          message:
              'Kredensial yang kamu masukkan tidak cocok dengan akun manapun.\n\nSisa percobaan: $remaining dari $_maxLoginAttempts sebelum login dikunci sementara.',
          icon: Icons.no_accounts_outlined,
          actionLabel: 'Lupa Password?',
          onAction: goToForgot,
        );
      } else if (_isEmailNotConfirmed(e.message)) {
        _showErrorDialog(
          title: 'Email Belum Terverifikasi',
          message:
              'Akunmu sudah terdaftar, tapi email belum diverifikasi.\n\nSilakan cek kotak masuk (atau folder spam) untuk link verifikasi.',
          icon: Icons.mark_email_unread_outlined,
        );
      } else {
        _showErrorDialog(
          title: 'Login Gagal',
          message:
              '${e.message}\n\nSisa percobaan: $remaining dari $_maxLoginAttempts.',
          icon: Icons.error_outline_rounded,
        );
      }
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog(
        title: 'Koneksi Bermasalah',
        message:
            'Tidak dapat terhubung ke server. Periksa koneksi internetmu lalu coba lagi.',
        icon: Icons.wifi_off_rounded,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _isCredentialError(String message) {
    final m = message.toLowerCase();
    return m.contains('invalid login credentials') ||
        m.contains('invalid credentials') ||
        m.contains('wrong password') ||
        m.contains('user not found');
  }

  bool _isEmailNotConfirmed(String message) {
    final m = message.toLowerCase();
    return m.contains('email not confirmed') || m.contains('not confirmed');
  }

  // ── Error Dialog ──────────────────────────────────────────────────────────

  void _showErrorDialog({
    required String title,
    required String message,
    IconData icon = Icons.error_outline_rounded,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: _white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _border),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _toggleBg,
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.4),
                    width: 1.5,
                  ),
                ),
                child: Icon(icon, color: Colors.redAccent, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: _grey,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _btn,
                    foregroundColor: _btnLabel,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Mengerti',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onAction();
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: _grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── Validators ────────────────────────────────────────────────────────────

  String? _validateEmail(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Email tidak boleh kosong';
    final emailRegex = RegExp(r'^[\w\.\-]+@([\w\-]+\.)+[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(v)) return 'Format email tidak valid';
    return null;
  }

  String? _validatePassword(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Password tidak boleh kosong';
    if (v.length < 6) return 'Password minimal 6 karakter';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(24, 16, 24, 24 + bottomInset),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── ILUSTRASI ala referensi ──────────────────────────
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: const _LoginHero(),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Enter your details to access your account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: _grey,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── TOGGLE Login / Sign up ───────────────────────────
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: _AuthToggle(
                          activeLabel: 'Login',
                          onSignUp: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RegisterScreen(),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── FORM ─────────────────────────────────────────────
                    SlideTransition(
                      position: _slideAnim,
                      child: FadeTransition(
                        opacity: _fadeAnim,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _label('username'),
                            const SizedBox(height: 6),
                            _field(
                              controller: _emailController,
                              hint: 'Email kamu',
                              keyboardType: TextInputType.emailAddress,
                              validator: _validateEmail,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 16),
                            _label('Password'),
                            const SizedBox(height: 6),
                            _field(
                              controller: _passwordController,
                              hint: '••••••••',
                              isPassword: true,
                              obscure: _obscurePassword,
                              validator: _validatePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _signIn(),
                              onToggle: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(6),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen(),
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 4,
                                  ),
                                  child: const Text(
                                    'Forgot Password',
                                    style: TextStyle(
                                      color: _ink,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Tombol Login (pill hitam ala referensi)
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _signIn,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _btn,
                                  foregroundColor: _btnLabel,
                                  disabledBackgroundColor:
                                      _btn.withValues(alpha: 0.6),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          color: _btnLabel,
                                          strokeWidth: 2.2,
                                        ),
                                      )
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Divider + Google (tetap dipertahankan fungsinya,
                            // tampilannya disamakan pill)
                            const Row(
                              children: [
                                Expanded(
                                  child: Divider(color: _divider),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: Text(
                                    'atau lanjut dengan',
                                    style: TextStyle(
                                      color: _hint,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(color: _divider),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed:
                                    _isLoading ? null : _signInWithGoogle,
                                icon: SvgPicture.asset(
                                  'assets/branding/google-logo.svg',
                                  height: 22,
                                  width: 22,
                                ),
                                label: const Text(
                                  'Masuk dengan Google',
                                  style: TextStyle(
                                    color: _ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(
                                    color: _border,
                                    width: 1.2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Helper Widgets ────────────────────────────────────────────────────────
  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          color: _grey,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? obscure : false,
      validator: validator,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: const TextStyle(color: _ink, fontSize: 15),
      cursorColor: _ink,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: _hint, fontSize: 14),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _hint,
                  size: 20,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: _white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        errorStyle: const TextStyle(color: Colors.redAccent, fontSize: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(
            color: _ink,
            width: 1.4,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.4),
        ),
      ),
    );
  }
}

/// Segmented control Login / Sign up ala referensi.
class _AuthToggle extends StatelessWidget {
  final String activeLabel;
  final VoidCallback onSignUp;

  const _AuthToggle({required this.activeLabel, required this.onSignUp});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: _toggleBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                activeLabel,
                style: const TextStyle(
                  color: _ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onSignUp,
              child: Container(
                height: 44,
                alignment: Alignment.center,
                child: const Text(
                  'Sign up',
                  style: TextStyle(
                    color: _grey,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ilustrasi hero ala referensi (kucing + gembok + kunci).
///
/// Dibuat murni dari widget supaya langsung jalan tanpa file gambar.
/// Kalau kamu sudah punya file ilustrasi persis seperti referensi,
/// tinggal ganti isi build() dengan:
/// `Image.asset('assets/branding/login_hero.png', height: 150)`
class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 155,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Blob biru di belakang
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF8DB8F2).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(36),
            ),
          ),
          // Kucing (digambar sederhana: kepala + telinga + wajah)
          Positioned(
            top: 4,
            child: SizedBox(
              width: 110,
              height: 90,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // telinga kiri/kanan
                  const Positioned(
                    left: 18,
                    top: 0,
                    child: _CatEar(),
                  ),
                  const Positioned(
                    right: 18,
                    top: 0,
                    child: _CatEar(),
                  ),
                  // kepala
                  Container(
                    width: 78,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(
                        color: const Color(0xFF1A1A1A),
                        width: 2.2,
                      ),
                    ),
                  ),
                  // mata merem + mulut
                  const Positioned(
                    top: 30,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('≧',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                        SizedBox(width: 12),
                        Text('≦',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  const Positioned(
                    top: 50,
                    child: Text('•ᴥ•',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                  // tangan mengepal ke atas (kanan)
                  Positioned(
                    right: 2,
                    top: 22,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF1A1A1A),
                          width: 2.2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Gembok biru
          Positioned(
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Stack(
                  alignment: Alignment.topCenter,
                  children: [
                    // body gembok
                    Container(
                      margin: const EdgeInsets.only(top: 16),
                      width: 56,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A9EFF),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF1A1A1A),
                          width: 2.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.lock,
                        color: Color(0xFF1A1A1A),
                        size: 22,
                      ),
                    ),
                    // shackle
                    Container(
                      width: 32,
                      height: 26,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(
                              color: const Color(0xFF1A1A1A), width: 2.2),
                          left: BorderSide(
                              color: const Color(0xFF1A1A1A), width: 2.2),
                          right: BorderSide(
                              color: const Color(0xFF1A1A1A), width: 2.2),
                        ),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
                // kunci hitam
                const Padding(
                  padding: EdgeInsets.only(left: 4, bottom: 4),
                  child: Icon(Icons.key, color: Color(0xFF1A1A1A), size: 34),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CatEar extends StatelessWidget {
  const _CatEar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFF1A1A1A), width: 2.2),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(4),
        ),
      ),
    );
  }
}

/// Icon sukses ala referensi kanan: tangan + badge centang hijau.
class _SuccessIcon extends StatelessWidget {
  final double size;

  const _SuccessIcon({this.size = 110});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: const Color(0xFFD8E9FF),
              shape: BoxShape.circle,
            ),
          ),
          // sparkles
          const Positioned(
            left: 16,
            top: 26,
            child: Icon(Icons.star, size: 14, color: Colors.white),
          ),
          const Positioned(
            right: 20,
            bottom: 26,
            child: Icon(Icons.star, size: 12, color: Colors.white),
          ),
          const Positioned(
            right: 24,
            top: 30,
            child: Icon(Icons.star, size: 10, color: Colors.white),
          ),
          // tangan
          Container(
            width: size * 0.52,
            height: size * 0.52,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.waving_hand_rounded,
              size: size * 0.32,
              color: Color(0xFF1A1A1A),
            ),
          ),
          // badge centang hijau
          Positioned(
            right: size * 0.08,
            top: size * 0.06,
            child: Container(
              width: size * 0.27,
              height: size * 0.27,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child: Icon(
                Icons.check_rounded,
                color: Colors.white,
                size: size * 0.16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

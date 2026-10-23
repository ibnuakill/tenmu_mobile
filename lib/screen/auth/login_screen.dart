import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_rate_limit.dart';
import '../../core/oauth_desktop.dart';
import '../../core/email_validator.dart';
import '../../core/lucide_icons.dart';
import 'email_otp_screen.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'widgets/auth_common.dart';

/// Layar masuk TenMu.
///
/// Tiga cara masuk:
///   1. Email + password (form utama)
///   2. Google OAuth
///   3. Email tanpa password (kode OTP 6 digit)
///
/// Security: rate limit (5× gagal → lock 3 jam) dan validasi email ketat.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  bool _isLoadingPassword = false;
  bool _isLoadingGoogle = false;
  String? _emailError;
  String? _passwordError;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── 1. Email + password ───────────────────────────────────────────────
  Future<void> _signInWithPassword() async {
    if (_isLoadingPassword) return;
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (!_agreedToTerms) {
      showAuthSnack(context, 'Setujui Ketentuan Layanan dulu ya.');
      return;
    }

    final emailErr = EmailValidator.validate(email);
    if (emailErr != null) {
      setState(() => _emailError = emailErr);
      return;
    }
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password tidak boleh kosong');
      return;
    }
    setState(() {
      _emailError = null;
      _passwordError = null;
    });

    // Rate limit: cek lock sebelum mencoba
    if (await AuthRateLimit.isLoginLocked(email)) {
      final remaining = await AuthRateLimit.getLoginRemainingLockSeconds(email);
      if (!mounted) return;
      showAuthErrorDialog(
        context,
        title: 'Akun Terkunci Sementara',
        message:
            'Terlalu banyak percobaan gagal. Coba lagi setelah ${AuthRateLimit.formatDuration(remaining)}.',
      );
      return;
    }

    setState(() => _isLoadingPassword = true);
    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      await AuthRateLimit.resetLoginAttempts(email);
      // Sukses → onAuthStateChange akan memicu bottom sheet sukses.
    } on AuthException catch (e) {
      final attempts = await AuthRateLimit.incrementLoginAttempt(email);
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('invalid login credentials')) {
        if (attempts >= 5) {
          showAuthErrorDialog(
            context,
            title: 'Akun Terkunci Sementara',
            message: 'Password salah 5×. Demi keamanan, akun diblokir 3 jam.',
          );
        } else {
          showAuthSnack(context, 'Email atau password salah. Sisa percobaan: ${5 - attempts}');
        }
      } else if (msg.contains('email not confirmed')) {
        showAuthSnack(
          context,
          'Email belum diverifikasi. Pakai "Masuk dengan Email" untuk verifikasi.',
        );
      } else {
        showAuthSnack(context, e.message);
      }
    } catch (_) {
      if (mounted) showAuthSnack(context, 'Gagal masuk. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoadingPassword = false);
    }
  }

  // ── 2. Google ─────────────────────────────────────────────────────────
  Future<void> _signInWithGoogle() async {
    if (_isLoadingGoogle) return;
    if (!_agreedToTerms) {
      showAuthSnack(context, 'Setujui Ketentuan Layanan dulu ya.');
      return;
    }
    setState(() => _isLoadingGoogle = true);
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    try {
      final redirectTo = kIsWeb
          ? Uri.base.origin
          : isDesktop
              ? 'http://127.0.0.1:8976/auth/callback'
              : 'tenmu://login-callback';
      if (isDesktop) await DesktopOAuthService().start();
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: redirectTo,
      );
    } on AuthException catch (e) {
      if (isDesktop) await DesktopOAuthService().stop();
      if (mounted) showAuthErrorDialog(context, title: 'Login Google Gagal', message: e.message);
    } catch (_) {
      if (isDesktop) await DesktopOAuthService().stop();
      if (mounted) {
        showAuthErrorDialog(
          context,
          title: 'Login Google Gagal',
          message: 'Tidak dapat masuk dengan Google. Periksa koneksi internetmu lalu coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingGoogle = false);
    }
  }

  // ── 3. Email OTP ──────────────────────────────────────────────────────
  Future<void> _openOtpLogin() async {
    if (!_agreedToTerms) {
      showAuthSnack(context, 'Setujui Ketentuan Layanan dulu ya.');
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const EmailOtpScreen()),
    );
    // Pop-up "Login Berhasil" ditangani AuthGate (lihat auth_gate.dart).
  }

  Future<void> _openRegister() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
    // Pop-up "Login Berhasil" ditangani AuthGate (lihat auth_gate.dart).
  }

  void _openForgotPassword() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoadingPassword || _isLoadingGoogle;

    return Scaffold(
      backgroundColor: AuthPalette.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FadeTransition(opacity: _fadeAnim, child: const _LoginHero()),
                  const SizedBox(height: 16),
                  const Text(
                    'Selamat Datang di TenMu',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AuthPalette.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Masuk untuk menemukan tempat menarik di sekitarmu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13.5, height: 1.4, color: AuthPalette.grey),
                  ),
                  const SizedBox(height: 26),
                  SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // ── Form email + password ──
                          AuthTextField(
                            controller: _emailController,
                            label: 'Email',
                            hint: 'nama@email.com',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            errorText: _emailError,
                            enabled: !busy,
                            onChanged: (_) {
                              if (_emailError != null) setState(() => _emailError = null);
                            },
                          ),
                          const SizedBox(height: 14),
                          AuthTextField(
                            controller: _passwordController,
                            label: 'Password',
                            hint: '••••••••',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            autofillHints: const [AutofillHints.password],
                            textInputAction: TextInputAction.done,
                            errorText: _passwordError,
                            enabled: !busy,
                            onChanged: (_) {
                              if (_passwordError != null) setState(() => _passwordError = null);
                            },
                            onSubmitted: (_) => _signInWithPassword(),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AuthPalette.grey,
                                size: 20,
                              ),
                              onPressed: () =>
                                  setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: busy ? null : _openForgotPassword,
                              child: const Text(
                                'Lupa password?',
                                style: TextStyle(color: AuthPalette.grey, fontSize: 13),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          AuthPrimaryButton(
                            label: 'Masuk',
                            loadingLabel: 'Masuk...',
                            isLoading: _isLoadingPassword,
                            onPressed: _signInWithPassword,
                          ),
                          const SizedBox(height: 22),
                          const AuthOrDivider(),
                          const SizedBox(height: 22),
                          // ── Google (kiri) & Email OTP (kanan) — bulat, icon saja ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _CircleAuthButton(
                                tooltip: 'Masuk dengan Google',
                                onPressed: busy ? null : _signInWithGoogle,
                                isLoading: _isLoadingGoogle,
                                child: SvgPicture.asset(
                                  'assets/branding/google-logo.svg',
                                  height: 28,
                                  width: 28,
                                ),
                              ),
                              const SizedBox(width: 24),
                              _CircleAuthButton(
                                tooltip: 'Masuk dengan Email (kode OTP)',
                                onPressed: busy ? null : _openOtpLogin,
                                child: const LucideIcon(
                                  'mail',
                                  size: 26,
                                  color: AuthPalette.ink,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          AuthTermsCheckbox(
                            value: _agreedToTerms,
                            onChanged: busy
                                ? null
                                : (v) => setState(() => _agreedToTerms = v ?? false),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Belum punya akun? ',
                                style: TextStyle(color: AuthPalette.grey, fontSize: 13.5),
                              ),
                              GestureDetector(
                                onTap: busy ? null : _openRegister,
                                child: const Text(
                                  'Daftar',
                                  style: TextStyle(
                                    color: AuthPalette.btn,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
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
    );
  }
}

class _CircleAuthButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool isLoading;
  final String tooltip;

  const _CircleAuthButton({
    required this.onPressed,
    required this.child,
    required this.tooltip,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 64,
        height: 64,
        child: Material(
          color: AuthPalette.surface,
          shape: CircleBorder(
            side: BorderSide(color: AuthPalette.border, width: 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: AuthPalette.ink,
                        strokeWidth: 2.2,
                      ),
                    )
                  : child,
            ),
          ),
        ),
      ),
    );
  }
}

class _LoginHero extends StatelessWidget {
  const _LoginHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: Center(
        child: RepaintBoundary(
          child: Lottie.asset(
            'assets/lottie/login_secure.json',
            width: 180,
            height: 180,
            fit: BoxFit.contain,
            repeat: true,
          ),
        ),
      ),
    );
  }
}

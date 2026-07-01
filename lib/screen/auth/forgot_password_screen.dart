import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';
import '../../core/auth_rate_limit.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _isSent = false;

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
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_isLoading) return;

    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _toast('Masukkan email terlebih dahulu.', isError: true);
      return;
    }

    // Cek lock
    final locked = await AuthRateLimit.isForgotLocked(email);
    if (locked) {
      final remaining = await AuthRateLimit.getLoginRemainingLockSeconds(email);
      _toast(
        'Terlalu banyak percobaan. Coba lagi setelah ${AuthRateLimit.formatDuration(remaining)}.',
        isError: true,
      );
      return;
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'tenmu://reset-callback',
      );

      if (!mounted) return;
      await AuthRateLimit.resetForgotAttempts(email);

      setState(() => _isSent = true);
      _toast('Link reset password telah dikirim ke email Anda.');
    } on AuthException catch (e) {
      if (!mounted) return;
      final attempts = await AuthRateLimit.incrementForgotAttempt(email);
      if (attempts >= 3) {
        _toast(
          'Terlalu banyak percobaan ($attempts/3). Akun diblokir 6 jam.',
          isError: true,
        );
      } else {
        _toast(
          'Gagal ($attempts/3). ${e.message}',
          isError: true,
        );
      }
    } catch (_) {
      _toast('Terjadi kesalahan. Coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: isError
            ? const Color(0xFF2A1A1A)
            : const Color(0xFF1A2A1A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError
                ? Colors.red.withValues(alpha: 0.5)
                : Colors.green.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 20),

              // ── Icon ──────────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.bgElevated,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(
                    Icons.lock_reset_outlined,
                    size: 48,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // ── Title ─────────────────────────────────────────────────
              FadeTransition(
                opacity: _fadeAnim,
                child: const Text(
                  'Lupa Password?',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _fadeAnim,
                child: const Text(
                  'Masukkan email untuk menerima\nlink reset password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // ── Form ──────────────────────────────────────────────────
              SlideTransition(
                position: _slideAnim,
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        _label('Email'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                          ),
                          cursorColor: AppColors.borderFocus,
                          decoration: InputDecoration(
                            hintText: 'contoh@email.com',
                            hintStyle: const TextStyle(
                              color: AppColors.textHint,
                              fontSize: 15,
                            ),
                            prefixIcon: const Icon(
                              Icons.alternate_email,
                              color: AppColors.iconColor,
                              size: 20,
                            ),
                            filled: true,
                            fillColor: AppColors.bgElevated,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.border,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.borderFocus,
                                width: 1.5,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: _isLoading
                              ? const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: AppColors.textSecondary,
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : ElevatedButton(
                                  onPressed: _isSent ? null : _sendResetLink,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _isSent
                                        ? AppColors.border
                                        : AppColors.btnPrimary,
                                    foregroundColor: AppColors.btnLabel,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                    _isSent
                                        ? 'Terkirim!'
                                        : 'Kirim Link Reset',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Success info ──────────────────────────────────────────
              if (_isSent) ...[
                const SizedBox(height: 20),
                FadeTransition(
                  opacity: _fadeAnim,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.mark_email_read_outlined,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Cek email Anda dan klik link reset yang dikirimkan.',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
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

  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textSecondary,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      letterSpacing: 0.5,
    ),
  );
}

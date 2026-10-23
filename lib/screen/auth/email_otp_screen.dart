import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/auth_rate_limit.dart';
import '../../core/email_validator.dart';
import 'widgets/auth_common.dart';

/// Login / daftar tanpa password memakai **kode OTP 6 digit** yang dikirim
/// Supabase ke email. Magic link sudah dihapus — user hanya mengetik kode.
///
/// Alur: masukkan email → kirim kode → masukkan kode → masuk.
/// Kode berlaku 5 menit (diatur di `supabase/config.toml` → otp_expiry = 300).
class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({super.key});

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  bool _codeSent = false;
  bool _isSending = false;
  bool _isVerifying = false;
  String? _emailError;
  String? _codeError;

  int _resendCountdown = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  // ── Langkah 1: kirim kode ─────────────────────────────────────────────
  Future<void> _sendCode() async {
    if (_isSending) return;
    final email = _emailController.text.trim();

    final err = EmailValidator.validate(email);
    if (err != null) {
      setState(() => _emailError = err);
      return;
    }
    final typo = EmailValidator.suggestFix(email);
    if (typo != null) {
      setState(() => _emailError = 'Sepertinya typo. Maksud kamu $typo?');
      return;
    }
    setState(() => _emailError = null);

    setState(() => _isSending = true);
    try {
      await Supabase.instance.client.auth.signInWithOtp(
        email: email,
        shouldCreateUser: true,
        data: {'full_name': _nameFromEmail(email)},
      );

      if (!mounted) return;
      _codeController.clear();
      setState(() {
        _codeSent = true;
        _resendCountdown = 60;
      });
      _startResendTimer();
      showAuthSnack(context, 'Kode dikirim ke $email. Berlaku 5 menit.', isError: false);
    } on AuthException catch (e) {
      if (!mounted) return;
      showAuthSnack(context, _parseSendError(e.message));
    } catch (_) {
      if (!mounted) return;
      showAuthSnack(context, 'Gagal mengirim kode. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  // ── Langkah 2: verifikasi kode ────────────────────────────────────────
  Future<void> _verifyCode() async {
    if (_isVerifying) return;
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();

    if (code.length != 6) {
      setState(() => _codeError = 'Masukkan 6 digit kode');
      return;
    }
    setState(() => _codeError = null);

    final locked = await AuthRateLimit.isOtpLocked(email);
    if (locked) {
      final remaining = await AuthRateLimit.getOtpRemainingLockSeconds(email);
      if (!mounted) return;
      showAuthSnack(
        context,
        'Terlalu banyak kode salah. Coba lagi setelah ${AuthRateLimit.formatDuration(remaining)}.',
      );
      return;
    }

    setState(() => _isVerifying = true);
    try {
      await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.email,
      );
      if (!mounted) return;
      // Pop layar ini SEGERA (sebelum pop-up sukses dari AuthGate muncul),
      // supaya langsung mendarat di beranda — bukan malah menutup pop-up-nya.
      Navigator.of(context).pop(true);
      await AuthRateLimit.resetOtpAttempts(email);
    } on AuthException catch (e) {
      final attempts = await AuthRateLimit.incrementOtpAttempt(email);
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('expired')) {
        setState(() => _codeError = 'Kode sudah kedaluwarsa. Kirim ulang kode.');
      } else if (attempts >= 5) {
        showAuthSnack(context, 'Kode salah 5×. Diblokir 30 menit.');
      } else {
        setState(() => _codeError = 'Kode salah. Sisa percobaan: ${5 - attempts}');
      }
    } catch (_) {
      if (!mounted) return;
      showAuthSnack(context, 'Gagal verifikasi. Coba lagi.');
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _resendCountdown--;
        if (_resendCountdown <= 0) t.cancel();
      });
    });
  }

  void _changeEmail() {
    _resendTimer?.cancel();
    setState(() {
      _codeSent = false;
      _resendCountdown = 0;
      _codeController.clear();
      _codeError = null;
    });
  }

  String _nameFromEmail(String email) {
    final local = email.split('@').first;
    if (local.isEmpty) return email;
    return local[0].toUpperCase() + local.substring(1);
  }

  String _parseSendError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('rate limit') || lower.contains('too many')) {
      return 'Terlalu banyak permintaan. Tunggu beberapa menit lalu coba lagi.';
    }
    if (lower.contains('error sending')) {
      return 'Gagal mengirim email. Periksa kuota/konfigurasi SMTP Supabase.';
    }
    return msg;
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: AuthPalette.bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AuthPalette.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AuthPalette.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AuthPalette.border),
                    ),
                    child: Icon(
                      _codeSent ? Icons.mark_email_read_outlined : Icons.mail_outline_rounded,
                      color: AuthPalette.ink,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _codeSent ? 'Masukkan Kode' : 'Masuk dengan Email',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AuthPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Kami mengirim 6 digit kode ke ${_emailController.text.trim()}. '
                            'Masukkan kode tersebut — berlaku 5 menit.'
                        : 'Masukkan email kamu. Kami akan mengirim kode verifikasi 6 digit.',
                    style: const TextStyle(fontSize: 13.5, color: AuthPalette.grey, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  if (!_codeSent) ...[
                    AuthTextField(
                      controller: _emailController,
                      label: 'Email',
                      hint: 'nama@email.com',
                      icon: Icons.mail_outline_rounded,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.email],
                      errorText: _emailError,
                      enabled: !_isSending,
                      onChanged: (_) {
                        if (_emailError != null) setState(() => _emailError = null);
                      },
                      onSubmitted: (_) => _sendCode(),
                    ),
                    const SizedBox(height: 20),
                    AuthPrimaryButton(
                      label: 'Kirim Kode',
                      loadingLabel: 'Mengirim...',
                      isLoading: _isSending,
                      onPressed: _sendCode,
                    ),
                  ] else ...[
                    AuthTextField(
                      controller: _codeController,
                      label: 'Kode 6 digit',
                      hint: '000000',
                      icon: Icons.password_rounded,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      errorText: _codeError,
                      enabled: !_isVerifying,
                      maxLength: 6,
                      onChanged: (_) {
                        if (_codeError != null) setState(() => _codeError = null);
                      },
                      onSubmitted: (_) => _verifyCode(),
                    ),
                    const SizedBox(height: 20),
                    AuthPrimaryButton(
                      label: 'Verifikasi & Masuk',
                      loadingLabel: 'Memverifikasi...',
                      isLoading: _isVerifying,
                      onPressed: _verifyCode,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: _changeEmail,
                          child: const Text(
                            'Ganti email',
                            style: TextStyle(color: AuthPalette.grey),
                          ),
                        ),
                        TextButton(
                          onPressed: _resendCountdown > 0 ? null : _sendCode,
                          child: Text(
                            _resendCountdown > 0
                                ? 'Kirim ulang ($_resendCountdown s)'
                                : 'Kirim ulang kode',
                            style: TextStyle(
                              color: _resendCountdown > 0 ? AuthPalette.hint : AuthPalette.ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 20),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Tidak menemukan email? Cek folder Spam/Promosi. Kode berlaku 5 menit dan hanya bisa dipakai sekali.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF92400E),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
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

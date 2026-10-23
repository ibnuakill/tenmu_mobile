import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/email_validator.dart';
import 'widgets/auth_common.dart';

/// Layar Daftar akun baru TenMu (email + password).
///
/// Setelah daftar, user langsung masuk (Supabase `enable_confirmations = false`)
/// dan `AuthGate` akan mengarahkan ke RoleChecker.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreedToTerms = false;
  bool _isLoading = false;

  String? _nameError;
  String? _emailError;
  String? _passwordError;
  String? _confirmError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_isLoading) return;
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    // Validasi
    if (name.isEmpty) {
      setState(() => _nameError = 'Nama lengkap wajib diisi');
      return;
    }
    final emailErr = EmailValidator.validate(email);
    if (emailErr != null) {
      setState(() => _emailError = emailErr);
      return;
    }
    final typo = EmailValidator.suggestFix(email);
    if (typo != null) {
      setState(() => _emailError = 'Sepertinya typo. Maksud kamu $typo?');
      return;
    }
    if (password.length < 6) {
      setState(() => _passwordError = 'Password minimal 6 karakter');
      return;
    }
    if (password != confirm) {
      setState(() => _confirmError = 'Konfirmasi password tidak cocok');
      return;
    }
    if (!_agreedToTerms) {
      showAuthSnack(context, 'Setujui Ketentuan Layanan dulu ya.');
      return;
    }
    setState(() {
      _nameError = null;
      _emailError = null;
      _passwordError = null;
      _confirmError = null;
    });

    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client.auth.signUp(
        email: email,
        password: password,
        data: {'full_name': name, 'name': name},
      );

      if (!mounted) return;
      if (res.session != null) {
        // Langsung masuk
        Navigator.of(context).pop(true);
      } else {
        // Konfirmasi email diaktifkan di server
        showAuthErrorDialog(
          context,
          title: 'Cek Email Kamu',
          message:
              'Akun dibuat. Kami mengirim tautan verifikasi ke $email. Buka email untuk mengaktifkan akun, lalu masuk.',
        );
      }
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.toLowerCase();
      if (msg.contains('already registered') || msg.contains('already been registered')) {
        showAuthSnack(context, 'Email ini sudah terdaftar. Coba masuk atau lupa password.');
      } else if (msg.contains('weak') || msg.contains('password')) {
        showAuthSnack(context, 'Password terlalu lemah. Gunakan minimal 6 karakter.');
      } else {
        showAuthSnack(context, e.message);
      }
    } catch (_) {
      if (mounted) showAuthSnack(context, 'Gagal mendaftar. Periksa koneksi lalu coba lagi.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
                  const Text(
                    'Buat Akun Baru',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AuthPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Isi data di bawah untuk mendaftar dengan email & password.',
                    style: TextStyle(fontSize: 13.5, color: AuthPalette.grey, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  AuthTextField(
                    controller: _nameController,
                    label: 'Nama Lengkap',
                    hint: 'Contoh: Alex Pratama',
                    icon: Icons.person_outline_rounded,
                    textCapitalization: TextCapitalization.words,
                    autofillHints: const [AutofillHints.name],
                    errorText: _nameError,
                    enabled: !_isLoading,
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'nama@email.com',
                    icon: Icons.mail_outline_rounded,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    errorText: _emailError,
                    enabled: !_isLoading,
                    onChanged: (_) {
                      if (_emailError != null) setState(() => _emailError = null);
                    },
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'Password',
                    hint: 'Minimal 6 karakter',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscurePassword,
                    autofillHints: const [AutofillHints.newPassword],
                    errorText: _passwordError,
                    enabled: !_isLoading,
                    onChanged: (_) {
                      if (_passwordError != null) setState(() => _passwordError = null);
                    },
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AuthPalette.grey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _confirmController,
                    label: 'Konfirmasi Password',
                    hint: 'Ulangi password',
                    icon: Icons.lock_outline_rounded,
                    obscure: _obscureConfirm,
                    textInputAction: TextInputAction.done,
                    errorText: _confirmError,
                    enabled: !_isLoading,
                    onChanged: (_) {
                      if (_confirmError != null) setState(() => _confirmError = null);
                    },
                    onSubmitted: (_) => _register(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirm
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: AuthPalette.grey,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    ),
                  ),
                  const SizedBox(height: 18),
                  AuthTermsCheckbox(
                    value: _agreedToTerms,
                    onChanged: _isLoading
                        ? null
                        : (v) => setState(() => _agreedToTerms = v ?? false),
                  ),
                  const SizedBox(height: 18),
                  AuthPrimaryButton(
                    label: 'Daftar',
                    loadingLabel: 'Mendaftar...',
                    isLoading: _isLoading,
                    onPressed: _register,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Sudah punya akun? ',
                        style: TextStyle(color: AuthPalette.grey, fontSize: 13.5),
                      ),
                      GestureDetector(
                        onTap: _isLoading ? null : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Masuk',
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
        ),
      ),
    );
  }
}

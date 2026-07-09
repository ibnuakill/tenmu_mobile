import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String? email;

  const EmailVerificationScreen({super.key, this.email});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  bool _isLoading = false;
  late String _displayEmail;
  late final StreamSubscription<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _displayEmail = widget.email ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    // Auto-redirect kalau session diupdate dari tempat lain (deep link, app lain)
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((event) {
      if (event.session?.user.emailConfirmedAt != null && mounted) {
        // AuthGate stream akan handle — gak perlu push manual
      }
    });
  }

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }

  Future<void> _checkVerification() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      // refreshSession() trigger onAuthStateChange di AuthGate
      // → rebuild → detect emailConfirmedAt != null → auto-redirect ke RoleChecker
      await Supabase.instance.client.auth.refreshSession();
    } catch (e) {
      if (mounted) _showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      // AuthGate stream akan redirect ke LoginScreen otomatis
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error logging out: $e');
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return PopScope(
      canPop: false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: theme.bgBase,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // Illustration / Icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: theme.bgElevated,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: theme.btnPrimary, width: 2),
                  ),
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    size: 60,
                    color: theme.btnPrimary,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Verifikasi Email',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Subtitle
                Text(
                  'Kami telah mengirimkan email verifikasi ke:',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),

                // Email address
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border, width: 1),
                  ),
                  child: Text(
                    _displayEmail,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.btnPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Langkah-langkah:',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _InstructionItem(
                        number: '1',
                        text: 'Buka email Anda',
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                      _InstructionItem(
                        number: '2',
                        text: 'Klik tombol "Verifikasi Email" dalam email',
                        theme: theme,
                      ),
                      const SizedBox(height: 8),
                      _InstructionItem(
                        number: '3',
                        text: 'Kembali ke aplikasi setelah verifikasi',
                        theme: theme,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Cek status tombol
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _checkVerification,
                    icon: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(theme.btnLabel),
                            ),
                          )
                        : Icon(Icons.refresh, color: theme.btnLabel),
                    label: Text(
                      _isLoading ? 'Mengecek...' : 'Saya Sudah Verifikasi',
                      style: TextStyle(
                        color: theme.btnLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.btnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Logout button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: Icon(Icons.logout, color: theme.textPrimary),
                    label: Text(
                      'Gunakan Email Lain',
                      style: TextStyle(color: theme.textPrimary),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.border, width: 1),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Help text
                Text(
                  'Email tidak masuk? Periksa folder spam atau coba kirim ulang.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: theme.textHint,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InstructionItem extends StatelessWidget {
  final String number;
  final String text;
  final ThemeProvider theme;

  const _InstructionItem({
    required this.number,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: theme.btnPrimary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              number,
              style: TextStyle(
                color: theme.btnLabel,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

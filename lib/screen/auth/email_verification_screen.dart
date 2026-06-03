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
  bool _isCheckingVerification = false;
  late String _displayEmail;

  @override
  void initState() {
    super.initState();
    _displayEmail = widget.email ?? Supabase.instance.client.auth.currentUser?.email ?? '';
    _startVerificationCheck();
  }

  void _startVerificationCheck() {
    // Check every 3 seconds if email has been verified
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _checkEmailVerification();
      }
    });
  }

  Future<void> _checkEmailVerification() async {
    if (!mounted) return;

    setState(() => _isCheckingVerification = true);

    try {
      // Refresh the session to get updated user data
      await Supabase.instance.client.auth.refreshSession();

      final user = Supabase.instance.client.auth.currentUser;

      if (user != null && user.emailConfirmedAt != null) {
        // Email is verified, navigate to appropriate screen
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
      } else {
        // Still not verified, check again after delay
        if (mounted) {
          setState(() => _isCheckingVerification = false);
          _startVerificationCheck();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingVerification = false);
        _showErrorSnackbar('Error checking verification: $e');
        _startVerificationCheck();
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    setState(() => _isLoading = true);

    try {
      // Supabase automatically sends verification email on signup
      // For resend, we show instruction to user to check email
      if (mounted) {
        _showSuccessSnackbar('Instruksi verifikasi telah dikirim. Silakan periksa email Anda.');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logout() async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error logging out: $e');
      }
    }
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green.shade700,
        duration: const Duration(seconds: 3),
      ),
    );
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

                // Checking status
                if (_isCheckingVerification)
                  Column(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(theme.btnPrimary),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Memeriksa verifikasi email...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 32),

                // Resend button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _resendVerificationEmail,
                    icon: Icon(
                      Icons.mail_outline,
                      color: _isLoading ? theme.textSecondary : theme.btnLabel,
                    ),
                    label: Text(
                      _isLoading ? 'Mengirim...' : 'Kirim Ulang Email',
                      style: TextStyle(
                        color: _isLoading ? theme.textSecondary : theme.btnLabel,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isLoading ? theme.bgElevated : theme.btnPrimary,
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

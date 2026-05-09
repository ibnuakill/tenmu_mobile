import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen>
    with SingleTickerProviderStateMixin {
  // Email controllers
  final _newEmailController = TextEditingController();

  // Password controllers
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoadingEmail = false;
  bool _isLoadingPassword = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  late TabController _tabController;

  String get _currentEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? '-';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _newEmailController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ── Ganti Email ──────────────────────────────────────────────────────────
  Future<void> _gantiEmail() async {
    final newEmail = _newEmailController.text.trim();
    if (newEmail.isEmpty) {
      _toast('Email baru tidak boleh kosong!', isError: true);
      return;
    }
    if (!newEmail.contains('@')) {
      _toast('Format email tidak valid!', isError: true);
      return;
    }
    if (newEmail == _currentEmail) {
      _toast('Email baru sama dengan email saat ini!', isError: true);
      return;
    }

    setState(() => _isLoadingEmail = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: newEmail),
      );
      if (mounted) {
        _newEmailController.clear();
        _toast('Link konfirmasi dikirim ke email baru. Cek inbox kamu!');
      }
    } on AuthException catch (e) {
      _toast(e.message, isError: true);
    } catch (e) {
      _toast('Terjadi kesalahan. Coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingEmail = false);
    }
  }

  // ── Ganti Password ────────────────────────────────────────────────────────
  Future<void> _gantiPassword() async {
    final current = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _toast('Semua field wajib diisi!', isError: true);
      return;
    }
    if (newPass.length < 6) {
      _toast('Password baru minimal 6 karakter!', isError: true);
      return;
    }
    if (newPass != confirm) {
      _toast('Konfirmasi password tidak cocok!', isError: true);
      return;
    }

    setState(() => _isLoadingPassword = true);
    try {
      // Verifikasi password lama dengan re-sign-in
      final email = _currentEmail;
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: current,
      );

      // Jika berhasil, ganti password
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _toast('Password berhasil diubah! ✅');
      }
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid') ||
          e.message.toLowerCase().contains('credentials')) {
        _toast('Password saat ini salah!', isError: true);
      } else {
        _toast(e.message, isError: true);
      }
    } catch (e) {
      _toast('Terjadi kesalahan. Coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingPassword = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: isError ? theme.snackError : theme.snackSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? theme.snackErrorBorder : theme.snackSuccessBorder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.border),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: theme.textPrimary,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'Pengaturan Akun',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // ── INFO AKUN ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.bgElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.borderFocus),
                    ),
                    child: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: theme.textPrimary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin TenMu',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentEmail,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── TAB BAR ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: theme.btnPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: theme.btnLabel,
                unselectedLabelColor: theme.textSecondary,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: '  Ganti Email  '),
                  Tab(text: '  Ganti Password  '),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // ── TAB VIEWS ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // ── TAB EMAIL ──────────────────────────────────────────────
                _buildEmailTab(theme),
                // ── TAB PASSWORD ───────────────────────────────────────────
                _buildPasswordTab(theme),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTab(ThemeProvider theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ganti Email',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Link konfirmasi akan dikirim ke email baru sebelum perubahan berlaku.',
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            _label('Email Saat Ini', theme),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: theme.bgBase,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border),
              ),
              child: Text(
                _currentEmail,
                style: TextStyle(color: theme.textHint, fontSize: 14),
              ),
            ),

            const SizedBox(height: 18),
            _label('Email Baru', theme),
            const SizedBox(height: 8),
            _field(
              controller: _newEmailController,
              hint: 'admin@email-baru.com',
              icon: Icons.alternate_email,
              keyboardType: TextInputType.emailAddress,
              theme: theme,
            ),

            const SizedBox(height: 28),
            _primaryButton(
              label: 'Kirim Link Konfirmasi',
              onTap: _isLoadingEmail ? null : _gantiEmail,
              isLoading: _isLoadingEmail,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordTab(ThemeProvider theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ganti Password',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Masukkan password saat ini untuk memverifikasi identitasmu.',
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),

            _label('Password Saat Ini', theme),
            const SizedBox(height: 8),
            _field(
              controller: _currentPasswordController,
              hint: '••••••••',
              icon: Icons.lock_open_outlined,
              isPassword: true,
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
              theme: theme,
            ),

            const SizedBox(height: 18),
            Divider(color: theme.border),
            const SizedBox(height: 18),

            _label('Password Baru', theme),
            const SizedBox(height: 8),
            _field(
              controller: _newPasswordController,
              hint: 'Minimal 6 karakter',
              icon: Icons.lock_outline,
              isPassword: true,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
              theme: theme,
            ),

            const SizedBox(height: 18),
            _label('Konfirmasi Password Baru', theme),
            const SizedBox(height: 8),
            _field(
              controller: _confirmPasswordController,
              hint: 'Ulangi password baru',
              icon: Icons.lock_outline,
              isPassword: true,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              theme: theme,
            ),

            const SizedBox(height: 28),
            _primaryButton(
              label: 'Simpan Password Baru',
              onTap: _isLoadingPassword ? null : _gantiPassword,
              isLoading: _isLoadingPassword,
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _label(String text, ThemeProvider theme) => Text(
    text,
    style: TextStyle(
      color: theme.textSecondary,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      letterSpacing: 0.5,
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool isPassword = false,
    bool obscure = false,
    VoidCallback? onToggle,
    required ThemeProvider theme,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? obscure : false,
      style: TextStyle(color: theme.textPrimary, fontSize: 15),
      cursorColor: theme.borderFocus,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textHint, fontSize: 15),
        prefixIcon: Icon(icon, color: theme.iconColor, size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: theme.textHint,
                  size: 20,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: theme.bgElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.borderFocus, width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
    required ThemeProvider theme,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: isLoading
          ? Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: theme.textSecondary,
                  strokeWidth: 2,
                ),
              ),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.btnPrimary,
                foregroundColor: theme.btnLabel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Quixotic Palette
const _kPrimary      = Color(0xFF1E7A52);
const _kAccentRed    = Color(0xFFEF4444);
const _kPageBg       = Color(0xFFF3F4F6);
const _kCardBg       = Color(0xFFFFFFFF);
const _kBorderColor  = Color(0xFFE5E7EB);
const _kTextPrimary  = Color(0xFF111827);
const _kTextSecondary= Color(0xFF6B7280);
const _kTextMuted    = Color(0xFF9CA3AF);
const _kShadow = BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4));

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
      final email = _currentEmail;
      await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: current,
      );

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: newPass),
      );

      if (mounted) {
        _currentPasswordController.clear();
        _newPasswordController.clear();
        _confirmPasswordController.clear();
        _toast('Password berhasil diperbarui!');
      }
    } on AuthException catch (e) {
      _toast(
        e.message.contains('Invalid login credentials')
            ? 'Password saat ini salah!'
            : e.message,
        isError: true,
      );
    } catch (e) {
      _toast('Gagal memperbarui password.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoadingPassword = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13)),
        backgroundColor: isError ? _kAccentRed : _kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kCardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _kPageBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorderColor),
            ),
            child: const Icon(Icons.arrow_back_ios_new, color: _kTextPrimary, size: 16),
          ),
        ),
        title: Text(
          'Pengaturan Akun',
          style: GoogleFonts.poppins(
            color: _kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
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
                color: _kCardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _kBorderColor),
                boxShadow: const [_kShadow],
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _kPrimary.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                      border: Border.all(color: _kPrimary.withValues(alpha: 0.2)),
                    ),
                    child: const Icon(
                      Icons.admin_panel_settings_rounded,
                      color: _kPrimary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Admin TenMu',
                        style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _currentEmail,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: _kTextSecondary,
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
                color: _kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kBorderColor),
                boxShadow: const [_kShadow],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(12),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: _kTextSecondary,
                labelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
                unselectedLabelStyle: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                tabs: const [
                  Tab(text: 'Ganti Email'),
                  Tab(text: 'Ganti Password'),
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
                _buildEmailTab(),
                _buildPasswordTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorderColor),
          boxShadow: const [_kShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ganti Email',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Link konfirmasi akan dikirim ke email baru sebelum perubahan berlaku.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _kTextSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            _label('Email Saat Ini'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: _kPageBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderColor),
              ),
              child: Text(
                _currentEmail,
                style: GoogleFonts.plusJakartaSans(color: _kTextMuted, fontSize: 14),
              ),
            ),

            const SizedBox(height: 18),
            _label('Email Baru'),
            const SizedBox(height: 8),
            _field(
              controller: _newEmailController,
              hint: 'admin@email-baru.com',
              icon: Icons.alternate_email_rounded,
              keyboardType: TextInputType.emailAddress,
            ),

            const SizedBox(height: 24),
            _primaryButton(
              label: 'Kirim Link Konfirmasi',
              onTap: _isLoadingEmail ? null : _gantiEmail,
              isLoading: _isLoadingEmail,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorderColor),
          boxShadow: const [_kShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ganti Password',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Masukkan password saat ini untuk memverifikasi identitasmu.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: _kTextSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            _label('Password Saat Ini'),
            const SizedBox(height: 8),
            _field(
              controller: _currentPasswordController,
              hint: '••••••••',
              icon: Icons.lock_open_rounded,
              isPassword: true,
              obscure: _obscureCurrent,
              onToggle: () =>
                  setState(() => _obscureCurrent = !_obscureCurrent),
            ),

            const SizedBox(height: 18),
            Container(height: 1, color: _kBorderColor),
            const SizedBox(height: 18),

            _label('Password Baru'),
            const SizedBox(height: 8),
            _field(
              controller: _newPasswordController,
              hint: 'Minimal 6 karakter',
              icon: Icons.lock_rounded,
              isPassword: true,
              obscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),

            const SizedBox(height: 18),
            _label('Konfirmasi Password Baru'),
            const SizedBox(height: 8),
            _field(
              controller: _confirmPasswordController,
              hint: 'Ulangi password baru',
              icon: Icons.lock_rounded,
              isPassword: true,
              obscure: _obscureConfirm,
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),

            const SizedBox(height: 24),
            _primaryButton(
              label: 'Simpan Password Baru',
              onTap: _isLoadingPassword ? null : _gantiPassword,
              isLoading: _isLoadingPassword,
            ),
          ],
        ),
      ),
    );
  }

  // ── Helper Widgets ─────────────────────────────────────────────────────────

  Widget _label(String text) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      color: _kTextSecondary,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      letterSpacing: 0.3,
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: isPassword ? obscure : false,
      style: GoogleFonts.plusJakartaSans(color: _kTextPrimary, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(color: _kTextMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: _kTextMuted, size: 18),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _kTextMuted,
                  size: 18,
                ),
                onPressed: onToggle,
              )
            : null,
        filled: true,
        fillColor: _kPageBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kBorderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _kPrimary, width: 1.5),
        ),
      ),
    );
  }

  Widget _primaryButton({
    required String label,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kPrimary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
          elevation: 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20, height: 20,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
              )
            : Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

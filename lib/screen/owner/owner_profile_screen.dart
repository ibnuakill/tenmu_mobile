import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/lucide_icons.dart';
import '../../core/theme_provider.dart';
import '../user/settings/widgets/settings_tile.dart';

/// Halaman "Pengaturan Akun" untuk role **owner** (Pemilik UMKM).
///
/// Sebelumnya owner diarahkan ke `AdminProfileScreen`, jadi yang muncul:
/// label "Admin TenMu", ikon panel admin, warna paten terang (dark mode
/// rusak), dan tidak ada opsi ubah nama/foto profil sama sekali.
///
/// Halaman ini menggabungkan semuanya dalam satu tempat — nama, foto, email,
/// dan password — dan seluruh warnanya ikut tema aktif.
class OwnerProfileScreen extends StatefulWidget {
  const OwnerProfileScreen({super.key});

  @override
  State<OwnerProfileScreen> createState() => _OwnerProfileScreenState();
}

class _OwnerProfileScreenState extends State<OwnerProfileScreen> {
  final _namaController = TextEditingController();
  final _emailBaruController = TextEditingController();
  final _passLamaController = TextEditingController();
  final _passBaruController = TextEditingController();
  final _passKonfirmController = TextEditingController();

  bool _isSavingNama = false;
  bool _isSavingEmail = false;
  bool _isSavingPassword = false;
  bool _isUploadingImage = false;

  bool _obscureLama = true;
  bool _obscureBaru = true;
  bool _obscureKonfirm = true;

  Uint8List? _selectedImageBytes;
  String? _avatarUrl;
  String _nama = '';

  User? get _user => Supabase.instance.client.auth.currentUser;
  String get _email => _user?.email ?? '-';

  @override
  void initState() {
    super.initState();
    final meta = _user?.userMetadata ?? const <String, dynamic>{};
    _nama = (meta['full_name'] ?? meta['nama'] ?? '').toString();
    _namaController.text = _nama;
    _avatarUrl = meta['avatar_url']?.toString();
    _loadProfilDariDb();
  }

  @override
  void dispose() {
    _namaController.dispose();
    _emailBaruController.dispose();
    _passLamaController.dispose();
    _passBaruController.dispose();
    _passKonfirmController.dispose();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  /// Metadata auth bisa basi, jadi nama & avatar diambil ulang dari tabel
  /// `profiles` (sumber yang dipakai dashboard & halaman verifikasi).
  Future<void> _loadProfilDariDb() async {
    final user = _user;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('nama, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      if (data == null || !mounted) return;

      final namaDb = data['nama']?.toString().trim();
      final avatarDb = data['avatar_url']?.toString();

      setState(() {
        if (namaDb != null && namaDb.isNotEmpty && namaDb != 'User') {
          _nama = namaDb;
          _namaController.text = namaDb;
        }
        if (avatarDb != null && avatarDb.isNotEmpty) {
          _avatarUrl = avatarDb;
        }
      });
    } catch (e) {
      debugPrint('OwnerProfile: gagal memuat profil — $e');
    }
  }

  // ── Feedback ───────────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: isError ? theme.snackError : theme.snackSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: isError ? theme.snackErrorBorder : theme.snackSuccessBorder,
          ),
        ),
      ),
    );
  }

  // ── Foto profil ────────────────────────────────────────────────────────────

  Future<void> _pickAndUploadAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (picked == null) return;

    final user = _user;
    if (user == null) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _selectedImageBytes = bytes;
      _isUploadingImage = true;
    });

    try {
      final fileName =
          'avatar_${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('profiles')
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

      final url = Supabase.instance.client.storage
          .from('profiles')
          .getPublicUrl(fileName);

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'avatar_url': url}),
      );

      // Sinkronkan juga ke tabel profiles supaya dashboard ikut berubah.
      try {
        await Supabase.instance.client
            .from('profiles')
            .update({
              'avatar_url': url,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      } catch (e) {
        debugPrint('OwnerProfile: gagal update avatar di profiles — $e');
      }

      if (!mounted) return;
      setState(() => _avatarUrl = url);
      _snack('Foto profil diperbarui ✅');
    } catch (e) {
      if (!mounted) return;
      setState(() => _selectedImageBytes = null);
      _snack('Gagal upload foto: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // ── Nama ───────────────────────────────────────────────────────────────────

  Future<void> _saveNama() async {
    final nama = _namaController.text.trim();

    if (nama.isEmpty) {
      _snack('Nama tidak boleh kosong!', isError: true);
      return;
    }
    if (nama.length < 2) {
      _snack('Nama minimal 2 karakter!', isError: true);
      return;
    }
    if (nama == _nama) {
      _snack('Nama belum berubah.', isError: true);
      return;
    }

    final user = _user;
    if (user == null) return;

    setState(() => _isSavingNama = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(data: {'full_name': nama, 'nama': nama}),
      );

      try {
        await Supabase.instance.client
            .from('profiles')
            .update({
              'nama': nama,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', user.id);
      } catch (e) {
        debugPrint('OwnerProfile: gagal update nama di profiles — $e');
      }

      if (!mounted) return;
      setState(() => _nama = nama);
      _snack('Nama berhasil diperbarui ✅');
    } on AuthException catch (e) {
      _snack(e.message, isError: true);
    } catch (e) {
      _snack('Gagal menyimpan nama: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingNama = false);
    }
  }

  // ── Email ──────────────────────────────────────────────────────────────────

  Future<void> _saveEmail() async {
    final emailBaru = _emailBaruController.text.trim();

    if (emailBaru.isEmpty) {
      _snack('Email baru tidak boleh kosong!', isError: true);
      return;
    }
    if (!emailBaru.contains('@') || !emailBaru.contains('.')) {
      _snack('Format email tidak valid!', isError: true);
      return;
    }
    if (emailBaru.toLowerCase() == _email.toLowerCase()) {
      _snack('Email baru sama dengan email saat ini!', isError: true);
      return;
    }

    setState(() => _isSavingEmail = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: emailBaru),
      );
      if (!mounted) return;
      _emailBaruController.clear();
      _snack('Link konfirmasi dikirim ke $emailBaru. Cek inbox (dan spam).');
    } on AuthException catch (e) {
      _snack(e.message, isError: true);
    } catch (e) {
      _snack('Gagal mengubah email. Coba lagi.', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingEmail = false);
    }
  }

  // ── Password ───────────────────────────────────────────────────────────────

  Future<void> _savePassword() async {
    final lama = _passLamaController.text.trim();
    final baru = _passBaruController.text.trim();
    final konfirm = _passKonfirmController.text.trim();

    if (lama.isEmpty || baru.isEmpty || konfirm.isEmpty) {
      _snack('Semua field password wajib diisi!', isError: true);
      return;
    }
    if (baru.length < 6) {
      _snack('Password baru minimal 6 karakter!', isError: true);
      return;
    }
    if (baru == lama) {
      _snack('Password baru harus beda dari yang lama!', isError: true);
      return;
    }
    if (baru != konfirm) {
      _snack('Konfirmasi password tidak cocok!', isError: true);
      return;
    }

    setState(() => _isSavingPassword = true);
    try {
      // Verifikasi password lama dulu — updateUser tidak memintanya sendiri.
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email,
        password: lama,
      );

      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: baru),
      );

      if (!mounted) return;
      _passLamaController.clear();
      _passBaruController.clear();
      _passKonfirmController.clear();
      _snack('Password berhasil diperbarui ✅');
    } on AuthException catch (e) {
      _snack(
        e.message.contains('Invalid login credentials')
            ? 'Password saat ini salah!'
            : e.message,
        isError: true,
      );
    } catch (e) {
      _snack('Gagal memperbarui password.', isError: true);
    } finally {
      if (mounted) setState(() => _isSavingPassword = false);
    }
  }

  // ── UI ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Pengaturan Akun',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        leading: IconButton(
          icon: LucideIcon('arrow-left', color: theme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            _kartuIdentitas(theme),
            const SizedBox(height: 24),

            // ── PROFIL ────────────────────────────────────────────────
            SettingsSectionHeader(title: 'Profil', theme: theme),
            const SizedBox(height: 8),
            SettingsCard(
              theme: theme,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Nama Lengkap', theme),
                      const SizedBox(height: 8),
                      _input(
                        theme: theme,
                        controller: _namaController,
                        hint: 'Nama yang tampil di profil',
                        icon: 'user',
                        textCapitalization: TextCapitalization.words,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Nama ini juga dipakai di dashboard & halaman verifikasi.',
                        style: TextStyle(
                          color: theme.textHint,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _tombol(
                        theme: theme,
                        label: 'Simpan Nama',
                        loading: _isSavingNama,
                        onPressed: _saveNama,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── EMAIL ─────────────────────────────────────────────────
            SettingsSectionHeader(title: 'Email', theme: theme),
            const SizedBox(height: 8),
            SettingsCard(
              theme: theme,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Email Saat Ini', theme),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: theme.bgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Row(
                          children: [
                            LucideIcon(
                              'mail',
                              color: theme.iconColor,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _email,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _label('Email Baru', theme),
                      const SizedBox(height: 8),
                      _input(
                        theme: theme,
                        controller: _emailBaruController,
                        hint: 'nama@email.com',
                        icon: 'mail',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Link konfirmasi dikirim ke email baru sebelum '
                        'perubahan berlaku.',
                        style: TextStyle(
                          color: theme.textHint,
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _tombol(
                        theme: theme,
                        label: 'Kirim Link Konfirmasi',
                        loading: _isSavingEmail,
                        onPressed: _saveEmail,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── PASSWORD ──────────────────────────────────────────────
            SettingsSectionHeader(title: 'Password', theme: theme),
            const SizedBox(height: 8),
            SettingsCard(
              theme: theme,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _label('Password Saat Ini', theme),
                      const SizedBox(height: 8),
                      _input(
                        theme: theme,
                        controller: _passLamaController,
                        hint: '••••••••',
                        icon: 'lock',
                        obscure: _obscureLama,
                        onToggleObscure: () =>
                            setState(() => _obscureLama = !_obscureLama),
                      ),
                      const SizedBox(height: 14),
                      _label('Password Baru', theme),
                      const SizedBox(height: 8),
                      _input(
                        theme: theme,
                        controller: _passBaruController,
                        hint: 'Minimal 6 karakter',
                        icon: 'lock',
                        obscure: _obscureBaru,
                        onToggleObscure: () =>
                            setState(() => _obscureBaru = !_obscureBaru),
                      ),
                      const SizedBox(height: 14),
                      _label('Konfirmasi Password Baru', theme),
                      const SizedBox(height: 8),
                      _input(
                        theme: theme,
                        controller: _passKonfirmController,
                        hint: 'Ulangi password baru',
                        icon: 'lock',
                        obscure: _obscureKonfirm,
                        onToggleObscure: () =>
                            setState(() => _obscureKonfirm = !_obscureKonfirm),
                      ),
                      const SizedBox(height: 16),
                      _tombol(
                        theme: theme,
                        label: 'Perbarui Password',
                        loading: _isSavingPassword,
                        onPressed: _savePassword,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),
            Center(
              child: Text(
                'TenMu • Akun Pemilik UMKM',
                style: TextStyle(
                  color: theme.textHint,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widget bantu ───────────────────────────────────────────────────────────

  Widget _kartuIdentitas(ThemeProvider theme) {
    final namaTampil = _nama.trim().isEmpty ? 'Pemilik UMKM' : _nama.trim();
    final avatar = _selectedImageBytes != null
        ? MemoryImage(_selectedImageBytes!)
        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                  ? NetworkImage(_avatarUrl!)
                  : null)
              as ImageProvider?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border.withValues(alpha: 0.4)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.18),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: theme.bgElevated,
                backgroundImage: avatar,
                child: avatar == null
                    ? LucideIcon('store', size: 28, color: theme.iconColor)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: GestureDetector(
                  onTap: _isUploadingImage ? null : _pickAndUploadAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: theme.btnPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.bgSurface, width: 2),
                    ),
                    child: _isUploadingImage
                        ? SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.btnLabel,
                            ),
                          )
                        : LucideIcon('camera', size: 13, color: theme.btnLabel),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  namaTampil,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.btnPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: theme.btnPrimary.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LucideIcon('store', size: 12, color: theme.btnPrimary),
                      const SizedBox(width: 5),
                      Text(
                        'Pemilik UMKM',
                        style: TextStyle(
                          color: theme.btnPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Ketuk ikon kamera untuk ganti foto',
                  style: TextStyle(color: theme.textHint, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text, ThemeProvider theme) {
    return Text(
      text,
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _input({
    required ThemeProvider theme,
    required TextEditingController controller,
    required String hint,
    required String icon,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: TextStyle(color: theme.textPrimary, fontSize: 14),
      cursorColor: theme.btnPrimary,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textHint, fontSize: 13.5),
        prefixIcon: LucideIcon(icon, color: theme.iconColor, size: 18),
        suffixIcon: onToggleObscure == null
            ? null
            : IconButton(
                onPressed: onToggleObscure,
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  size: 19,
                  color: theme.iconColor,
                ),
              ),
        filled: true,
        fillColor: theme.bgElevated,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
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
          borderSide: BorderSide(color: theme.borderFocus),
        ),
      ),
    );
  }

  Widget _tombol({
    required ThemeProvider theme,
    required String label,
    required bool loading,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.btnPrimary,
          foregroundColor: theme.btnLabel,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: theme.btnLabel,
                ),
              )
            : Text(
                label,
                style: TextStyle(
                  color: theme.btnLabel,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
      ),
    );
  }
}

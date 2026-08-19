import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../profile/admin_profile_screen.dart';
import 'widgets/admin_settings_widgets.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  bool _isClearing = false;

  String get _currentEmail =>
      Supabase.instance.client.auth.currentUser?.email ?? '-';

  Future<void> _clearCache() async {
    setState(() => _isClearing = true);
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      if (mounted) _toast('Cache berhasil dibersihkan ✅');
    } catch (e) {
      if (mounted) _toast('Gagal: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Logout', style: GoogleFonts.poppins(color: kTextPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Yakin ingin logout dari akun admin?',
          style: GoogleFonts.plusJakartaSans(color: kTextSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal', style: GoogleFonts.plusJakartaSans(color: kTextSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            child: Text('Logout', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _toast(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13)),
        backgroundColor: isError ? kAccentRed : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Pengaturan Admin',
          style: GoogleFonts.poppins(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── INFO AKUN ────────────────────────────────────────────────
            AdminInfoCard(email: _currentEmail),
            const SizedBox(height: 28),

            // ── AKUN ─────────────────────────────────────────────────────
            const SectionLabel(title: 'AKUN ADMIN'),
            const SizedBox(height: 8),
            SettingsCard(
              children: [
                SettingsNavTile(
                  icon: Icons.lock_reset_rounded,
                  iconColor: kPrimary,
                  title: 'Ubah Email / Password',
                  subtitle: 'Perbarui kredensial akun admin',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminProfileScreen(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── SISTEM ───────────────────────────────────────────────────
            const SectionLabel(title: 'SISTEM & CACHE'),
            const SizedBox(height: 8),
            SettingsCard(
              children: [
                SettingsActionTile(
                  icon: Icons.cached_rounded,
                  iconColor: kAccentGreen,
                  title: 'Bersihkan Cache Gambar',
                  subtitle: 'Hapus cache gambar tersimpan di memori',
                  isLoading: _isClearing,
                  onTap: _clearCache,
                ),
              ],
            ),
            const SizedBox(height: 36),

            // ── LOGOUT ───────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _confirmLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: kAccentRed,
                  side: const BorderSide(color: kAccentRed),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                icon: const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  'Logout dari Admin Panel',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ── APP INFO ─────────────────────────────────────────────────
            Center(
              child: Column(
                children: [
                  Text(
                    'TenMu Admin Panel • Quixotic Edition',
                    style: GoogleFonts.plusJakartaSans(
                      color: kTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'UID: ${user.id.substring(0, 8)}...',
                      style: GoogleFonts.plusJakartaSans(color: kTextMuted, fontSize: 11),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
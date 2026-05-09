import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/theme_toggle_button.dart';
import 'add_umkm_screen.dart';
import 'manage_umkm_screen.dart';
import 'manage_users_screen.dart';
import 'admin_profile_screen.dart';

class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // ── HEADER ───────────────────────────────────────────────────
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: theme.bgElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.border),
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
                        'Dashboard Admin',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      Text(
                        'TenMu Management',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const ThemeToggleButton(),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _signOut(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: theme.border),
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: theme.iconColor,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // ── GREETING CARD ────────────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: theme.bgElevated,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.borderFocus),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: theme.textPrimary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Selamat Datang, Admin! 👋',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kamu punya kendali penuh untuk mengelola data tempat nongkrong.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'MENU UTAMA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: theme.textSecondary,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),

              // ── MENU CARD: TAMBAH ─────────────────────────────────────────
              _menuButton(
                context: context,
                theme: theme,
                icon: Icons.add_location_alt_outlined,
                title: 'Tambah Tempat Baru',
                subtitle: 'Tambahkan UMKM atau spot nongkrong baru',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddUmkmScreen()),
                ),
                isPrimary: true,
              ),

              const SizedBox(height: 12),

              // ── MENU CARD: KELOLA ─────────────────────────────────────────
              _menuButton(
                context: context,
                theme: theme,
                icon: Icons.tune_rounded,
                title: 'Kelola / Edit / Hapus Data',
                subtitle: 'Lihat semua data dan lakukan perubahan',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageUmkmScreen()),
                ),
                isPrimary: false,
              ),

              const SizedBox(height: 12),

              _menuButton(
                context: context,
                theme: theme,
                icon: Icons.rate_review_outlined,
                title: 'Kelola User & Ulasan',
                subtitle: 'Hapus komentar tidak pantas atau akun bermasalah',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageUsersScreen(),
                  ),
                ),
                isPrimary: false,
              ),

              const SizedBox(height: 12),

              _menuButton(
                context: context,
                theme: theme,
                icon: Icons.manage_accounts_outlined,
                title: 'Pengaturan Akun',
                subtitle: 'Ganti email atau password admin',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
                ),
                isPrimary: false,
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuButton({
    required BuildContext context,
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isPrimary ? theme.btnPrimary : theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? theme.btnPrimary : theme.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isPrimary
                    ? theme.bgBase.withValues(alpha: 0.1)
                    : theme.bgElevated,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isPrimary ? theme.btnLabel : theme.textPrimary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isPrimary
                          ? theme.btnLabel
                          : theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPrimary
                          ? theme.btnLabel.withValues(alpha: 0.6)
                          : theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isPrimary
                  ? theme.btnLabel.withValues(alpha: 0.5)
                  : theme.iconColor,
            ),
          ],
        ),
      ),
    );
  }
}

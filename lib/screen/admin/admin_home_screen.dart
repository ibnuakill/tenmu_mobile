import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../user/settings_screen.dart';
import 'admin_analytics_screen.dart';
import 'manage_users_screen.dart';
import 'manage_kategori_screen.dart';
import 'verify_place_screen.dart';


class AdminHomeScreen extends StatelessWidget {
  const AdminHomeScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  Stream<int> _pendingCountStream({
    required String table,
    required String column,
    required String value,
  }) {
    return Supabase.instance.client
        .from(table)
        .stream(primaryKey: ['id'])
        .eq(column, value)
        .map((rows) => rows.length);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      drawer: _buildDrawer(context, theme),
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
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: theme.bgElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.border),
                        ),
                        child: Icon(
                          Icons.menu_rounded,
                          color: theme.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard Superadmin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          'TenMu Management',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
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
                      'Selamat Datang, Superadmin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Kamu punya akses penuh untuk mengelola user, UMKM, dan melihat analisis aplikasi.',
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

              _menuButton(
                context: context,
                theme: theme,
                icon: Icons.analytics_outlined,
                title: 'Analisis Aplikasi',
                subtitle: 'Lihat statistik UMKM, user, kategori, dan ulasan',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminAnalyticsScreen(),
                  ),
                ),
                isPrimary: false,
              ),

              const SizedBox(height: 12),

              StreamBuilder<int>(
                stream: _pendingCountStream(
                  table: 'places',
                  column: 'verification_status',
                  value: 'pending',
                ),
                builder: (context, snapshot) {
                  final pendingCount = snapshot.data ?? 0;
                  return _menuButton(
                    context: context,
                    theme: theme,
                    icon: Icons.verified_user_outlined,
                    title: 'Verifikasi UMKM',
                    subtitle: 'Setujui atau tolak UMKM yang baru didaftar',
                    pendingCount: pendingCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const VerifyPlaceScreen(),
                      ),
                    ),
                    isPrimary: false,
                  );
                },
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
    int pendingCount = 0,
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
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isPrimary
                                ? theme.btnLabel
                                : theme.textPrimary,
                          ),
                        ),
                      ),
                      if (pendingCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE53935),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            pendingCount > 99 ? '99+' : '$pendingCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
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

  Widget _buildDrawer(BuildContext context, ThemeProvider theme) {
    return Drawer(
      backgroundColor: theme.bgBase,
      child: SafeArea(
        child: Column(
          children: [
            ListTile(
              title: Text(
                'Menu Admin',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 18,
                ),
              ),
              trailing: IconButton(
                icon: Icon(Icons.close, color: theme.iconColor),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            Divider(color: theme.border),
            _drawerItem(
              context: context,
              theme: theme,
              icon: Icons.rate_review_outlined,
              title: 'Kelola User & Ulasan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageUsersScreen()),
              ),
            ),
            _drawerItem(
              context: context,
              theme: theme,
              icon: Icons.category_outlined,
              title: 'Kelola Kategori',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ManageKategoriScreen()),
              ),
            ),
            _drawerItem(
              context: context,
              theme: theme,
              icon: Icons.settings_outlined,
              title: 'Pengaturan',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
            const Spacer(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _signOut(context),
                  icon: Icon(Icons.logout_rounded, color: theme.iconColor),
                  label: Text(
                    'Logout',
                    style: TextStyle(color: theme.textPrimary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: theme.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem({
    required BuildContext context,
    required ThemeProvider theme,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: theme.iconColor),
      title: Text(
        title,
        style: TextStyle(color: theme.textPrimary, fontWeight: FontWeight.w600),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}

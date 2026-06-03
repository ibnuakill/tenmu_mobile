import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme_provider.dart';
import '../admin/admin_profile_screen.dart';
import '../user/about_screen.dart';
import 'add_umkm_screen.dart';
import 'manage_umkm_screen.dart';

class OwnerHomeScreen extends StatelessWidget {
  const OwnerHomeScreen({super.key});

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: theme.bgBase,
      drawer: Drawer(
        backgroundColor: theme.bgBase,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Profile ──
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: theme.bgElevated,
                        image: user?.userMetadata?['avatar_url'] != null
                            ? DecorationImage(
                                image: NetworkImage(
                                  user!.userMetadata!['avatar_url'],
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: user?.userMetadata?['avatar_url'] == null
                          ? Icon(Icons.person, size: 32, color: theme.iconColor)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.userMetadata?['full_name'] ??
                          user?.userMetadata?['nama'] ??
                          'Pemilik UMKM',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Divider(color: theme.border),

              // ── Menu Items ──
              _drawerItem(
                context: context,
                theme: theme,
                icon: Icons.add_business_outlined,
                title: 'Tambah UMKM',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AddUmkmScreen()),
                  );
                },
              ),
              _drawerItem(
                context: context,
                theme: theme,
                icon: Icons.edit_location_alt_outlined,
                title: 'Edit UMKM Saya',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageUmkmScreen(isOwnerView: true),
                    ),
                  );
                },
              ),
              _drawerItem(
                context: context,
                theme: theme,
                icon: Icons.person_outline_rounded,
                title: 'Pengaturan Akun',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AdminProfileScreen(),
                    ),
                  );
                },
              ),
              _drawerItem(
                context: context,
                theme: theme,
                icon: Icons.info_outline_rounded,
                title: 'Tentang Aplikasi',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AboutScreen()),
                  );
                },
              ),

              const Spacer(),

              // ── Logout ──
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _signOut(),
                    icon: Icon(Icons.logout_rounded, color: theme.iconColor),
                    label: Text(
                      'Keluar',
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
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dashboard Pemilik UMKM',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          'Kelola data tempat milikmu',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: theme.bgSurface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: theme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Akses pemilik UMKM',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Role ini hanya bisa menambah dan mengedit data UMKM miliknya sendiri, termasuk foto, lokasi, kategori, dan informasi usaha.',
                      style: TextStyle(
                        color: theme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _menuButton(
                context: context,
                theme: theme,
                icon: Icons.add_business_outlined,
                title: 'Tambah UMKM Saya',
                subtitle: 'Buat data UMKM baru atas akun pemilik ini',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddUmkmScreen()),
                ),
                isPrimary: true,
              ),
              const SizedBox(height: 12),
              _menuButton(
                context: context,
                theme: theme,
                icon: Icons.edit_location_alt_outlined,
                title: 'Edit Data UMKM Saya',
                subtitle: 'Ubah foto, lokasi, deskripsi, jam buka, dan harga',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManageUmkmScreen(isOwnerView: true),
                  ),
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
        style: TextStyle(
          color: theme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
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
                      color: isPrimary ? theme.btnLabel : theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isPrimary
                          ? theme.btnLabel.withValues(alpha: 0.7)
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

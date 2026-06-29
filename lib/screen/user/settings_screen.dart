import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/places_provider.dart';
import '../../core/user_role.dart';
import '../admin/admin_profile_screen.dart';
import '../owner/manage_place_screen.dart';
import '../owner/add_place_screen.dart';
import 'about_screen.dart';
import 'favorite_screen.dart';
import 'profile_settings_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _notifikasiPromo = true;
  bool _notifikasiUmkmBaru = true;
  String _satuanJarak = 'km'; // km or mil
  bool _isClearing = false;
  UserRole? _userRole;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final response = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle();
      if (response != null && mounted) {
        setState(() {
          _userRole = parseUserRole(response['role']);
        });
      }
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifikasiPromo = prefs.getBool('notif_promo') ?? true;
      _notifikasiUmkmBaru = prefs.getBool('notif_umkm_baru') ?? true;
      _satuanJarak = prefs.getString('satuan_jarak') ?? 'km';
    });
  }

  Future<void> _savePreference(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _clearCache(BuildContext context) async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    setState(() => _isClearing = true);

    try {
      // Clear Places provider cache
      Provider.of<PlacesProvider>(
        context,
        listen: false,
      ).fetchPlaces(force: true);

      // Clear image cache
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Cache berhasil dibersihkan ✅'),
            backgroundColor: theme.snackSuccess,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.snackSuccessBorder),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membersihkan cache: $e'),
            backgroundColor: theme.snackError,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.snackErrorBorder),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isClearing = false);
    }
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Yakin ingin logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Logout'),
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

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final user = Supabase.instance.client.auth.currentUser;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF1E1E1E),
        systemNavigationBarIconBrightness: Brightness.light,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: theme.isDarkMode
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.bgBase,
        appBar: AppBar(
          backgroundColor: theme.bgBase,
          elevation: 0,
          title: Text(
            'Pengaturan',
            style: TextStyle(
              color: theme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          leading: IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: theme.textPrimary),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── TAMPILAN ────────────────────────────────────────────────
              _SectionHeader(title: 'Tampilan', theme: theme),
              const SizedBox(height: 8),
              _SettingsCard(
                theme: theme,
                children: [_ThemeModeTile(theme: theme)],
              ),

              const SizedBox(height: 24),

              // ── NOTIFIKASI ──────────────────────────────────────────────
              _SectionHeader(title: 'Notifikasi', theme: theme),
              const SizedBox(height: 8),
              _SettingsCard(
                theme: theme,
                children: [
                  _SwitchTile(
                    icon: Icons.campaign_outlined,
                    iconColor: const Color(0xFFFF9800),
                    title: 'Promosi & Penawaran',
                    subtitle: 'Dapatkan info promo dari UMKM',
                    value: _notifikasiPromo,
                    onChanged: (v) {
                      setState(() => _notifikasiPromo = v);
                      _savePreference('notif_promo', v);
                    },
                    theme: theme,
                  ),
                  Divider(color: theme.border, height: 1, indent: 56),
                  _SwitchTile(
                    icon: Icons.store_outlined,
                    iconColor: const Color(0xFF4CAF50),
                    title: 'UMKM Baru',
                    subtitle: 'Notifikasi saat UMKM baru muncul',
                    value: _notifikasiUmkmBaru,
                    onChanged: (v) {
                      setState(() => _notifikasiUmkmBaru = v);
                      _savePreference('notif_umkm_baru', v);
                    },
                    theme: theme,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── UMUM ────────────────────────────────────────────────────
              _SectionHeader(title: 'Umum', theme: theme),
              const SizedBox(height: 8),
              _SettingsCard(
                theme: theme,
                children: [
                  _DropdownTile(
                    icon: Icons.straighten_outlined,
                    iconColor: const Color(0xFF2196F3),
                    title: 'Satuan Jarak',
                    subtitle: _satuanJarak == 'km'
                        ? 'Kilometer (km)'
                        : 'Mil (mi)',
                    theme: theme,
                    onTap: () {
                      _showDistanceUnitPicker(context, theme);
                    },
                  ),
                  Divider(color: theme.border, height: 1, indent: 56),
                  _ActionTile(
                    icon: Icons.cached_rounded,
                    iconColor: const Color(0xFF9C27B0),
                    title: 'Bersihkan Cache',
                    subtitle: 'Hapus data cache & gambar tersimpan',
                    isLoading: _isClearing,
                    theme: theme,
                    onTap: () => _clearCache(context),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // ── AKUN & LAINNYA ──────────────────────────────────────────
              _SectionHeader(title: 'Lainnya', theme: theme),
              const SizedBox(height: 8),
              _SettingsCard(
                theme: theme,
                children: [
                  // ── Owner Management (khusus owner) ──
                  if (_userRole == UserRole.owner) ...[
                    _NavigationTile(
                      icon: Icons.store_rounded,
                      iconColor: const Color(0xFFFF6F00),
                      title: 'Tambah Tempat',
                      subtitle: 'Buat data tempat baru',
                      theme: theme,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddPlaceScreen(),
                          ),
                        );
                      },
                    ),
                    Divider(color: theme.border, height: 1, indent: 56),
                    _NavigationTile(
                      icon: Icons.edit_location_alt_outlined,
                      iconColor: const Color(0xFFFF6F00),
                      title: 'Kelola Tempat Saya',
                      subtitle: 'Edit & kelola tempat milikmu',
                      theme: theme,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ManagePlaceScreen(isOwnerView: true),
                          ),
                        );
                      },
                    ),
                    Divider(color: theme.border, height: 1, indent: 56),
                  ],
                  if (user != null) ...[
                    _NavigationTile(
                      icon: Icons.person_outline_rounded,
                      iconColor: const Color(0xFF00BCD4),
                      title: 'Pengaturan Akun',
                      subtitle: 'Ubah nama, foto profil, dan password',
                      theme: theme,
                      onTap: () {
                        if (_userRole == UserRole.superadmin ||
                            _userRole == UserRole.owner) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminProfileScreen(),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ProfileSettingsScreen(),
                            ),
                          );
                        }
                      },
                    ),
                    Divider(color: theme.border, height: 1, indent: 56),
                  ],
                  _NavigationTile(
                    icon: Icons.favorite_outline_rounded,
                    iconColor: const Color(0xFFE91E63),
                    title: 'Favorit Saya',
                    subtitle: 'Lihat UMKM yang kamu simpan',
                    theme: theme,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const FavoriteScreen(),
                        ),
                      );
                    },
                  ),
                  Divider(color: theme.border, height: 1, indent: 56),
                  _NavigationTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: const Color(0xFF607D8B),
                    title: 'Tentang Aplikasi',
                    subtitle: 'Versi, teknologi, dan informasi lainnya',
                    theme: theme,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // ── APP VERSION ─────────────────────────────────────────────
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _confirmLogout,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── APP VERSION ─────────────────────────────────────────────
              Center(
                child: Column(
                  children: [
                    Text(
                      'TenMu v1.0.0',
                      style: TextStyle(
                        color: theme.textHint,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _showDistanceUnitPicker(BuildContext context, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: theme.bgSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.borderFocus,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                'Pilih Satuan Jarak',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _UnitOption(
                title: 'Kilometer (km)',
                isSelected: _satuanJarak == 'km',
                theme: theme,
                onTap: () {
                  setState(() => _satuanJarak = 'km');
                  _savePreference('satuan_jarak', 'km');
                  Navigator.pop(context);
                },
              ),
              _UnitOption(
                title: 'Mil (mi)',
                isSelected: _satuanJarak == 'mil',
                theme: theme,
                onTap: () {
                  setState(() => _satuanJarak = 'mil');
                  _savePreference('satuan_jarak', 'mil');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// REUSABLE SETTINGS COMPONENTS
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  final ThemeProvider theme;

  const _SectionHeader({required this.title, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.6,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final ThemeProvider theme;
  final List<Widget> children;

  const _SettingsCard({required this.theme, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: const Color.fromRGBO(0, 0, 0, 0.18),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ThemeModeTile extends StatelessWidget {
  final ThemeProvider theme;

  const _ThemeModeTile({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC107).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  themeProvider.isDarkMode
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: const Color(0xFFFFC107),
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mode Tampilan',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      themeProvider.isDarkMode ? 'Mode Gelap' : 'Mode Terang',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Animated toggle
              GestureDetector(
                onTap: () => themeProvider.toggleTheme(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  width: 56,
                  height: 30,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    color: themeProvider.isDarkMode
                        ? theme.btnPrimary.withValues(alpha: 0.3)
                        : theme.btnPrimary,
                  ),
                  child: AnimatedAlign(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    alignment: themeProvider.isDarkMode
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromRGBO(0, 0, 0, 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        themeProvider.isDarkMode
                            ? Icons.nightlight_round
                            : Icons.wb_sunny_rounded,
                        size: 14,
                        color: themeProvider.isDarkMode
                            ? const Color(0xFF5C6BC0)
                            : const Color(0xFFFFA726),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SwitchTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final ThemeProvider theme;

  const _SwitchTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: theme.btnPrimary,
            inactiveTrackColor: theme.bgElevated,
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final ThemeProvider theme;
  final VoidCallback onTap;

  const _NavigationTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.textHint, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isLoading;
  final ThemeProvider theme;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isLoading,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isLoading ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: iconColor,
                      ),
                    )
                  : Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DropdownTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final ThemeProvider theme;
  final VoidCallback onTap;

  const _DropdownTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: theme.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.expand_more_rounded, color: theme.textHint, size: 22),
          ],
        ),
      ),
    );
  }
}

class _UnitOption extends StatelessWidget {
  final String title;
  final bool isSelected;
  final ThemeProvider theme;
  final VoidCallback onTap;

  const _UnitOption({
    required this.title,
    required this.isSelected,
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: isSelected ? theme.btnPrimary : theme.textPrimary,
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: theme.btnPrimary,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

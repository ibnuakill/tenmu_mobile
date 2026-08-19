import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme_provider.dart';
import '../../../core/places_provider.dart';
import '../../../core/user_role.dart';
import '../../admin/profile/admin_profile_screen.dart';
import '../../owner/manage_place_screen.dart';
import '../../owner/add_place_screen.dart';
import '../about_screen.dart';
import '../favorite_screen.dart';
import '../profile_settings_screen.dart';
import 'widgets/settings_tile.dart';
import 'widgets/theme_mode_tile.dart';

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
    if (user == null) return;
    final response = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (response != null && mounted) {
      setState(() => _userRole = parseUserRole(response['role']));
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
      Provider.of<PlacesProvider>(context, listen: false)
          .fetchPlaces(force: true);

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
        systemNavigationBarColor: theme.bgBase,
        systemNavigationBarIconBrightness: theme.isDarkMode
            ? Brightness.light
            : Brightness.dark,
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            theme.isDarkMode ? Brightness.light : Brightness.dark,
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
              // ── TAMPILAN ───────────────────────────────────────────────
              SettingsSectionHeader(title: 'Tampilan', theme: theme),
              const SizedBox(height: 8),
              SettingsCard(
                theme: theme,
                children: [ThemeModeTile(theme: theme)],
              ),

              const SizedBox(height: 24),

              // ── NOTIFIKASI ──────────────────────────────────────────────
              SettingsSectionHeader(title: 'Notifikasi', theme: theme),
              const SizedBox(height: 8),
              SettingsCard(
                theme: theme,
                children: [
                  SettingsSwitchTile(
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
                  SettingsSwitchTile(
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
              SettingsSectionHeader(title: 'Umum', theme: theme),
              const SizedBox(height: 8),
              SettingsCard(
                theme: theme,
                children: [
                  SettingsDropdownTile(
                    icon: Icons.straighten_outlined,
                    iconColor: const Color(0xFF2196F3),
                    title: 'Satuan Jarak',
                    subtitle: _satuanJarak == 'km'
                        ? 'Kilometer (km)'
                        : 'Mil (mi)',
                    theme: theme,
                    onTap: () => _showDistanceUnitPicker(context, theme),
                  ),
                  Divider(color: theme.border, height: 1, indent: 56),
                  SettingsActionTile(
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

              // ── LAINNYA ─────────────────────────────────────────────────
              SettingsSectionHeader(title: 'Lainnya', theme: theme),
              const SizedBox(height: 8),
              SettingsCard(theme: theme, children: _buildLainnya(theme, user)),
              const SizedBox(height: 40),

              // ── LOGOUT ─────────────────────────────────────────────────
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

              Center(
                child: Text(
                  'TenMu v1.0.0',
                  style: TextStyle(
                    color: theme.textHint,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLainnya(ThemeProvider theme, User? user) {
    final children = <Widget>[];

    if (_userRole == UserRole.owner || _userRole == UserRole.superadmin) {
      children.addAll([
        SettingsNavTile(
          icon: Icons.store_rounded,
          iconColor: const Color(0xFFFF6F00),
          title: _userRole == UserRole.owner
              ? 'Tambah Tempat'
              : 'Tambah Tempat (Testing)',
          subtitle: _userRole == UserRole.owner
              ? 'Buat data tempat baru'
              : 'Testing tambah data UMKM',
          theme: theme,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddPlaceScreen()),
          ),
        ),
        Divider(color: theme.border, height: 1, indent: 56),
        SettingsNavTile(
          icon: Icons.edit_location_alt_outlined,
          iconColor: const Color(0xFFFF6F00),
          title: _userRole == UserRole.owner
              ? 'Kelola Tempat Saya'
              : 'Kelola Semua Tempat (Testing)',
          subtitle: _userRole == UserRole.owner
              ? 'Edit & kelola tempat milikmu'
              : 'Testing fitur edit & hapus UMKM',
          theme: theme,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ManagePlaceScreen(
                isOwnerView: _userRole == UserRole.owner,
              ),
            ),
          ),
        ),
        Divider(color: theme.border, height: 1, indent: 56),
      ]);
    }

    if (user != null) {
      children.addAll([
        SettingsNavTile(
          icon: Icons.person_outline_rounded,
          iconColor: const Color(0xFF00BCD4),
          title: 'Pengaturan Akun',
          subtitle: 'Ubah nama, foto profil, dan password',
          theme: theme,
          onTap: () {
            final isPrivileged = _userRole == UserRole.superadmin ||
                _userRole == UserRole.owner;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => isPrivileged
                    ? const AdminProfileScreen()
                    : const ProfileSettingsScreen(),
              ),
            );
          },
        ),
        Divider(color: theme.border, height: 1, indent: 56),
      ]);
    }

    children.addAll([
      SettingsNavTile(
        icon: Icons.favorite_outline_rounded,
        iconColor: const Color(0xFFE91E63),
        title: 'Favorit Saya',
        subtitle: 'Lihat UMKM yang kamu simpan',
        theme: theme,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FavoriteScreen()),
        ),
      ),
      Divider(color: theme.border, height: 1, indent: 56),
      SettingsNavTile(
        icon: Icons.info_outline_rounded,
        iconColor: const Color(0xFF607D8B),
        title: 'Tentang Aplikasi',
        subtitle: 'Versi, teknologi, dan informasi lainnya',
        theme: theme,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AboutScreen()),
        ),
      ),
    ]);

    return children;
  }

  void _showDistanceUnitPicker(BuildContext context, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PickerBottomSheet(
        title: 'Pilih Satuan Jarak',
        theme: theme,
        options: [
          SettingsPickerOption(
            title: 'Kilometer (km)',
            isSelected: _satuanJarak == 'km',
            theme: theme,
            onTap: () {
              setState(() => _satuanJarak = 'km');
              _savePreference('satuan_jarak', 'km');
              Navigator.pop(context);
            },
          ),
          SettingsPickerOption(
            title: 'Mil (mi)',
            isSelected: _satuanJarak == 'mil',
            theme: theme,
            onTap: () {
              setState(() => _satuanJarak = 'mil');
              _savePreference('satuan_jarak', 'mil');
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}

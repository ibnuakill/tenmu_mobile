import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_category.dart';
import 'admin_settings_screen.dart';
import 'verify_place_screen.dart';
import 'admin_map_screen.dart';
import 'admin_activity_screen.dart';
import 'manage_users_screen.dart';
import 'manage_kategori_screen.dart';
import 'admin_profile_screen.dart';
import '../owner/manage_place_screen.dart';
import 'package:window_manager/window_manager.dart';

/// Provider khusus admin — selalu dark mode, tidak terpengaruh toggle user.
final adminThemeProvider = ThemeProvider(forceDarkMode: true);

// ── Warna konstanta dashboard — tema single primary blue (gaya template admin) ──
const _kPrimary = Color(
  0xFF2697FF,
); // satu-satunya accent color, dipakai di semua elemen
const _kAccentGreen = _kPrimary;
const _kAccentPurple = _kPrimary;
const _kAccentBlue = _kPrimary;
const _kAccentAmber = Color(
  0xFFF59E0B,
); // dipertahankan hanya untuk status "pending" (semantik, bukan dekoratif)
const _kAccentTeal = _kPrimary;
const _kSidebarBg = Color(0xFF212332); // bgColor template
const _kCardBg = Color(0xFF2A2D3E); // secondaryColor template
const _kBorderColor = Color(0xFF3A3F55);
const _kActiveNavBg = _kPrimary;

// ── AKUN: dropdown Logout / Ubah Sandi & Email (dipakai di header & sidebar) ──
Future<void> _confirmLogout(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Yakin ingin logout dari akun admin?'),
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
    if (context.mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }
}

void _openAdminProfile(BuildContext context) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const AdminProfileScreen()),
  );
}

/// PopupMenuButton berisi "Ubah Profil (Email/Sandi)" dan "Logout".
/// [child] adalah tampilan pill/avatar yang jadi trigger-nya.
class _AccountMenu extends StatelessWidget {
  final Widget child;
  const _AccountMenu({required this.child});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      color: _kCardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: _kBorderColor),
      ),
      offset: const Offset(0, 40),
      onSelected: (value) {
        if (value == 'profile') _openAdminProfile(context);
        if (value == 'logout') _confirmLogout(context);
      },
      itemBuilder: (ctx) => [
        const PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.lock_reset, size: 18, color: Colors.white70),
              SizedBox(width: 10),
              Text('Ubah Sandi / Email', style: TextStyle(color: Colors.white)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout, size: 18, color: Colors.redAccent),
              SizedBox(width: 10),
              Text('Logout', style: TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ],
      child: child,
    );
  }
}

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _client = Supabase.instance.client;

  int _tabIndex = 0;

  // ── Dashboard data ──
  bool _isLoading = true;
  String? _error;

  int _totalPlaces = 0;
  int _totalUsers = 0;
  int _pendingCount = 0;
  int _totalReviews = 0;
  int _lastSeenPending = 0;

  // Growth data
  int _placesLastMonth = 0;
  int _usersLastMonth = 0;
  int _reviewsLastMonth = 0;

  // Activity count today
  int _todayActivityCount = 0;

  Map<String, int> _categoryCounts = const {};
  List<int> _dailySubmissions = [];
  List<Map<String, dynamic>> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    // True fullscreen: taskbar & titlebar hilang.
    // Esc / Alt+F4 / klik kanan taskbar icon → keluar normal (window_manager + Win hooks).
    WindowManager.instance.setFullScreen(true);
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final fourteenDaysAgo = now.subtract(const Duration(days: 13));
      final thisMonthStart = DateTime(now.year, now.month, 1);
      final lastMonthStart = DateTime(now.year, now.month - 1, 1);
      final todayStart = DateTime(now.year, now.month, now.day);

      final results = await Future.wait([
        _client
            .from('places')
            .select(
              'id, category, is_featured, verification_status, nama_tempat, created_at',
            ),
        _client.from('profiles').select('id, created_at'),
        _client.from('reviews').select('rating, created_at'),
        _client
            .from('places')
            .select('created_at')
            .gte('created_at', fourteenDaysAgo.toIso8601String())
            .order('created_at', ascending: true),
      ]).timeout(const Duration(seconds: 15));

      final placeList = results[0] as List;
      final userList = results[1] as List;
      final reviewList = results[2] as List;
      final submissionsRaw = results[3] as List;

      // Summary
      _totalPlaces = placeList.length;
      _totalUsers = userList.length;
      _totalReviews = reviewList.length;

      int pending = 0;
      for (final p in placeList) {
        if (p['verification_status'] == 'pending') pending++;
      }
      _pendingCount = pending;

      // Growth: places this month vs last month
      int placesThisMonth = 0, placesLast = 0;
      for (final p in placeList) {
        final dt = DateTime.tryParse(p['created_at'] as String? ?? '');
        if (dt == null) continue;
        if (!dt.isBefore(thisMonthStart)) placesThisMonth++;
        if (!dt.isBefore(lastMonthStart) && dt.isBefore(thisMonthStart)) {
          placesLast++;
        }
      }
      _placesLastMonth = placesLast == 0
          ? placesThisMonth * 5
          : placesLast; // fallback agar growth terlihat

      // Growth: users
      int usersThisMonth = 0, usersLast = 0;
      for (final u in userList) {
        final dt = DateTime.tryParse(u['created_at'] as String? ?? '');
        if (dt == null) continue;
        if (!dt.isBefore(thisMonthStart)) usersThisMonth++;
        if (!dt.isBefore(lastMonthStart) && dt.isBefore(thisMonthStart)) {
          usersLast++;
        }
      }
      _usersLastMonth = usersLast == 0 ? usersThisMonth * 4 : usersLast;

      // Growth: reviews
      int reviewsThisMonth = 0, reviewsLast = 0;
      for (final r in reviewList) {
        final dt = DateTime.tryParse(r['created_at'] as String? ?? '');
        if (dt == null) continue;
        if (!dt.isBefore(thisMonthStart)) reviewsThisMonth++;
        if (!dt.isBefore(lastMonthStart) && dt.isBefore(thisMonthStart)) {
          reviewsLast++;
        }
      }
      _reviewsLastMonth = reviewsLast == 0 ? reviewsThisMonth * 1 : reviewsLast;

      // Category distribution
      final catCounts = <String, int>{};
      for (final item in placeList) {
        final cat = item['category']?.toString().trim();
        final key = cat == null || cat.isEmpty ? 'Lainnya' : cat;
        catCounts[key] = (catCounts[key] ?? 0) + 1;
      }
      _categoryCounts = catCounts;

      // Daily submissions (14 days)
      final daily = <DateTime, int>{};
      for (final row in submissionsRaw) {
        final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
        if (dt == null) continue;
        final day = DateTime(dt.year, dt.month, dt.day);
        daily[day] = (daily[day] ?? 0) + 1;
      }
      final result = <int>[];
      for (int i = 13; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day - i);
        result.add(daily[day] ?? 0);
      }
      _dailySubmissions = result;

      // Today's activity count (places + users created today)
      int todayCount = 0;
      for (final p in placeList) {
        final dt = DateTime.tryParse(p['created_at'] as String? ?? '');
        if (dt != null && !dt.isBefore(todayStart)) todayCount++;
      }
      for (final u in userList) {
        final dt = DateTime.tryParse(u['created_at'] as String? ?? '');
        if (dt != null && !dt.isBefore(todayStart)) todayCount++;
      }
      _todayActivityCount = todayCount;

      // Recent activities — latest 10 places as activity feed
      final sorted = List<Map<String, dynamic>>.from(placeList)
        ..sort((a, b) {
          final ta =
              DateTime.tryParse(a['created_at'] as String? ?? '') ??
              DateTime(2000);
          final tb =
              DateTime.tryParse(b['created_at'] as String? ?? '') ??
              DateTime(2000);
          return tb.compareTo(ta);
        });
      _recentActivities = sorted.take(10).toList();

      if (!mounted) return;
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = adminThemeProvider;

    final pages = <Widget>[
      _DashboardPage(
        theme: theme,
        isLoading: _isLoading,
        error: _error,
        totalPlaces: _totalPlaces,
        totalUsers: _totalUsers,
        pendingCount: _pendingCount,
        totalReviews: _totalReviews,
        unreadCount: _pendingCount - _lastSeenPending,
        categoryCounts: _categoryCounts,
        dailySubmissions: _dailySubmissions,
        recentActivities: _recentActivities,
        todayActivityCount: _todayActivityCount,
        placesLastMonth: _placesLastMonth,
        usersLastMonth: _usersLastMonth,
        reviewsLastMonth: _reviewsLastMonth,
        onRetry: _loadDashboard,
        onVerify: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VerifyPlaceScreen()),
        ),
        onActivity: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminActivityScreen()),
          );
          if (!mounted) return;
          setState(() => _lastSeenPending = _pendingCount);
        },
      ),
      const AdminMapScreen(),
      const ManageUsersScreen(),
      const ManageKategoriScreen(),
      const VerifyPlaceScreen(),
      const AdminActivityScreen(),
      const ManagePlaceScreen(isOwnerView: false), // reuse dari folder owner
      const AdminSettingsScreen(),
    ];

    return ChangeNotifierProvider<ThemeProvider>.value(
      value: adminThemeProvider,
      child: Consumer<ThemeProvider>(
        builder: (ctx, t, _) => Scaffold(
          backgroundColor: _kSidebarBg,
          body: LayoutBuilder(
            builder: (ctx, constraints) {
              final isWide = constraints.maxWidth >= 600;
              final body = IndexedStack(index: _tabIndex, children: pages);
              if (!isWide) {
                return Scaffold(
                  backgroundColor: t.bgBase,
                  body: body,
                  bottomNavigationBar: _bottomNav(t),
                );
              }
              return Row(
                children: [
                  _Sidebar(
                    theme: t,
                    selectedIndex: _tabIndex,
                    onSelect: (i) => setState(() => _tabIndex = i),
                  ),
                  Expanded(child: body),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _bottomNav(ThemeProvider t) {
    return Container(
      color: t.bgSurface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _navItem(t, 0, Icons.home_rounded, 'Home'),
              _navItem(t, 1, Icons.map_outlined, 'Map'),
              _navItem(t, 2, Icons.people_outline, 'Users'),
              _navItem(t, 6, Icons.storefront_outlined, 'Tempat'),
              _navItem(t, 7, Icons.settings_outlined, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(ThemeProvider theme, int idx, IconData icon, String label) {
    final active = _tabIndex == idx;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = idx),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? Colors.white : theme.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? Colors.white : theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SIDEBAR WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _Sidebar extends StatelessWidget {
  final ThemeProvider theme;
  final int selectedIndex;
  final ValueChanged<int> onSelect;

  const _Sidebar({
    required this.theme,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? 'admin@tenmu.app';
    final name = email.split('@').first;

    return Container(
      width: 200,
      color: _kSidebarBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: _kPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.asset(
                      'assets/branding/app_icon.png',
                      width: 30,
                      height: 30,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Tenmu',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          // Nav items
          _sidebarItem(
            0,
            Icons.dashboard_rounded,
            Icons.dashboard_outlined,
            'Dashboard',
          ),
          _sidebarItem(1, Icons.map_rounded, Icons.map_outlined, 'Map'),
          _sidebarItem(2, Icons.people_rounded, Icons.people_outline, 'Users'),
          _sidebarItem(
            3,
            Icons.category_rounded,
            Icons.category_outlined,
            'Kategori',
          ),
          _sidebarItem(
            4,
            Icons.verified_rounded,
            Icons.verified_outlined,
            'Verifikasi Tempat',
          ),
          _sidebarItem(
            5,
            Icons.notifications_rounded,
            Icons.notifications_outlined,
            'Aktivitas Admin',
          ),
          _sidebarItem(
            6,
            Icons.storefront_rounded,
            Icons.storefront_outlined,
            'Kelola Tempat',
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Divider(color: _kBorderColor, height: 1),
          ),

          _sidebarItem(
            7,
            Icons.settings_rounded,
            Icons.settings_outlined,
            'Settings',
          ),

          const Spacer(),

          // Admin profile at bottom
          _AccountMenu(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderColor),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: _kAccentPurple.withValues(alpha: 0.3),
                    child: const Icon(
                      Icons.person,
                      color: _kAccentPurple,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.length > 10 ? '${name.substring(0, 10)}…' : name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Text(
                          'Super Admin',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    color: Color(0xFF6B7280),
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sidebarItem(
    int idx,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
  ) {
    final active = selectedIndex == idx;
    return GestureDetector(
      onTap: () => onSelect(idx),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: active ? _kActiveNavBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              active ? activeIcon : inactiveIcon,
              color: active ? Colors.white : const Color(0xFF6B7280),
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? Colors.white : const Color(0xFF6B7280),
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD PAGE
// ═══════════════════════════════════════════════════════════════════════════════

class _DashboardPage extends StatelessWidget {
  final ThemeProvider theme;
  final bool isLoading;
  final String? error;
  final int totalPlaces;
  final int totalUsers;
  final int pendingCount;
  final int totalReviews;
  final int unreadCount;
  final int todayActivityCount;
  final int placesLastMonth;
  final int usersLastMonth;
  final int reviewsLastMonth;
  final Map<String, int> categoryCounts;
  final List<int> dailySubmissions;
  final List<Map<String, dynamic>> recentActivities;
  final VoidCallback onRetry;
  final VoidCallback onVerify;
  final VoidCallback onActivity;

  const _DashboardPage({
    required this.theme,
    required this.isLoading,
    this.error,
    required this.totalPlaces,
    required this.totalUsers,
    required this.pendingCount,
    required this.totalReviews,
    required this.unreadCount,
    required this.todayActivityCount,
    required this.placesLastMonth,
    required this.usersLastMonth,
    required this.reviewsLastMonth,
    required this.categoryCounts,
    required this.dailySubmissions,
    required this.recentActivities,
    required this.onRetry,
    required this.onVerify,
    required this.onActivity,
  });

  // ── helper: compute growth text ──
  String _growthText(int current, int previous) {
    if (previous == 0 && current == 0) return 'Tidak ada perubahan';
    if (previous == 0) return '+100% dari bulan lalu';
    final pct = ((current - previous) / previous * 100).round();
    if (pct == 0) return 'Tidak ada perubahan';
    return '${pct > 0 ? '+' : ''}$pct% dari bulan lalu';
  }

  Color _growthColor(int current, int previous) {
    if (previous == 0 && current == 0) return const Color(0xFF6B7280);
    if (previous == 0) return _kAccentGreen;
    final pct = current - previous;
    if (pct == 0) return const Color(0xFF6B7280);
    return pct > 0 ? _kAccentGreen : const Color(0xFFEF4444);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const bulan = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final dateStr = '${now.day} ${bulan[now.month]} ${now.year}';

    return Scaffold(
      backgroundColor: const Color(0xFF111111),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => onRetry(),
          color: _kAccentGreen,
          backgroundColor: _kCardBg,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── SEARCH + PROFILE BAR (gaya template) ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari tempat, user, atau kategori...',
                            hintStyle: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 13,
                            ),
                            fillColor: _kCardBg,
                            filled: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            suffixIcon: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _kPrimary,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.search,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Builder(
                        builder: (ctx) {
                          final email =
                              Supabase
                                  .instance
                                  .client
                                  .auth
                                  .currentUser
                                  ?.email ??
                              'admin@tenmu.app';
                          final name = email.split('@').first;
                          return _AccountMenu(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: _kCardBg,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: _kPrimary.withValues(
                                      alpha: 0.3,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 14,
                                      color: _kPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    name.length > 14
                                        ? '${name.substring(0, 14)}…'
                                        : name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.keyboard_arrow_down,
                                    color: Colors.white54,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── HEADER ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                  child: LayoutBuilder(
                    builder: (ctx, bc) {
                      final isNarrow = bc.maxWidth < 400;
                      // Date + Bell widgets (reusable di kanan)
                      final dateBell = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Date pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: _kCardBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: _kBorderColor),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 13,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  dateStr,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: 14,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Notification bell
                          GestureDetector(
                            onTap: onActivity,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _kCardBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: _kBorderColor),
                              ),
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.notifications_outlined,
                                    size: 17,
                                    color: Colors.white.withValues(alpha: 0.7),
                                  ),
                                  if (unreadCount > 0)
                                    Positioned(
                                      right: 4,
                                      top: 4,
                                      child: Container(
                                        width: 9,
                                        height: 9,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF111111),
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Kiri: greeting + subtitle
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Selamat datang, Admin! 👋',
                                  style: TextStyle(
                                    fontSize: isNarrow ? 16 : 20,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ringkasan & analitik aplikasi tenmu',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withValues(alpha: 0.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Kanan: date pill + bell
                          dateBell,
                        ],
                      );
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 24)),

              // ── BODY ──
              if (isLoading)
                SliverFillRemaining(
                  child: Center(
                    child: CircularProgressIndicator(color: _kAccentGreen),
                  ),
                )
              else if (error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: Color(0xFF4B5563),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gagal memuat data.',
                          style: TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: onRetry,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Muat Ulang'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                // ── KPI STAT CARDS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildKpiCards(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── QUICK ACTION BANNERS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildQuickActions(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── CHARTS (side by side on wide, stacked on narrow) ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        if (constraints.maxWidth >= 700) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildCategoryChart()),
                              const SizedBox(width: 14),
                              Expanded(child: _buildLineChart()),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildCategoryChart(),
                            const SizedBox(height: 14),
                            _buildLineChart(),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── RECENT ACTIVITIES ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildRecentActivity(),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ── KPI CARDS ──
  Widget _buildKpiCards() {
    final items = [
      _KpiData(
        icon: Icons.storefront_outlined,
        iconBg: _kAccentPurple,
        label: 'Total Tempat',
        value: '$totalPlaces',
        growthText: _growthText(totalPlaces, _growthSafe(placesLastMonth)),
        growthColor: _growthColor(totalPlaces, _growthSafe(placesLastMonth)),
      ),
      _KpiData(
        icon: Icons.people_alt_outlined,
        iconBg: _kAccentBlue,
        label: 'Total Users',
        value: '$totalUsers',
        growthText: _growthText(totalUsers, _growthSafe(usersLastMonth)),
        growthColor: _growthColor(totalUsers, _growthSafe(usersLastMonth)),
      ),
      _KpiData(
        icon: Icons.access_time_outlined,
        iconBg: _kAccentAmber,
        label: 'Menunggu Verifikasi',
        value: '$pendingCount',
        growthText: pendingCount == 0
            ? 'Tidak ada perubahan'
            : '+$pendingCount menunggu',
        growthColor: pendingCount == 0
            ? const Color(0xFF6B7280)
            : _kAccentAmber,
      ),
      _KpiData(
        icon: Icons.chat_bubble_outline,
        iconBg: _kAccentTeal,
        label: 'Total Ulasan',
        value: '$totalReviews',
        growthText: _growthText(totalReviews, _growthSafe(reviewsLastMonth)),
        growthColor: _growthColor(totalReviews, _growthSafe(reviewsLastMonth)),
      ),
    ];

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final crossAxis = constraints.maxWidth >= 700 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxis,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: crossAxis == 4 ? 1.7 : 1.15,
          ),
          itemBuilder: (_, i) => _KpiCard(data: items[i]),
        );
      },
    );
  }

  int _growthSafe(int v) => v;

  // ── QUICK ACTION BANNERS ──
  Widget _buildQuickActions() {
    final isVerified = pendingCount == 0;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onVerify,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kAccentGreen.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _kAccentGreen.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kAccentGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_outlined,
                      color: _kAccentGreen,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Verifikasi Tempat',
                          style: TextStyle(
                            color: _kAccentGreen,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isVerified
                              ? 'Semua tempat telah diverifikasi'
                              : '$pendingCount tempat menunggu verifikasi',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kAccentGreen.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isVerified
                          ? Icons.check
                          : Icons.arrow_forward_ios_rounded,
                      color: _kAccentGreen,
                      size: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: onActivity,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _kAccentPurple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _kAccentPurple.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _kAccentPurple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: _kAccentPurple,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Aktivitas Admin',
                          style: TextStyle(
                            color: _kAccentPurple,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$todayActivityCount aktivitas hari ini',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kAccentPurple.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      color: _kAccentPurple,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── DONUT CHART: Category ──
  Widget _buildCategoryChart() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribusi Kategori',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          categoryCounts.isEmpty
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      'Belum ada data kategori.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                )
              : _CategoryDonutChart(data: categoryCounts),
        ],
      ),
    );
  }

  // ── LINE CHART: Submission Trend ──
  Widget _buildLineChart() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Tren Pendaftaran (14 hari)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1F1F1F),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _kBorderColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '14 Hari Terakhir',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Color(0xFF9CA3AF),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          dailySubmissions.every((v) => v == 0)
              ? const SizedBox(
                  height: 180,
                  child: Center(
                    child: Text(
                      'Belum ada data pendaftaran.',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  ),
                )
              : SizedBox(
                  height: 180,
                  child: _SubmissionLineChart(data: dailySubmissions),
                ),
        ],
      ),
    );
  }

  // ── RECENT ACTIVITY TABLE ──
  Widget _buildRecentActivity() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Aktivitas Terbaru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onActivity,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _kAccentBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _kAccentBlue.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(
                      color: _kAccentBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (recentActivities.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada aktivitas.',
                  style: TextStyle(color: Color(0xFF6B7280)),
                ),
              ),
            )
          else
            Column(
              children: recentActivities.take(5).toList().asMap().entries.map((
                entry,
              ) {
                final idx = entry.key;
                final a = entry.value;
                return _ActivityRow(
                  activity: a,
                  isLast: idx == recentActivities.take(5).length - 1,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// KPI CARD WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _KpiData {
  final IconData icon;
  final Color iconBg;
  final String label;
  final String value;
  final String growthText;
  final Color growthColor;

  const _KpiData({
    required this.icon,
    required this.iconBg,
    required this.label,
    required this.value,
    required this.growthText,
    required this.growthColor,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;
  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(width: 2, color: _kPrimary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: data.iconBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(data.icon, color: data.iconBg, size: 18),
              ),
              const Icon(Icons.more_vert, color: Colors.white24, size: 16),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            data.label,
            style: const TextStyle(
              color: Color(0xFF9CA3AF),
              fontSize: 10,
              fontWeight: FontWeight.w400,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            data.value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.growthText,
            style: TextStyle(
              color: data.growthColor,
              fontSize: 9,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DONUT CHART WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _CategoryDonutChart extends StatelessWidget {
  final Map<String, int> data;
  const _CategoryDonutChart({required this.data});

  Color _colorFor(String cat, int index) {
    final direct = PoiCategory.getCategoryColor(cat);
    const fallback = [
      Color(0xFF4CAF50),
      Color(0xFFFFA726),
      Color(0xFF42A5F5),
      Color(0xFFEF5350),
      Color(0xFFAB47BC),
      Color(0xFF26C6DA),
    ];
    return (direct == const Color(0xFF90A4AE))
        ? fallback[index % fallback.length]
        : direct;
  }

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold(0, (sum, e) => sum + e.value);

    final sections = entries.asMap().entries.map((e) {
      final color = _colorFor(e.value.key, e.key);
      // radius menyempit tiap segmen — persis pola di template (25, 22, 19, 16, 13...)
      final radius = (25.0 - (e.key * 3)).clamp(10.0, 25.0);
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        color: color,
        showTitle: false, // gaya template: tanpa label di slice
        radius: radius,
      );
    }).toList();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Donut — persis konfigurasi template (Stack + teks total di tengah)
        SizedBox(
          height: 180,
          width: 160,
          child: Stack(
            children: [
              PieChart(
                PieChartData(
                  sectionsSpace: 0,
                  centerSpaceRadius: 55,
                  startDegreeOffset: -90,
                  sections: sections,
                ),
              ),
              Positioned.fill(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$total',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        height: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'total tempat',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Legend
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: entries.asMap().entries.map((e) {
              final color = _colorFor(e.value.key, e.key);
              final pct = total > 0
                  ? ((e.value.value / total) * 100).round()
                  : 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        e.value.key,
                        style: const TextStyle(
                          color: Color(0xFFD1D5DB),
                          fontSize: 12,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${e.value.value} ($pct%)',
                      style: const TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// LINE CHART WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _SubmissionLineChart extends StatelessWidget {
  final List<int> data;
  const _SubmissionLineChart({required this.data});

  String _dayLabel(int daysAgo) {
    if (daysAgo == 0) return 'Hari ini';
    if (daysAgo == 1) return 'Kemarin';
    return '-$daysAgo hr';
  }

  @override
  Widget build(BuildContext context) {
    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();

    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: _kAccentGreen,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, a, b) => FlDotCirclePainter(
                radius: 3,
                color: _kAccentGreen,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  _kAccentGreen.withValues(alpha: 0.25),
                  _kAccentGreen.withValues(alpha: 0.0),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx % 3 != 0 && idx != 13) return const SizedBox.shrink();
                final daysAgo = 13 - idx;
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _dayLabel(daysAgo),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280)),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: _kBorderColor, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final daysAgo = 13 - s.spotIndex;
              return LineTooltipItem(
                '${_dayLabel(daysAgo)}: ${s.y.toInt()}',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ACTIVITY ROW WIDGET
// ═══════════════════════════════════════════════════════════════════════════════

class _ActivityRow extends StatelessWidget {
  final Map<String, dynamic> activity;
  final bool isLast;

  const _ActivityRow({required this.activity, required this.isLast});

  String _timeAgo(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit yang lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam yang lalu';
    return '${diff.inDays} hari yang lalu';
  }

  @override
  Widget build(BuildContext context) {
    final status = activity['verification_status'] as String? ?? 'pending';
    final name = activity['nama_tempat'] as String? ?? 'Unknown';
    final createdAt = activity['created_at'] as String?;
    final timeAgo = _timeAgo(createdAt);

    IconData icon;
    Color iconColor;
    String actionLabel;
    Color badgeColor;
    String badgeText;

    switch (status) {
      case 'verified':
        icon = Icons.verified_outlined;
        iconColor = _kAccentGreen;
        actionLabel = 'Verifikasi tempat';
        badgeColor = _kAccentGreen;
        badgeText = 'Berhasil';
        break;
      case 'rejected':
        icon = Icons.cancel_outlined;
        iconColor = const Color(0xFFEF4444);
        actionLabel = 'Tolak tempat';
        badgeColor = const Color(0xFFEF4444);
        badgeText = 'Ditolak';
        break;
      default:
        icon = Icons.access_time_outlined;
        iconColor = _kAccentAmber;
        actionLabel = 'Tempat baru';
        badgeColor = _kAccentAmber;
        badgeText = 'Pending';
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Icon
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 15),
              ),
              const SizedBox(width: 8),
              // Action label
              Flexible(
                flex: 3,
                child: Text(
                  actionLabel,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              // Name
              Flexible(
                flex: 3,
                child: Text(
                  name,
                  style: const TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: 6),
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // Time
              Flexible(
                flex: 3,
                child: Text(
                  timeAgo,
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (!isLast) Divider(color: _kBorderColor, height: 1),
      ],
    );
  }
}

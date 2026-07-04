import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_category.dart';
import '../user/settings_screen.dart';
import 'verify_place_screen.dart';
import 'admin_map_screen.dart';
import 'admin_activity_screen.dart';
import 'manage_users_screen.dart';

/// Provider khusus admin — selalu dark mode, tidak terpengaruh toggle user.
final adminThemeProvider = ThemeProvider(forceDarkMode: true);

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
  double _avgRating = 0;
  int _totalReviews = 0;
  int _featuredCount = 0;

  Map<String, int> _categoryCounts = const {};
  List<int> _dailySubmissions = []; // 14 entries

  @override
  void initState() {
    super.initState();
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

      final results = await Future.wait([
        _client.from('places').select('id, category, is_featured'),
        _client.from('profiles').select('id'),
        _client
            .from('places')
            .select('id')
            .eq('verification_status', 'pending'),
        _client.from('reviews').select('rating'),
        _client
            .from('places')
            .select('created_at')
            .gte('created_at', fourteenDaysAgo.toIso8601String())
            .order('created_at', ascending: true),
      ]).timeout(const Duration(seconds: 15));

      final placeList = results[0] as List;
      final userList = results[1] as List;
      final pendingList = results[2] as List;
      final reviewList = results[3] as List;
      final submissionsRaw = results[4] as List;

      // Summary
      _totalPlaces = placeList.length;
      _totalUsers = userList.length;
      _pendingCount = pendingList.length;
      _totalReviews = reviewList.length;

      double ratingSum = 0;
      for (final r in reviewList) {
        final rating = r['rating'];
        if (rating is num) ratingSum += rating.toDouble();
      }
      _avgRating = _totalReviews == 0 ? 0 : ratingSum / _totalReviews;

      var featured = 0;
      for (final item in placeList) {
        if (item['is_featured'] == true) featured++;
      }
      _featuredCount = featured;

      // Category distribution
      final catCounts = <String, int>{};
      for (final item in placeList) {
        final cat = item['category']?.toString().trim();
        final key = cat == null || cat.isEmpty ? 'Tanpa kategori' : cat;
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
        avgRating: _avgRating,
        totalReviews: _totalReviews,
        featuredCount: _featuredCount,
        categoryCounts: _categoryCounts,
        dailySubmissions: _dailySubmissions,
        onRetry: _loadDashboard,
        onVerify: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VerifyPlaceScreen()),
        ),
        onActivity: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminActivityScreen()),
        ),
      ),
      const AdminMapScreen(),
      const ManageUsersScreen(),
      const SettingsScreen(),
    ];

    return ChangeNotifierProvider<ThemeProvider>.value(
      value: adminThemeProvider,
      child: Consumer<ThemeProvider>(
        builder: (ctx, t, _) => Scaffold(
          backgroundColor: t.bgBase,
          body: IndexedStack(index: _tabIndex, children: pages),
          bottomNavigationBar: Container(
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
                    _navItem(t, 3, Icons.settings_outlined, 'Settings'),
                  ],
                ),
              ),
            ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 22,
              color: active ? theme.textPrimary : theme.textSecondary,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? theme.textPrimary : theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DASHBOARD PAGE (Home + Analytics gabungan)
// ═══════════════════════════════════════════════════════════════════════════════

class _DashboardPage extends StatelessWidget {
  final ThemeProvider theme;
  final bool isLoading;
  final String? error;
  final int totalPlaces;
  final int totalUsers;
  final int pendingCount;
  final double avgRating;
  final int totalReviews;
  final int featuredCount;
  final Map<String, int> categoryCounts;
  final List<int> dailySubmissions;
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
    required this.avgRating,
    required this.totalReviews,
    required this.featuredCount,
    required this.categoryCounts,
    required this.dailySubmissions,
    required this.onRetry,
    required this.onVerify,
    required this.onActivity,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => onRetry(),
        color: theme.iconColor,
        backgroundColor: theme.bgSurface,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── TOP HEADER ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Admin Dashboard',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: theme.textPrimary,
                          ),
                        ),
                        Text(
                          'Ringkasan & Analitik Aplikasi',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: onActivity,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.bgElevated,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.notifications_outlined,
                          color: theme.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 20)),

            // ── BODY ──
            if (isLoading)
              SliverFillRemaining(
                child: Center(
                  child: CircularProgressIndicator(color: theme.iconColor),
                ),
              )
            else if (error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 48,
                          color: theme.textHint,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat data.',
                          style: TextStyle(color: theme.textSecondary),
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
                ),
              )
            else ...[
              // ── KPI STAT CARDS ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _kpiGrid(context),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── QUICK ACTIONS ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _quickActions(context),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 20)),

              // ── CATEGORY PIE CHART ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _sectionCard(
                    title: 'Distribusi Kategori',
                    child: categoryCounts.isEmpty
                        ? _emptyPlaceholder('Belum ada data kategori.')
                        : SizedBox(
                            height: 260,
                            child: _CategoryPieChart(
                              theme: theme,
                              data: categoryCounts,
                            ),
                          ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── SUBMISSION LINE CHART ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _sectionCard(
                    title: 'Tren Pendaftaran (14 hari)',
                    child: dailySubmissions.every((v) => v == 0)
                        ? _emptyPlaceholder('Belum ada UMKM baru.')
                        : SizedBox(
                            height: 220,
                            child: _SubmissionLineChart(
                              theme: theme,
                              data: dailySubmissions,
                            ),
                          ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ],
        ),
      ),
    );
  }

  // ── 6-cell KPI grid ──
  Widget _kpiGrid(BuildContext context) {
    final items = [
      _KpiItem(
        Icons.storefront_outlined,
        '$totalPlaces',
        'Total Tempat',
        theme.btnPrimary,
      ),
      _KpiItem(
        Icons.people_outline,
        '$totalUsers',
        'Total Users',
        const Color(0xFF8B5CF6),
      ),
      _KpiItem(
        Icons.pending_actions_outlined,
        '$pendingCount',
        'Menunggu',
        const Color(0xFFF59E0B),
      ),
      _KpiItem(
        Icons.star_border,
        avgRating.toStringAsFixed(1),
        'Avg Rating',
        const Color(0xFF10B981),
      ),
      _KpiItem(
        Icons.rate_review_outlined,
        '$totalReviews',
        'Ulasan',
        const Color(0xFF3B82F6),
      ),
      _KpiItem(
        Icons.bookmark_outlined,
        '$featuredCount',
        'Unggulan',
        const Color(0xFFEC4899),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (_, i) => _kpiCard(items[i]),
    );
  }

  Widget _kpiCard(_KpiItem item) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: item.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, color: item.color, size: 16),
          ),
          const Spacer(),
          Text(
            item.value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(fontSize: 10, color: theme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ── Quick Action Buttons ──
  Widget _quickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _actionBtn(
            icon: Icons.verified_outlined,
            label: 'Verifikasi\nTempat',
            color: const Color(0xFF10B981),
            onTap: onVerify,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _actionBtn(
            icon: Icons.notifications_outlined,
            label: 'Aktivitas\nAdmin',
            color: const Color(0xFF8B5CF6),
            onTap: onActivity,
          ),
        ),
      ],
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Section card wrapper ──
  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _emptyPlaceholder(String msg) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Text(msg, style: TextStyle(color: theme.textSecondary)),
      ),
    );
  }
}

class _KpiItem {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  const _KpiItem(this.icon, this.value, this.label, this.color);
}

// ── Pie Chart: Category Distribution ───────────────────────────────
class _CategoryPieChart extends StatelessWidget {
  final ThemeProvider theme;
  final Map<String, int> data;

  const _CategoryPieChart({required this.theme, required this.data});

  /// Warna menggunakan PoiCategory.getCategoryColor() sesuai dataset Kab. Cirebon
  Color _colorFor(String cat, int index) {
    // Coba match persis dulu
    final direct = PoiCategory.getCategoryColor(cat);
    // getCategoryColor return abu-abu default jika tidak ditemukan
    // fallback rainbow jika tetap default
    const fallback = [
      Color(0xFF4CAF50), Color(0xFFFFA726), Color(0xFF42A5F5),
      Color(0xFFEF5350), Color(0xFFAB47BC), Color(0xFF26C6DA),
      Color(0xFF8D6E63), Color(0xFFFF7043), Color(0xFF66BB6A),
    ];
    return (direct == const Color(0xFF90A4AE))
        ? fallback[index % fallback.length]
        : direct;
  }

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = entries.asMap().entries.map((e) {
      final color = _colorFor(e.value.key, e.key);
      return PieChartSectionData(
        value: e.value.value.toDouble(),
        color: color,
        radius: 50,
        title: '${e.value.value}',
        titleStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      );
    }).toList();

    final total = entries.fold(0, (sum, e) => sum + e.value);

    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: entries.asMap().entries.map((e) {
            final color = _colorFor(e.value.key, e.key);
            final pct = total > 0
                ? ((e.value.value / total) * 100).toStringAsFixed(0)
                : '0';
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  '${e.value.key} ($pct%)',
                  style: TextStyle(fontSize: 11, color: theme.textSecondary),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Line Chart: Submission Trend ───────────────────────────────────
class _SubmissionLineChart extends StatelessWidget {
  final ThemeProvider theme;
  final List<int> data;

  const _SubmissionLineChart({required this.theme, required this.data});

  String _dayLabel(int daysAgo) {
    if (daysAgo == 0) return 'Hr ini';
    if (daysAgo == 1) return 'Kemrn';
    if (daysAgo == 2) return '2 hr';
    return '$daysAgo hr';
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
            color: theme.btnPrimary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, a, b) => FlDotCirclePainter(
                radius: 3,
                color: theme.btnPrimary,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: theme.btnPrimary.withValues(alpha: 0.15),
            ),
          ),
        ],
        titlesData: FlTitlesData(
          show: true,
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
                    style: TextStyle(fontSize: 10, color: theme.textHint),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: theme.textHint),
                  ),
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
              FlLine(color: theme.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) {
              final daysAgo = 13 - s.spotIndex;
              return LineTooltipItem(
                '${_dayLabel(daysAgo)}: ${s.y.toInt()}',
                TextStyle(
                  color: theme.textPrimary,
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

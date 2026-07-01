import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../user/settings_screen.dart';
import 'admin_analytics_screen.dart';
import 'manage_users_screen.dart';
import 'manage_kategori_screen.dart';
import 'verify_place_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final _client = Supabase.instance.client;

  int _tabIndex = 0;

  bool _summaryLoading = true;
  String? _summaryError;

  int _totalPlaces = 0;
  int _totalUsers = 0;
  int _pendingCount = 0;
  double _avgRating = 0;

  bool _chartLoading = true;
  List<int> _dailySubmissions = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    await Future.wait([_loadSummary(), _loadMiniChart()]);
  }

  Future<void> _loadSummary() async {
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });
    try {
      final results = await Future.wait([
        _client.from('places').select('id'),
        _client.from('profiles').select('id'),
        _client
            .from('places')
            .select('id')
            .eq('verification_status', 'pending'),
        _client.from('reviews').select('rating'),
      ]);
      final places = results[0] as List;
      final users = results[1] as List;
      final pending = results[2] as List;
      final reviews = results[3] as List;

      double ratingSum = 0;
      for (final r in reviews) {
        final rating = r['rating'];
        if (rating is num) ratingSum += rating.toDouble();
      }

      if (!mounted) return;
      setState(() {
        _totalPlaces = places.length;
        _totalUsers = users.length;
        _pendingCount = pending.length;
        _avgRating = reviews.isEmpty ? 0 : ratingSum / reviews.length;
        _summaryLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _summaryError = e.toString();
        _summaryLoading = false;
      });
    }
  }

  Future<void> _loadMiniChart() async {
    try {
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 6));
      final raw = await _client
          .from('places')
          .select('created_at')
          .gte('created_at', sevenDaysAgo.toIso8601String())
          .order('created_at', ascending: true);

      final daily = <DateTime, int>{};
      for (final row in raw) {
        final dt = DateTime.tryParse(row['created_at'] as String? ?? '');
        if (dt == null) continue;
        final day = DateTime(dt.year, dt.month, dt.day);
        daily[day] = (daily[day] ?? 0) + 1;
      }

      final result = <int>[];
      for (int i = 6; i >= 0; i--) {
        final day = DateTime(now.year, now.month, now.day - i);
        result.add(daily[day] ?? 0);
      }

      if (!mounted) return;
      setState(() {
        _dailySubmissions = result;
        _chartLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _chartLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    final pages = <Widget>[
      _DashboardPage(
        theme: theme,
        summaryLoading: _summaryLoading,
        summaryError: _summaryError,
        totalPlaces: _totalPlaces,
        totalUsers: _totalUsers,
        pendingCount: _pendingCount,
        avgRating: _avgRating,
        chartLoading: _chartLoading,
        dailySubmissions: _dailySubmissions,
        onRetry: _loadDashboard,
        onAnalytics: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const AdminAnalyticsScreen()),
        ),
        onVerify: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const VerifyPlaceScreen()),
        ),
      ),
      const ManageUsersScreen(),
      const ManageKategoriScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: theme.bgBase,
      body: IndexedStack(
        index: _tabIndex,
        children: pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.bgSurface,
          border: Border(top: BorderSide(color: theme.border)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Theme(
              data: Theme.of(context).copyWith(
                splashColor: Colors.transparent,
                highlightColor: Colors.transparent,
              ),
              child: Row(
                children: [
                  _navItem(theme, 0, Icons.dashboard_rounded, 'Dashboard'),
                  _navItem(theme, 1, Icons.people_outline, 'User'),
                  _navItem(theme, 2, Icons.category_outlined, 'Kategori'),
                  _navItem(theme, 3, Icons.settings_outlined, 'Pengaturan'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(ThemeProvider theme, int idx, IconData icon, String label) {
    final active = _tabIndex == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: active ? theme.btnPrimary : theme.textHint,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: active ? theme.btnPrimary : theme.textHint,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: active ? 20 : 0,
                height: 3,
                decoration: BoxDecoration(
                  color: active ? theme.btnPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Dashboard Page (extracted from body) ──────────────────────────
class _DashboardPage extends StatelessWidget {
  final ThemeProvider theme;
  final bool summaryLoading;
  final String? summaryError;
  final int totalPlaces;
  final int totalUsers;
  final int pendingCount;
  final double avgRating;
  final bool chartLoading;
  final List<int> dailySubmissions;
  final VoidCallback onRetry;
  final VoidCallback onAnalytics;
  final VoidCallback onVerify;

  const _DashboardPage({
    required this.theme,
    required this.summaryLoading,
    this.summaryError,
    required this.totalPlaces,
    required this.totalUsers,
    required this.pendingCount,
    required this.avgRating,
    required this.chartLoading,
    required this.dailySubmissions,
    required this.onRetry,
    required this.onAnalytics,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 28),

            // ── HEADER ──
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: theme.bgElevated,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.border),
                  ),
                  child: Icon(
                    Icons.admin_panel_settings_outlined,
                    color: theme.textPrimary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dashboard',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    Text(
                      'Superadmin',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textSecondary,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── ANALYTICS SUMMARY ──
            if (summaryLoading)
              _buildSummaryShimmer(context, theme)
            else if (summaryError != null)
              _buildErrorRetry(theme)
            else
              _AnalyticsSummaryRow(
                theme: theme,
                totalPlaces: totalPlaces,
                totalUsers: totalUsers,
                pendingCount: pendingCount,
                avgRating: avgRating,
              ),

            const SizedBox(height: 20),

            // ── MINI CHART ──
            _MiniChartPreview(
              theme: theme,
              data: dailySubmissions,
              isLoading: chartLoading,
            ),

            const SizedBox(height: 24),

            // ── MENU ──
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

            _MenuGrid(
              theme: theme,
              pendingCount: pendingCount,
              onAnalytics: onAnalytics,
              onVerify: onVerify,
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryShimmer(BuildContext context, ThemeProvider theme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(
        4,
        (_) => Container(
          width: (MediaQuery.of(context).size.width - 50) / 2,
          height: 80,
          decoration: BoxDecoration(
            color: theme.bgElevated,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorRetry(ThemeProvider theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.snackErrorBorder),
      ),
      child: Column(
        children: [
          Icon(Icons.cloud_off_rounded, color: theme.textHint, size: 32),
          const SizedBox(height: 8),
          Text(
            'Gagal memuat data',
            style: TextStyle(color: theme.textSecondary),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Muat Ulang'),
          ),
        ],
      ),
    );
  }
}

// ── Analytics Summary Row ──────────────────────────────────────────
class _AnalyticsSummaryRow extends StatelessWidget {
  final ThemeProvider theme;
  final int totalPlaces;
  final int totalUsers;
  final int pendingCount;
  final double avgRating;

  const _AnalyticsSummaryRow({
    required this.theme,
    required this.totalPlaces,
    required this.totalUsers,
    required this.pendingCount,
    required this.avgRating,
  });

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 50) / 2;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _miniStat(w, Icons.storefront_outlined, '$totalPlaces', 'Total UMKM'),
        _miniStat(w, Icons.people_outline, '$totalUsers', 'Pengguna'),
        _miniStat(
          w,
          Icons.pending_actions_outlined,
          '$pendingCount',
          'Pending',
        ),
        _miniStat(
          w,
          Icons.star_border,
          avgRating.toStringAsFixed(1),
          'Rating',
        ),
      ],
    );
  }

  Widget _miniStat(double w, IconData icon, String value, String label) {
    return Container(
      width: w,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: theme.iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini Chart Preview ─────────────────────────────────────────────
class _MiniChartPreview extends StatelessWidget {
  final ThemeProvider theme;
  final List<int> data;
  final bool isLoading;

  const _MiniChartPreview({
    required this.theme,
    required this.data,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded,
                  size: 18, color: theme.iconColor),
              const SizedBox(width: 6),
              Text(
                'Tren Pendaftaran (7 hari)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 140,
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: theme.iconColor,
                    ),
                  )
                : data.every((v) => v == 0)
                    ? Center(
                        child: Text(
                          'Belum ada data',
                          style: TextStyle(color: theme.textSecondary),
                        ),
                      )
                    : BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: (data.reduce(
                                      (a, b) => a > b ? a : b) +
                                  1)
                              .toDouble(),
                          barTouchData: BarTouchData(
                            touchTooltipData: BarTouchTooltipData(
                              getTooltipItem: (group, _, rod, a) {
                                return BarTooltipItem(
                                  '${rod.toY.toInt()}',
                                  TextStyle(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              },
                            ),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 22,
                                getTitlesWidget: (value, meta) {
                                  final days = [
                                    'S', 'S', 'R', 'K', 'J', 'S', 'M'
                                  ]; // width too tight for full names
                                  final idx = value.toInt();
                                  if (idx < 0 || idx >= 7) {
                                    return const SizedBox.shrink();
                                  }
                                  // Reverse: idx 0 = today, 6 = 6 days ago
                                  final label =
                                      days[6 - idx];
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(top: 6),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.textHint,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 24,
                                getTitlesWidget:
                                    (value, meta) {
                                  if (value ==
                                      meta.max) {
                                    return const SizedBox
                                        .shrink();
                                  }
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(
                                            right: 4),
                                    child: Text(
                                      value.toInt().toString(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.textHint,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                            topTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false),
                            ),
                            rightTitles: AxisTitles(
                              sideTitles: SideTitles(
                                  showTitles: false),
                            ),
                          ),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: 1,
                            getDrawingHorizontalLine:
                                (value) => FlLine(
                              color: theme.border,
                              strokeWidth: 0.5,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: List.generate(
                            data.length,
                            (i) => BarChartGroupData(
                              x: i,
                              barRods: [
                                BarChartRodData(
                                  toY: data[i].toDouble(),
                                  color: theme.btnPrimary,
                                  width: 14,
                                  borderRadius:
                                      const BorderRadius.vertical(
                                    top: Radius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

// ── Menu Grid ──────────────────────────────────────────────────────
class _MenuGrid extends StatelessWidget {
  final ThemeProvider theme;
  final int pendingCount;
  final VoidCallback onAnalytics;
  final VoidCallback onVerify;

  const _MenuGrid({
    required this.theme,
    required this.pendingCount,
    required this.onAnalytics,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.of(context).size.width - 50) / 2;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _tile(
          w,
          Icons.analytics_outlined,
          'Analisis Aplikasi',
          'Statistik & grafik',
          onAnalytics,
          false,
        ),
        _tile(
          w,
          Icons.verified_user_outlined,
          'Verifikasi UMKM',
          pendingCount > 0
              ? '$pendingCount menunggu'
              : 'Setujui atau tolak',
          onVerify,
          false,
          badge: pendingCount,
        ),
      ],
    );
  }

  Widget _tile(
    double w,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
    bool isPrimary, {
    int badge = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: w,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.bgElevated,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: theme.textPrimary, size: 20),
                ),
                const Spacer(),
                if (badge > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.snackError,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge > 99 ? '99+' : '$badge',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

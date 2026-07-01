import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme_provider.dart';
import '../../core/user_role.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final _client = Supabase.instance.client;
  bool _isLoading = true;
  String? _error;

  // summary
  int _totalPlaces = 0;
  int _totalReviews = 0;
  double _avgRating = 0;
  int _featuredCount = 0;

  // charts
  Map<String, int> _roleCounts = const {};
  Map<String, int> _categoryCounts = const {};
  List<int> _dailySubmissions = []; // 14 entries

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final now = DateTime.now();
      final fourteenDaysAgo = now.subtract(const Duration(days: 13));

      final results = await Future.wait([
        _client.from('places').select('id, category, is_featured'),
        _client.from('reviews').select('rating'),
        _client.from('profiles').select('role'),
        _client
            .from('places')
            .select('created_at')
            .gte('created_at', fourteenDaysAgo.toIso8601String())
            .order('created_at', ascending: true),
      ]);

      final umkmList = results[0] as List;
      final reviewList = results[1] as List;
      final profileList = results[2] as List;
      final submissionsRaw = results[3] as List;

      // ── Summary ──
      _totalPlaces = umkmList.length;
      _totalReviews = reviewList.length;

      double ratingSum = 0;
      for (final r in reviewList) {
        final rating = r['rating'];
        if (rating is num) ratingSum += rating.toDouble();
      }
      _avgRating = _totalReviews == 0 ? 0 : ratingSum / _totalReviews;

      var featured = 0;
      for (final item in umkmList) {
        if (item['is_featured'] == true) featured++;
      }
      _featuredCount = featured;

      // ── Role Distribution ──
      final roleCounts = <String, int>{};
      for (final p in profileList) {
        final role = parseUserRole(p['role']);
        roleCounts[role.label] = (roleCounts[role.label] ?? 0) + 1;
      }
      _roleCounts = roleCounts;

      // ── Category Distribution ──
      final catCounts = <String, int>{};
      for (final item in umkmList) {
        final cat = item['category']?.toString().trim();
        final key = cat == null || cat.isEmpty ? 'Tanpa kategori' : cat;
        catCounts[key] = (catCounts[key] ?? 0) + 1;
      }
      _categoryCounts = catCounts;

      // ── Daily Submissions (14 days) ──
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
      setState(() {
        _isLoading = false;
      });
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
    final theme = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
        title: Text(
          'Analisis Aplikasi',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.iconColor))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.cloud_off_rounded,
                            size: 40, color: theme.textHint),
                        const SizedBox(height: 12),
                        Text(
                          'Gagal memuat analisis.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: theme.textSecondary, height: 1.5),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: _loadAnalytics,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Muat Ulang'),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadAnalytics,
                  color: theme.iconColor,
                  backgroundColor: theme.bgSurface,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // ── Stat Cards ──
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _statCard(
                            theme,
                            Icons.storefront_outlined,
                            '$_totalPlaces',
                            'Total UMKM',
                          ),
                          _statCard(
                            theme,
                            Icons.rate_review_outlined,
                            '$_totalReviews',
                            'Total Ulasan',
                          ),
                          _statCard(
                            theme,
                            Icons.star_border,
                            _avgRating.toStringAsFixed(1),
                            'Rata-rata Rating',
                          ),
                          _statCard(
                            theme,
                            Icons.bookmark_outlined,
                            '$_featuredCount',
                            'UMKM Unggulan',
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ── Role Pie Chart ──
                      _SectionCard(
                        theme: theme,
                        title: 'Distribusi Role',
                        child: _roleCounts.isEmpty
                            ? _emptyPlaceholder(theme, 'Belum ada data pengguna.')
                            : SizedBox(
                                height: 250,
                                child: _RolePieChart(
                                    theme: theme, data: _roleCounts),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // ── Category Bar Chart ──
                      _SectionCard(
                        theme: theme,
                        title: 'Distribusi Kategori UMKM',
                        child: _categoryCounts.isEmpty
                            ? _emptyPlaceholder(theme, 'Belum ada kategori.')
                            : SizedBox(
                                height: 280,
                                child: _CategoryBarChart(
                                    theme: theme, data: _categoryCounts),
                              ),
                      ),

                      const SizedBox(height: 16),

                      // ── Submissions Line Chart ──
                      _SectionCard(
                        theme: theme,
                        title: 'Tren Pendaftaran (14 hari)',
                        child: _dailySubmissions.every((v) => v == 0)
                            ? _emptyPlaceholder(
                                theme, 'Belum ada UMKM baru.')
                            : SizedBox(
                                height: 220,
                                child: _SubmissionLineChart(
                                    theme: theme, data: _dailySubmissions),
                              ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _emptyPlaceholder(ThemeProvider theme, String msg) {
    return SizedBox(
      height: 180,
      child: Center(
        child: Text(msg, style: TextStyle(color: theme.textSecondary)),
      ),
    );
  }

  Widget _statCard(
    ThemeProvider theme,
    IconData icon,
    String value,
    String label,
  ) {
    return SizedBox(
      width: 160,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.iconColor, size: 16),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Card Wrapper ───────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final ThemeProvider theme;
  final String title;
  final Widget child;

  const _SectionCard({
    required this.theme,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
}

// ── Pie Chart: Role Distribution ───────────────────────────────────
class _RolePieChart extends StatelessWidget {
  final ThemeProvider theme;
  final Map<String, int> data;

  const _RolePieChart({required this.theme, required this.data});

  static const _roleColors = [
    Color(0xFF4CAF50),
    Color(0xFFFFA726),
    Color(0xFF42A5F5),
    Color(0xFFEF5350),
    Color(0xFFAB47BC),
  ];

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = entries.asMap().entries.map((e) {
      final color = _roleColors[e.key % _roleColors.length];
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
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 36,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // Legend
        Wrap(
          spacing: 16,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: entries.asMap().entries.map((e) {
            final color = _roleColors[e.key % _roleColors.length];
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
                const SizedBox(width: 6),
                Text(
                  '${e.value.key} ($pct%)',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textSecondary,
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Bar Chart: Category Distribution ──────────────────────────────
class _CategoryBarChart extends StatelessWidget {
  final ThemeProvider theme;
  final Map<String, int> data;

  const _CategoryBarChart({required this.theme, required this.data});

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top5 = entries.take(5).toList().reversed.toList();

    if (top5.isEmpty) {
      return Center(
        child:
            Text('Belum ada kategori.', style: TextStyle(color: theme.textSecondary)),
      );
    }

    final maxVal = top5.fold(0, (max, e) => e.value > max ? e.value : max);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: (maxVal + 2).toDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, a) => BarTooltipItem(
              '${rod.toY.toInt()}',
              TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                if (value == meta.max) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(fontSize: 10, color: theme.textHint),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 100,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= top5.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    top5[idx].key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textPrimary,
                    ),
                  ),
                );
              },
            ),
          ),
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: theme.border, strokeWidth: 0.5),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(
          top5.length,
          (i) => BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: top5[i].value.toDouble(),
                color: theme.btnPrimary,
                width: 16,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Line Chart: Submission Trend ───────────────────────────────────
class _SubmissionLineChart extends StatelessWidget {
  final ThemeProvider theme;
  final List<int> data; // 14 entries, index 0 = today

  const _SubmissionLineChart({required this.theme, required this.data});

  String _dayLabel(int daysAgo) {
    if (daysAgo == 0) return 'Hr ini';
    if (daysAgo == 1) return 'Kemrn';
    if (daysAgo == 2) return '2 hr';
    return '$daysAgo hr';
  }

  @override
  Widget build(BuildContext context) {
    final spots = data.asMap().entries.map(
      (e) => FlSpot(e.key.toDouble(), e.value.toDouble()),
    ).toList();

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
                // Show every 3rd label to avoid crowding
                if (idx % 3 != 0 && idx != 13) {
                  return const SizedBox.shrink();
                }
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
          topTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              AxisTitles(sideTitles: SideTitles(showTitles: false)),
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

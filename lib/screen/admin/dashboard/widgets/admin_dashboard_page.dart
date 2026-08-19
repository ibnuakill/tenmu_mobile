import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'admin_design.dart';
import 'admin_shell.dart';

class DashboardPage extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final int totalPlaces;
  final int totalUsers;
  final int pendingCount;
  final int activeCount;
  final int totalReviews;
  final int reviewsThisMonth;
  final Map<String, int> categoryCounts;
  final List<int> dailySubmissions;
  final List<Map<String, dynamic>> recentActivities;
  final List<Map<String, dynamic>> topPlaces;
  final int todayActivityCount;
  final int placesLastMonth;
  final int usersLastMonth;
  final int reviewsLastMonth;
  final VoidCallback onRetry;
  final VoidCallback onVerify;
  final VoidCallback onActivity;

  const DashboardPage({
    super.key,
    required this.isLoading,
    required this.error,
    required this.totalPlaces,
    required this.totalUsers,
    required this.pendingCount,
    required this.activeCount,
    required this.totalReviews,
    required this.reviewsThisMonth,
    required this.categoryCounts,
    required this.dailySubmissions,
    required this.recentActivities,
    required this.topPlaces,
    required this.todayActivityCount,
    required this.placesLastMonth,
    required this.usersLastMonth,
    required this.reviewsLastMonth,
    required this.onRetry,
    required this.onVerify,
    required this.onActivity,
  });


  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const bulan = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];
    final dateStr = '1 ${bulan[now.month]} - ${now.day} ${bulan[now.month]}, ${now.year}';

    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async => onRetry(),
          color: kPrimary,
          backgroundColor: kCardBg,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── WELCOME BANNER ROW ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final isMobile = constraints.maxWidth < 600;
                      
                      if (isMobile) {
                        // ── MOBILE LAYOUT ──
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              'Dashboard Admin Tenmu',
                              style: GoogleFonts.poppins(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Date + Kelola UMKM + Akun (Row)
                            Row(
                              children: [
                                // Date range pill (shrink)
                                Expanded(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: kCardBg,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: kBorderColor),
                                      boxShadow: const [kShadow],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 12, color: kTextMuted),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            dateStr,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.plusJakartaSans(
                                              fontSize: 10, color: kTextPrimary, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Kelola UMKM compact
                                GestureDetector(
                                  onTap: onVerify,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: kCardBg,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(color: kBorderColor),
                                      boxShadow: const [kShadow],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.add_rounded, size: 14, color: kTextPrimary),
                                        const SizedBox(width: 4),
                                        Text('UMKM',
                                          style: GoogleFonts.plusJakartaSans(
                                            fontSize: 11, color: kTextPrimary, fontWeight: FontWeight.w700)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                
                                // Akun Menu
                                const AccountMenuButton(),
                              ],
                            ),
                          ],
                        );
                      } else {
                        // ── DESKTOP LAYOUT (original) ──
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Dashboard Admin Tenmu',
                                style: GoogleFonts.poppins(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ),
                            // Date range pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: kCardBg,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: kBorderColor),
                                boxShadow: const [kShadow],
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 13, color: kTextMuted),
                                  const SizedBox(width: 8),
                                  Text(dateStr,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12, color: kTextPrimary, fontWeight: FontWeight.w600)),
                                  const SizedBox(width: 4),
                                  const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kTextMuted),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Action pill button (+ Kelola UMKM)
                            GestureDetector(
                              onTap: onVerify,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  color: kCardBg,
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: kBorderColor),
                                  boxShadow: const [kShadow],
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_rounded, size: 16, color: kTextPrimary),
                                    const SizedBox(width: 6),
                                    Text('Kelola UMKM',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 12, color: kTextPrimary, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Akun Menu
                            const AccountMenuButton(),
                          ],
                        );
                      }
                    },
                  ),
                ),
              ),

              // ── MAIN DASHBOARD GRID CONTENT ──
              if (isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5)),
                )
              else if (error != null)
                SliverFillRemaining(
                  child: Center(
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Muat Ulang'),
                    ),
                  ),
                )
              else ...[
                // ── TOP ROW CARDS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        if (constraints.maxWidth >= 950) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Card (UMKM Summary Card)
                              SizedBox(
                                width: 290,
                                child: _buildEmeraldCardWidget(),
                              ),
                              const SizedBox(width: 16),
                              // Center Card (UMKM Growth Bar Chart)
                              Expanded(
                                flex: 3,
                                child: _buildEngagementBarChart(),
                              ),
                              const SizedBox(width: 16),
                              // Right Card (User Summary Line Chart)
                              SizedBox(
                                width: 280,
                                child: _buildTotalBalanceLineChart(),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildEmeraldCardWidget(),
                            const SizedBox(height: 16),
                            _buildEngagementBarChart(),
                            const SizedBox(height: 16),
                            _buildTotalBalanceLineChart(),
                          ],
                        );
                      },
                    ),
                  ),
                ),

                const SliverToBoxAdapter(child: SizedBox(height: 16)),

                // ── BOTTOM ROW CARDS ──
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        if (constraints.maxWidth >= 950) {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Bottom Left (Recent Activity Table)
                              Expanded(
                                flex: 6,
                                child: _buildRecentActivityTable(),
                              ),
                              const SizedBox(width: 16),
                              // Bottom Right (Top UMKM)
                              Expanded(
                                flex: 4,
                                child: _buildTopUmkmWidget(),
                              ),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            _buildRecentActivityTable(),
                            const SizedBox(height: 16),
                            _buildTopUmkmWidget(),
                          ],
                        );
                      },
                    ),
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

  Widget _arrowButton() {
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: kPageBg,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.north_east_rounded, size: 14, color: kTextSecondary),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // TOP ROW WIDGETS
  // ═════════════════════════════════════════════════════════════════════════════

  // 1. LEFT: Emerald Credit Card Card Widget
  Widget _buildEmeraldCardWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ringkasan UMKM', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
                  Text('Aktif dan menunggu approval', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted)),
                ],
              ),
              _arrowButton(),
            ],
          ),
          const SizedBox(height: 16),

          // ── DARK EMERALD HERO CARD (Persis Kartu VISA di Gambar) ──
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: kPrimary.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('TENMU', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1.5)),
                    const Icon(Icons.verified_user_rounded, color: Colors.white70, size: 20),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Total listing UMKM', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 12),
                Text(
                  '$totalPlaces Tempat',
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.5),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$activeCount aktif', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70)),
                    Text('$pendingCount pending', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w700)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Weekly Revenue Sub-box ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Review bulan ini', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted)),
                  const SizedBox(height: 2),
                  Text('$reviewsThisMonth Ulasan', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: kTextPrimary)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: kAccentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('$totalReviews total', style: GoogleFonts.plusJakartaSans(color: kAccentGreen, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. CENTER: UMKM Growth Chart Widget
  Widget _buildEngagementBarChart() {
    final bars = dailySubmissions.length >= 6
        ? dailySubmissions.sublist(dailySubmissions.length - 6)
        : dailySubmissions;
    final maxValue = bars.isEmpty
        ? 1
        : bars.reduce((value, element) => value > element ? value : element);
    final maxY = (maxValue + 1).toDouble().clamp(4, 12).toDouble();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (ctx, constraints) {
              final isNarrow = constraints.maxWidth < 420;
              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.subtitles_outlined, size: 18, color: kTextSecondary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Pertumbuhan UMKM',
                            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        _arrowButton(),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: kPageBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            child: Text('14 hari', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextSecondary)),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: kPrimary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text('Terbaru', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  const Icon(Icons.subtitles_outlined, size: 18, color: kTextSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pertumbuhan UMKM',
                      style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Toggle Monthly | Annually
                  Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: kPageBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text('14 hari', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextSecondary)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text('Terbaru', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _arrowButton(),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // ── BAR CHART (Pill Bars with April Solid Green Highlight) ──
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const months = ['H-5', 'H-4', 'H-3', 'H-2', 'H-1', 'H'];
                        final idx = value.toInt();
                        if (idx >= 0 && idx < months.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(months[idx], style: GoogleFonts.plusJakartaSans(fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w600)),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: List.generate(
                  bars.length,
                  (index) => _barGroup(
                    index,
                    bars[index].toDouble(),
                    isHighlighted: index == bars.length - 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _barGroup(int x, double y, {required bool isHighlighted}) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: isHighlighted ? kPrimary : const Color(0xFFA7F3D0).withValues(alpha: 0.7),
          width: 26,
          borderRadius: BorderRadius.circular(16),
        ),
      ],
    );
  }

  // 3. RIGHT: User Summary Line Chart Widget
  Widget _buildTotalBalanceLineChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Pengguna', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
                  Text('Akun pengguna aplikasi', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted)),
                ],
              ),
              _arrowButton(),
            ],
          ),
          const SizedBox(height: 16),

          Text('Terdaftar di Tenmu', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted)),
          const SizedBox(height: 2),
          Text(
            '$totalUsers Pengguna',
            style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.w800, color: kTextPrimary, letterSpacing: -0.5),
          ),
          const SizedBox(height: 14),

          // Wave Line Chart
          SizedBox(
            height: 90,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0, maxX: 6,
                minY: 0, maxY: 6,
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 2),
                      FlSpot(1, 3.5),
                      FlSpot(2, 2.8),
                      FlSpot(3, 4.5),
                      FlSpot(4, 3.2),
                      FlSpot(5, 5.0),
                      FlSpot(6, 4.2),
                    ],
                    isCurved: true,
                    color: kAccentGreen,
                    barWidth: 2.5,
                    dotData: FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [kAccentGreen.withValues(alpha: 0.25), kAccentGreen.withValues(alpha: 0.0)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Action buttons: Send ↑ & Receive ↓
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onVerify,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: kPrimary,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Kelola UMKM', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 4),
                        const Icon(Icons.storefront_rounded, color: Colors.white, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: onActivity,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: kPageBg,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Audit Log', style: GoogleFonts.plusJakartaSans(color: kTextPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        const Icon(Icons.timeline_rounded, color: kTextSecondary, size: 14),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════════
  // BOTTOM ROW WIDGETS
  // ═════════════════════════════════════════════════════════════════════════════

  // 4. BOTTOM LEFT: Recent Activity Table Widget
  Widget _buildRecentActivityTable() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aktivitas Terbaru', style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
                  Text('UMKM baru daftar dan status verifikasi', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted)),
                ],
              ),
              _arrowButton(),
            ],
          ),
          const SizedBox(height: 16),

          // Table Headers
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Nama UMKM', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Tanggal', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Jam', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Status', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600))),
                Expanded(flex: 2, child: Text('Kategori', textAlign: TextAlign.right, style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w600))),
              ],
            ),
          ),
          const Divider(color: kBorderColor, height: 1),

          // Table Rows
          if (recentActivities.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('Belum ada riwayat aktivitas.', style: GoogleFonts.plusJakartaSans(color: kTextMuted))),
            )
          else
            Column(
              children: recentActivities.take(5).map((a) {
                final name = a['nama_tempat'] as String? ?? 'Unknown';
                final status = a['verification_status'] as String? ?? 'pending';
                final cat = a['category'] as String? ?? 'UMKM';
                final createdAt = DateTime.tryParse(a['created_at'] as String? ?? '');

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      // Name column with brand circular avatar
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: kPrimary.withValues(alpha: 0.1),
                              child: Text(name.substring(0, 1).toUpperCase(), style: GoogleFonts.poppins(color: kPrimary, fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(name, overflow: TextOverflow.ellipsis, maxLines: 1, style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                            ),
                          ],
                        ),
                      ),
                      // Date
                      Expanded(
                        flex: 2,
                        child: Text(_formatDate(createdAt), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextSecondary)),
                      ),
                      // Time
                      Expanded(
                        flex: 2,
                        child: Text(_formatTime(createdAt), style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextSecondary)),
                      ),
                      // Status dot
                      Expanded(
                        flex: 2,
                        child: Row(
                          children: [
                            Container(
                              width: 6, height: 6,
                              decoration: BoxDecoration(
                                color: status == 'verified' ? kAccentGreen : kAccentAmber,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              status == 'verified' ? 'Aktif' : status == 'rejected' ? 'Ditolak' : 'Pending',
                              style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextPrimary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      // Amount / Detail
                      Expanded(
                        flex: 2,
                        child: Text(
                          cat,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // 5. BOTTOM RIGHT: Top UMKM Widget
  Widget _buildTopUmkmWidget() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UMKM Rating Tertinggi', style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
          Text('Berdasarkan view places_with_ratings', style: GoogleFonts.plusJakartaSans(fontSize: 11, color: kTextMuted)),
          const SizedBox(height: 12),

          Row(
            children: [
              Text(
                topPlaces.isEmpty
                    ? 'Belum ada rating'
                    : "${((topPlaces.first['avg_rating'] as num?)?.toDouble() ?? 0).toStringAsFixed(1)} ★",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: kTextPrimary),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kAccentGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('${topPlaces.length} UMKM', style: GoogleFonts.plusJakartaSans(color: kAccentGreen, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: kBorderColor, height: 1),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Paling Direkomendasikan', style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                  Text('Rating dan jumlah ulasan', style: GoogleFonts.plusJakartaSans(fontSize: 10, color: kTextMuted)),
                ],
              ),
              _arrowButton(),
            ],
          ),
          const SizedBox(height: 14),

          if (topPlaces.isEmpty)
            Text('Rating akan muncul setelah UMKM menerima review.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: kTextMuted))
          else
            Column(
              children: topPlaces.take(4).map((place) {
                final name = place['nama_tempat'] as String? ?? 'UMKM';
                final category = place['category'] as String? ?? 'Kategori';
                final rating = (place['avg_rating'] as num?)?.toDouble() ?? 0;
                final reviews = (place['review_count'] as num?)?.toInt() ?? 0;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: kAccentGreen.withValues(alpha: 0.12),
                        child: const Icon(Icons.star_rounded, size: 16, color: kAccentGreen),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary)),
                            Text(category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                    fontSize: 10, color: kTextMuted)),
                          ],
                        ),
                      ),
                      Text('${rating.toStringAsFixed(1)} ★',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary)),
                      const SizedBox(width: 6),
                      Text('($reviews)',
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 10, color: kTextMuted)),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    const months = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${value.day} ${months[value.month]} ${value.year}';
  }

  String _formatTime(DateTime? value) {
    if (value == null) return '-';
    final hour = value.hour.toString().padLeft(2, '0');
    final minute = value.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
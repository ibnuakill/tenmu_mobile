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
  Map<String, int> _roleCounts = const {};
  Map<String, int> _categoryCounts = const {};
  int _totalUmkm = 0;
  int _totalReviews = 0;
  int _featuredCount = 0;
  double _averageRating = 0;

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
      final umkmData = await _client
          .from('places')
          .select('id, category, is_featured');
      final reviewData = await _client.from('reviews').select('rating');
      final profileData = await _client.from('profiles').select('role');

      final umkmList = List<Map<String, dynamic>>.from(umkmData);
      final reviewList = List<Map<String, dynamic>>.from(reviewData);
      final profileList = List<Map<String, dynamic>>.from(profileData);

      final roleCounts = <String, int>{};
      for (final profile in profileList) {
        final role = parseUserRole(profile['role']);
        roleCounts[role.label] = (roleCounts[role.label] ?? 0) + 1;
      }

      final categoryCounts = <String, int>{};
      var featuredCount = 0;
      for (final item in umkmList) {
        final category = item['category']?.toString().trim();
        final normalized = category == null || category.isEmpty
            ? 'Tanpa kategori'
            : category;
        categoryCounts[normalized] = (categoryCounts[normalized] ?? 0) + 1;
        if (item['is_featured'] == true) {
          featuredCount++;
        }
      }

      var ratingSum = 0.0;
      for (final review in reviewList) {
        final rating = review['rating'];
        if (rating is num) {
          ratingSum += rating.toDouble();
        }
      }

      if (!mounted) return;
      setState(() {
        _roleCounts = roleCounts;
        _categoryCounts = categoryCounts;
        _totalUmkm = umkmList.length;
        _totalReviews = reviewList.length;
        _featuredCount = featuredCount;
        _averageRating = reviewList.isEmpty ? 0 : ratingSum / reviewList.length;
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
          'Analisis Superadmin',
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
                child: Text(
                  'Gagal memuat analisis.\n$_error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.textSecondary, height: 1.5),
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _statCard(theme, 'Total UMKM', '$_totalUmkm'),
                      _statCard(theme, 'Total Ulasan', '$_totalReviews'),
                      _statCard(
                        theme,
                        'Rata-rata Rating',
                        _averageRating.toStringAsFixed(1),
                      ),
                      _statCard(theme, 'UMKM Unggulan', '$_featuredCount'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _sectionCard(
                    theme: theme,
                    title: 'Distribusi Role',
                    child: _buildMapList(theme, _roleCounts),
                  ),
                  const SizedBox(height: 16),
                  _sectionCard(
                    theme: theme,
                    title: 'Distribusi Kategori UMKM',
                    child: _buildMapList(theme, _categoryCounts),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _statCard(ThemeProvider theme, String title, String value) {
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
            Text(
              value,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(color: theme.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard({
    required ThemeProvider theme,
    required String title,
    required Widget child,
  }) {
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
              fontSize: 16,
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

  Widget _buildMapList(ThemeProvider theme, Map<String, int> items) {
    if (items.isEmpty) {
      return Text(
        'Belum ada data.',
        style: TextStyle(color: theme.textSecondary),
      );
    }

    final entries = items.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      children: entries
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: TextStyle(color: theme.textPrimary),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: theme.bgElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.border),
                    ),
                    child: Text(
                      '${entry.value}',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

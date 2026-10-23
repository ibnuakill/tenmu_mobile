import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dashboard/widgets/admin_design.dart';

/// Admin → Review & Rating.
/// Menampilkan seluruh ulasan user terhadap UMKM, lengkap dengan statistik,
/// filter bintang, pencarian, dan aksi hapus (moderasi).
class ManageReviewScreen extends StatefulWidget {
  const ManageReviewScreen({super.key});

  @override
  State<ManageReviewScreen> createState() => _ManageReviewScreenState();
}

class _ManageReviewScreenState extends State<ManageReviewScreen> {
  final _client = Supabase.instance.client;
  final _searchCtrl = TextEditingController();

  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _reviews = [];
  Map<String, String> _placeNames = {};
  Map<String, String> _userNames = {};
  int? _ratingFilter;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        _client
            .from('reviews')
            .select('id, umkm_id, user_id, rating, komentar, created_at')
            .order('created_at', ascending: false)
            .limit(300),
        _client.from('places').select('id, nama_tempat'),
        _client.from('profiles').select('id, nama'),
      ]).timeout(const Duration(seconds: 15));

      final reviews = (res[0] as List).cast<Map<String, dynamic>>();
      final places = (res[1] as List).cast<Map<String, dynamic>>();
      final users = (res[2] as List).cast<Map<String, dynamic>>();

      final pMap = <String, String>{};
      for (final p in places) {
        pMap[p['id'].toString()] = (p['nama_tempat'] ?? '-').toString();
      }
      final uMap = <String, String>{};
      for (final u in users) {
        final nama = (u['nama'] ?? '').toString().trim();
        uMap[u['id'].toString()] = nama.isEmpty ? 'Pengguna' : nama;
      }

      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _placeNames = pMap;
        _userNames = uMap;
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

  Future<void> _deleteReview(Map<String, dynamic> review) async {
    final konfirmasi = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Hapus ulasan?',
          style: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Ulasan dari "${_userNames[review['user_id']?.toString()] ?? 'Pengguna'}" '
          'untuk "${_placeNames[review['umkm_id']?.toString()] ?? '-'}" akan dihapus permanen.',
          style: const TextStyle(fontFamily: 'Nunito', fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(fontFamily: 'Nunito', color: kTextMuted),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Hapus',
              style: TextStyle(
                fontFamily: 'Nunito',
                color: kAccentRed,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (konfirmasi != true) return;

    try {
      await _client.from('reviews').delete().eq('id', review['id']);
      if (!mounted) return;
      _snack('Ulasan dihapus.', false);
      await _load();
    } catch (e) {
      if (!mounted) return;
      _snack('Gagal menghapus: $e', true);
    }
  }

  void _snack(String msg, bool isError) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontFamily: 'Nunito')),
        backgroundColor: isError ? kAccentRed : kAccentGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<Map<String, dynamic>> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _reviews.where((r) {
      if (_ratingFilter != null &&
          (r['rating'] as num?)?.toInt() != _ratingFilter) {
        return false;
      }
      if (q.isEmpty) return true;
      final place = (_placeNames[r['umkm_id']?.toString()] ?? '').toLowerCase();
      final user = (_userNames[r['user_id']?.toString()] ?? '').toLowerCase();
      final komentar = (r['komentar'] ?? '').toString().toLowerCase();
      return place.contains(q) || user.contains(q) || komentar.contains(q);
    }).toList();
  }

  double get _avgRating {
    if (_reviews.isEmpty) return 0;
    final total = _reviews.fold<int>(
      0,
      (sum, r) => sum + ((r['rating'] as num?)?.toInt() ?? 0),
    );
    return total / _reviews.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(),
              const SizedBox(height: 16),
              _statsRow(),
              const SizedBox(height: 16),
              _filterBar(),
              const SizedBox(height: 12),
              Expanded(child: _body()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Review & Rating',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Moderasi ulasan user terhadap UMKM',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                color: kTextMuted,
              ),
            ),
          ],
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: kAccentGreen.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${_reviews.length} ulasan',
            style: const TextStyle(
              fontFamily: 'Nunito',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kAccentGreen,
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: _isLoading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, size: 20),
          color: kTextMuted,
        ),
      ],
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        _statCard(
          'Total ulasan',
          '${_reviews.length}',
          Icons.rate_review_rounded,
        ),
        const SizedBox(width: 12),
        _statCard(
          'Rata-rata rating',
          _reviews.isEmpty ? '-' : _avgRating.toStringAsFixed(1),
          Icons.star_rounded,
        ),
        const SizedBox(width: 12),
        _statCard(
          'UMKM dinilai',
          '${_reviews.map((r) => r['umkm_id']).toSet().length}',
          Icons.storefront_rounded,
        ),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [kShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kAccentGreen.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: kAccentGreen),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 11,
                      color: kTextMuted,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterBar() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: kBorderColor),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, size: 18, color: kTextMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 13,
                      color: kTextPrimary,
                    ),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'Cari UMKM, user, atau komentar…',
                      hintStyle: TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _chip('Semua', null),
        const SizedBox(width: 6),
        for (final r in [5, 4, 3, 2, 1]) ...[
          _chip('$r', r),
          const SizedBox(width: 6),
        ],
      ],
    );
  }

  Widget _chip(String label, int? rating) {
    final active = _ratingFilter == rating;
    return GestureDetector(
      onTap: () => setState(() => _ratingFilter = rating),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? kPrimary : kCardBg,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: active ? kPrimary : kBorderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rating != null) ...[
              Icon(
                Icons.star_rounded,
                size: 13,
                color: active ? Colors.white : kAccentAmber,
              ),
              const SizedBox(width: 3),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: active ? Colors.white : kTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gagal memuat ulasan',
              style: TextStyle(
                fontFamily: 'Nunito',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 11,
                color: kTextMuted,
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
              child: const Text(
                'Muat Ulang',
                style: TextStyle(fontFamily: 'Nunito', color: Colors.white),
              ),
            ),
          ],
        ),
      );
    }

    final items = _filtered;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.rate_review_outlined, size: 44, color: kTextMuted),
            const SizedBox(height: 10),
            Text(
              _reviews.isEmpty
                  ? 'Belum ada ulasan dari user.'
                  : 'Tidak ada ulasan yang cocok dengan filter.',
              style: const TextStyle(
                fontFamily: 'Nunito',
                fontSize: 13,
                color: kTextMuted,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 12),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _reviewCard(items[i]),
    );
  }

  Widget _reviewCard(Map<String, dynamic> review) {
    final userName = _userNames[review['user_id']?.toString()] ?? 'Pengguna';
    final placeName = _placeNames[review['umkm_id']?.toString()] ?? 'UMKM';
    final rating = (review['rating'] as num?)?.toInt() ?? 0;
    final komentar = (review['komentar'] ?? '').toString().trim();
    final tanggal = _formatTanggal(review['created_at']);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [kShadow],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 17,
                backgroundColor: kPageBg,
                child: Text(
                  userName.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Nunito',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$placeName · $tanggal',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Nunito',
                        fontSize: 11,
                        color: kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Row(
                children: [
                  for (int i = 1; i <= 5; i++)
                    Icon(
                      i <= rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 15,
                      color: i <= rating ? kAccentAmber : kBorderColor,
                    ),
                ],
              ),
              IconButton(
                tooltip: 'Hapus ulasan',
                onPressed: () => _deleteReview(review),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                color: kAccentRed,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if (komentar.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kPageBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                komentar,
                style: const TextStyle(
                  fontFamily: 'Nunito',
                  fontSize: 12.5,
                  height: 1.45,
                  color: kTextSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTanggal(dynamic raw) {
    final dt = DateTime.tryParse(raw?.toString() ?? '');
    if (dt == null) return '-';
    const bulan = [
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
    final jam = dt.hour.toString().padLeft(2, '0');
    final menit = dt.minute.toString().padLeft(2, '0');
    return '${dt.day} ${bulan[dt.month - 1]} ${dt.year} · $jam:$menit';
  }
}

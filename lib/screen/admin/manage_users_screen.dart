import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/app_colors.dart';

/// Screen Admin: Kelola User & Hapus Review yang tidak pantas.
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  // ── Data ──────────────────────────────────────────────────
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingUsers = true;
  bool _loadingReviews = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
    _loadReviews();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ── Load semua user dari auth.users (via service role function atau tabel publik) ──
  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      // Mengambil dari tabel profiles atau reviews untuk mendapatkan user_id unik
      // Supabase auth.users tidak bisa diakses langsung dari client, 
      // jadi kita ambil user_id unik dari tabel reviews
      final data = await _client
          .from('reviews')
          .select('user_id, created_at')
          .order('created_at', ascending: false);

      // Kumpulkan unique user_id
      final Map<String, Map<String, dynamic>> uniqueUsers = {};
      for (final row in List<Map<String, dynamic>>.from(data)) {
        final uid = row['user_id'] as String;
        if (!uniqueUsers.containsKey(uid)) {
          uniqueUsers[uid] = row;
        }
      }

      setState(() {
        _users = uniqueUsers.values.toList();
        _loadingUsers = false;
      });
    } catch (_) {
      setState(() => _loadingUsers = false);
    }
  }

  // ── Load semua review ──────────────────────────────────────
  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    try {
      final data = await _client
          .from('reviews')
          .select()
          .order('created_at', ascending: false);
      setState(() {
        _reviews = List<Map<String, dynamic>>.from(data);
        _loadingReviews = false;
      });
    } catch (_) {
      setState(() => _loadingReviews = false);
    }
  }

  // ── Hapus satu review ──────────────────────────────────────
  Future<void> _deleteReview(Map<String, dynamic> review) async {
    final confirm = await _showConfirmDialog(
      title: 'Hapus Ulasan?',
      content:
          'Ulasan dengan rating ${review['rating']} bintang ini akan dihapus secara permanen.',
    );
    if (confirm == true && mounted) {
      try {
        await _client.from('reviews').delete().eq('id', review['id']);
        await _loadReviews();
        _snack('Ulasan berhasil dihapus.', isError: false);
      } catch (e) {
        _snack('Gagal menghapus: $e', isError: true);
      }
    }
  }

  // ── Hapus SEMUA review milik satu user ─────────────────────
  Future<void> _deleteAllReviewsByUser(String userId) async {
    final confirm = await _showConfirmDialog(
      title: 'Hapus Semua Ulasan User?',
      content:
          'Semua ulasan dari user ini akan dihapus. Tindakan ini tidak bisa dibatalkan.',
    );
    if (confirm == true && mounted) {
      try {
        await _client.from('reviews').delete().eq('user_id', userId);
        await _loadReviews();
        await _loadUsers();
        _snack('Semua ulasan user berhasil dihapus.', isError: false);
      } catch (e) {
        _snack('Gagal: $e', isError: true);
      }
    }
  }

  Future<bool?> _showConfirmDialog({
    required String title,
    required String content,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          content,
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  void _snack(String msg, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: isError ? AppColors.snackError : AppColors.snackSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError
                ? AppColors.snackErrorBorder
                : AppColors.snackSuccessBorder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: AppColors.textPrimary,
              size: 16,
            ),
          ),
        ),
        title: const Text(
          'Kelola User & Ulasan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.textPrimary,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textHint,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: const [
            Tab(text: 'Semua Ulasan'),
            Tab(text: 'Per User'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _AllReviewsTab(
            reviews: _reviews,
            isLoading: _loadingReviews,
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onDelete: _deleteReview,
            onRefresh: _loadReviews,
          ),
          _UserListTab(
            users: _users,
            reviews: _reviews,
            isLoading: _loadingUsers,
            onDeleteAll: _deleteAllReviewsByUser,
            onRefresh: () async {
              await _loadUsers();
              await _loadReviews();
            },
          ),
        ],
      ),
    );
  }
}

// ── Tab 1: Semua Ulasan ─────────────────────────────────────────────────────
class _AllReviewsTab extends StatelessWidget {
  final List<Map<String, dynamic>> reviews;
  final bool isLoading;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final Future<void> Function(Map<String, dynamic>) onDelete;
  final Future<void> Function() onRefresh;

  const _AllReviewsTab({
    required this.reviews,
    required this.isLoading,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onDelete,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = searchQuery.isEmpty
        ? reviews
        : reviews.where((r) {
            final komentar = (r['komentar'] ?? '').toLowerCase();
            final uid = (r['user_id'] ?? '').toLowerCase();
            return komentar.contains(searchQuery.toLowerCase()) ||
                uid.contains(searchQuery.toLowerCase());
          }).toList();

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.iconColor,
      backgroundColor: AppColors.bgSurface,
      child: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: TextField(
                onChanged: onSearchChanged,
                style: const TextStyle(color: AppColors.textPrimary),
                cursorColor: AppColors.borderFocus,
                decoration: const InputDecoration(
                  hintText: 'Cari komentar atau user ID...',
                  hintStyle: TextStyle(color: AppColors.textHint, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search,
                    color: AppColors.iconColor,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                Text(
                  '${filtered.length} ulasan',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textHint,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.iconColor,
                    ),
                  )
                : filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada ulasan.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(color: AppColors.border),
                    itemBuilder: (context, i) {
                      final review = filtered[i];
                      return _AdminReviewTile(
                        review: review,
                        onDelete: () => onDelete(review),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Tab 2: Per User ─────────────────────────────────────────────────────────
class _UserListTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> reviews;
  final bool isLoading;
  final Future<void> Function(String userId) onDeleteAll;
  final Future<void> Function() onRefresh;

  const _UserListTab({
    required this.users,
    required this.reviews,
    required this.isLoading,
    required this.onDeleteAll,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.iconColor,
      backgroundColor: AppColors.bgSurface,
      child: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.iconColor),
            )
          : users.isEmpty
          ? const Center(
              child: Text(
                'Belum ada user yang memberikan ulasan.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, _) =>
                  const Divider(color: AppColors.border),
              itemBuilder: (context, i) {
                final user = users[i];
                final userId = user['user_id'] as String;
                final userReviews =
                    reviews.where((r) => r['user_id'] == userId).toList();

                return _UserTile(
                  userId: userId,
                  reviewCount: userReviews.length,
                  reviews: userReviews,
                  onDeleteAll: () => onDeleteAll(userId),
                );
              },
            ),
    );
  }
}

// ── Tile: Satu review di tab Admin ─────────────────────────────────────────
class _AdminReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onDelete;

  const _AdminReviewTile({required this.review, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final rating = review['rating'] as int;
    final komentar = review['komentar'] as String?;
    final userId = review['user_id'] as String;
    final shortId = userId.length > 8 ? '${userId.substring(0, 8)}...' : userId;
    final createdAt = review['created_at'] != null
        ? DateTime.tryParse(review['created_at'])
        : null;
    final dateStr = createdAt != null
        ? '${createdAt.day}/${createdAt.month}/${createdAt.year}'
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Center(
              child: Text(
                '$rating★',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: rating >= 4
                      ? const Color(0xFFFFB800)
                      : rating >= 3
                      ? AppColors.textSecondary
                      : const Color(0xFF8B2020),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'User: $shortId',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ],
                ),
                if (komentar != null && komentar.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    komentar,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ] else
                  const Text(
                    'Tidak ada komentar.',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Tombol hapus
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8B0000).withValues(alpha: 0.3),
                ),
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 16,
                color: Color(0xFF8B2020),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tile: Satu user di tab Per User ─────────────────────────────────────────
class _UserTile extends StatelessWidget {
  final String userId;
  final int reviewCount;
  final List<Map<String, dynamic>> reviews;
  final VoidCallback onDeleteAll;

  const _UserTile({
    required this.userId,
    required this.reviewCount,
    required this.reviews,
    required this.onDeleteAll,
  });

  @override
  Widget build(BuildContext context) {
    final shortId =
        userId.length > 12 ? '${userId.substring(0, 12)}...' : userId;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 8, bottom: 8),
      iconColor: AppColors.iconColor,
      collapsedIconColor: AppColors.iconColor,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: const Center(
          child: Icon(
            Icons.person_outline,
            size: 20,
            color: AppColors.iconColor,
          ),
        ),
      ),
      title: Text(
        shortId,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textPrimary,
          fontFamily: 'monospace',
        ),
      ),
      subtitle: Text(
        '$reviewCount ulasan',
        style: const TextStyle(fontSize: 11, color: AppColors.textHint),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: onDeleteAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF8B0000).withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Hapus Semua',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8B2020),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      children: reviews
          .map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.bgElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['rating']}★ — UMKM ID: ${r['umkm_id']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (r['komentar'] != null && r['komentar'] != '') ...[
                      const SizedBox(height: 4),
                      Text(
                        r['komentar'],
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

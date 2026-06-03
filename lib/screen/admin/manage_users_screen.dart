import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme_provider.dart';
import '../../core/user_role.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

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

  Future<void> _loadUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final data = await _client
          .from('profiles')
          .select('id, role, full_name, nama')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _loadingUsers = false;
      });
    } catch (_) {
      setState(() => _loadingUsers = false);
    }
  }

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

  Future<void> _updateUserRole(String userId, UserRole role) async {
    try {
      await _client.from('profiles').update({'role': role.value}).eq('id', userId);
      await _loadUsers();
      _snack('Role berhasil diubah ke ${role.label}.', isError: false);
    } catch (e) {
      _snack('Gagal mengubah role: $e', isError: true);
    }
  }

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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: theme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          content,
          style: TextStyle(color: theme.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
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
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: isError ? theme.snackError : theme.snackSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? theme.snackErrorBorder : theme.snackSuccessBorder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.border),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              color: theme.textPrimary,
              size: 16,
            ),
          ),
        ),
        title: Text(
          'Kelola User & Ulasan',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.textPrimary,
          labelColor: theme.textPrimary,
          unselectedLabelColor: theme.textHint,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Semua Ulasan'),
            Tab(text: 'Role User'),
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
            onRoleChanged: _updateUserRole,
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
    final theme = Provider.of<ThemeProvider>(context);
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
      color: theme.iconColor,
      backgroundColor: theme.bgSurface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border),
              ),
              child: TextField(
                onChanged: onSearchChanged,
                style: TextStyle(color: theme.textPrimary),
                cursorColor: theme.borderFocus,
                decoration: InputDecoration(
                  hintText: 'Cari komentar atau user ID...',
                  hintStyle: TextStyle(color: theme.textHint, fontSize: 13),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.iconColor,
                    size: 18,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
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
                  style: TextStyle(fontSize: 12, color: theme.textHint),
                ),
              ],
            ),
          ),
          Expanded(
            child: isLoading
                ? Center(
                    child: CircularProgressIndicator(color: theme.iconColor),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada ulasan.',
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => Divider(color: theme.border),
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

class _UserListTab extends StatelessWidget {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> reviews;
  final bool isLoading;
  final Future<void> Function(String userId) onDeleteAll;
  final Future<void> Function(String userId, UserRole role) onRoleChanged;
  final Future<void> Function() onRefresh;

  const _UserListTab({
    required this.users,
    required this.reviews,
    required this.isLoading,
    required this.onDeleteAll,
    required this.onRoleChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: theme.iconColor,
      backgroundColor: theme.bgSurface,
      child: isLoading
          ? Center(child: CircularProgressIndicator(color: theme.iconColor))
          : users.isEmpty
          ? Center(
              child: Text(
                'Belum ada data user di tabel profiles.',
                style: TextStyle(color: theme.textSecondary),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: users.length,
              separatorBuilder: (_, _) => Divider(color: theme.border),
              itemBuilder: (context, i) {
                final user = users[i];
                final userId = user['id'] as String;
                final userReviews = reviews
                    .where((r) => r['user_id'] == userId)
                    .toList();

                return _UserTile(
                  userId: userId,
                  name:
                      user['full_name']?.toString() ??
                      user['nama']?.toString() ??
                      'Tanpa nama',
                  role: parseUserRole(user['role']),
                  reviewCount: userReviews.length,
                  reviews: userReviews,
                  onDeleteAll: () => onDeleteAll(userId),
                  onRoleChanged: (role) => onRoleChanged(userId, role),
                );
              },
            ),
    );
  }
}

class _AdminReviewTile extends StatelessWidget {
  final Map<String, dynamic> review;
  final VoidCallback onDelete;

  const _AdminReviewTile({required this.review, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
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
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.border),
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
                      ? theme.textSecondary
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
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textHint,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const Spacer(),
                    Text(
                      dateStr,
                      style: TextStyle(fontSize: 11, color: theme.textHint),
                    ),
                  ],
                ),
                if (komentar != null && komentar.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    komentar,
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ] else
                  Text(
                    'Tidak ada komentar.',
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.textHint,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
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

class _UserTile extends StatelessWidget {
  final String userId;
  final String name;
  final UserRole role;
  final int reviewCount;
  final List<Map<String, dynamic>> reviews;
  final VoidCallback onDeleteAll;
  final ValueChanged<UserRole> onRoleChanged;

  const _UserTile({
    required this.userId,
    required this.name,
    required this.role,
    required this.reviewCount,
    required this.reviews,
    required this.onDeleteAll,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final shortId = userId.length > 12 ? '${userId.substring(0, 12)}...' : userId;

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(left: 8, right: 8, bottom: 8),
      iconColor: theme.iconColor,
      collapsedIconColor: theme.iconColor,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.bgElevated,
          shape: BoxShape.circle,
          border: Border.all(color: theme.border),
        ),
        child: Center(
          child: Icon(Icons.person_outline, size: 20, color: theme.iconColor),
        ),
      ),
      title: Text(
        name,
        style: TextStyle(
          fontSize: 13,
          color: theme.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        '$reviewCount ulasan • $shortId',
        style: TextStyle(fontSize: 11, color: theme.textHint),
      ),
      trailing: const Icon(Icons.expand_more),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.bgElevated,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Role Akun',
                style: TextStyle(
                  color: theme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<UserRole>(
                initialValue: role,
                dropdownColor: theme.bgSurface,
                style: TextStyle(color: theme.textPrimary),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.bgSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: theme.border),
                  ),
                ),
                items: UserRole.values
                    .map(
                      (item) => DropdownMenuItem<UserRole>(
                        value: item,
                        child: Text(item.label),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null && value != role) {
                    onRoleChanged(value);
                  }
                },
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: onDeleteAll,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF8B0000).withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Text(
                      'Hapus Semua Ulasan User Ini',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8B2020),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ...reviews.map(
          (r) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${r['rating']}★ - UMKM ID: ${r['umkm_id']}',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (r['komentar'] != null && r['komentar'] != '') ...[
                    const SizedBox(height: 4),
                    Text(
                      r['komentar'],
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

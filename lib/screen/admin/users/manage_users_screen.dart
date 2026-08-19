import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme_provider.dart';
import '../../../core/user_role.dart';

import 'widgets/manage_users_widgets.dart';

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
          .select('id, role, nama, status')
          .order('id', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
        _loadingUsers = false;
      });
    } catch (e) {
      debugPrint('Load users error: $e');
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

  Future<void> _toggleBanUser(String userId, String currentName, bool isBanned) async {
    final action = isBanned ? 'Aktifkan' : 'Nonaktifkan';
    final confirm = await _showConfirmDialog(
      title: '$action User?',
      content: isBanned
          ? 'User "$currentName" akan bisa login kembali.'
          : 'User "$currentName" tidak bisa login sampai diaktifkan kembali.',
    );
    if (confirm == true && mounted) {
      try {
        await _client
            .from('profiles')
            .update({'status': isBanned ? 'active' : 'banned'})
            .eq('id', userId);
        await _loadUsers();
        _snack('User $currentName $action.', isError: false);
      } catch (e) {
        _snack('Gagal: $e', isError: true);
      }
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
    return Scaffold(
      backgroundColor: kPageBg,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Kelola User & Ulasan',
          style: GoogleFonts.poppins(
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kPrimary,
          indicatorWeight: 3,
          labelColor: kPrimary,
          unselectedLabelColor: kTextMuted,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w500, fontSize: 13),
          tabs: const [
            Tab(text: 'Daftar User'),
            Tab(text: 'Semua Ulasan'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          UserListTab(
            users: _users,
            reviews: _reviews,
            isLoading: _loadingUsers,
            onDeleteAll: _deleteAllReviewsByUser,
            onRoleChanged: _updateUserRole,
            onToggleBan: _toggleBanUser,
            onRefresh: () async {
              await _loadUsers();
              await _loadReviews();
            },
          ),
          AllReviewsTab(
            reviews: _reviews,
            isLoading: _loadingReviews,
            searchQuery: _searchQuery,
            onSearchChanged: (v) => setState(() => _searchQuery = v),
            onDelete: _deleteReview,
            onRefresh: _loadReviews,
          ),
        ],
      ),
    );
  }
}
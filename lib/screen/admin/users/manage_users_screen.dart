import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme_provider.dart';
import '../../../core/user_role.dart';
import '../../../core/admin_api.dart';

import 'widgets/manage_users_widgets.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _loadingUsers = true;
  bool _loadingReviews = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
    _loadReviews();
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
      await AdminApi.call('set_role', {'user_id': userId, 'role': role.value});
      await _loadUsers();
      _snack('Role berhasil diubah ke ${role.label}.', isError: false);
    } on AdminApiException catch (e) {
      _snack('Gagal mengubah role: ${e.message}', isError: true);
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
        await AdminApi.call('set_status', {
          'user_id': userId,
          'status': isBanned ? 'active' : 'banned',
        });
        await _loadUsers();
        _snack('User $currentName $action.', isError: false);
      } on AdminApiException catch (e) {
        _snack('Gagal: ${e.message}', isError: true);
      } catch (e) {
        _snack('Gagal: $e', isError: true);
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
        await AdminApi.call('reviews_delete_by_user', {'user_id': userId});
        await _loadReviews();
        _snack('Semua ulasan user berhasil dihapus.', isError: false);
      } on AdminApiException catch (e) {
        _snack('Gagal: ${e.message}', isError: true);
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
          'Manajemen User',
          style: TextStyle(
            fontFamily: 'Nunito',
            color: kTextPrimary,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
      ),
      body: UserListTab(
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
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme_provider.dart';

class ManageRoleRequestsScreen extends StatefulWidget {
  const ManageRoleRequestsScreen({super.key});

  @override
  State<ManageRoleRequestsScreen> createState() =>
      _ManageRoleRequestsScreenState();
}

class _ManageRoleRequestsScreenState extends State<ManageRoleRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _approvedRequests = [];
  List<Map<String, dynamic>> _rejectedRequests = [];

  bool _loadingPending = true;
  bool _loadingApproved = true;
  bool _loadingRejected = true;

  String? _pendingError;
  String? _approvedError;
  String? _rejectedError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadPending(), _loadApproved(), _loadRejected()]);
  }

  Future<void> _loadPending() async {
    setState(() {
      _loadingPending = true;
      _pendingError = null;
    });
    try {
      final data = await _client
          .from('profiles')
          .select(
            'id, nama, requested_role, request_message, request_status, request_created_at',
          )
          .eq('request_status', 'pending')
          .order('request_created_at', ascending: true);

      setState(() {
        _pendingRequests = List<Map<String, dynamic>>.from(data);
        _loadingPending = false;
      });
    } catch (e) {
      setState(() {
        _loadingPending = false;
        _pendingError = e.toString();
      });
    }
  }

  Future<void> _loadApproved() async {
    setState(() {
      _loadingApproved = true;
      _approvedError = null;
    });
    try {
      final data = await _client
          .from('profiles')
          .select('id, nama, role, request_status, request_handled_at')
          .eq('request_status', 'approved')
          .eq('role', 'owner')
          .order('request_handled_at', ascending: false);

      setState(() {
        _approvedRequests = List<Map<String, dynamic>>.from(data);
        _loadingApproved = false;
      });
    } catch (e) {
      setState(() {
        _loadingApproved = false;
        _approvedError = e.toString();
      });
    }
  }

  Future<void> _loadRejected() async {
    setState(() {
      _loadingRejected = true;
      _rejectedError = null;
    });
    try {
      final data = await _client
          .from('profiles')
          .select(
            'id, nama, requested_role, request_message, request_status, request_handled_at',
          )
          .eq('request_status', 'rejected')
          .order('request_handled_at', ascending: false);

      setState(() {
        _rejectedRequests = List<Map<String, dynamic>>.from(data);
        _loadingRejected = false;
      });
    } catch (e) {
      setState(() {
        _loadingRejected = false;
        _rejectedError = e.toString();
      });
    }
  }

  Future<void> _approve(String userId) async {
    final adminId = _client.auth.currentUser?.id;
    try {
      await _client
          .from('profiles')
          .update({
            'role': 'owner',
            'request_status': 'approved',
            'request_handled_by': adminId,
            'request_handled_at': DateTime.now().toIso8601String(),
            'requested_role': null,
            'request_message': null,
          })
          .eq('id', userId);
      await _loadAll();
      _snack('Permintaan disetujui.', isError: false);
    } catch (e) {
      _snack('Gagal approve: $e', isError: true);
    }
  }

  Future<void> _reject(String userId, String reason) async {
    final adminId = _client.auth.currentUser?.id;
    try {
      await _client
          .from('profiles')
          .update({
            'request_status': 'rejected',
            'request_handled_by': adminId,
            'request_handled_at': DateTime.now().toIso8601String(),
            'request_message': reason,
          })
          .eq('id', userId);
      await _loadAll();
      _snack('Permintaan ditolak.', isError: false);
    } catch (e) {
      _snack('Gagal reject: $e', isError: true);
    }
  }

  void _showRejectDialog(String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Alasan penolakan'),
        content: TextField(controller: reasonController, maxLines: 4),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(context);
              _reject(userId, reason);
            },
            child: const Text('Tolak'),
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Permintaan Role'),
        backgroundColor: theme.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.textPrimary,
          labelColor: theme.textPrimary,
          unselectedLabelColor: theme.textHint,
          tabs: [
            Tab(text: 'Pending (${_pendingRequests.length})'),
            Tab(text: 'Disetujui (${_approvedRequests.length})'),
            Tab(text: 'Ditolak (${_rejectedRequests.length})'),
          ],
        ),
      ),
      backgroundColor: theme.bgBase,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPendingTab(theme),
          _buildApprovedTab(theme),
          _buildRejectedTab(theme),
        ],
      ),
    );
  }

  Widget _buildPendingTab(ThemeProvider theme) {
    if (_loadingPending) {
      return Center(child: CircularProgressIndicator(color: theme.iconColor));
    }
    if (_pendingError != null) {
      return _errorView(
        theme: theme,
        message: _pendingError!,
        onRetry: _loadPending,
      );
    }
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Text(
          'Tidak ada permintaan pending.',
          style: TextStyle(color: theme.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPending,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _pendingRequests.length,
        itemBuilder: (context, i) {
          final r = _pendingRequests[i];
          final created = r['request_created_at'] != null
              ? DateTime.tryParse(r['request_created_at'])
              : null;
          final userId = r['id']?.toString() ?? '';
          final shortId = userId.length > 8 ? '${userId.substring(0, 8)}...' : userId;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: theme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: ListTile(
              title: Text(
                r['nama'] ?? 'User $shortId',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (r['request_message'] != null &&
                      (r['request_message'] as String).isNotEmpty)
                    Text(
                      r['request_message'],
                      style: TextStyle(color: theme.textSecondary),
                    ),
                  if (created != null)
                    Text(
                      'Diajukan: ${created.day}/${created.month}/${created.year}',
                      style: TextStyle(color: theme.textHint, fontSize: 12),
                    ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton(
                    onPressed: () => _showRejectDialog(r['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8B0000),
                    ),
                    child: const Text('Tolak'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _approve(r['id']),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28A745),
                    ),
                    child: const Text('Setujui'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildApprovedTab(ThemeProvider theme) {
    if (_loadingApproved) {
      return Center(child: CircularProgressIndicator(color: theme.iconColor));
    }
    if (_approvedError != null) {
      return _errorView(
        theme: theme,
        message: _approvedError!,
        onRetry: _loadApproved,
      );
    }
    if (_approvedRequests.isEmpty) {
      return Center(
        child: Text(
          'Belum ada owner yang disetujui.',
          style: TextStyle(color: theme.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadApproved,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _approvedRequests.length,
        itemBuilder: (context, i) {
          final r = _approvedRequests[i];
          final userId = r['id']?.toString() ?? '';
          final shortId = userId.length > 8 ? '${userId.substring(0, 8)}...' : userId;
          final handledAt = r['request_handled_at'] != null
              ? DateTime.tryParse(r['request_handled_at'])
              : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['nama'] ?? 'User $shortId',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Role saat ini: owner',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                if (handledAt != null)
                  Text(
                    'Disetujui: ${handledAt.day}/${handledAt.month}/${handledAt.year}',
                    style: TextStyle(color: theme.textHint, fontSize: 12),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRejectedTab(ThemeProvider theme) {
    if (_loadingRejected) {
      return Center(child: CircularProgressIndicator(color: theme.iconColor));
    }
    if (_rejectedError != null) {
      return _errorView(
        theme: theme,
        message: _rejectedError!,
        onRetry: _loadRejected,
      );
    }
    if (_rejectedRequests.isEmpty) {
      return Center(
        child: Text(
          'Belum ada permintaan yang ditolak.',
          style: TextStyle(color: theme.textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRejected,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _rejectedRequests.length,
        itemBuilder: (context, i) {
          final r = _rejectedRequests[i];
          final userId = r['id']?.toString() ?? '';
          final shortId = userId.length > 8 ? '${userId.substring(0, 8)}...' : userId;
          final handledAt = r['request_handled_at'] != null
              ? DateTime.tryParse(r['request_handled_at'])
              : null;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.bgSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  r['nama'] ?? 'User $shortId',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Alasan: ${r['request_message'] ?? '-'}',
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                if (handledAt != null)
                  Text(
                    'Ditolak: ${handledAt.day}/${handledAt.month}/${handledAt.year}',
                    style: TextStyle(color: theme.textHint, fontSize: 12),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _errorView({
    required ThemeProvider theme,
    required String message,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 30),
            const SizedBox(height: 12),
            Text(
              message.replaceFirst('Exception: ', ''),
              style: TextStyle(color: theme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            ElevatedButton(onPressed: onRetry, child: const Text('Coba Lagi')),
          ],
        ),
      ),
    );
  }
}

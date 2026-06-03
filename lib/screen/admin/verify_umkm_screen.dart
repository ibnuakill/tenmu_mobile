import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/umkm_image_helper.dart';

class VerifyUmkmScreen extends StatefulWidget {
  const VerifyUmkmScreen({super.key});

  @override
  State<VerifyUmkmScreen> createState() => _VerifyUmkmScreenState();
}

class _VerifyUmkmScreenState extends State<VerifyUmkmScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingUmkm = [];
  List<Map<String, dynamic>> _verifiedUmkm = [];
  List<Map<String, dynamic>> _rejectedUmkm = [];

  bool _loadingPending = true;
  bool _loadingVerified = true;
  bool _loadingRejected = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadUmkm();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUmkm() async {
    await Future.wait([_loadPending(), _loadVerified(), _loadRejected()]);
  }

  Future<void> _loadPending() async {
    setState(() => _loadingPending = true);
    try {
      final data = await _client
          .from('umkm')
          .select('*, owner_id(*)')
          .eq('verification_status', 'pending')
          .order('created_at', ascending: true);

      setState(() {
        _pendingUmkm = List<Map<String, dynamic>>.from(data);
        _loadingPending = false;
      });
    } catch (_) {
      setState(() => _loadingPending = false);
    }
  }

  Future<void> _loadVerified() async {
    setState(() => _loadingVerified = true);
    try {
      final data = await _client
          .from('umkm')
          .select('*, owner_id(*)')
          .eq('verification_status', 'verified')
          .order('verified_at', ascending: false)
          .limit(50);

      setState(() {
        _verifiedUmkm = List<Map<String, dynamic>>.from(data);
        _loadingVerified = false;
      });
    } catch (_) {
      setState(() => _loadingVerified = false);
    }
  }

  Future<void> _loadRejected() async {
    setState(() => _loadingRejected = true);
    try {
      final data = await _client
          .from('umkm')
          .select('*, owner_id(*)')
          .eq('verification_status', 'rejected')
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _rejectedUmkm = List<Map<String, dynamic>>.from(data);
        _loadingRejected = false;
      });
    } catch (_) {
      setState(() => _loadingRejected = false);
    }
  }

  Future<void> _approveUmkm(Map<String, dynamic> umkm) async {
    final userId = _client.auth.currentUser?.id;
    try {
      await _client
          .from('umkm')
          .update({
            'verification_status': 'verified',
            'verified_by': userId,
            'verified_at': DateTime.now().toIso8601String(),
            'rejection_reason': null,
          })
          .eq('id', umkm['id']);

      await _loadUmkm();
      _snack('UMKM berhasil diverifikasi!', isError: false);
    } catch (e) {
      _snack('Gagal: $e', isError: true);
    }
  }

  Future<void> _rejectUmkm(Map<String, dynamic> umkm, String reason) async {
    if (reason.trim().isEmpty) {
      _snack('Alasan penolakan tidak boleh kosong.', isError: true);
      return;
    }

    try {
      await _client
          .from('umkm')
          .update({
            'verification_status': 'rejected',
            'rejection_reason': reason.trim(),
            'verified_by': _client.auth.currentUser?.id,
          })
          .eq('id', umkm['id']);

      await _loadUmkm();
      _snack('UMKM ditolak.', isError: false);
    } catch (e) {
      _snack('Gagal: $e', isError: true);
    }
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
          'Verifikasi UMKM',
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
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
          ),
          tabs: [
            Tab(text: 'Pending (${_pendingUmkm.length})'),
            Tab(text: 'Verified (${_verifiedUmkm.length})'),
            Tab(text: 'Rejected (${_rejectedUmkm.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingTab(
            umkmList: _pendingUmkm,
            isLoading: _loadingPending,
            onApprove: _approveUmkm,
            onReject: _rejectUmkm,
            onRefresh: _loadPending,
          ),
          _VerifiedTab(
            umkmList: _verifiedUmkm,
            isLoading: _loadingVerified,
            onRefresh: _loadVerified,
          ),
          _RejectedTab(
            umkmList: _rejectedUmkm,
            isLoading: _loadingRejected,
            onRefresh: _loadRejected,
          ),
        ],
      ),
    );
  }
}

// ── Tab Pending ──────────────────────────────────────────────
class _PendingTab extends StatelessWidget {
  final List<Map<String, dynamic>> umkmList;
  final bool isLoading;
  final Future<void> Function(Map<String, dynamic>) onApprove;
  final Future<void> Function(Map<String, dynamic>, String) onReject;
  final Future<void> Function() onRefresh;

  const _PendingTab({
    required this.umkmList,
    required this.isLoading,
    required this.onApprove,
    required this.onReject,
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
          : umkmList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 56,
                    color: theme.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Tidak ada UMKM menunggu verifikasi.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: umkmList.length,
              itemBuilder: (context, index) {
                final umkm = umkmList[index];
                return _UmkmCard(
                  umkm: umkm,
                  theme: theme,
                  onApprove: () => onApprove(umkm),
                  onReject: () => _showRejectDialog(context, theme, umkm),
                );
              },
            ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    ThemeProvider theme,
    Map<String, dynamic> umkm,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tolak UMKM',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Alasan penolakan:',
              style: TextStyle(color: theme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              style: TextStyle(color: theme.textPrimary),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Jelaskan alasan penolakan...',
                hintStyle: TextStyle(color: theme.textHint),
                fillColor: theme.bgElevated,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: theme.border),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal', style: TextStyle(color: theme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              onReject(umkm, reasonController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B0000),
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
  }
}

// ── Tab Verified ─────────────────────────────────────────────
class _VerifiedTab extends StatelessWidget {
  final List<Map<String, dynamic>> umkmList;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _VerifiedTab({
    required this.umkmList,
    required this.isLoading,
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
          : umkmList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_outlined,
                    size: 56,
                    color: theme.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada UMKM yang diverifikasi.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: umkmList.length,
              itemBuilder: (context, index) {
                final umkm = umkmList[index];
                final imageUrl = UmkmImageHelper.primaryImageUrl(umkm);
                final verifiedAt = umkm['verified_at'] != null
                    ? DateTime.tryParse(umkm['verified_at'])
                    : null;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: theme.bgElevated,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: theme.textHint,
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: theme.bgElevated,
                              child: Icon(
                                Icons.storefront_outlined,
                                color: theme.iconColor,
                              ),
                            ),
                    ),
                    title: Text(
                      umkm['nama_tempat'] ?? 'Tanpa Nama',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          umkm['alamat'] ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (verifiedAt != null)
                          Text(
                            'Verified: ${verifiedAt.day}/${verifiedAt.month}/${verifiedAt.year}',
                            style: TextStyle(
                              color: const Color(0xFF28A745),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.verified_rounded,
                      color: const Color(0xFF28A745),
                      size: 24,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Tab Rejected ─────────────────────────────────────────────
class _RejectedTab extends StatelessWidget {
  final List<Map<String, dynamic>> umkmList;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _RejectedTab({
    required this.umkmList,
    required this.isLoading,
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
          : umkmList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined, size: 56, color: theme.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada UMKM yang ditolak.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: umkmList.length,
              itemBuilder: (context, index) {
                final umkm = umkmList[index];
                final imageUrl = UmkmImageHelper.primaryImageUrl(umkm);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: theme.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                width: 50,
                                height: 50,
                                color: theme.bgElevated,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: theme.textHint,
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              color: theme.bgElevated,
                              child: Icon(
                                Icons.storefront_outlined,
                                color: theme.iconColor,
                              ),
                            ),
                    ),
                    title: Text(
                      umkm['nama_tempat'] ?? 'Tanpa Nama',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          umkm['alamat'] ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (umkm['rejection_reason'] != null)
                          Text(
                            'Alasan: ${umkm['rejection_reason']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF8B2020),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    trailing: Icon(
                      Icons.block,
                      color: const Color(0xFF8B2020),
                      size: 24,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── UMKM Card untuk Pending Tab ──────────────────────────────
class _UmkmCard extends StatelessWidget {
  final Map<String, dynamic> umkm;
  final ThemeProvider theme;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _UmkmCard({
    required this.umkm,
    required this.theme,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = UmkmImageHelper.primaryImageUrl(umkm);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        children: [
          // ── Image ────────────────────────────────────────────
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: imageUrl != null
                ? Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: double.infinity,
                      height: 160,
                      color: theme.bgElevated,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: theme.textHint,
                        size: 40,
                      ),
                    ),
                  )
                : Container(
                    width: double.infinity,
                    height: 160,
                    color: theme.bgElevated,
                    child: Icon(
                      Icons.storefront_outlined,
                      color: theme.iconColor,
                      size: 40,
                    ),
                  ),
          ),

          // ── Content ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  umkm['nama_tempat'] ?? 'Tanpa Nama',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  umkm['alamat'] ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                if (umkm['deskripsi'] != null &&
                    umkm['deskripsi']!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    umkm['deskripsi'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: theme.textHint, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: const Text('Tolak'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(
                            0xFF8B0000,
                          ).withValues(alpha: 0.1),
                          foregroundColor: const Color(0xFF8B2020),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: const BorderSide(color: Color(0xFF8B2020)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onApprove,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Setujui'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

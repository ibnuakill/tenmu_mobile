import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_image_helper.dart';
import '../../core/notification_service.dart';
import '../owner/edit_place_screen.dart';

class VerifyPlaceScreen extends StatefulWidget {
  const VerifyPlaceScreen({super.key});

  @override
  State<VerifyPlaceScreen> createState() => _VerifyPlaceScreenState();
}

class _VerifyPlaceScreenState extends State<VerifyPlaceScreen>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingPlaces = [];
  List<Map<String, dynamic>> _verifiedPlaces = [];
  List<Map<String, dynamic>> _rejectedPlaces = [];

  bool _loadingPending = true;
  bool _loadingVerified = true;
  bool _loadingRejected = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPlaces();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    await Future.wait([_loadPending(), _loadVerified(), _loadRejected()]);
  }

  Future<void> _loadPending() async {
    setState(() => _loadingPending = true);
    try {
      final data = await _client
          .from('places')
          .select('*, owner_id(*)')
          .eq('verification_status', 'pending')
          .order('created_at', ascending: true);

      setState(() {
        _pendingPlaces = List<Map<String, dynamic>>.from(data);
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
          .from('places')
          .select('*, owner_id(*)')
          .eq('verification_status', 'verified')
          .order('verified_at', ascending: false)
          .limit(50);

      setState(() {
        _verifiedPlaces = List<Map<String, dynamic>>.from(data);
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
          .from('places')
          .select('*, owner_id(*)')
          .eq('verification_status', 'rejected')
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _rejectedPlaces = List<Map<String, dynamic>>.from(data);
        _loadingRejected = false;
      });
    } catch (_) {
      setState(() => _loadingRejected = false);
    }
  }

  Future<void> _approvePlace(Map<String, dynamic> place) async {
    final userId = _client.auth.currentUser?.id;
    try {
      await _client
          .from('places')
          .update({
            'verification_status': 'verified',
            'verified_by': userId,
            'verified_at': DateTime.now().toIso8601String(),
            'rejection_reason': null,
          })
          .eq('id', place['id']);

      await _loadPlaces();
      _snack('Tempat berhasil diverifikasi!', isError: false);

      // Kirim push notification ke semua user via OneSignal
      NotificationService.sendNewPlaceNotification(
        placeId: place['id'],
        placeName: place['nama_tempat'] ?? 'Tempat baru',
      );
    } catch (e) {
      _snack('Gagal: $e', isError: true);
    }
  }

  Future<void> _rejectPlace(Map<String, dynamic> place, String reason) async {
    if (reason.trim().isEmpty) {
      _snack('Alasan penolakan tidak boleh kosong.', isError: true);
      return;
    }

    try {
      await _client
          .from('places')
          .update({
            'verification_status': 'rejected',
            'rejection_reason': reason.trim(),
            'verified_by': _client.auth.currentUser?.id,
          })
          .eq('id', place['id']);

      await _loadPlaces();
      _snack('Tempat ditolak.', isError: false);
    } catch (e) {
      _snack('Gagal: $e', isError: true);
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> place) async {
    final currentFeatured = place['is_featured'] == true;
    final newFeatured = !currentFeatured;
    // Optimistic update lokal
    setState(() {
      final idx = _verifiedPlaces.indexWhere((p) => p['id'] == place['id']);
      if (idx != -1) {
        _verifiedPlaces[idx] = Map<String, dynamic>.from(_verifiedPlaces[idx])
          ..['is_featured'] = newFeatured;
      }
    });
    try {
      await _client
          .from('places')
          .update({'is_featured': newFeatured})
          .eq('id', place['id']);
      _snack(
        newFeatured ? '⭐ Ditambahkan ke unggulan!' : 'Dihapus dari unggulan.',
        isError: false,
      );
    } catch (e) {
      // Rollback jika gagal
      setState(() {
        final idx = _verifiedPlaces.indexWhere((p) => p['id'] == place['id']);
        if (idx != -1) {
          _verifiedPlaces[idx] = Map<String, dynamic>.from(_verifiedPlaces[idx])
            ..['is_featured'] = currentFeatured;
        }
      });
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
            Tab(text: 'Pending (${_pendingPlaces.length})'),
            Tab(text: 'Verified (${_verifiedPlaces.length})'),
            Tab(text: 'Rejected (${_rejectedPlaces.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingTab(
            placesList: _pendingPlaces,
            isLoading: _loadingPending,
            onApprove: _approvePlace,
            onReject: _rejectPlace,
            onRefresh: _loadPending,
          ),
          _VerifiedTab(
            placesList: _verifiedPlaces,
            isLoading: _loadingVerified,
            onRefresh: _loadVerified,
            onToggleFeatured: _toggleFeatured,
          ),
          _RejectedTab(
            placesList: _rejectedPlaces,
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
  final List<Map<String, dynamic>> placesList;
  final bool isLoading;
  final Future<void> Function(Map<String, dynamic>) onApprove;
  final Future<void> Function(Map<String, dynamic>, String) onReject;
  final Future<void> Function() onRefresh;

  const _PendingTab({
    required this.placesList,
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
          : placesList.isEmpty
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
                    'Tidak ada tempat menunggu verifikasi.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: placesList.length,
              itemBuilder: (context, index) {
                final place = placesList[index];
                return _PlaceCard(
                  place: place,
                  theme: theme,
                  onApprove: () => onApprove(place),
                  onReject: () => _showRejectDialog(context, theme, place),
                );
              },
            ),
    );
  }

  void _showRejectDialog(
    BuildContext context,
    ThemeProvider theme,
    Map<String, dynamic> place,
  ) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Tolak Tempat',
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
              onReject(place, reasonController.text);
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
class _VerifiedTab extends StatefulWidget {
  final List<Map<String, dynamic>> placesList;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function(Map<String, dynamic>) onToggleFeatured;

  const _VerifiedTab({
    required this.placesList,
    required this.isLoading,
    required this.onRefresh,
    required this.onToggleFeatured,
  });

  @override
  State<_VerifiedTab> createState() => _VerifiedTabState();
}

class _VerifiedTabState extends State<_VerifiedTab> {
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: theme.iconColor,
      backgroundColor: theme.bgSurface,
      child: widget.isLoading
          ? Center(child: CircularProgressIndicator(color: theme.iconColor))
          : widget.placesList.isEmpty
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
                    'Belum ada tempat yang diverifikasi.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.placesList.length,
              itemBuilder: (context, index) {
                final place = widget.placesList[index];
                final imageUrl = PoiImageHelper.primaryImageUrl(place);
                final verifiedAt = place['verified_at'] != null
                    ? DateTime.tryParse(place['verified_at'])
                    : null;
                final isFeatured = place['is_featured'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.bgSurface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFeatured
                          ? const Color(0xFFF4B942).withValues(alpha: 0.5)
                          : theme.border,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(12),
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: imageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
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
                    title: Row(
                      children: [
                        if (isFeatured) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFF4B942),
                            size: 14,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            place['nama_tempat'] ?? 'Tanpa Nama',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place['alamat'] ?? '-',
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
                            style: const TextStyle(
                              color: Color(0xFF28A745),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ⭐ Toggle Featured button
                        GestureDetector(
                          onTap: () => widget.onToggleFeatured(place),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isFeatured
                                  ? const Color(0xFFF4B942).withValues(alpha: 0.12)
                                  : theme.bgElevated,
                              borderRadius: BorderRadius.circular(8),
                              border: isFeatured
                                  ? Border.all(
                                      color: const Color(0xFFF4B942).withValues(alpha: 0.4),
                                    )
                                  : null,
                            ),
                            child: Icon(
                              isFeatured ? Icons.star_rounded : Icons.star_outline_rounded,
                              color: isFeatured
                                  ? const Color(0xFFF4B942)
                                  : theme.textHint,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Edit button
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditPlaceScreen(place: place),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.bgElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: theme.textHint,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFF28A745),
                          size: 22,
                        ),
                      ],
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
  final List<Map<String, dynamic>> placesList;
  final bool isLoading;
  final Future<void> Function() onRefresh;

  const _RejectedTab({
    required this.placesList,
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
          : placesList.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cancel_outlined, size: 56, color: theme.textHint),
                  const SizedBox(height: 12),
                  Text(
                    'Belum ada tempat yang ditolak.',
                    style: TextStyle(color: theme.textSecondary),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: placesList.length,
              itemBuilder: (context, index) {
                final place = placesList[index];
                final imageUrl = PoiImageHelper.primaryImageUrl(place);

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
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorWidget: (_, _, _) => Container(
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
                      place['nama_tempat'] ?? 'Tanpa Nama',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          place['alamat'] ?? '-',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        if (place['rejection_reason'] != null)
                          Text(
                            'Alasan: ${place['rejection_reason']}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFF8B2020),
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => EditPlaceScreen(place: place),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.bgElevated,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: theme.textHint,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.block,
                          color: const Color(0xFF8B2020),
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

// ── Place Card untuk Pending Tab ──────────────────────────────
class _PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final ThemeProvider theme;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _PlaceCard({
    required this.place,
    required this.theme,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = PoiImageHelper.primaryImageUrl(place);

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
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: 160,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
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
                  place['nama_tempat'] ?? 'Tanpa Nama',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  place['alamat'] ?? '-',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: theme.textSecondary, fontSize: 12),
                ),
                if (place['deskripsi'] != null &&
                    place['deskripsi']!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    place['deskripsi'],
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
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => EditPlaceScreen(place: place),
                          ),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.bgElevated,
                          foregroundColor: theme.textPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(color: theme.border),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/notification_service.dart';
import 'widgets/verify_place_widgets.dart';

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
    final placeId = place['id'];
    final ownerId = place['owner_id'] != null && place['owner_id'] is Map
        ? place['owner_id']['id']
        : place['owner_id'];

    try {
      await _client.from('places').update({
        'verification_status': 'verified',
        'verified_at': DateTime.now().toIso8601String(),
        'rejection_reason': null,
      }).eq('id', placeId);

      _snack('Tempat "${place['nama_tempat']}" berhasil diverifikasi!', isError: false);

      if (ownerId != null && ownerId.toString().isNotEmpty) {
        NotificationService.sendNewPlaceNotification(
          placeId: placeId is int ? placeId : int.tryParse(placeId.toString()) ?? 0,
          placeName: place['nama_tempat'] ?? '',
        );
      }

      _loadPlaces();
    } catch (e) {
      _snack('Gagal memverifikasi: $e', isError: true);
    }
  }

  Future<void> _rejectPlace(Map<String, dynamic> place, String reason) async {
    final placeId = place['id'];

    try {
      await _client.from('places').update({
        'verification_status': 'rejected',
        'rejection_reason': reason.isEmpty ? 'Tidak memenuhi syarat' : reason,
      }).eq('id', placeId);

      _snack('Tempat "${place['nama_tempat']}" ditolak.', isError: false);

      // Notifikasi penolakan (opsional)

      _loadPlaces();
    } catch (e) {
      _snack('Gagal menolak tempat: $e', isError: true);
    }
  }

  Future<void> _toggleFeatured(Map<String, dynamic> place) async {
    final currentFeatured = place['is_featured'] == true;
    final newFeatured = !currentFeatured;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 13)),
        backgroundColor: isError ? kAccentRed : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
          'Verifikasi Tempat',
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
          PendingTab(
            placesList: _pendingPlaces,
            isLoading: _loadingPending,
            onRefresh: _loadPending,
            onApprove: _approvePlace,
            onReject: _rejectPlace,
          ),
          VerifiedTab(
            placesList: _verifiedPlaces,
            isLoading: _loadingVerified,
            onRefresh: _loadVerified,
            onToggleFeatured: _toggleFeatured,
          ),
          RejectedTab(
            placesList: _rejectedPlaces,
            isLoading: _loadingRejected,
            onRefresh: _loadRejected,
          ),
        ],
      ),
    );
  }
}
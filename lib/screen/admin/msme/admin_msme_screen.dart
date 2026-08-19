import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/app_colors_light.dart';
import '../../../core/poi_image_helper.dart';
import '../../owner/add_place_screen.dart';
import '../../owner/edit_place_screen.dart';

// ── Tenmu Admin Design Tokens (Light Mode — hardcoded, konsisten dgn admin_home_screen) ──
const _kPrimary       = Color(0xFF1A1A1A);
const _kAccentGreen   = Color(0xFF1ED760);
const _kAccentAmber   = Color(0xFFF59E0B);
const _kAccentRed     = Color(0xFFEF4444);

const _kPageBg        = AppColorsLight.bgBase;
const _kCardBg        = AppColorsLight.bgSurface;
const _kBorderColor   = AppColorsLight.border;

const _kTextPrimary   = AppColorsLight.textPrimary;
const _kTextSecondary = AppColorsLight.textSecondary;
const _kTextMuted     = AppColorsLight.textHint;

const _kShadow = BoxShadow(
  color: Color(0x0C000000),
  blurRadius: 16,
  offset: Offset(0, 4),
);

class AdminMsmeScreen extends StatefulWidget {
  const AdminMsmeScreen({super.key});

  @override
  State<AdminMsmeScreen> createState() => _AdminMsmeScreenState();
}

class _AdminMsmeScreenState extends State<AdminMsmeScreen> {
  final _client = Supabase.instance.client;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  List<Map<String, dynamic>> _allPlaces = [];
  List<Map<String, dynamic>> _filteredPlaces = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';
  String _statusFilter = 'all'; // all | verified | pending | rejected

  static const _pageSize = 20;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _client
          .from('places')
          .select('*')
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _allPlaces = (data as List).cast<Map<String, dynamic>>();
        _applyFilters();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      setState(() {
        _visibleCount =
            (_visibleCount + _pageSize).clamp(0, _filteredPlaces.length);
      });
    }
  }

  void _applyFilters() {
    var list = _allPlaces;
    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((p) {
        final name = (p['nama_tempat'] as String? ?? '').toLowerCase();
        final cat = (p['category'] as String? ?? '').toLowerCase();
        return name.contains(q) || cat.contains(q);
      }).toList();
    }
    // Status filter
    if (_statusFilter != 'all') {
      list = list
          .where((p) =>
              (p['verification_status'] as String? ?? 'pending') ==
              _statusFilter)
          .toList();
    }
    setState(() {
      _filteredPlaces = list;
      _visibleCount = _pageSize;
    });
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      appBar: AppBar(
        backgroundColor: _kCardBg,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Text(
          'Manajemen UMKM',
          style: GoogleFonts.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _kTextPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _kBorderColor),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: _kAccentGreen,
                strokeWidth: 2.5,
              ),
            )
          : _error != null
              ? _errorView()
              : Column(
                  children: [
                    const SizedBox(height: 16),
                    // ── SEARCH + ADD BAR ──
                    _searchAndAddBar(),
                    const SizedBox(height: 12),
                    // ── STATUS FILTER CHIPS ──
                    _statusChips(),
                    const SizedBox(height: 4),
                    // ── ITEM COUNT ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '${_filteredPlaces.length} tempat ditemukan',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            color: _kTextMuted,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // ── DATA LIST ──
                    Expanded(child: _dataView()),
                  ],
                ),
    );
  }

  // ── ERROR VIEW ──
  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _kAccentRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child:
                  const Icon(Icons.cloud_off_rounded, size: 28, color: _kAccentRed),
            ),
            const SizedBox(height: 16),
            Text(
              'Gagal memuat data UMKM',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kTextMuted),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: _loadPlaces,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.refresh_rounded, size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Coba Lagi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── SEARCH + ADD BAR ──
  Widget _searchAndAddBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _kBorderColor),
                boxShadow: const [_kShadow],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  _searchQuery = v;
                  _applyFilters();
                },
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded,
                      size: 18, color: _kTextMuted),
                  hintText: 'Cari UMKM...',
                  hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: _kTextMuted),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 13),
                ),
                style: GoogleFonts.plusJakartaSans(
                    fontSize: 13, color: _kTextPrimary),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // Add UMKM button
          GestureDetector(
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AddPlaceScreen()),
              );
              _loadPlaces();
            },
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: _kAccentGreen,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: _kAccentGreen.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, size: 18, color: Colors.black),
                  const SizedBox(width: 6),
                  Text(
                    'Tambah',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── STATUS FILTER CHIPS ──
  Widget _statusChips() {
    final chips = [
      ('all', 'Semua'),
      ('verified', 'Terverifikasi'),
      ('pending', 'Pending'),
      ('rejected', 'Ditolak'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: chips.map((c) {
          final isActive = _statusFilter == c.$1;
          return GestureDetector(
            onTap: () {
              setState(() => _statusFilter = c.$1);
              _applyFilters();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.only(right: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color:
                    isActive ? _kPrimary.withValues(alpha: 0.1) : _kCardBg,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: isActive
                      ? _kPrimary.withValues(alpha: 0.35)
                      : _kBorderColor,
                ),
                boxShadow: isActive ? [] : const [_kShadow],
              ),
              child: Text(
                c.$2,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.w500,
                  color: isActive ? _kPrimary : _kTextSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── DATA LIST VIEW ──
  Widget _dataView() {
    if (_filteredPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _kBorderColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.inbox_outlined,
                  size: 32, color: _kTextMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'Tidak ada UMKM ditemukan',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _kTextPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Coba ubah filter atau tambah UMKM baru.',
              style:
                  GoogleFonts.plusJakartaSans(fontSize: 12, color: _kTextMuted),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddPlaceScreen()),
                );
                _loadPlaces();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: _kAccentGreen,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add_rounded,
                        size: 16, color: Colors.black),
                    const SizedBox(width: 6),
                    Text(
                      'Tambah UMKM',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    final displayList = _filteredPlaces.take(_visibleCount).toList();

    return RefreshIndicator(
      onRefresh: _loadPlaces,
      color: _kAccentGreen,
      backgroundColor: _kCardBg,
      child: ListView.builder(
        controller: _scrollCtrl,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        itemCount: displayList.length + 1,
        itemBuilder: (context, index) {
          if (index >= displayList.length) {
            if (_visibleCount >= _filteredPlaces.length) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: Text(
                    'Semua data sudah ditampilkan',
                    style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: _kTextMuted),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _visibleCount = (_visibleCount + _pageSize)
                        .clamp(0, _filteredPlaces.length);
                  }),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _kCardBg,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Text(
                      'Muat Lebih Banyak',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _kTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          final place = displayList[index];
          return _buildPlaceCard(place);
        },
      ),
    );
  }

  // ── PLACE CARD ──
  Widget _buildPlaceCard(Map<String, dynamic> place) {
    final name = place['nama_tempat'] as String? ?? 'Tanpa Nama';
    final category = place['category'] as String? ?? '-';
    final address = place['alamat'] as String? ?? '';
    final status = place['verification_status'] as String? ?? 'pending';
    final imageUrl = PoiImageHelper.primaryImageUrl(place);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorderColor),
        boxShadow: const [_kShadow],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Thumbnail ──
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => _buildAvatar(name),
                    )
                  : _buildAvatar(name),
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _kTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _statusBadge(status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  // Category chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: _kPageBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: _kBorderColor),
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _kTextSecondary,
                      ),
                    ),
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 11, color: _kTextMuted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            address,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                                fontSize: 11, color: _kTextMuted),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  // ── Action buttons ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Edit button
                      GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  EditPlaceScreen(place: place),
                            ),
                          );
                          _loadPlaces();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _kPrimary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_outlined,
                                  size: 13, color: Colors.white),
                              const SizedBox(width: 4),
                              Text(
                                'Edit',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Delete button
                      GestureDetector(
                        onTap: () => _confirmDelete(place),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _kAccentRed.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _kAccentRed.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.delete_outline_rounded,
                                  size: 13, color: _kAccentRed),
                              const SizedBox(width: 4),
                              Text(
                                'Hapus',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: _kAccentRed,
                                ),
                              ),
                            ],
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
      ),
    );
  }

  // ── Confirm Delete ──
  Future<void> _confirmDelete(Map<String, dynamic> place) async {
    final name = place['nama_tempat'] as String? ?? 'UMKM ini';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kCardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _kBorderColor),
        ),
        title: Text(
          'Hapus UMKM',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700, color: _kTextPrimary),
        ),
        content: Text(
          'Yakin ingin menghapus "$name"? Tindakan ini tidak dapat dibatalkan.',
          style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: _kTextSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Batal',
                style: GoogleFonts.plusJakartaSans(color: _kTextSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _kAccentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Hapus',
                style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _client.from('places').delete().eq('id', place['id']);
        if (mounted) _loadPlaces();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e',
                  style: GoogleFonts.plusJakartaSans()),
              backgroundColor: _kAccentRed,
            ),
          );
        }
      }
    }
  }

  // ── AVATAR ──
  Widget _buildAvatar(String name) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: _kAccentGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          _initials(name),
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w800,
            color: _kAccentGreen,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  // ── STATUS BADGE ──
  Widget _statusBadge(String status) {
    late Color bgColor;
    late Color textColor;
    late IconData icon;
    late String label;

    switch (status) {
      case 'verified':
        bgColor = _kAccentGreen.withValues(alpha: 0.12);
        textColor = _kAccentGreen;
        label = 'Aktif';
        icon = Icons.check_circle_rounded;
        break;
      case 'rejected':
        bgColor = _kAccentRed.withValues(alpha: 0.1);
        textColor = _kAccentRed;
        label = 'Ditolak';
        icon = Icons.cancel_rounded;
        break;
      default:
        bgColor = _kAccentAmber.withValues(alpha: 0.1);
        textColor = _kAccentAmber;
        label = 'Pending';
        icon = Icons.pending_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: textColor),
          const SizedBox(width: 3),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

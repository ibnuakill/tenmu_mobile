import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme_provider.dart';
import '../../core/umkm_image_helper.dart';
import '../../core/umkm_provider.dart';
import 'settings_screen.dart';
import '../../core/umkm_category.dart';
import '../../core/location_permission_helper.dart';
import '../auth/login_screen.dart';
import 'umkm_detail_screen.dart';
import 'route_map_screen.dart';

import 'widgets/category_filter_widget.dart';
import 'widgets/price_range_filter_widget.dart';
import 'widgets/sort_filter_widget.dart';
import 'favorite_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  late RangeValues _priceRange;
  SortOption _selectedSort = SortOption.terbaru;
  Position? _currentPosition;

  bool get _hasActiveFilters =>
      _selectedCategories.isNotEmpty ||
      _priceRange.start > 0 ||
      _priceRange.end < 1000000;

  String _sortLabel(SortOption option) {
    switch (option) {
      case SortOption.terbaru:
        return 'Terbaru';
      case SortOption.terdekat:
        return 'Terdekat';
      case SortOption.rating:
        return 'Rating';
    }
  }

  @override
  void initState() {
    super.initState();
    _priceRange = const RangeValues(0, 1000000);
    // optimization: fetch via provider with caching logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UMKMProvider>(context, listen: false).fetchUMKM();
      _requestUserLocation();
    });
  }

  Future<void> _requestUserLocation() async {
    try {
      final accessStatus = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'menampilkan jarak ke lokasi usaha',
      );

      if (accessStatus == LocationAccessStatus.granted) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (mounted) {
          setState(() {
            _currentPosition = position;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting user location: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _getCurrentLocationForSort() async {
    try {
      final accessStatus = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'mengurutkan berdasarkan jarak terdekat',
      );

      if (accessStatus == LocationAccessStatus.granted) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        setState(() {
          _currentPosition = position;
        });
      } else {
        setState(() {
          _selectedSort = SortOption.terbaru; // Fallback jika ditolak
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _selectedSort = SortOption.terbaru;
      });
    }
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  void _goToLogin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showFilterBottomSheet(BuildContext context, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: BoxDecoration(
            color: theme.bgBase,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Handle Drag ──
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.borderFocus,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // ── Header Title ──
              Text(
                'Filter Pencarian',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),

              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      CategoryFilterWidget(
                        selectedCategories: _selectedCategories,
                        onCategoriesChanged: (selected) {
                          setState(() => _selectedCategories = selected);
                        },
                      ),
                      const SizedBox(height: 24),
                      PriceRangeFilterWidget(
                        initialRange: _priceRange,
                        minPrice: 0,
                        maxPrice: 1000000,
                        onRangeChanged: (range) {
                          setState(() => _priceRange = range);
                        },
                      ),
                      const SizedBox(height: 24),
                      SortFilterWidget(
                        selectedSort: _selectedSort,
                        onSortChanged: (sort) {
                          setState(() => _selectedSort = sort);
                          if (sort == SortOption.terdekat &&
                              _currentPosition == null) {
                            _getCurrentLocationForSort();
                          }
                        },
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),

              // ── Apply Button ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.btnPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      'Terapkan Filter',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.btnLabel,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Map<String, dynamic>> _getFilteredUMKM(UMKMProvider umkmProvider) {
    final raw = umkmProvider.umkmList;
    List<Map<String, dynamic>> umkmList = raw.where((u) {
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final nama = (u['nama_tempat'] ?? '').toLowerCase();
        final alamat = (u['alamat'] ?? '').toLowerCase();
        matchesSearch =
            nama.contains(_searchQuery) || alamat.contains(_searchQuery);
      }
      bool matchesCategory = true;
      if (_selectedCategories.isNotEmpty) {
        final umkmCategory = u['category'] ?? 'Lainnya';
        matchesCategory = _selectedCategories.contains(umkmCategory);
      }
      bool matchesPrice = true;
      final minPrice = (u['min_price'] ?? 0).toDouble();
      final maxPrice = (u['max_price'] ?? 1000000).toDouble();
      matchesPrice =
          !(maxPrice < _priceRange.start || minPrice > _priceRange.end);
      return matchesSearch && matchesCategory && matchesPrice;
    }).toList();

    if (_selectedSort == SortOption.terdekat && _currentPosition != null) {
      umkmList.sort((a, b) {
        final latA = (a['latitude'] as num?)?.toDouble() ?? 0.0;
        final lngA = (a['longitude'] as num?)?.toDouble() ?? 0.0;
        final latB = (b['latitude'] as num?)?.toDouble() ?? 0.0;
        final lngB = (b['longitude'] as num?)?.toDouble() ?? 0.0;

        if (latA == 0.0 && latB != 0.0) return 1;
        if (latB == 0.0 && latA != 0.0) return -1;

        final distA = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          latA,
          lngA,
        );
        final distB = Geolocator.distanceBetween(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          latB,
          lngB,
        );

        return distA.compareTo(distB);
      });
    } else if (_selectedSort == SortOption.rating) {
      umkmList.sort((a, b) {
        final ratingA = umkmProvider.ratings[a['id']] ?? 0.0;
        final ratingB = umkmProvider.ratings[b['id']] ?? 0.0;
        return ratingB.compareTo(ratingA);
      });
    }
    return umkmList;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final umkmProvider = Provider.of<UMKMProvider>(context);
    final user = Supabase.instance.client.auth.currentUser;
    final umkmList = _getFilteredUMKM(umkmProvider);

    return Scaffold(
      backgroundColor: theme.bgBase,
      // ── DRAWER NAVIGATION ──
      drawer: user != null
          ? _buildLoggedInDrawer(context, theme, umkmProvider, user)
          : _buildGuestDrawer(context, theme, umkmProvider),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── HEADER ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => GestureDetector(
                      onTap: () => Scaffold.of(context).openDrawer(),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.bgElevated,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.border),
                          boxShadow: const [
                            BoxShadow(
                              color: Color.fromRGBO(0, 0, 0, 0.15),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.menu,
                          color: theme.textPrimary,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.bgElevated,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: theme.border),
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.15),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextField(
                        onChanged: (v) =>
                            setState(() => _searchQuery = v.toLowerCase()),
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 14,
                        ),
                        cursorColor: theme.borderFocus,
                        textAlignVertical: TextAlignVertical.center,
                        decoration: InputDecoration(
                          hintText: 'Cari tempat...',
                          hintStyle: TextStyle(
                            color: theme.textHint,
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: theme.iconColor,
                            size: 18,
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () => _showFilterBottomSheet(context, theme),
                            child: Icon(
                              Icons.tune_rounded,
                              color: _hasActiveFilters
                                  ? theme.btnPrimary
                                  : theme.iconColor,
                              size: 18,
                            ),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 0,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RouteMapScreen(umkmList: umkmList),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.btnPrimary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(0, 0, 0, 0.15),
                            blurRadius: 8,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.map_rounded,
                        color: theme.btnLabel,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── LIST & FILTER (Using Provider for caching and performance) ─────────
            Expanded(
              child: Builder(
                builder: (context) {
                  if (umkmProvider.isLoading && umkmProvider.umkmList.isEmpty) {
                    return Center(
                      child: CircularProgressIndicator(color: theme.iconColor),
                    );
                  }

                  // Error state - show retry option
                  if (umkmProvider.error != null &&
                      umkmProvider.umkmList.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 56,
                              color: theme.textHint,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Gagal memuat data',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pastikan koneksi internet aktif',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ElevatedButton.icon(
                              onPressed: () {
                                umkmProvider.clearError();
                                umkmProvider.fetchUMKM(force: true);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.btnPrimary,
                                foregroundColor: theme.btnLabel,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── LIST UMKM ──────────────────────────────────────────────────
                      Expanded(
                        child: RefreshIndicator(
                          onRefresh: () async {
                            umkmProvider.clearError();
                            await umkmProvider.fetchUMKM(force: true);
                            // Refresh user location on pull-to-refresh
                            await _requestUserLocation();
                            // Show snackbar if refresh failed but we have cached data
                            if (umkmProvider.error != null &&
                                umkmProvider.umkmList.isNotEmpty) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Gagal memperbarui data',
                                    ),
                                    backgroundColor: Colors.red.shade700,
                                    behavior: SnackBarBehavior.floating,
                                    action: SnackBarAction(
                                      label: 'Retry',
                                      textColor: Colors.white,
                                      onPressed: () =>
                                          umkmProvider.fetchUMKM(force: true),
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                          color: theme.btnPrimary,
                          backgroundColor: theme.bgElevated,
                          child: umkmList.isEmpty
                              ? ListView(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  children: [
                                    SizedBox(
                                      height:
                                          MediaQuery.of(context).size.height *
                                          0.5,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.storefront_outlined,
                                              size: 56,
                                              color: theme.textHint,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Belum ada tempat ditemukan.',
                                              style: TextStyle(
                                                color: theme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : ListView.builder(
                                  physics:
                                      const AlwaysScrollableScrollPhysics(),
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    0,
                                    20,
                                    20,
                                  ),
                                  itemCount: umkmList.length,
                                  itemBuilder: (context, index) {
                                    final umkm = umkmList[index];
                                    return _UmkmCard(
                                      umkm: umkm,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              UmkmDetailScreen(umkm: umkm),
                                        ),
                                      ),
                                      userPosition: _currentPosition,
                                    );
                                  },
                                ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UmkmCard extends StatelessWidget {
  final Map<String, dynamic> umkm;
  final VoidCallback onTap;
  final Position? userPosition;

  const _UmkmCard({required this.umkm, required this.onTap, this.userPosition});

  String? _getDistanceText() {
    if (userPosition == null) return null;

    final lat = (umkm['latitude'] as num?)?.toDouble();
    final lng = (umkm['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;

    final distance = Geolocator.distanceBetween(
      userPosition!.latitude,
      userPosition!.longitude,
      lat,
      lng,
    );

    if (distance < 1000) {
      return '${distance.round()} m';
    } else {
      return '${(distance / 1000).toStringAsFixed(1)} km';
    }
  }

  String _resolveCategory() {
    final category = umkm['category']?.toString().trim();
    if (category == null || category.isEmpty) {
      return UmkmCategory.lainnya;
    }
    return UmkmCategory.isValidCategory(category)
        ? category
        : UmkmCategory.lainnya;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final distanceText = _getDistanceText();
    final imageUrl = UmkmImageHelper.primaryImageUrl(umkm);
    final category = _resolveCategory();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.28),
              blurRadius: 18,
              offset: Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar
            if (imageUrl != null)
              Stack(
                children: [
                  Image.network(
                    imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    cacheWidth: 600, // optimization: limit image cache size
                    errorBuilder: (_, _, _) => Container(
                      height: 180,
                      color: theme.bgElevated,
                      child: Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: theme.textHint,
                        ),
                      ),
                    ),
                  ),
                  if (umkm['is_featured'] == true)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rekomendasi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.48),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            UmkmCategory.getCategoryIcon(category),
                            size: 14,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            category.toUpperCase(),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else
              Container(
                height: 120,
                color: theme.bgElevated,
                child: Center(
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 40,
                    color: theme.textHint,
                  ),
                ),
              ),

            // Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    umkm['nama_tempat'] ?? 'Tanpa Nama',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: theme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (umkm['deskripsi'] != null)
                    Text(
                      umkm['deskripsi'],
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      if (distanceText != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.bgElevated,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.near_me_rounded,
                                size: 14,
                                color: theme.btnPrimary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                distanceText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: theme.btnPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: theme.iconColor,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          umkm['alamat'] ?? 'Alamat tidak diketahui',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Buka detail',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                            color: theme.textSecondary,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.btnPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          size: 18,
                          color: theme.btnLabel,
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
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlighted;

  const _InfoPill({
    required this.icon,
    required this.label,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: highlighted ? theme.btnPrimary : theme.bgElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: highlighted ? theme.btnLabel : theme.iconColor,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: highlighted ? theme.btnLabel : theme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Drawer builders (minimal, keep inside this file for locality) ──
Widget _buildGuestDrawer(
  BuildContext context,
  ThemeProvider theme,
  UMKMProvider umkmProvider,
) {
  return Drawer(
    backgroundColor: theme.bgSurface,
    child: SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: theme.bgElevated,
                ),
                child: Icon(Icons.person, size: 32, color: theme.iconColor),
              ),
              const SizedBox(height: 12),
              Text(
                'Guest',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Temukan UMKM lokal',
                style: TextStyle(color: theme.textSecondary),
              ),
            ],
          ),
        ),

        ListTile(
          leading: Icon(Icons.settings_outlined, color: theme.iconColor),
          title: Text('Pengaturan', style: TextStyle(color: theme.textPrimary)),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              },
              icon: Icon(Icons.login, color: theme.btnLabel),
              label: Text(
                'Masuk / Daftar',
                style: TextStyle(color: theme.btnLabel),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.btnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ],
      ),
    ),
  );
}

Widget _buildLoggedInDrawer(
  BuildContext context,
  ThemeProvider theme,
  UMKMProvider umkmProvider,
  User user,
) {
  return Drawer(
    backgroundColor: theme.bgBase,
    child: SafeArea(
      child: Column(
        children: [
          ListTile(
            title: Text(
              'Menu',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            ),
            trailing: IconButton(
              icon: Icon(Icons.close, color: theme.iconColor),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Divider(color: theme.border),

          // Account header (compact)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: theme.bgElevated,
                    image: user.userMetadata?['avatar_url'] != null
                        ? DecorationImage(
                            image: NetworkImage(user.userMetadata!['avatar_url']),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: user.userMetadata?['avatar_url'] == null
                      ? Icon(Icons.person, color: theme.iconColor)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.userMetadata?['full_name'] ??
                            user.userMetadata?['nama'] ??
                            'Pengguna',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user.email ?? '',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Menu items (styled like admin)
          ListTile(
            leading: Icon(Icons.bookmark, color: theme.iconColor),
            title: Text(
              'Favorit Saya',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const FavoriteScreen()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.settings_outlined, color: theme.iconColor),
            title: Text(
              'Pengaturan',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          ),

          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(context);
                  await Supabase.instance.client.auth.signOut();
                },
                icon: Icon(Icons.logout_rounded, color: theme.iconColor),
                label: Text(
                  'Keluar',
                  style: TextStyle(color: theme.textPrimary),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.border),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

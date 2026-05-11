import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme_provider.dart';
import '../../core/umkm_provider.dart';
import '../../core/theme_toggle_button.dart';
import '../../core/umkm_category.dart';
import '../../core/location_permission_helper.dart';
import '../auth/login_screen.dart';
import 'umkm_detail_screen.dart';
import 'route_map_screen.dart';
import 'widgets/category_filter_widget.dart';
import 'widgets/price_range_filter_widget.dart';
import 'widgets/sort_filter_widget.dart';
import 'favorite_screen.dart';
import 'profile_settings_screen.dart';

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

  @override
  void initState() {
    super.initState();
    _priceRange = const RangeValues(0, 1000000);
    // optimization: fetch via provider with caching logic
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UMKMProvider>(context, listen: false).fetchUMKM();
    });
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
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
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
                          if (sort == SortOption.terdekat && _currentPosition == null) {
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
              )
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final umkmProvider = Provider.of<UMKMProvider>(context);
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      backgroundColor: theme.bgBase,
      // ── DRAWER NAVIGATION ──
      drawer: Drawer(
        backgroundColor: theme.bgSurface,
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              decoration: BoxDecoration(color: theme.btnPrimary),
              accountName: Text(
                user?.userMetadata?['full_name'] ?? user?.userMetadata?['nama'] ?? 'Guest',
                style: TextStyle(color: theme.btnLabel, fontWeight: FontWeight.bold),
              ),
              accountEmail: Text(
                user?.email ?? 'Belum login',
                style: TextStyle(color: theme.btnLabel),
              ),
              currentAccountPicture: CircleAvatar(
                backgroundColor: theme.bgBase,
                backgroundImage: user?.userMetadata?['avatar_url'] != null
                    ? NetworkImage(user!.userMetadata!['avatar_url'])
                    : null,
                child: user?.userMetadata?['avatar_url'] == null
                    ? Icon(Icons.person, color: theme.iconColor, size: 40)
                    : null,
              ),
            ),
            ListTile(
              leading: Icon(Icons.bookmark, color: theme.iconColor),
              title: Text('Favorit Saya', style: TextStyle(color: theme.textPrimary)),
              onTap: () {
                Navigator.pop(context); // Tutup drawer
                if (user != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Silakan login terlebih dahulu')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.settings, color: theme.iconColor),
              title: Text('Pengaturan Profil', style: TextStyle(color: theme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                if (user != null) {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Silakan login terlebih dahulu')),
                  );
                }
              },
            ),
            ListTile(
              leading: Icon(Icons.map, color: theme.iconColor),
              title: Text('Peta Rute', style: TextStyle(color: theme.textPrimary)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => RouteMapScreen(umkmList: umkmProvider.umkmList)));
              },
            ),
            const Spacer(),
            Divider(color: theme.border),
            if (user != null)
              ListTile(
                leading: Icon(Icons.logout, color: Colors.red),
                title: Text('Keluar', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _signOut(context);
                },
              )
            else
              ListTile(
                leading: Icon(Icons.login, color: theme.btnPrimary),
                title: Text('Masuk', style: TextStyle(color: theme.btnPrimary)),
                onTap: () {
                  Navigator.pop(context);
                  _goToLogin(context);
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
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
                        margin: const EdgeInsets.only(right: 16),
                        decoration: BoxDecoration(
                          color: theme.bgElevated,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: theme.border),
                        ),
                        child: Icon(Icons.menu, color: theme.textPrimary, size: 24),
                      ),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TenMu',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: theme.textPrimary,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        'Temukan tempat nongkrong favoritmu',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const ThemeToggleButton(),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── LIST & FILTER (Using Provider for caching and performance) ─────────
            Expanded(
              child: Builder(
                builder: (context) {
                  if (umkmProvider.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(color: theme.iconColor),
                    );
                  }

                  final raw = umkmProvider.umkmList;
                  List<Map<String, dynamic>> umkmList = raw.where((u) {
                    // Filter by search query
                    bool matchesSearch = true;
                    if (_searchQuery.isNotEmpty) {
                      final nama = (u['nama_tempat'] ?? '').toLowerCase();
                      final alamat = (u['alamat'] ?? '').toLowerCase();
                      matchesSearch = nama.contains(_searchQuery) ||
                          alamat.contains(_searchQuery);
                    }

                    // Filter by category
                    bool matchesCategory = true;
                    if (_selectedCategories.isNotEmpty) {
                      final umkmCategory = u['category'] ?? 'Lainnya';
                      matchesCategory = _selectedCategories.contains(umkmCategory);
                    }

                    // Filter by price range
                    bool matchesPrice = true;
                    final minPrice = (u['min_price'] ?? 0).toDouble();
                    final maxPrice = (u['max_price'] ?? 1000000).toDouble();
                    matchesPrice = !(maxPrice < _priceRange.start || minPrice > _priceRange.end);

                    return matchesSearch && matchesCategory && matchesPrice;
                  }).toList();

                  // Sort logic
                  if (_selectedSort == SortOption.terdekat && _currentPosition != null) {
                    umkmList.sort((a, b) {
                      final latA = (a['latitude'] as num?)?.toDouble() ?? 0.0;
                      final lngA = (a['longitude'] as num?)?.toDouble() ?? 0.0;
                      final latB = (b['latitude'] as num?)?.toDouble() ?? 0.0;
                      final lngB = (b['longitude'] as num?)?.toDouble() ?? 0.0;

                      if (latA == 0.0 && latB != 0.0) return 1;
                      if (latB == 0.0 && latA != 0.0) return -1;

                      final distA = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, latA, lngA);
                      final distB = Geolocator.distanceBetween(_currentPosition!.latitude, _currentPosition!.longitude, latB, lngB);

                      return distA.compareTo(distB);
                    });
                  } else if (_selectedSort == SortOption.rating) {
                    umkmList.sort((a, b) {
                      final ratingA = umkmProvider.ratings[a['id']] ?? 0.0;
                      final ratingB = umkmProvider.ratings[b['id']] ?? 0.0;
                      return ratingB.compareTo(ratingA); // Descending (highest rating first)
                    });
                  } // Default: terbaru (already sorted in provider)

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── SEARCH BAR & MAP & FILTER BUTTON ────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: theme.bgSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: theme.border),
                                ),
                                child: TextField(
                                  onChanged: (v) =>
                                      setState(() => _searchQuery = v.toLowerCase()),
                                  style: TextStyle(color: theme.textPrimary),
                                  cursorColor: theme.borderFocus,
                                  decoration: InputDecoration(
                                    hintText: 'Cari nama tempat atau alamat...',
                                    hintStyle: TextStyle(
                                      color: theme.textHint,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: Icon(
                                      Icons.search,
                                      color: theme.iconColor,
                                      size: 20,
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                _showFilterBottomSheet(context, theme);
                              },
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: (_selectedCategories.isNotEmpty || _priceRange.start > 0 || _priceRange.end < 1000000)
                                      ? theme.btnPrimary
                                      : theme.bgSurface,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: (_selectedCategories.isNotEmpty || _priceRange.start > 0 || _priceRange.end < 1000000)
                                        ? theme.btnPrimary
                                        : theme.border,
                                  ),
                                ),
                                child: Icon(
                                  Icons.tune_rounded,
                                  color: (_selectedCategories.isNotEmpty || _priceRange.start > 0 || _priceRange.end < 1000000)
                                      ? theme.btnLabel
                                      : theme.iconColor,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
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
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: theme.btnPrimary,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.map_rounded,
                                  color: theme.btnLabel,
                                  size: 24,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ── LIST UMKM ──────────────────────────────────────────────────
                      Expanded(
                        child: umkmList.isEmpty
                            ? Center(
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
                                      style: TextStyle(color: theme.textSecondary),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                                itemCount: umkmList.length,
                                itemBuilder: (context, index) {
                                  final umkm = umkmList[index];
                                  return _UmkmCard(
                                    umkm: umkm,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => UmkmDetailScreen(umkm: umkm),
                                      ),
                                    ),
                                  );
                                },
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

  const _UmkmCard({required this.umkm, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar
            if (umkm['gambar_url'] != null)
              Stack(
                children: [
                  Image.network(
                    umkm['gambar_url'],
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
                          color: theme.bgBase.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: theme.border),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star_rounded,
                              size: 14,
                              color: theme.textPrimary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Rekomendasi',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: theme.textPrimary,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

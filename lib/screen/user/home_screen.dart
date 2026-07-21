import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_image_helper.dart';
import '../../core/places_provider.dart';
import 'settings_screen.dart';
import '../../core/poi_category.dart';
import '../../core/location_permission_helper.dart';
import '../../core/user_role.dart';
import 'poi_detail_screen.dart';
import 'route_map_screen.dart';

import '../owner/add_place_screen.dart';
import 'widgets/category_filter_widget.dart';
import 'widgets/sort_filter_widget.dart';
import '../../core/haversine.dart';
import '../../core/geocoding_service.dart';
import 'widgets/chat_bot.dart';
import 'user_notification_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  SortOption _selectedSort = SortOption.terbaru;
  Position? _currentPosition;
  int _currentNavIndex = 0;
  UserRole? _userRole;
  String? _selectedCategoryTab; // for the chip row
  String? _userName;
  String? _userLocation;
  bool _isUpdatingLocation = false;
  int _unreadNotifCount = 0;
  bool _isHeaderCollapsed = false;
  final ScrollController _scrollController = ScrollController();
  static const double _collapseOffset = 80.0;

  bool get _isOwner => _userRole == UserRole.owner;

  // Teal color matching the reference design header
  static const Color _headerTeal = Color(0xFF1A7A6E);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<PlacesProvider>(context, listen: false).fetchPlaces();
      _requestUserLocation();
      _loadUserRole();
      _loadUserProfile();
      _loadUnreadCount();
    });
    _scrollController.addListener(() {
      final collapsed = _scrollController.offset > _collapseOffset;
      if (collapsed != _isHeaderCollapsed) {
        setState(() => _isHeaderCollapsed = collapsed);
      }
    });
  }

  Future<void> _loadUnreadCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      if (mounted) {
        setState(() => _unreadNotifCount = (data as List).length);
      }
    } catch (_) {}
  }

  Future<void> _loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('full_name, nama, role, city')
          .eq('id', user.id)
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          _userName =
              res['full_name'] ??
              res['nama'] ??
              user.userMetadata?['full_name'] ??
              user.userMetadata?['nama'] ??
              'Pengguna';
          _userLocation = res['city'] ?? 'Cirebon';
        });
      } else {
        setState(() {
          _userName =
              user.userMetadata?['full_name'] ??
              user.userMetadata?['nama'] ??
              'Pengguna';
          _userLocation = 'Cirebon';
        });
      }
    } catch (_) {
      final user = Supabase.instance.client.auth.currentUser;
      setState(() {
        _userName =
            user?.userMetadata?['full_name'] ??
            user?.userMetadata?['nama'] ??
            'Pengguna';
        _userLocation = 'Cirebon';
      });
    }
  }

  Future<void> _loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (res != null && mounted) {
      setState(() => _userRole = parseUserRole(res['role']));
    }
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
    _scrollController.dispose();
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
          _selectedSort = SortOption.terbaru;
        });
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
      setState(() {
        _selectedSort = SortOption.terbaru;
      });
    }
  }

  Future<void> _updateLocationFromGPS() async {
    if (_isUpdatingLocation) return;
    setState(() => _isUpdatingLocation = true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Memperbarui lokasi dari GPS...'),
          duration: Duration(seconds: 2),
        ),
      );
    }

    try {
      final accessStatus = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'memperbarui lokasi saat ini',
      );

      if (accessStatus == LocationAccessStatus.granted) {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        final address = await GeocodingService.reverse(
          position.latitude,
          position.longitude,
        );
        if (address != null && mounted) {
          final parts = address.split(',');
          // Ambil 2 bagian pertama agar tidak terlalu panjang
          final shortAddress = parts.take(2).join(',').trim();
          setState(() {
            _userLocation = shortAddress;
            _currentPosition = position;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lokasi diperbarui: $shortAddress'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error updating location from GPS: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui lokasi'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdatingLocation = false);
      }
    }
  }

  void _onNavTap(int index) {
    if (index == _currentNavIndex && index != 0) return;
    if (index == 0) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      setState(() => _currentNavIndex = 0);
      return;
    }
    if (index == 2) {
      if (!_isOwner) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddPlaceScreen()),
      ).then((_) {
        if (mounted) setState(() => _currentNavIndex = 0);
      });
      return;
    }
    if (index == 3) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ChatBotSheet(),
      );
      return;
    }
    setState(() => _currentNavIndex = index);
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteMapScreen(
              placesList: Provider.of<PlacesProvider>(
                context,
                listen: false,
              ).placesList,
            ),
          ),
        ).then((_) {
          if (mounted) setState(() => _currentNavIndex = 0);
        });
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ).then((_) {
          if (mounted) setState(() => _currentNavIndex = 0);
        });
    }
  }

  void _showSearchSheet(BuildContext context, ThemeProvider theme) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String localQuery = _searchQuery;
        Set<String> localCategories = Set.from(_selectedCategories);
        SortOption localSort = _selectedSort;

        return StatefulBuilder(
          builder: (ctx, setLocal) {
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (ctx, scrollCtrl) {
                return Container(
                  decoration: BoxDecoration(
                    color: theme.bgBase,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Handle
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12, bottom: 4),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.borderFocus,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header row
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                        child: Row(
                          children: [
                            Text(
                              'Cari & Filter',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: theme.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            // Reset all
                            if (localQuery.isNotEmpty ||
                                localCategories.isNotEmpty ||
                                localSort != SortOption.terbaru)
                              GestureDetector(
                                onTap: () {
                                  setLocal(() {
                                    localQuery = '';
                                    localCategories = {};
                                    localSort = SortOption.terbaru;
                                  });
                                  setState(() {
                                    _searchQuery = '';
                                    _selectedCategories = {};
                                    _selectedSort = SortOption.terbaru;
                                  });
                                },
                                child: Text(
                                  'Reset',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.red.shade400,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Search field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: theme.bgSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: localQuery.isNotEmpty
                                  ? _headerTeal
                                  : theme.border,
                              width: localQuery.isNotEmpty ? 1.5 : 1,
                            ),
                          ),
                          child: TextField(
                            autofocus: true,
                            controller: TextEditingController(text: localQuery)
                              ..selection = TextSelection.collapsed(
                                offset: localQuery.length,
                              ),
                            onChanged: (v) {
                              setLocal(() => localQuery = v.toLowerCase());
                              setState(() => _searchQuery = v.toLowerCase());
                            },
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 14,
                            ),
                            cursorColor: _headerTeal,
                            textAlignVertical: TextAlignVertical.center,
                            decoration: InputDecoration(
                              hintText: 'Cari tempat wisata, kuliner...',
                              hintStyle: TextStyle(
                                color: theme.textHint,
                                fontSize: 13,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: localQuery.isNotEmpty
                                    ? _headerTeal
                                    : theme.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: localQuery.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        setLocal(() => localQuery = '');
                                        setState(() => _searchQuery = '');
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        color: theme.textSecondary,
                                        size: 18,
                                      ),
                                    )
                                  : null,
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Scrollable filter area
                      Expanded(
                        child: ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                          children: [
                            // Divider
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: theme.border, height: 1),
                            ),
                            // Category filter
                            CategoryFilterWidget(
                              selectedCategories: localCategories,
                              onCategoriesChanged: (selected) {
                                setLocal(() => localCategories = selected);
                                setState(() => _selectedCategories = selected);
                              },
                            ),
                            const SizedBox(height: 20),
                            // Sort filter
                            SortFilterWidget(
                              selectedSort: localSort,
                              onSortChanged: (sort) {
                                setLocal(() => localSort = sort);
                                setState(() => _selectedSort = sort);
                                if (sort == SortOption.terdekat &&
                                    _currentPosition == null) {
                                  _getCurrentLocationForSort();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    ).whenComplete(() {
      // sync state after sheet close
      setState(() {});
    });
  }

  List<Map<String, dynamic>> _getFilteredPlaces(PlacesProvider placesProvider) {
    final raw = placesProvider.placesList;
    List<Map<String, dynamic>> placesList = raw.where((u) {
      bool matchesSearch = true;
      if (_searchQuery.isNotEmpty) {
        final nama = (u['nama_tempat'] ?? '').toLowerCase();
        final alamat = (u['alamat'] ?? '').toLowerCase();
        matchesSearch =
            nama.contains(_searchQuery) || alamat.contains(_searchQuery);
      }
      bool matchesCategory = true;
      final Set<String> activeCategories = {
        ..._selectedCategories,
        if (_selectedCategoryTab != null && _selectedCategoryTab != 'Semua')
          _selectedCategoryTab!,
      };
      if (activeCategories.isNotEmpty) {
        final umkmCategory = u['category'] ?? 'Lainnya';
        matchesCategory = activeCategories.contains(umkmCategory);
      }
      return matchesSearch && matchesCategory;
    }).toList();

    if (_selectedSort == SortOption.terdekat && _currentPosition != null) {
      Haversine.sortByDistance(
        places: placesList,
        userLat: _currentPosition!.latitude,
        userLng: _currentPosition!.longitude,
      );
    } else if (_selectedSort == SortOption.rating) {
      placesList.sort((a, b) {
        final ratingA = placesProvider.ratings[a['id']] ?? 0.0;
        final ratingB = placesProvider.ratings[b['id']] ?? 0.0;
        return ratingB.compareTo(ratingA);
      });
    }
    return placesList;
  }

  double _getRating(PlacesProvider p, int? id) => p.ratings[id] ?? 0.0;

  // ── Header widget ──
  // ── Header expanded (full) ──
  Widget _buildHeader(ThemeProvider theme) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final firstName = (_userName ?? 'Pengguna').split(' ').first;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      decoration: const BoxDecoration(
        color: _headerTeal,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: location + search + bell
              Row(
                children: [
                  GestureDetector(
                    onTap: _updateLocationFromGPS,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 16,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        _isUpdatingLocation
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 140,
                                ),
                                child: Text(
                                  _userLocation ?? 'Cirebon',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  // Search button → opens search sheet
                  GestureDetector(
                    onTap: () => _showSearchSheet(context, theme),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.search_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          Positioned(
                            top: -3,
                            right: -3,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.orangeAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Notification button
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UserNotificationScreen(),
                        ),
                      );
                      _loadUnreadCount();
                    },
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (_unreadNotifCount > 0)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                _unreadNotifCount > 99
                                    ? '99+'
                                    : '$_unreadNotifCount',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // ── Greeting row: collapse saat scroll ──
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 250),
                firstCurve: Curves.easeOut,
                secondCurve: Curves.easeIn,
                sizeCurve: Curves.easeInOut,
                crossFadeState: _isHeaderCollapsed
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 18),
                    // User greeting row
                    Row(
                      children: [
                        // Avatar
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.4),
                              width: 2,
                            ),
                            image: avatarUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(avatarUrl),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                  size: 26,
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Hi, $firstName!',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Mau eksplor ke mana hari ini?',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                  ],
                ),
                // Collapsed: just small vertical space
                secondChild: const SizedBox(height: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(ThemeProvider theme) {
    final categories = ['Semua', ...PoiCategory.allCategories];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = _selectedCategoryTab == null
              ? cat == 'Semua'
              : _selectedCategoryTab == cat;
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryTab = cat == 'Semua' ? null : cat;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? _headerTeal : theme.bgSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? _headerTeal : theme.border,
                  width: 1.2,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: _headerTeal.withValues(alpha: 0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cat != 'Semua') ...[
                    Text(
                      PoiCategory.getCategoryEmoji(cat),
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : theme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Horizontal recommendation card section ──
  Widget _buildRecommendationSection(
    ThemeProvider theme,
    List<Map<String, dynamic>> places,
    PlacesProvider provider,
    String title,
  ) {
    if (places.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {},
                child: Text(
                  'Lihat Semua',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _headerTeal,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: places.length > 8 ? 8 : places.length,
            separatorBuilder: (_, _) => const SizedBox(width: 14),
            itemBuilder: (context, index) {
              final place = places[index];
              final imageUrl = PoiImageHelper.primaryImageUrl(place);
              final rating = _getRating(provider, place['id']);
              final category = _resolveCategory(place);
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PoiDetailScreen(place: place),
                  ),
                ),
                child: Container(
                  width: 200,
                  decoration: BoxDecoration(
                    color: theme.bgSurface,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Stack(
                        children: [
                          imageUrl != null
                              ? Image.network(
                                  imageUrl,
                                  width: double.infinity,
                                  height: 130,
                                  fit: BoxFit.cover,
                                  cacheWidth: 400,
                                  errorBuilder: (_, _, _) =>
                                      _placeholder(theme),
                                )
                              : _placeholder(theme),
                          // Category badge top-left
                          Positioned(
                            top: 10,
                            left: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    PoiCategory.getCategoryEmoji(category),
                                    style: const TextStyle(fontSize: 10),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    category,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // Heart icon top-right
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.favorite_border_rounded,
                                size: 15,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Content
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                place['nama_tempat'] ?? '',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    size: 11,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      place['alamat'] ?? '',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: theme.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Spacer(),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: Color(0xFFFFC107),
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    rating > 0
                                        ? rating.toStringAsFixed(1)
                                        : 'Baru',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  if (place['verification_status'] ==
                                      'verified')
                                    Icon(
                                      Icons.verified_rounded,
                                      size: 14,
                                      color: _headerTeal,
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  String _resolveCategory(Map<String, dynamic> place) {
    final category = place['category']?.toString().trim();
    if (category == null || category.isEmpty) return PoiCategory.lainnya;
    return PoiCategory.isValidCategory(category)
        ? category
        : PoiCategory.lainnya;
  }

  Widget _placeholder(ThemeProvider theme) {
    return Container(
      height: 130,
      color: theme.bgElevated,
      child: Center(
        child: Icon(Icons.image_outlined, size: 28, color: theme.textHint),
      ),
    );
  }

  // ── Bottom Nav Bar ──
  Widget _bottomNav(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(theme, Icons.home_rounded, 0, 'Beranda'),
              _navItem(theme, Icons.map_rounded, 1, 'Peta'),
              if (_isOwner) _navItemAdd(theme),
              _navItem(theme, Icons.auto_awesome_rounded, 3, 'AI'),
              _navItem(theme, Icons.person_rounded, 4, 'Profil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(ThemeProvider theme, IconData icon, int index, String label) {
    final active = index == _currentNavIndex;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? _headerTeal.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: active ? _headerTeal : theme.iconColor),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                color: active ? _headerTeal : theme.textHint,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItemAdd(ThemeProvider theme) {
    return GestureDetector(
      onTap: () => _onNavTap(2),
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_headerTeal, Color(0xFF0F5C52)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _headerTeal.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 26),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final placesProvider = Provider.of<PlacesProvider>(context);
    final allPlaces = _getFilteredPlaces(placesProvider);
    final featured = allPlaces.where((p) => p['is_featured'] == true).toList();

    return Scaffold(
      backgroundColor: theme.bgBase,
      body: Column(
        children: [
          // Teal header — animates on scroll
          _buildHeader(theme),

          const SizedBox(height: 16),

          // Category chips
          _buildCategoryChips(theme),

          const SizedBox(height: 16),

          // Content
          Expanded(
            child: Builder(
              builder: (context) {
                if (placesProvider.isLoading &&
                    placesProvider.placesList.isEmpty) {
                  return Center(
                    child: CircularProgressIndicator(
                      color: _headerTeal,
                      strokeWidth: 2.5,
                    ),
                  );
                }

                if (placesProvider.error != null &&
                    placesProvider.placesList.isEmpty) {
                  return _errorState(theme, placesProvider);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    placesProvider.clearError();
                    await placesProvider.fetchPlaces(force: true);
                    await _requestUserLocation();
                    if (placesProvider.error != null &&
                        placesProvider.placesList.isNotEmpty) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Text('Gagal memperbarui data'),
                          backgroundColor: Colors.red.shade700,
                          behavior: SnackBarBehavior.floating,
                          action: SnackBarAction(
                            label: 'Retry',
                            textColor: Colors.white,
                            onPressed: () =>
                                placesProvider.fetchPlaces(force: true),
                          ),
                        ),
                      );
                    }
                  },
                  color: _headerTeal,
                  backgroundColor: theme.bgElevated,
                  child: allPlaces.isEmpty
                      ? _emptyState(theme)
                      : ListView(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.only(bottom: 20),
                          children: [
                            // Rekomendasi section
                            if (featured.isNotEmpty) ...[
                              _buildRecommendationSection(
                                theme,
                                featured,
                                placesProvider,
                                'Rekomendasi Utama',
                              ),
                              const SizedBox(height: 24),
                            ],

                            // Terdekat / semua section
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                              child: Row(
                                children: [
                                  Text(
                                    _selectedCategoryTab != null
                                        ? _selectedCategoryTab!
                                        : 'Semua Tempat',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: theme.textPrimary,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.bgSurface,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.border),
                                    ),
                                    child: Text(
                                      '${allPlaces.length} tempat',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            ...allPlaces.map(
                              (place) => _PlaceCard(
                                place: place,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        PoiDetailScreen(place: place),
                                  ),
                                ),
                                userPosition: _currentPosition,
                                rating: _getRating(placesProvider, place['id']),
                                accentColor: _headerTeal,
                              ),
                            ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _bottomNav(theme),
    );
  }

  Widget _errorState(ThemeProvider theme, PlacesProvider provider) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 56, color: theme.textHint),
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
              style: TextStyle(fontSize: 13, color: theme.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                provider.clearError();
                provider.fetchPlaces(force: true);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _headerTeal,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(ThemeProvider theme) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.3,
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
                  style: TextStyle(color: theme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Place Card (vertical list) ──
class _PlaceCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback onTap;
  final Position? userPosition;
  final double rating;
  final Color accentColor;

  const _PlaceCard({
    required this.place,
    required this.onTap,
    this.userPosition,
    this.rating = 0,
    this.accentColor = const Color(0xFF1A7A6E),
  });

  String? _getDistanceText() {
    if (userPosition == null) return null;
    final lat = (place['latitude'] as num?)?.toDouble();
    final lng = (place['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null || lat == 0 || lng == 0) return null;
    final distanceKm = Haversine.distance(
      userPosition!.latitude,
      userPosition!.longitude,
      lat,
      lng,
    );
    return Haversine.formatDistance(distanceKm);
  }

  String _resolveCategory() {
    final category = place['category']?.toString().trim();
    if (category == null || category.isEmpty) return PoiCategory.lainnya;
    return PoiCategory.isValidCategory(category)
        ? category
        : PoiCategory.lainnya;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final distanceText = _getDistanceText();
    final imageUrl = PoiImageHelper.primaryImageUrl(place);
    final category = _resolveCategory();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.10),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left image
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                bottomLeft: Radius.circular(20),
              ),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 110,
                      height: 120,
                      fit: BoxFit.cover,
                      cacheWidth: 220,
                      errorBuilder: (_, _, _) => Container(
                        width: 110,
                        height: 120,
                        color: theme.bgElevated,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: theme.textHint,
                          size: 28,
                        ),
                      ),
                    )
                  : Container(
                      width: 110,
                      height: 120,
                      color: theme.bgElevated,
                      child: Center(
                        child: Icon(
                          Icons.storefront_outlined,
                          color: theme.textHint,
                          size: 28,
                        ),
                      ),
                    ),
            ),

            // Right content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${PoiCategory.getCategoryEmoji(category)} $category',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: accentColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Name
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            place['nama_tempat'] ?? 'Tanpa Nama',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (place['verification_status'] == 'verified' &&
                            place['owner_id'] != null)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: accentColor,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Address
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 11,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            place['alamat'] ?? 'Alamat tidak diketahui',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Rating + distance
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFFFC107),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : 'Baru',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: theme.textPrimary,
                          ),
                        ),
                        if (distanceText != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: theme.textHint,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.near_me_rounded,
                            size: 12,
                            color: accentColor,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            distanceText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: accentColor,
                            ),
                          ),
                        ],
                      ],
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
}

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
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
import 'dart:math' as math;

import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  // ── State ──
  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  SortOption _selectedSort = SortOption.terbaru;
  Position? _currentPosition;
  int _currentNavIndex = 0;
  UserRole? _userRole;
  String? _selectedCategoryTab;
  String? _userName;
  String? _userLocation;
  bool _isUpdatingLocation = false;
  int _unreadNotifCount = 0;
  final ScrollController _scrollController = ScrollController();
  Timer? _searchDebounce;

  // ── Carousel ──
  late final PageController _carouselCtrl;
  int _currentCardPage = 0;
  final ValueNotifier<double> _carouselPage = ValueNotifier<double>(0.0);

  // ── Animation ──
  late final AnimationController _entranceCtrl;
  late final AnimationController _cardCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _isOwner => _userRole == UserRole.owner;

  static const Color _fallbackAccent = Color(0xFF1A7A6E);

  // ── Category list ──
  final List<String> _categories = ['Semua', ...PoiCategory.allCategories];

  @override
  void initState() {
    super.initState();

    _entranceCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _cardCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnim = CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _entranceCtrl, curve: Curves.easeOutCubic),
        );

    _scrollController.addListener(_onScroll);

    _carouselCtrl = PageController(viewportFraction: 0.88, initialPage: 0);
    _carouselCtrl.addListener(() {
      final rawPage = _carouselCtrl.page ?? 0.0;
      _carouselPage.value = rawPage;
      final page = rawPage.round();
      if (page != _currentCardPage) {
        setState(() => _currentCardPage = page);
      }
    });

    _entranceCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardCtrl.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider =
          Provider.of<PlacesProvider>(context, listen: false);
      provider.setQuery(_buildQuery());
      provider.fetchFeatured();
      _requestUserLocation();
      _loadUserRole();
      _loadUserProfile();
      _loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _entranceCtrl.dispose();
    _cardCtrl.dispose();
    _carouselPage.dispose();
    _carouselCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Data loading ──

  Future<void> _loadUnreadCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      if (mounted) setState(() => _unreadNotifCount = (data as List).length);
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
      final u = Supabase.instance.client.auth.currentUser;
      setState(() {
        _userName =
            u?.userMetadata?['full_name'] ??
            u?.userMetadata?['nama'] ??
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
      final status = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'menampilkan jarak ke lokasi usaha',
      );
      if (status == LocationAccessStatus.granted) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        if (mounted) setState(() => _currentPosition = pos);

        // Reverse geocoding otomatis agar lokasi di header langsung ter-update
        final address = await GeocodingService.reverse(
          pos.latitude,
          pos.longitude,
        );
        if (address != null && mounted) {
          final parts = address.split(',');
          final shortAddr = parts.take(2).join(',').trim();
          setState(() {
            _userLocation = shortAddr;
          });
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _getCurrentLocationForSort() async {
    try {
      final status = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'mengurutkan berdasarkan jarak terdekat',
      );
      if (status == LocationAccessStatus.granted) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        setState(() => _currentPosition = pos);
        // Posisi tersedia → ulangi query 'terdekat' ke server.
        _scheduleQuery(immediate: true);
      } else {
        setState(() => _selectedSort = SortOption.terbaru);
      }
    } catch (_) {
      setState(() => _selectedSort = SortOption.terbaru);
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
      final status = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'memperbarui lokasi saat ini',
      );
      if (status == LocationAccessStatus.granted) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        final address = await GeocodingService.reverse(
          pos.latitude,
          pos.longitude,
        );
        if (address != null && mounted) {
          final parts = address.split(',');
          final shortAddr = parts.take(2).join(',').trim();
          setState(() {
            _userLocation = shortAddr;
            _currentPosition = pos;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Lokasi diperbarui: $shortAddr'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui lokasi'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUpdatingLocation = false);
    }
  }

  // ── Navigation ──

  void _onNavTap(int index) {
    if (index == _currentNavIndex && index != 0) return;
    if (index == 0) {
      Navigator.of(context).popUntil((r) => r.isFirst);
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

  // ── Query server-side ──

  /// Susun PlaceQuery dari semua state filter/sort di UI.
  /// Semua filter/sort kini dijalankan Postgres via RPC; client hanya menampilkan
  /// hasil page yg sudah server-filtered.
  PlaceQuery _buildQuery() {
    final cats = [
      ..._selectedCategories,
      if (_selectedCategoryTab != null && _selectedCategoryTab != 'Semua')
        _selectedCategoryTab!,
    ].map(PoiCategory.normalizeCategory).toList();

    final SortMode sort;
    if (_selectedSort == SortOption.terdekat && _currentPosition != null) {
      sort = SortMode.terdekat;
    } else if (_selectedSort == SortOption.rating) {
      sort = SortMode.rating;
    } else {
      sort = SortMode.terbaru;
    }

    return PlaceQuery(
      search: _searchQuery.toLowerCase().trim(),
      categories: cats,
      sort: sort,
      userLat: _currentPosition?.latitude,
      userLng: _currentPosition?.longitude,
    );
  }

  /// Debounce pencarian (400ms) lalu fetch ulang halaman 1.
  void _scheduleQuery({bool immediate = false}) {
    _searchDebounce?.cancel();
    if (immediate) {
      final provider =
          Provider.of<PlacesProvider>(context, listen: false);
      provider.setQuery(_buildQuery(), force: true);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      final provider =
          Provider.of<PlacesProvider>(context, listen: false);
      provider.setQuery(_buildQuery(), force: true);
    });
  }

  /// Infinite scroll: fetch halaman berikutnya saat mendekati dasar list.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      final p = Provider.of<PlacesProvider>(context, listen: false);
      if (p.hasMore && !p.isLoadingMore && !p.isLoading) {
        p.fetchMore();
      }
    }
  }

  List<Map<String, dynamic>> _getFilteredPlaces(PlacesProvider provider) =>
      provider.placesList;

  double _getRating(PlacesProvider p, int? id) => p.ratings[id] ?? 0.0;

  String _resolveCategory(Map<String, dynamic> place) {
    final c = place['category']?.toString().trim();
    if (c == null || c.isEmpty) return PoiCategory.lainnya;
    return PoiCategory.normalizeCategory(c);
  }

  void _showFilterSheet(
    BuildContext context,
    ThemeProvider theme,
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String localQuery = _searchQuery;
        Set<String> localCats = Set.from(_selectedCategories);
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
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
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
                            if (localQuery.isNotEmpty ||
                                localCats.isNotEmpty ||
                                localSort != SortOption.terbaru)
                              GestureDetector(
                                onTap: () {
                                  setLocal(() {
                                    localQuery = '';
                                    localCats = {};
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
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: theme.bgSurface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: localQuery.isNotEmpty
                                  ? accent
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
                              _scheduleQuery();
                            },
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 14,
                            ),
                            cursorColor: accent,
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
                                    ? accent
                                    : theme.textSecondary,
                                size: 20,
                              ),
                              suffixIcon: localQuery.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () {
                                        setLocal(() => localQuery = '');
                                        setState(() => _searchQuery = '');
                                        _scheduleQuery(immediate: true);
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
                      Expanded(
                        child: ListView(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Divider(color: theme.border, height: 1),
                            ),
                            CategoryFilterWidget(
                              selectedCategories: localCats,
                              onCategoriesChanged: (s) {
                                setLocal(() => localCats = s);
                                setState(() => _selectedCategories = s);
                                _scheduleQuery();
                              },
                            ),
                            const SizedBox(height: 20),
                            SortFilterWidget(
                              selectedSort: localSort,
                              onSortChanged: (s) {
                                setLocal(() => localSort = s);
                                setState(() => _selectedSort = s);
                                _scheduleQuery();
                                if (s == SortOption.terdekat &&
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
      // Sheet ditutup → sinkronkan query server dengan pilihan terakhir.
      setState(() {});
      _scheduleQuery(immediate: true);
    });
  }

  // ════════════════════════════════════════
  // ── BUILD ──
  // ════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final placesProvider = Provider.of<PlacesProvider>(context);
    final allPlaces = _getFilteredPlaces(placesProvider);
    final featured = placesProvider.featuredList;

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final dynamicScheme = theme.isDarkMode ? darkDynamic : lightDynamic;
        final accent = dynamicScheme?.primary ?? _fallbackAccent;

        return Scaffold(
          backgroundColor: theme.bgBase,
          extendBody: true,
          body: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // ── Greeting Header ──
                  SliverToBoxAdapter(
                    child: _buildGreetingHeader(theme, accent),
                  ),
                  // ── Search Bar ──
                  SliverToBoxAdapter(child: _buildSearchBar(theme, accent)),
                  // ── Category Section Title ──
                  SliverToBoxAdapter(child: _buildSectionTitle(theme)),
                  // ── Category Chips ──
                  SliverToBoxAdapter(child: _buildCategoryChips(theme, accent)),
                  // ── Content ──
                  SliverToBoxAdapter(
                    child: _buildMainContent(
                      theme,
                      accent,
                      placesProvider,
                      allPlaces,
                      featured,
                    ),
                  ),
                  // Bottom padding
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
                ],
              ),
            ),
          ),
          bottomNavigationBar: _buildPillBottomNav(theme, accent),
        );
      },
    );
  }

  // ── Greeting Header ──
  Widget _buildGreetingHeader(ThemeProvider theme, Color accent) {
    final user = Supabase.instance.client.auth.currentUser;
    final avatarUrl = user?.userMetadata?['avatar_url'] as String?;
    final firstName = (_userName ?? 'Pengguna').split(' ').first;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Halo, $firstName',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                      letterSpacing: -0.8,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: _updateLocationFromGPS,
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: accent,
                        ),
                        const SizedBox(width: 3),
                        if (_isUpdatingLocation)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              color: accent,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Text(
                            _userLocation ?? 'Selamat datang di Tenmu',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Notif bell
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: theme.bgElevated,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.notifications_outlined,
                      color: theme.textPrimary,
                      size: 22,
                    ),
                  ),
                  if (_unreadNotifCount > 0)
                    Positioned(
                      top: -3,
                      right: -3,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _unreadNotifCount > 9 ? '9+' : '$_unreadNotifCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Avatar
            GestureDetector(
              onTap: () => _onNavTap(4),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.border, width: 2),
                  image: avatarUrl != null
                      ? DecorationImage(
                          image: CachedNetworkImageProvider(avatarUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                  color: theme.bgElevated,
                ),
                child: avatarUrl == null
                    ? Icon(
                        Icons.person_rounded,
                        color: theme.textSecondary,
                        size: 22,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Search Bar ──
  Widget _buildSearchBar(ThemeProvider theme, Color accent) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _showFilterSheet(context, theme, accent),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: theme.bgElevated,
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: theme.textHint, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      _searchQuery.isEmpty
                          ? 'Cari tempat, cafe, wisata...'
                          : _searchQuery,
                      style: TextStyle(
                        color: _searchQuery.isEmpty
                            ? theme.textHint
                            : theme.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    if (_searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _searchQuery = ''),
                        child: Icon(
                          Icons.close_rounded,
                          size: 18,
                          color: theme.textHint,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => _showFilterSheet(context, theme, accent),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color:
                    (_selectedCategories.isNotEmpty ||
                        _selectedSort != SortOption.terbaru)
                    ? accent
                    : theme.textPrimary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.textPrimary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(Icons.tune_rounded, color: theme.bgBase, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  // ── Section title ──
  Widget _buildSectionTitle(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Text(
        'Pilih destinasimu',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: theme.textPrimary,
          letterSpacing: -0.4,
        ),
      ),
    );
  }

  // ── Category Chips ──
  Widget _buildCategoryChips(ThemeProvider theme, Color accent) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        itemCount: _categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == 'Semua'
              ? _selectedCategoryTab == null || _selectedCategoryTab == 'Semua'
              : _selectedCategoryTab == cat;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCategoryTab = (cat == 'Semua') ? null : cat;
              });
              _scheduleQuery(immediate: true);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? theme.textPrimary : theme.bgElevated,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                cat == 'Semua'
                    ? cat
                    : '${PoiCategory.getCategoryEmoji(cat)} $cat',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? theme.bgBase : theme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Main Content ──
  Widget _buildMainContent(
    ThemeProvider theme,
    Color accent,
    PlacesProvider placesProvider,
    List<Map<String, dynamic>> allPlaces,
    List<Map<String, dynamic>> featured,
  ) {
    if (placesProvider.isLoading && placesProvider.placesList.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.2),
        child: Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2.5),
        ),
      );
    }

    if (placesProvider.error != null && placesProvider.placesList.isEmpty) {
      return _buildErrorState(theme, placesProvider, accent);
    }

    if (allPlaces.isEmpty) {
      return _buildEmptyState(theme, accent);
    }

    return RefreshIndicator(
      onRefresh: () async {
        final messenger = ScaffoldMessenger.of(context);
        placesProvider.clearError();
        await placesProvider.setQuery(_buildQuery(), force: true);
        await placesProvider.fetchFeatured(force: true);
        await _requestUserLocation();
        if (placesProvider.error != null &&
            placesProvider.placesList.isNotEmpty) {
          messenger.showSnackBar(
            SnackBar(
              content: const Text('Gagal memperbarui data'),
              backgroundColor: Colors.red.shade700,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      color: accent,
      backgroundColor: theme.bgElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Featured Carousel ──
          const SizedBox(height: 20),
          _buildFeaturedCarousel(
            // Fallback: jika tidak ada yang di-featured, tampilkan 8 terbaru
            featured.isNotEmpty ? featured : allPlaces.take(8).toList(),
            theme,
            accent,
            placesProvider,
            isFallback: featured.isEmpty,
          ),

          // ── 2. Semua Tempat list ──
          if (allPlaces.isNotEmpty) ...[
            _buildAllPlacesHeader(theme, accent, allPlaces.length),
            ...allPlaces.asMap().entries.map((e) {
              return _buildListPlaceCard(
                e.value,
                _getRating(placesProvider, e.value['id']),
                theme,
                accent,
                e.key,
              );
            }),
            // Footer status load-more
            if (placesProvider.isLoadingMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(
                    color: accent,
                    strokeWidth: 2,
                  ),
                ),
              )
            else if (!placesProvider.hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Tidak ada tempat lagi',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  // ── Featured Carousel (PageView with scale animation) ──
  Widget _buildFeaturedCarousel(
    List<Map<String, dynamic>> cards,
    ThemeProvider theme,
    Color accent,
    PlacesProvider provider, {
    bool isFallback = false,
  }) {
    final displayCards = cards.take(8).toList();
    if (displayCards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label section
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Icon(
                isFallback ? Icons.schedule_rounded : Icons.star_rounded,
                size: 16,
                color: isFallback ? theme.textSecondary : const Color(0xFFF4B942),
              ),
              const SizedBox(width: 6),
              Text(
                isFallback ? 'Terbaru' : 'Unggulan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isFallback ? theme.textSecondary : const Color(0xFFF4B942),
                  letterSpacing: 0.3,
                ),
              ),
              if (isFallback) ...[
                const Spacer(),
                Text(
                  'Belum ada tempat unggulan',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.textHint,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: _carouselCtrl,
            itemCount: displayCards.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (i) {
              _carouselPage.value = i.toDouble();
              setState(() => _currentCardPage = i);
            },
            itemBuilder: (context, index) {
              return ValueListenableBuilder<double>(
                valueListenable: _carouselPage,
                builder: (context, page, child) {
                  // delta: -1 (kiri) .. 0 (aktif) .. 1 (kanan)
                  final double delta = (index - page).clamp(-1.0, 1.0);

                  // Efek 3D cover-flow: rotate + scale + opacity
                  final double rotationY = delta * (35 * math.pi / 180);
                  final double translateX = -delta * 30;
                  final double scale = 1.0 - delta.abs() * 0.18;
                  final double opacity = 1.0 - delta.abs() * 0.4;

                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // perspective
                      ..translateByDouble(translateX, 0.0, 0.0, 1.0)
                      ..rotateY(rotationY)
                      ..scaleByDouble(scale, scale, 1.0, 1.0),
                    child: Opacity(
                      opacity: opacity.clamp(0.5, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 6,
                  ),
                  child: _buildFeaturedCardItem(
                    displayCards[index],
                    theme,
                    accent,
                    provider,
                  ),
                ),
              );
            },
          ),
        ),
          // Dot indicator
          const SizedBox(height: 14),
          if (displayCards.length > 1)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(displayCards.length, (i) {
                final active = i == _currentCardPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 22 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? (isFallback ? theme.textPrimary : const Color(0xFFF4B942))
                        : theme.textHint.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(999),
                  ),
                );
              }),
            ),
      ],
    );
  }

  Widget _buildFeaturedCardItem(
    Map<String, dynamic> place,
    ThemeProvider theme,
    Color accent,
    PlacesProvider provider,
  ) {
    final imageUrl = PoiImageHelper.primaryImageUrl(place);
    final rating = _getRating(provider, place['id']);
    final category = _resolveCategory(place);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PoiDetailScreen(place: place)),
      ),
      child: Container(
        height: 400,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image
            imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    memCacheWidth: 800,
                    fadeInDuration: const Duration(milliseconds: 300),
                    placeholder: (_, _) => Container(
                      color: theme.bgElevated,
                      child: Icon(
                        Icons.image_outlined,
                        size: 48,
                        color: theme.textHint,
                      ),
                    ),
                    errorWidget: (_, _, _) => Container(
                      color: theme.bgElevated,
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 48,
                        color: theme.textHint,
                      ),
                    ),
                  )
                : Container(
                    color: accent.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.storefront_rounded,
                      size: 64,
                      color: accent.withValues(alpha: 0.4),
                    ),
                  ),
            // Gradient overlay
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.3),
                    Colors.black.withValues(alpha: 0.88),
                  ],
                  stops: const [0.0, 0.35, 0.6, 1.0],
                ),
              ),
            ),
            // Top: category badge + heart
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          PoiCategory.getCategoryEmoji(category),
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          category,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: const Icon(
                      Icons.favorite_border_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ],
              ),
            ),
            // Bottom: info + button
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          size: 13,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            place['alamat'] ?? 'Indonesia',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      place['nama_tempat'] ?? 'Tanpa Nama',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFFC107),
                          size: 15,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          rating > 0 ? rating.toStringAsFixed(1) : 'Baru',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lihat Detail',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Colors.black87,
                              ),
                            ],
                          ),
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
  }

  // ── List Place Card (vertical, compact) ──
  Widget _buildListPlaceCard(
    Map<String, dynamic> place,
    double rating,
    ThemeProvider theme,
    Color accent,
    int index,
  ) {
    final imageUrl = PoiImageHelper.primaryImageUrl(place);
    final category = _resolveCategory(place);
    String? distanceText;
    if (_currentPosition != null) {
      final lat = (place['latitude'] as num?)?.toDouble();
      final lng = (place['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0 && lng != 0) {
        final dist = Haversine.distance(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          lat,
          lng,
        );
        distanceText = Haversine.formatDistance(dist);
      }
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - v)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PoiDetailScreen(place: place)),
        ),
        child: Container(
          margin: const EdgeInsets.fromLTRB(24, 0, 24, 14),
          decoration: BoxDecoration(
            color: theme.bgSurface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              // Image
              SizedBox(
                width: 100,
                height: 100,
                child: imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        memCacheWidth: 200,
                        placeholder: (_, _) => Container(
                          color: theme.bgElevated,
                          child: Icon(
                            Icons.image_outlined,
                            color: theme.textHint,
                            size: 24,
                          ),
                        ),
                        errorWidget: (_, _, _) => Container(
                          color: theme.bgElevated,
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: theme.textHint,
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        color: theme.bgElevated,
                        child: Icon(
                          Icons.storefront_outlined,
                          color: theme.textHint,
                          size: 24,
                        ),
                      ),
              ),
              // Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Category tag
                      Text(
                        '${PoiCategory.getCategoryEmoji(category)} $category',
                        style: TextStyle(
                          fontSize: 11,
                          color: accent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place['nama_tempat'] ?? 'Tanpa Nama',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        place['alamat'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 13,
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
                              color: accent,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              distanceText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (place['verification_status'] == 'verified')
                            Icon(
                              Icons.verified_rounded,
                              size: 14,
                              color: accent,
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
      ),
    );
  }

  // ── Error State ──
  Widget _buildErrorState(
    ThemeProvider theme,
    PlacesProvider provider,
    Color accent,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.15),
      child: Center(
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
                provider.setQuery(_buildQuery(), force: true);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Semua Tempat Header ──
  Widget _buildAllPlacesHeader(ThemeProvider theme, Color accent, int count) {
    final hasFilter =
        _searchQuery.isNotEmpty ||
        _selectedCategories.isNotEmpty ||
        _selectedCategoryTab != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasFilter ? 'Hasil Pencarian' : 'Semua Tempat',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$count tempat ditemukan',
                style: TextStyle(fontSize: 12, color: theme.textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Empty State ──
  Widget _buildEmptyState(ThemeProvider theme, Color accent) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.explore_outlined,
              size: 72,
              color: accent.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Tidak ada hasil untuk\n"$_searchQuery"'
                  : 'Belum ada tempat ditemukan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (_searchQuery.isNotEmpty ||
                _selectedCategories.isNotEmpty ||
                _selectedCategoryTab != null)
              GestureDetector(
                onTap: () => setState(() {
                  _searchQuery = '';
                  _selectedCategories = {};
                  _selectedCategoryTab = null;
                  _scheduleQuery(immediate: true);
                }),
                child: Text(
                  'Hapus pencarian',
                  style: TextStyle(color: accent, fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Pill Bottom Nav ──
  Widget _buildPillBottomNav(ThemeProvider theme, Color accent) {
    final isDark = theme.isDarkMode;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _pillNavItem(Icons.home_rounded, 0, accent),
              _pillNavItem(Icons.map_rounded, 1, accent),
              if (_isOwner) _pillNavAdd(accent),
              _pillNavItem(Icons.auto_awesome_rounded, 3, accent),
              _pillNavItem(Icons.person_rounded, 4, accent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pillNavItem(IconData icon, int index, Color accent) {
    final active = index == _currentNavIndex;
    return GestureDetector(
      onTap: () => _onNavTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          size: 24,
          color: active ? Colors.white : Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
  }

  Widget _pillNavAdd(Color accent) {
    return GestureDetector(
      onTap: () => _onNavTap(2),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: accent,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
      ),
    );
  }
}

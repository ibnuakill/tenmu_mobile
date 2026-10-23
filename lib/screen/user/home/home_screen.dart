import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import '../../../core/places_provider.dart';
import '../../../core/notification_center.dart';
import '../../../widgets/notification_popup.dart';
import '../../owner/add_place_screen.dart';
import '../map/route_map_screen.dart';
import '../user_notification_screen.dart';
import '../chat/chat_bot_sheet.dart';
import '../post/post_feed_screen.dart';
import '../widgets/sort_filter_widget.dart';
import '../settings/settings_screen.dart';
import 'home_controller.dart';
import 'widgets/home_widgets.dart';
import 'widgets/home_filter_sheet.dart';

/// Orchestrator: composes header, search, categories, carousel, list, bottom nav.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  static const Color _fallbackAccent = Color(0xFF1A7A6E);

  late final HomeController _ctrl;
  late final ScrollController _scrollCtrl;
  late final PageController _carouselCtrl;
  late final ValueNotifier<double> _carouselPage;
  late final AnimationController _entranceCtrl;
  late final AnimationController _cardCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  int _currentCardPage = 0;
  StreamSubscription<AppNotification>? _notifSub;
  bool _notifInited = false;

  @override
  void initState() {
    super.initState();
    _ctrl = HomeController(context: context);
    _scrollCtrl = ScrollController();
    _carouselCtrl = PageController(viewportFraction: 0.88);
    _carouselPage = ValueNotifier(0.0);

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

    _scrollCtrl.addListener(() =>
        _ctrl.onScrollNearEnd(_scrollCtrl, context.read<PlacesProvider>()));
    _carouselCtrl.addListener(() {
      final raw = _carouselCtrl.page ?? 0.0;
      _carouselPage.value = raw;
      final p = raw.round();
      if (p != _currentCardPage) {
        setState(() => _currentCardPage = p);
      }
    });

    _entranceCtrl.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _cardCtrl.forward();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ctrl.bootstrap();
      final provider = context.read<PlacesProvider>();
      provider.setQuery(_ctrl.buildQuery());
      provider.fetchFeatured();
      _ctrl.requestUserLocation();
      _ctrl.loadUserRole();
      _ctrl.loadUserProfile();
      _ctrl.loadUnreadCount();
      _initNotifications();
    });
  }

  /// Nyalakan pusat notifikasi: badge lonceng + pop-up saat pesan baru masuk.
  void _initNotifications() {
    if (_notifInited || !mounted) return;
    _notifInited = true;
    final nc = context.read<NotificationCenter>();
    _notifSub ??= nc.onNew.listen((n) {
      if (!mounted) return;
      showNotificationPopup(
        context,
        notification: n,
        onTap: _openNotifScreen,
      );
    });
    nc.start();
  }

  Future<void> _openNotifScreen() async {
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserNotificationScreen()),
    );
    if (mounted) context.read<NotificationCenter>().refresh();
  }

  @override
  void dispose() {
    _notifSub?.cancel();
    _ctrl.dispose();
    _entranceCtrl.dispose();
    _cardCtrl.dispose();
    _carouselPage.dispose();
    _carouselCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final placesProvider = context.watch<PlacesProvider>();
    final allPlaces = placesProvider.placesList;
    final featured = placesProvider.featuredList;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (light, dark) {
            final dynamicScheme = theme.isDarkMode ? dark : light;
            final accent = dynamicScheme?.primary ?? _fallbackAccent;
            return _buildScaffold(
              theme: theme,
              accent: accent,
              provider: placesProvider,
              allPlaces: allPlaces,
              featured: featured,
            );
          },
        );
      },
    );
  }

  /// Kartu carousel 3D di beranda: maksimal 10 POI, urut TERBARU di depan.
  List<Map<String, dynamic>> _featuredCards(
    List<Map<String, dynamic>> featured,
    List<Map<String, dynamic>> allPlaces,
  ) {
    final source = featured.isNotEmpty ? featured : allPlaces;
    final sorted = [...source]..sort((a, b) {
      final da = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final db = DateTime.tryParse(b['created_at']?.toString() ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da); // terbaru dulu
    });
    return sorted.take(10).toList();
  }

  Widget _buildScaffold({
    required ThemeProvider theme,
    required Color accent,
    required PlacesProvider provider,
    required List<Map<String, dynamic>> allPlaces,
    required List<Map<String, dynamic>> featured,
  }) {
    return Scaffold(
      backgroundColor: theme.bgBase,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: CustomScrollView(
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: HomeGreetingHeader(
                  theme: theme,
                  userName: _ctrl.userName ?? 'Pengguna',
                  userLocation: _ctrl.userLocation,
                  isUpdatingLocation: _ctrl.isUpdatingLocation,
                  unreadNotifCount: context.watch<NotificationCenter>().unreadCount,
                  onTapLocation: () => _ctrl.updateLocationFromGPS(
                    ScaffoldMessenger.of(context),
                  ),
                  onTapNotification: _openNotifScreen,
                ),
              ),
              SliverToBoxAdapter(
                child: HomeSearchBar(
                  theme: theme,
                  accent: accent,
                  searchQuery: _ctrl.searchQuery,
                  hasActiveFilter: _hasActiveFilter(),
                  onTapSearch: () => _openFilterSheet(accent),
                  onClearSearch: () => _ctrl.clearSearchQuery(provider),
                  onTapFilter: () => _openFilterSheet(accent),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              SliverToBoxAdapter(
                child: HomeSectionTitle(
                  theme: theme,
                  title: 'Pilih destinasimu',
                ),
              ),
              SliverToBoxAdapter(
                child: _buildContent(theme, accent, provider, allPlaces, featured),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: HomePillBottomNav(
        theme: theme,
        accent: accent,
        currentIndex: _ctrl.currentNavIndex,
        isOwner: _ctrl.isOwner,
        onTap: _onNavTap,
      ),
    );
  }

  bool _hasActiveFilter() => _ctrl.selectedCategories.isNotEmpty ||
      _ctrl.selectedSort != SortOption.terbaru;

  Widget _buildContent(
    ThemeProvider theme,
    Color accent,
    PlacesProvider provider,
    List<Map<String, dynamic>> allPlaces,
    List<Map<String, dynamic>> featured,
  ) {
    if (provider.isLoading && provider.placesList.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.2),
        child: Center(
          child: CircularProgressIndicator(color: accent, strokeWidth: 2.5),
        ),
      );
    }
    if (provider.error != null && provider.placesList.isEmpty) {
      return HomeErrorState(
        theme: theme,
        accent: accent,
        onRetry: () {
          provider.clearError();
          provider.setQuery(_ctrl.buildQuery(), force: true);
        },
      );
    }
    if (allPlaces.isEmpty) {
      return HomeEmptyState(
        theme: theme,
        accent: accent,
        searchQuery: _ctrl.searchQuery,
        hasFilter: _hasActiveFilter() || _ctrl.searchQuery.isNotEmpty,
        onClearFilter: () {
          _ctrl.resetFilters(provider);
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () => _ctrl.refreshAll(provider),
      color: accent,
      backgroundColor: theme.bgElevated,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          HomeFeaturedCarousel(
            theme: theme,
            accent: accent,
            cards: _featuredCards(featured, allPlaces),
            controller: _carouselCtrl,
            pageNotifier: _carouselPage,
            currentPage: _currentCardPage,
            isFallback: featured.isEmpty,
            provider: provider,
            ratingOf: (id) => provider.ratings[id] ?? 0.0,
          ),
          if (allPlaces.isNotEmpty) ...[
            HomeAllPlacesHeader(
              theme: theme,
              count: allPlaces.length,
              hasFilter: _hasActiveFilter() || _ctrl.searchQuery.isNotEmpty,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.65,
                ),
                itemCount: allPlaces.length,
                itemBuilder: (context, index) {
                  final place = allPlaces[index];
                  return HomePoiGridCard(
                    place: place,
                    rating: provider.ratings[place['id']] ?? 0.0,
                    theme: theme,
                    accent: accent,
                    index: index,
                    userPosition: _ctrl.currentPosition,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (provider.isLoadingMore)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (!provider.hasMore)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Tidak ada tempat lagi',
                    style: TextStyle(color: theme.textSecondary, fontSize: 13),
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

  void _openFilterSheet(Color accent) {
    HomeFilterSheet.show(
      context,
      initialQuery: _ctrl.searchQuery,
      initialSort: _ctrl.selectedSort,
      initialCategories: _ctrl.selectedCategories,
      onQueryChanged: (v) {
        _ctrl.patchQuery(v);
        _ctrl.scheduleQuery(context.read<PlacesProvider>());
      },
      onCategoriesChanged: (v) {
        _ctrl.setCategories(v, context.read<PlacesProvider>());
      },
      onSortChanged: (s) {
        _ctrl.setSort(s, context.read<PlacesProvider>());
      },
      onReset: () => _ctrl.resetFilters(context.read<PlacesProvider>()),
    ).whenComplete(() {
      if (!mounted) return;
      _ctrl.scheduleQuery(context.read<PlacesProvider>(), immediate: true);
    });
  }

  void _onNavTap(int index) {
    if (index == _ctrl.currentNavIndex && index != 0) return;
    if (index == 0) {
      Navigator.of(context).popUntil((r) => r.isFirst);
      _ctrl.setNavIndex(0);
      return;
    }
    if (index == 2) {
      if (!_ctrl.isOwner) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddPlaceScreen()),
      ).then((_) {
        if (mounted) _ctrl.setNavIndex(0);
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
    if (index == 5) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PostFeedScreen()),
      ).then((_) {
        if (mounted) _ctrl.setNavIndex(0);
      });
      return;
    }
    _ctrl.setNavIndex(index);
    switch (index) {
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RouteMapScreen(
              placesList: context.read<PlacesProvider>().placesList,
            ),
          ),
        ).then((_) {
          if (mounted) _ctrl.setNavIndex(0);
        });
      case 4:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ).then((_) {
          if (mounted) _ctrl.setNavIndex(0);
        });
    }
  }
}

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import '../../../core/places_provider.dart';
import '../../../core/poi_category.dart';
import '../../owner/add_place_screen.dart';
import '../map/route_map_screen.dart';
import '../user_notification_screen.dart';
import '../chat/chat_bot_sheet.dart';
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

  final List<String> _categories = ['Semua', ...PoiCategory.allCategories];

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
    });
  }

  @override
  void dispose() {
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

  Widget _buildScaffold({
    required ThemeProvider theme,
    required Color accent,
    required PlacesProvider provider,
    required List<Map<String, dynamic>> allPlaces,
    required List<Map<String, dynamic>> featured,
  }) {
    return Scaffold(
      backgroundColor: theme.bgBase,
      extendBody: true,
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
                  unreadNotifCount: _ctrl.unreadNotifCount,
                  avatarUrl: _ctrl.avatarUrl,
                  onTapLocation: () => _ctrl.updateLocationFromGPS(
                    ScaffoldMessenger.of(context),
                  ),
                  onTapNotification: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UserNotificationScreen(),
                      ),
                    );
                    _ctrl.loadUnreadCount();
                  },
                  onTapAvatar: () => _onNavTap(4),
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
                child: HomeCategoryChips(
                  theme: theme,
                  accent: accent,
                  categories: _categories,
                  selectedCategoryTab: _ctrl.selectedCategoryTab,
                  onChanged: (v) => _ctrl.setCategoryTab(v, provider),
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

  bool _hasActiveFilter() =>
      _ctrl.selectedCategories.isNotEmpty ||
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
        padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.2),
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
          _ctrl.setCategoryTab(null, provider);
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
            cards: featured.isNotEmpty ? featured : allPlaces.take(8).toList(),
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
            ...allPlaces.asMap().entries.map(
                  (e) => HomePoiListCard(
                    place: e.value,
                    rating: provider.ratings[e.value['id']] ?? 0.0,
                    theme: theme,
                    accent: accent,
                    index: e.key,
                    userPosition: _ctrl.currentPosition,
                  ),
                ),
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
      initialCategories: _ctrl.selectedCategories,
      initialSort: _ctrl.selectedSort,
      onQueryChanged: (v) {
        _ctrl.patchQuery(v);
        _ctrl.scheduleQuery(context.read<PlacesProvider>());
      },
      onCategoriesChanged: (s) {
        _ctrl.setCategories(s, context.read<PlacesProvider>());
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

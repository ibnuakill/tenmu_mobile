import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/poi_image_helper.dart';
import '../../../core/theme_provider.dart';
import '../map/route_map_screen.dart';
import 'poi_detail_controller.dart';
import 'widgets/detail_bottom_bar.dart';
import 'widgets/detail_fade_appbar.dart';
import 'widgets/detail_hero.dart';
import 'widgets/detail_image_preview.dart';
import 'widgets/detail_stats_tab.dart';
import 'widgets/detail_tabs.dart';

/// Composer: hero image + stats + tabs + bottom action bar.
/// Business logic (favorite, distance, stats) lives in [PoiDetailController].
class PoiDetailScreen extends StatefulWidget {
  final Map<String, dynamic> place;
  const PoiDetailScreen({super.key, required this.place});

  @override
  State<PoiDetailScreen> createState() => _PoiDetailScreenState();
}

class _PoiDetailScreenState extends State<PoiDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  late final ScrollController _scrollController;
  late final PoiDetailController _ctrl;

  double _appBarOpacity = 0.0;
  static const double _appBarFadeStart = 200.0;
  static const double _appBarFadeEnd = 280.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _ctrl = PoiDetailController(context: context, place: widget.place);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final theme = Provider.of<ThemeProvider>(context, listen: false);
      _ctrl.bootstrap(theme);
    });
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    double opacity = 0.0;
    if (offset > _appBarFadeStart) {
      opacity =
          ((offset - _appBarFadeStart) / (_appBarFadeEnd - _appBarFadeStart))
              .clamp(0.0, 1.0);
    }
    if (opacity != _appBarOpacity) {
      setState(() => _appBarOpacity = opacity);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onBack() => Navigator.pop(context);

  Future<void> _launchWhatsApp(ThemeProvider theme) async {
    final num = _ctrl.phoneNumber;
    if (num == null) return;
    String normalized = num;
    if (normalized.startsWith('0')) normalized = '62${normalized.substring(1)}';
    final waUri = Uri.parse('https://wa.me/$normalized');
    final telUri = Uri.parse('tel:$num');
    try {
      if (await canLaunchUrl(waUri)) {
        await launchUrl(waUri, mode: LaunchMode.externalApplication);
      } else if (await canLaunchUrl(telUri)) {
        await launchUrl(telUri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tidak dapat membuka WhatsApp untuk $num'),
            backgroundColor: theme.snackError,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: theme.snackError,
        ),
      );
    }
  }

  void _goToRoute() {
    if (!_ctrl.hasLocation) return;
    final lat = _ctrl.lat;
    final lng = _ctrl.lng;
    if (lat == null || lng == null) return;
    final categoryStr =
        (widget.place['kategori'] ?? widget.place['category'])?.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RouteMapScreen(
          destinationLat: lat,
          destinationLng: lng,
          destinationName: widget.place['nama_tempat'] ?? '',
          destinationCategory: categoryStr,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final imageUrls = PoiImageHelper.extractImageUrls(widget.place);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.bgBase,
        extendBodyBehindAppBar: true,
        body: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) {
            return Stack(
              children: [
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverToBoxAdapter(
                      child: DetailHero(
                        theme: theme,
                        imageUrls: imageUrls,
                        placeName: _ctrl.placeName,
                        address: _ctrl.address,
                        isFeatured: _ctrl.isFeatured,
                        isFavorite: _ctrl.isFavorite,
                        isLoadingFavorite: _ctrl.isLoadingFavorite,
                        topPadding: topPad,
                        onBack: _onBack,
                        onTapFavorite: _ctrl.toggleFavorite,
                        onShowImagePreview: (i) =>
                            DetailImagePreview.show(
                          context,
                          imageUrls: imageUrls,
                          initialIndex: i,
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 100 + bottomPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(16, 20, 16, 0),
                              child: DetailStatsRow(
                                theme: theme,
                                durationText: _ctrl.durationText,
                                distanceText: _ctrl.distanceText,
                                avgRating: _ctrl.avgRating,
                                reviewCount: _ctrl.reviewCount,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: DetailPillTabBar(
                                controller: _tabController,
                                theme: theme,
                                tabs: const ['Detail', 'Ulasan'],
                              ),
                            ),
                            const SizedBox(height: 24),
                            DetailTabContent(
                              tabController: _tabController,
                              theme: theme,
                              place: widget.place,
                              imageUrls: imageUrls,
                              onShowImage: (i) =>
                                  DetailImagePreview.show(
                                context,
                                imageUrls: imageUrls,
                                initialIndex: i,
                              ),
                              placeId: widget.place['id'],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_appBarOpacity > 0)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: DetailFadeAppBar(
                      theme: theme,
                      opacity: _appBarOpacity,
                      topPadding: topPad,
                      title: _ctrl.placeName,
                      isFavorite: _ctrl.isFavorite,
                      isLoadingFavorite: _ctrl.isLoadingFavorite,
                      onBack: _onBack,
                      onTapFavorite: _ctrl.toggleFavorite,
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: DetailBottomActionBar(
                    theme: theme,
                    bottomPad: bottomPad,
                    hasPhone: _ctrl.hasPhone,
                    hasLocation: _ctrl.hasLocation,
                    onWhatsApp: () => _launchWhatsApp(theme),
                    onRoute: _goToRoute,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

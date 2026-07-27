import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_image_helper.dart';
import '../../core/poi_facility.dart';
import '../../core/haversine.dart';
import 'route_map_screen.dart';
import 'review_section.dart';

class PoiDetailScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const PoiDetailScreen({super.key, required this.place});

  @override
  State<PoiDetailScreen> createState() => _PoiDetailScreenState();
}

class _PoiDetailScreenState extends State<PoiDetailScreen>
    with SingleTickerProviderStateMixin {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;

  // Tab controller for Details / Route / Reviews
  late TabController _tabController;

  // Scroll offset for dynamic appbar opacity
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0.0;
  static const double _appBarFadeStart = 200.0;
  static const double _appBarFadeEnd = 280.0;

  // ── Stats data ──────────────────────────────────────────────────────────
  String? _distanceText;      // e.g. "3.2 km"
  String? _durationText;      // e.g. "15 mnt"
  double _avgRating = 0.0;    // e.g. 4.9
  int _reviewCount = 0;       // e.g. 124

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkFavoriteStatus();
    _scrollController.addListener(_onScroll);
    _fetchDistance();
    _fetchReviewStats();
  }

  /// Hitung jarak & durasi rute user → tempat via OSRM Routing API (fallback: Haversine)
  Future<void> _fetchDistance() async {
    try {
      final lat = (widget.place['latitude'] as num?)?.toDouble();
      final lng = (widget.place['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) return;

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 5),
        ),
      );

      // Default fallback (Haversine)
      final fallbackDistKm = Haversine.distance(pos.latitude, pos.longitude, lat, lng);
      String dist = Haversine.formatDistance(fallbackDistKm);
      final fallbackMins = (fallbackDistKm / 40.0 * 60).round();
      String durText = fallbackMins < 60
          ? '${fallbackMins > 0 ? fallbackMins : 1} mnt'
          : '${fallbackMins ~/ 60} jam ${fallbackMins % 60 > 0 ? '${fallbackMins % 60} mnt' : ''}'.trim();

      // Coba fetch rute aktual dari OSRM
      try {
        final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/driving/'
          '${pos.longitude},${pos.latitude};$lng,$lat?overview=false',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          final data = json.decode(res.body);
          if (data['code'] == 'Ok' && (data['routes'] as List).isNotEmpty) {
            final route = data['routes'][0];
            final double distanceMeters = (route['distance'] as num).toDouble();
            final double durationSeconds = (route['duration'] as num).toDouble();

            final routeDistKm = distanceMeters / 1000.0;
            dist = Haversine.formatDistance(routeDistKm);

            final minutes = (durationSeconds / 60.0).round();
            if (minutes < 60) {
              durText = '${minutes > 0 ? minutes : 1} mnt';
            } else {
              final hours = minutes ~/ 60;
              final mins = minutes % 60;
              durText = mins > 0 ? '$hours jam $mins mnt' : '$hours jam';
            }
          }
        }
      } catch (e) {
        debugPrint('OSRM fetch fallback to Haversine: $e');
      }

      if (mounted) {
        setState(() {
          _distanceText = dist;
          _durationText = durText;
        });
      }
    } catch (_) {
      // Geolocator/GPS gagal — tetap tampilkan '--'
    }
  }

  /// Ambil rata-rata rating & jumlah ulasan dari Supabase
  Future<void> _fetchReviewStats() async {
    try {
      final id = widget.place['id'];
      if (id == null) return;
      final data = await Supabase.instance.client
          .from('reviews')
          .select('rating')
          .eq('umkm_id', id);
      if (!mounted) return;
      final list = List<Map<String, dynamic>>.from(data);
      if (list.isEmpty) return;
      final avg = list.map((r) => (r['rating'] as num).toDouble()).reduce((a, b) => a + b) / list.length;
      setState(() {
        _avgRating = avg;
        _reviewCount = list.length;
      });
    } catch (_) {}
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
    _imagePageController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // ─── Image full-screen preview ─────────────────────────────────────────────

  void _showImagePreview(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
    ThemeProvider theme,
  ) {
    final previewController = PageController(initialPage: initialIndex);
    int previewIndex = initialIndex;

    showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Stack(
              children: [
                PageView.builder(
                  controller: previewController,
                  itemCount: imageUrls.length,
                  onPageChanged: (i) => setDialogState(() => previewIndex = i),
                  itemBuilder: (_, index) => InteractiveViewer(
                    minScale: 1.0,
                    maxScale: 5.0,
                    child: Center(
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.contain,
                        errorBuilder: (_, _, _) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white38,
                          size: 48,
                        ),
                      ),
                    ),
                  ),
                ),
                if (imageUrls.length > 1)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 32,
                    child: _ImageDotIndicator(
                      count: imageUrls.length,
                      currentIndex: previewIndex,
                    ),
                  ),
                Positioned(
                  top: 48,
                  right: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(dialogContext),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.black38,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ─── Supabase helpers ──────────────────────────────────────────────────────

  Future<void> _checkFavoriteStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() => _isLoadingFavorite = false);
      return;
    }
    try {
      final response = await Supabase.instance.client
          .from('favorites')
          .select('id')
          .eq('user_id', user.id)
          .eq('umkm_id', widget.place['id'])
          .maybeSingle();
      if (mounted) {
        setState(() {
          _isFavorite = response != null;
          _isLoadingFavorite = false;
        });
      }
    } catch (e) {
      debugPrint('Error checking favorite: $e');
      if (mounted) setState(() => _isLoadingFavorite = false);
    }
  }

  Future<void> _toggleFavorite() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan login untuk menyimpan favorit.')),
      );
      return;
    }
    setState(() => _isFavorite = !_isFavorite);
    try {
      if (_isFavorite) {
        await Supabase.instance.client.from('favorites').insert({
          'user_id': user.id,
          'umkm_id': widget.place['id'],
        });
      } else {
        await Supabase.instance.client
            .from('favorites')
            .delete()
            .eq('user_id', user.id)
            .eq('umkm_id', widget.place['id']);
      }
    } catch (e) {
      setState(() => _isFavorite = !_isFavorite);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memperbarui favorit: $e')),
        );
      }
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final topPad = MediaQuery.of(context).padding.top;
    final bottomPad = MediaQuery.of(context).padding.bottom;

    final double? lat = widget.place['latitude'] != null
        ? (widget.place['latitude'] is int
              ? (widget.place['latitude'] as int).toDouble()
              : widget.place['latitude'] as double)
        : null;
    final double? lng = widget.place['longitude'] != null
        ? (widget.place['longitude'] is int
              ? (widget.place['longitude'] as int).toDouble()
              : widget.place['longitude'] as double)
        : null;
    final bool hasLocation = lat != null && lng != null;
    final String? nomorTelepon = widget.place['nomor_telepon'];
    final String? jamBuka = widget.place['jam_buka'];
    final String? jamTutup = widget.place['jam_tutup'];
    final imageUrls = PoiImageHelper.extractImageUrls(widget.place);
    final bool hasPhone = nomorTelepon != null && nomorTelepon.isNotEmpty;

    // ── Open/close logic ──────────────────────────────────────────────────
    // ignore: unused_local_variable
    bool isOpen = false;
    if (jamBuka != null && jamTutup != null) {
      try {
        final now = TimeOfDay.now();
        final cur = now.hour * 60 + now.minute;
        final op = jamBuka.split(':');
        final cl = jamTutup.split(':');
        final openMin = int.parse(op[0]) * 60 + int.parse(op[1]);
        final closeMin = int.parse(cl[0]) * 60 + int.parse(cl[1]);
        isOpen = closeMin < openMin
            ? (cur >= openMin || cur <= closeMin)
            : (cur >= openMin && cur <= closeMin);
      } catch (_) {}
    }

    // ── WhatsApp launcher ──────────────────────────────────────────────────
    Future<void> launchWhatsApp() async {
      if (!hasPhone) return;
      String num = nomorTelepon;
      if (num.startsWith('0')) num = '62${num.substring(1)}';
      final waUri = Uri.parse('https://wa.me/$num');
      final telUri = Uri.parse('tel:$nomorTelepon');
      try {
        if (await canLaunchUrl(waUri)) {
          await launchUrl(waUri, mode: LaunchMode.externalApplication);
        } else if (await canLaunchUrl(telUri)) {
          await launchUrl(telUri);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Tidak dapat membuka WhatsApp untuk $nomorTelepon',
                ),
                backgroundColor: theme.snackError,
              ),
            );
          }
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error: $e'),
              backgroundColor: theme.snackError,
            ),
          );
        }
      }
    }

    void goToRoute() {
      if (!hasLocation) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RouteMapScreen(
            destinationLat: lat,
            destinationLng: lng,
            destinationName: widget.place['nama_tempat'] ?? '',
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: theme.bgBase,
        extendBodyBehindAppBar: true,
        body: Stack(
          children: [
            // ── Scrollable content ───────────────────────────────────────
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── Hero image block ─────────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 320,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Photo carousel
                        imageUrls.isNotEmpty
                            ? PageView.builder(
                                controller: _imagePageController,
                                itemCount: imageUrls.length,
                                onPageChanged: (i) =>
                                    setState(() => _currentImageIndex = i),
                                itemBuilder: (_, index) => Image.network(
                                  imageUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    color: theme.bgSurface,
                                    child: Center(
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: theme.textHint,
                                        size: 42,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                color: theme.bgSurface,
                                child: Center(
                                  child: Icon(
                                    Icons.storefront_outlined,
                                    size: 72,
                                    color: theme.textHint,
                                  ),
                                ),
                              ),

                        // Bottom gradient overlay
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.35, 0.72, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Color(0x55000000),
                                  Color(0xBB000000),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Top gradient for nav button legibility
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.0, 0.28],
                                colors: [Color(0x77000000), Colors.transparent],
                              ),
                            ),
                          ),
                        ),

                        // Tap-to-preview overlay
                        if (imageUrls.isNotEmpty)
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.translucent,
                              onTap: () => _showImagePreview(
                                context,
                                imageUrls,
                                _currentImageIndex,
                                theme,
                              ),
                            ),
                          ),

                        // ── Back + Favorite buttons ──────────────────────
                        Positioned(
                          top: topPad + 8,
                          left: 12,
                          right: 12,
                          child: Row(
                            children: [
                              _CircleIconButton(
                                icon: Icons.arrow_back_ios_new_rounded,
                                onTap: () => Navigator.pop(context),
                              ),
                              const Spacer(),
                              if (!_isLoadingFavorite)
                                _CircleIconButton(
                                  icon: _isFavorite
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  iconColor: _isFavorite
                                      ? Colors.redAccent
                                      : Colors.white,
                                  onTap: _toggleFavorite,
                                ),
                            ],
                          ),
                        ),

                        // ── Location + name overlay ──────────────────────
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 20,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Featured badge
                              if (widget.place['is_featured'] == true) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star_rounded,
                                        size: 12,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Rekomendasi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],

                              // Address row
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 13,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      widget.place['alamat'] ?? '-',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.white70,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),

                              // Place name
                              Text(
                                widget.place['nama_tempat'] ?? 'Tanpa Nama',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  height: 1.2,
                                  shadows: [
                                    Shadow(
                                      blurRadius: 8,
                                      color: Colors.black45,
                                    ),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),

                        // ── Image dot indicators ─────────────────────────
                        if (imageUrls.length > 1)
                          Positioned(
                            right: 16,
                            bottom: 24,
                            child: _ImageDotIndicator(
                              count: imageUrls.length,
                              currentIndex: _currentImageIndex,
                              compact: true,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Content below image ─────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 100 + bottomPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Stats row ─────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                          child: _StatsRow(
                            theme: theme,
                            durationText: _durationText,
                            distanceText: _distanceText,
                            avgRating: _avgRating,
                            reviewCount: _reviewCount,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── Tab bar ───────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _PillTabBar(
                            controller: _tabController,
                            theme: theme,
                            tabs: const ['Detail', 'Rute', 'Ulasan'],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ── Tab content ───────────────────────────────────
                        _TabContent(
                          tabController: _tabController,
                          theme: theme,
                          place: widget.place,
                          imageUrls: imageUrls,
                          hasLocation: hasLocation,
                          onShowImage: (index) => _showImagePreview(
                            context,
                            imageUrls,
                            index,
                            theme,
                          ),
                          placeId: widget.place['id'],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Floating appbar (fades in on scroll) ──────────────────────
            if (_appBarOpacity > 0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AnimatedOpacity(
                  opacity: _appBarOpacity,
                  duration: Duration.zero,
                  child: Container(
                    height: topPad + 56,
                    color: theme.bgBase.withValues(alpha: _appBarOpacity),
                    child: Padding(
                      padding: EdgeInsets.only(top: topPad),
                      child: Row(
                        children: [
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: theme.textPrimary,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                          Expanded(
                            child: Text(
                              widget.place['nama_tempat'] ?? '',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: theme.textPrimary,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                          if (!_isLoadingFavorite)
                            IconButton(
                              icon: Icon(
                                _isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: _isFavorite
                                    ? Colors.redAccent
                                    : theme.textPrimary,
                              ),
                              onPressed: _toggleFavorite,
                            ),
                          const SizedBox(width: 8),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            // ── Sticky bottom action bar ─────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomActionBar(
                theme: theme,
                bottomPad: bottomPad,
                hasPhone: hasPhone,
                hasLocation: hasLocation,
                onWhatsApp: launchWhatsApp,
                onRoute: goToRoute,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stats Row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final ThemeProvider theme;
  final String? durationText;
  final String? distanceText;
  final double avgRating;
  final int reviewCount;

  const _StatsRow({
    required this.theme,
    this.durationText,
    this.distanceText,
    this.avgRating = 0.0,
    this.reviewCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Format review: 4.9 (124)
    final ratingText = reviewCount > 0
        ? avgRating.toStringAsFixed(1)
        : '--';
    final reviewLabel = reviewCount > 0
        ? '${_formatCount(reviewCount)} Ulasan'
        : 'Ulasan';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.border.withValues(alpha: 0.5)),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // ── Durasi Perjalanan ────────────────────────────────────────
            Expanded(
              child: _StatItem(
                icon: Icons.access_time_outlined,
                iconColor: theme.btnPrimary,
                value: durationText ?? '--',
                label: 'Durasi',
                theme: theme,
              ),
            ),

            VerticalDivider(
              color: theme.border.withValues(alpha: 0.5),
              thickness: 1,
              width: 1,
            ),

            // ── Jarak ────────────────────────────────────────────────────
            Expanded(
              child: _StatItem(
                icon: Icons.location_on_outlined,
                iconColor: theme.btnPrimary,
                value: distanceText ?? '--',
                label: 'Jarak',
                theme: theme,
              ),
            ),

            VerticalDivider(
              color: theme.border.withValues(alpha: 0.5),
              thickness: 1,
              width: 1,
            ),

            // ── Ulasan ───────────────────────────────────────────────────
            Expanded(
              child: _StatItem(
                icon: Icons.star_outline_rounded,
                iconColor: Colors.amber,
                value: ratingText,
                label: reviewLabel,
                theme: theme,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCount(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return n.toString();
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final ThemeProvider theme;

  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: theme.textPrimary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 3),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: theme.textHint,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Pill Tab Bar ───────────────────────────────────────────────────────────────

class _PillTabBar extends StatefulWidget {
  final TabController controller;
  final ThemeProvider theme;
  final List<String> tabs;

  const _PillTabBar({
    required this.controller,
    required this.theme,
    required this.tabs,
  });

  @override
  State<_PillTabBar> createState() => _PillTabBarState();
}

class _PillTabBarState extends State<_PillTabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: widget.theme.bgSurface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: widget.theme.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: List.generate(widget.tabs.length, (i) {
          final active = widget.controller.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? widget.theme.btnPrimary : Colors.transparent,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Text(
                  widget.tabs[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: active
                        ? widget.theme.btnLabel
                        : widget.theme.textSecondary,
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Tab Content ───────────────────────────────────────────────────────────────

class _TabContent extends StatelessWidget {
  final TabController tabController;
  final ThemeProvider theme;
  final Map<String, dynamic> place;
  final List<String> imageUrls;
  final bool hasLocation;
  final void Function(int index) onShowImage;
  final dynamic placeId;

  const _TabContent({
    required this.tabController,
    required this.theme,
    required this.place,
    required this.imageUrls,
    required this.hasLocation,
    required this.onShowImage,
    required this.placeId,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: tabController,
      builder: (context, _) {
        switch (tabController.index) {
          case 0:
            return _DetailsTab(
              theme: theme,
              place: place,
              imageUrls: imageUrls,
              onShowImage: onShowImage,
            );
          case 1:
            return _RouteTab(theme: theme, hasLocation: hasLocation);
          case 2:
            return _ReviewsTab(theme: theme, placeId: placeId);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

// ─── Details Tab ───────────────────────────────────────────────────────────────

class _DetailsTab extends StatelessWidget {
  final ThemeProvider theme;
  final Map<String, dynamic> place;
  final List<String> imageUrls;
  final void Function(int) onShowImage;

  const _DetailsTab({
    required this.theme,
    required this.place,
    required this.imageUrls,
    required this.onShowImage,
  });

  @override
  Widget build(BuildContext context) {
    final facilities = PoiFacility.fromList(place['fasilitas']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── About section ──────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tentang ${place['nama_tempat'] ?? 'Tempat Ini'}',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                place['deskripsi'] ?? 'Tidak ada deskripsi yang tersedia.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.75,
                  color: theme.textSecondary,
                ),
              ),
            ],
          ),
        ),

        // ── Fasilitas ──────────────────────────────────────────────────
        if (facilities.isNotEmpty) ...[
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Text(
              'Fasilitas',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: facilities
                  .map(
                    (f) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: theme.bgSurface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: theme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(f.icon, size: 15, color: theme.btnPrimary),
                          const SizedBox(width: 6),
                          Text(
                            f.label,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: theme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],

        // ── Gallery ────────────────────────────────────────────────────
        if (imageUrls.isNotEmpty) ...[
          const SizedBox(height: 28),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Galeri',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: theme.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () => onShowImage(0),
                  child: Text(
                    'Lihat Semua',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: theme.btnPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: imageUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) => GestureDetector(
                onTap: () => onShowImage(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    imageUrls[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 120,
                      height: 120,
                      color: theme.bgSurface,
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: theme.textHint,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Route Tab ─────────────────────────────────────────────────────────────────

class _RouteTab extends StatelessWidget {
  final ThemeProvider theme;
  final bool hasLocation;

  const _RouteTab({required this.theme, required this.hasLocation});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.border),
        ),
        child: hasLocation
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_outlined, size: 40, color: theme.btnPrimary),
                  const SizedBox(height: 12),
                  Text(
                    'Tekan "Mulai Perjalanan" di bawah untuk\nmembuka navigasi ke tempat ini.',
                    style: TextStyle(
                      fontSize: 14,
                      color: theme.textSecondary,
                      height: 1.6,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_off_outlined,
                    size: 40,
                    color: theme.textHint,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Koordinat lokasi belum tersedia.',
                    style: TextStyle(fontSize: 14, color: theme.textHint),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }
}

// ─── Reviews Tab ───────────────────────────────────────────────────────────────

class _ReviewsTab extends StatelessWidget {
  final ThemeProvider theme;
  final dynamic placeId;

  const _ReviewsTab({required this.theme, required this.placeId});

  @override
  Widget build(BuildContext context) {
    if (placeId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(
          'Ulasan tidak tersedia.',
          style: TextStyle(color: theme.textHint),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: ReviewSection(umkmId: placeId as int),
    );
  }
}

// ─── Bottom Action Bar ─────────────────────────────────────────────────────────

class _BottomActionBar extends StatefulWidget {
  final ThemeProvider theme;
  final double bottomPad;
  final bool hasPhone;
  final bool hasLocation;
  final VoidCallback onWhatsApp;
  final VoidCallback onRoute;

  const _BottomActionBar({
    required this.theme,
    required this.bottomPad,
    required this.hasPhone,
    required this.hasLocation,
    required this.onWhatsApp,
    required this.onRoute,
  });

  @override
  State<_BottomActionBar> createState() => _BottomActionBarState();
}

class _BottomActionBarState extends State<_BottomActionBar> {
  double _dragPosition = 0.0;
  bool _isActionTriggered = false;

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + widget.bottomPad),
          decoration: BoxDecoration(
            color: widget.theme.bgBase.withValues(alpha: 0.85),
            border: Border(top: BorderSide(color: widget.theme.border, width: 0.5)),
          ),
          child: Row(
            children: [
              // WhatsApp / Phone pill button
              if (widget.hasPhone) ...[
                GestureDetector(
                  onTap: widget.onWhatsApp,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: widget.theme.btnPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      color: widget.theme.btnLabel,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],

              // Slide to Action Button
              Expanded(
                child: widget.hasLocation
                    ? LayoutBuilder(
                        builder: (context, constraints) {
                          const double thumbSize = 44.0;
                          final double maxDrag = constraints.maxWidth - thumbSize - 8.0;

                          return Container(
                            height: 52,
                            decoration: BoxDecoration(
                              color: widget.theme.bgElevated,
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(color: widget.theme.border),
                            ),
                            child: Stack(
                              alignment: Alignment.centerLeft,
                              children: [
                                // Background Text + Chevrons Hint
                                Center(
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 150),
                                    opacity: (1.0 - (_dragPosition / maxDrag)).clamp(0.0, 1.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Geser Mulai Perjalanan',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: widget.theme.textPrimary,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.keyboard_double_arrow_right_rounded,
                                          size: 18,
                                          color: widget.theme.textHint,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                                // Draggable Thumb Button
                                Positioned(
                                  left: 4.0 + _dragPosition,
                                  child: GestureDetector(
                                    onHorizontalDragUpdate: (details) {
                                      if (_isActionTriggered) return;
                                      setState(() {
                                        _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDrag);
                                      });
                                    },
                                    onHorizontalDragEnd: (details) {
                                      if (_isActionTriggered) return;
                                      if (_dragPosition >= maxDrag * 0.8) {
                                        setState(() {
                                          _dragPosition = maxDrag;
                                          _isActionTriggered = true;
                                        });
                                        widget.onRoute();
                                        // Reset slider position after short delay when back
                                        Future.delayed(const Duration(milliseconds: 600), () {
                                          if (mounted) {
                                            setState(() {
                                              _dragPosition = 0.0;
                                              _isActionTriggered = false;
                                            });
                                          }
                                        });
                                      } else {
                                        setState(() {
                                          _dragPosition = 0.0;
                                        });
                                      }
                                    },
                                    child: Container(
                                      width: thumbSize,
                                      height: thumbSize,
                                      decoration: BoxDecoration(
                                        color: widget.theme.btnPrimary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.15),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Icon(
                                        Icons.arrow_forward_rounded,
                                        color: widget.theme.btnLabel,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      )
                    : Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: widget.theme.bgSurface,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: widget.theme.border),
                        ),
                        child: Center(
                          child: Text(
                            'Lokasi tidak tersedia',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: widget.theme.textHint,
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Reusable widgets ──────────────────────────────────────────────────────────

/// Frosted circle icon button (for back/bookmark on hero image)
class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0x44000000),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor ?? Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Dot indicator for image carousel — visual only, swipe to navigate
class _ImageDotIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;
  final bool compact;

  const _ImageDotIndicator({
    required this.count,
    required this.currentIndex,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 8 : 10,
          vertical: compact ? 5 : 6,
        ),
        decoration: BoxDecoration(
          color: Colors.black38,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (i) {
            final active = i == currentIndex;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? (compact ? 18 : 16) : (compact ? 5 : 6),
              height: compact ? 5 : 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                color: active ? Colors.white : Colors.white54,
              ),
            );
          }),
        ),
      ),
    );
  }
}

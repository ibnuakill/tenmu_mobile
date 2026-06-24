import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_image_helper.dart';
import '../../core/poi_facility.dart';
import 'route_map_screen.dart';
import 'review_section.dart';

class PoiDetailScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const PoiDetailScreen({super.key, required this.place});

  @override
  State<PoiDetailScreen> createState() => _PoiDetailScreenState();
}

class _PoiDetailScreenState extends State<PoiDetailScreen> {
  bool _isFavorite = false;
  bool _isLoadingFavorite = true;
  final PageController _imagePageController = PageController();
  int _currentImageIndex = 0;

  // ─── Scroll offset for dynamic appbar opacity ─────────────────────────────
  final ScrollController _scrollController = ScrollController();
  double _appBarOpacity = 0.0;
  static const double _appBarFadeStart = 200.0;
  static const double _appBarFadeEnd = 280.0;

  @override
  void initState() {
    super.initState();
    _checkFavoriteStatus();
    _scrollController.addListener(_onScroll);
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
    _imagePageController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  // ─── Image full-screen preview ────────────────────────────────────────────

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

  // ─── Supabase helpers ─────────────────────────────────────────────────────

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

  // ─── Supabase helpers ─────────────────────────────────────────────────────

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
    final bool hasActions = hasPhone || hasLocation;

    // ── Open/close logic ───────────────────────────────────────────────────
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
            // ── Scrollable content ────────────────────────────────────────
            CustomScrollView(
              controller: _scrollController,
              slivers: [
                // ── Hero image block ───────────────────────────────────────
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 340,
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

                        // Bottom gradient overlay for text legibility
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                stops: [0.35, 0.72, 1.0],
                                colors: [
                                  Colors.transparent,
                                  Color(0x66000000),
                                  Color(0xCC000000),
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
                                colors: [Color(0x88000000), Colors.transparent],
                              ),
                            ),
                          ),
                        ),

                        // ── Tap-to-preview overlay ────────────────────────
                        // Diletakkan sebelum tombol-tombol supaya back/bookmark
                        // tetap bisa dipencet (layer lebih atas di Stack).
                        // HitTestBehavior.translucent = swipe tetap lolos ke
                        // PageView, tapi tap ketangkap untuk buka fullscreen.
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

                        // ── Back + Bookmark buttons ──────────────────────
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
                                      ? Icons.bookmark_rounded
                                      : Icons.bookmark_border_rounded,
                                  iconColor: _isFavorite
                                      ? Colors.amber
                                      : Colors.white,
                                  onTap: _toggleFavorite,
                                ),
                            ],
                          ),
                        ),

                        // ── Name + address + meta overlaid on photo ──────
                        Positioned(
                          left: 20,
                          right: 20,
                          bottom: 24,
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
                                const SizedBox(height: 8),
                              ],

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
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    size: 14,
                                    color: Colors.white70,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      widget.place['alamat'] ?? '-',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.white70,
                                        height: 1.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // ── Image dot indicators ─────────────────────────
                        if (imageUrls.length > 1)
                          Positioned(
                            right: 16,
                            bottom: 28,
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

                // ── Content ────────────────────────────────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    // Extra bottom padding for the sticky bar + safe area
                    padding: EdgeInsets.fromLTRB(
                      0,
                      0,
                      0,
                      hasActions ? 100 + bottomPad : 32 + bottomPad,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Jam operasional row ──────────────────────────
                        if (jamBuka != null && jamTutup != null) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isOpen
                                        ? Colors.green.withValues(alpha: 0.12)
                                        : Colors.red.withValues(alpha: 0.10),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isOpen
                                          ? Colors.green.withValues(alpha: 0.4)
                                          : Colors.red.withValues(alpha: 0.4),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isOpen
                                            ? Icons.circle
                                            : Icons.circle_outlined,
                                        size: 8,
                                        color: isOpen
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        isOpen ? 'Buka' : 'Tutup',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isOpen
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Icon(
                                  Icons.access_time_outlined,
                                  size: 15,
                                  color: theme.textHint,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$jamBuka – $jamTutup',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: theme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          const SizedBox(height: 20),

                        // ── Fasilitas ────────────────────────────────────
                        Builder(
                          builder: (_) {
                            final facilities = PoiFacility.fromList(
                              widget.place['fasilitas'],
                            );
                            if (facilities.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: theme.border,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              f.icon,
                                              size: 15,
                                              color: theme.btnPrimary,
                                            ),
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
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                        Divider(
                          color: theme.border,
                          height: 1,
                          indent: 20,
                          endIndent: 20,
                        ),

                        // ── Deskripsi ────────────────────────────────────
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Tentang Tempat Ini',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: theme.textPrimary,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.place['deskripsi'] ??
                                    'Tidak ada deskripsi yang tersedia.',
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.75,
                                  color: theme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // ── No-location notice ────────────────────────────
                        if (!hasLocation) ...[
                          const SizedBox(height: 24),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: theme.bgSurface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.border),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_off_outlined,
                                    size: 16,
                                    color: theme.textHint,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Koordinat lokasi belum tersedia.',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.textHint,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // ── Review section ────────────────────────────────
                        if (widget.place['id'] != null) ...[
                          const SizedBox(height: 24),
                          Divider(
                            color: theme.border,
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: ReviewSection(
                              umkmId: widget.place['id'] as int,
                            ),
                          ),
                        ],
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
                                    ? Icons.bookmark_rounded
                                    : Icons.bookmark_border_rounded,
                                color: _isFavorite
                                    ? Colors.amber
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

            // ── Sticky bottom action bar ───────────────────────────────────
            if (hasActions)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _StickyActionBar(
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

// ─── Sticky bottom action bar ──────────────────────────────────────────────────

class _StickyActionBar extends StatelessWidget {
  final ThemeProvider theme;
  final double bottomPad;
  final bool hasPhone;
  final bool hasLocation;
  final VoidCallback onWhatsApp;
  final VoidCallback onRoute;

  const _StickyActionBar({
    required this.theme,
    required this.bottomPad,
    required this.hasPhone,
    required this.hasLocation,
    required this.onWhatsApp,
    required this.onRoute,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomPad),
          decoration: BoxDecoration(
            color: theme.bgBase.withValues(alpha: 0.82),
            border: Border(top: BorderSide(color: theme.border, width: 0.5)),
          ),
          child: Row(
            children: [
              // WhatsApp button (outline, secondary)
              if (hasPhone) ...[
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      onPressed: onWhatsApp,
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: theme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Color(0xFF25D366),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'WhatsApp',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (hasLocation) const SizedBox(width: 10),
              ],

              // Route button (filled, primary)
              if (hasLocation)
                Expanded(
                  flex: hasPhone ? 1 : 2,
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: onRoute,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.btnPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_rounded,
                            color: theme.btnLabel,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Lihat Rute',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: theme.btnLabel,
                            ),
                          ),
                        ],
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

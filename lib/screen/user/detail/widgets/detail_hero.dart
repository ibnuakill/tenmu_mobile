import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/theme_provider.dart';
import 'detail_helpers.dart';

/// Full-bleed hero image block: photo carousel + gradient + back/fav buttons
/// + featured badge + place name overlay + dot indicators.
class DetailHero extends StatefulWidget {
  final ThemeProvider theme;
  final List<String> imageUrls;
  final String placeName;
  final String? address;
  final bool isFeatured;
  final bool isFavorite;
  final bool isLoadingFavorite;
  final double topPadding;
  final VoidCallback onBack;
  final VoidCallback onTapFavorite;
  final void Function(int index) onShowImagePreview;

  const DetailHero({
    super.key,
    required this.theme,
    required this.imageUrls,
    required this.placeName,
    required this.address,
    required this.isFeatured,
    required this.isFavorite,
    required this.isLoadingFavorite,
    required this.topPadding,
    required this.onBack,
    required this.onTapFavorite,
    required this.onShowImagePreview,
  });

  @override
  State<DetailHero> createState() => _DetailHeroState();
}

class _DetailHeroState extends State<DetailHero> {
  late final PageController _pageCtrl;
  int _imageIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo carousel
          widget.imageUrls.isNotEmpty
              ? PageView.builder(
                  controller: _pageCtrl,
                  itemCount: widget.imageUrls.length,
                  onPageChanged: (i) => setState(() => _imageIndex = i),
                  itemBuilder: (_, index) => CachedNetworkImage(
                    imageUrl: widget.imageUrls[index],
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
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
            child: const DecoratedBox(
              decoration: BoxDecoration(
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
            child: const DecoratedBox(
              decoration: BoxDecoration(
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
          if (widget.imageUrls.isNotEmpty)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => widget.onShowImagePreview(_imageIndex),
              ),
            ),

          // ── Back + Favorite buttons ──────────────────────
          Positioned(
            top: widget.topPadding + 8,
            left: 12,
            right: 12,
            child: Row(
              children: [
                GlassCircleButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: widget.onBack,
                ),
                const Spacer(),
                if (!widget.isLoadingFavorite)
                  GlassCircleButton(
                    icon: widget.isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor:
                        widget.isFavorite ? Colors.redAccent : Colors.white,
                    onTap: widget.onTapFavorite,
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
                if (widget.isFeatured) ...[
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
                        widget.address ?? '-',
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
                Text(
                  widget.placeName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.2,
                    shadows: [
                      Shadow(blurRadius: 8, color: Colors.black45),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // ── Image dot indicators ─────────────────────────
          if (widget.imageUrls.length > 1)
            Positioned(
              right: 16,
              bottom: 24,
              child: ImageDotIndicator(
                count: widget.imageUrls.length,
                currentIndex: _imageIndex,
                compact: true,
              ),
            ),
        ],
      ),
    );
  }
}

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/places_provider.dart';
import '../../../../core/poi_image_helper.dart';
import '../../../../core/poi_category.dart';
import '../../../../core/haversine.dart';
import '../../detail/poi_detail_screen.dart';

/// Greeting header (Halo, nama + lokasi + notif + avatar).
class HomeGreetingHeader extends StatelessWidget {
  final String userName;
  final String? userLocation;
  final bool isUpdatingLocation;
  final int unreadNotifCount;
  final String? avatarUrl;
  final VoidCallback onTapLocation;
  final VoidCallback onTapNotification;
  final VoidCallback onTapAvatar;

  const HomeGreetingHeader({
    super.key,
    required this.theme,
    required this.userName,
    required this.userLocation,
    required this.isUpdatingLocation,
    required this.unreadNotifCount,
    required this.avatarUrl,
    required this.onTapLocation,
    required this.onTapNotification,
    required this.onTapAvatar,
  });

  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    final firstName = (userName.isEmpty ? 'Pengguna' : userName).split(' ').first;
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
                    onTap: onTapLocation,
                    child: Row(
                      children: [
                        Icon(
                          Icons.location_on_rounded,
                          size: 14,
                          color: theme.btnPrimary,
                        ),
                        const SizedBox(width: 3),
                        if (isUpdatingLocation)
                          SizedBox(
                            width: 12,
                            height: 12,
                            child: CircularProgressIndicator(
                              color: theme.btnPrimary,
                              strokeWidth: 2,
                            ),
                          )
                        else
                          Text(
                            userLocation ?? 'Selamat datang di Tenmu',
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
            _NotificationBell(
              theme: theme,
              count: unreadNotifCount,
              onTap: onTapNotification,
            ),
            const SizedBox(width: 10),
            _AvatarBubble(
              theme: theme,
              avatarUrl: avatarUrl,
              onTap: onTapAvatar,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  final ThemeProvider theme;
  final int count;
  final VoidCallback onTap;
  const _NotificationBell({
    required this.theme,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
          if (count > 0)
            Positioned(
              top: -3,
              right: -3,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count > 9 ? '9+' : '$count',
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
    );
  }
}

class _AvatarBubble extends StatelessWidget {
  final ThemeProvider theme;
  final String? avatarUrl;
  final VoidCallback onTap;
  const _AvatarBubble({
    required this.theme,
    required this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: theme.border, width: 2),
          image: avatarUrl != null
              ? DecorationImage(
                  image: CachedNetworkImageProvider(avatarUrl!),
                  fit: BoxFit.cover,
                )
              : null,
          color: theme.bgElevated,
        ),
        child: avatarUrl == null
            ? Icon(Icons.person_rounded, color: theme.textSecondary, size: 22)
            : null,
      ),
    );
  }
}

/// Search bar (tap-to-open filter sheet) + filter button.
class HomeSearchBar extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final String searchQuery;
  final bool hasActiveFilter;
  final VoidCallback onTapSearch;
  final VoidCallback onClearSearch;
  final VoidCallback onTapFilter;

  const HomeSearchBar({
    super.key,
    required this.theme,
    required this.accent,
    required this.searchQuery,
    required this.hasActiveFilter,
    required this.onTapSearch,
    required this.onClearSearch,
    required this.onTapFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: onTapSearch,
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
                    Expanded(
                      child: Text(
                        searchQuery.isEmpty
                            ? 'Cari tempat, cafe, wisata...'
                            : searchQuery,
                        style: TextStyle(
                          color: searchQuery.isEmpty
                              ? theme.textHint
                              : theme.textPrimary,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (searchQuery.isNotEmpty)
                      GestureDetector(
                        onTap: onClearSearch,
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
            onTap: onTapFilter,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: hasActiveFilter ? accent : theme.textPrimary,
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
}

/// Section title (Pilih destinasimu).
class HomeSectionTitle extends StatelessWidget {
  final ThemeProvider theme;
  final String title;
  const HomeSectionTitle({super.key, required this.theme, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: theme.textPrimary,
          letterSpacing: -0.4,
        ),
      ),
    );
  }
}

/// Horizontal category chips (Semua + kategori).
class HomeCategoryChips extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final List<String> categories;
  final String? selectedCategoryTab; // null/'Semua' = Semua
  final ValueChanged<String?> onChanged;

  const HomeCategoryChips({
    super.key,
    required this.theme,
    required this.accent,
    required this.categories,
    required this.selectedCategoryTab,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = categories[index];
          final isSelected = cat == 'Semua'
              ? selectedCategoryTab == null || selectedCategoryTab == 'Semua'
              : selectedCategoryTab == cat;

          return GestureDetector(
            onTap: () =>
                onChanged(cat == 'Semua' ? null : cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
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
}

/// 3D cover-flow featured carousel with dot indicator.
class HomeFeaturedCarousel extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final List<Map<String, dynamic>> cards;
  final PageController controller;
  final ValueNotifier<double> pageNotifier;
  final int currentPage;
  final bool isFallback;
  final PlacesProvider provider;
  final double Function(int? placeId) ratingOf;

  const HomeFeaturedCarousel({
    super.key,
    required this.theme,
    required this.accent,
    required this.cards,
    required this.controller,
    required this.pageNotifier,
    required this.currentPage,
    required this.isFallback,
    required this.provider,
    required this.ratingOf,
  });

  @override
  Widget build(BuildContext context) {
    final displayCards = cards.take(8).toList();
    if (displayCards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: Row(
            children: [
              Icon(
                isFallback ? Icons.schedule_rounded : Icons.star_rounded,
                size: 16,
                color: isFallback
                    ? theme.textSecondary
                    : const Color(0xFFF4B942),
              ),
              const SizedBox(width: 6),
              Text(
                isFallback ? 'Terbaru' : 'Unggulan',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isFallback
                      ? theme.textSecondary
                      : const Color(0xFFF4B942),
                  letterSpacing: 0.3,
                ),
              ),
              if (isFallback) ...[
                const Spacer(),
                Text(
                  'Belum ada tempat unggulan',
                  style: TextStyle(fontSize: 11, color: theme.textHint),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: controller,
            itemCount: displayCards.length,
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              return ValueListenableBuilder<double>(
                valueListenable: pageNotifier,
                builder: (context, page, child) {
                  final double delta = (index - page).clamp(-1.0, 1.0);
                  final double rotationY = delta * (35 * math.pi / 180);
                  final double translateX = -delta * 30;
                  final double scale = 1.0 - delta.abs() * 0.18;
                  final double opacity = 1.0 - delta.abs() * 0.4;
                  return Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
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
                  child: _FeaturedCardItem(
                    place: displayCards[index],
                    theme: theme,
                    accent: accent,
                    rating: ratingOf(displayCards[index]['id']),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        if (displayCards.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(displayCards.length, (i) {
              final active = i == currentPage;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 22 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: active
                      ? (isFallback
                          ? theme.textPrimary
                          : const Color(0xFFF4B942))
                      : theme.textHint.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class _FeaturedCardItem extends StatelessWidget {
  final Map<String, dynamic> place;
  final ThemeProvider theme;
  final Color accent;
  final double rating;

  const _FeaturedCardItem({
    required this.place,
    required this.theme,
    required this.accent,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = PoiImageHelper.primaryImageUrl(place);
    final category = (place['category']?.toString().trim().isNotEmpty ?? false)
        ? PoiCategory.normalizeCategory(place['category'])
        : PoiCategory.lainnya;

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
            if (imageUrl != null)
              CachedNetworkImage(
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
            else
              Container(
                color: accent.withValues(alpha: 0.15),
                child: Icon(
                  Icons.storefront_rounded,
                  size: 64,
                  color: accent.withValues(alpha: 0.4),
                ),
              ),
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
            // Top badges
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  _GlassChip(emoji: PoiCategory.getCategoryEmoji(category), label: category),
                  const Spacer(),
                  _GlassCircle(child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 18)),
                ],
              ),
            ),
            // Bottom info
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
                        const Icon(Icons.location_on_rounded, size: 13, color: Colors.white70),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            place['alamat'] ?? 'Indonesia',
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
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
                        const Icon(Icons.star_rounded, color: Color(0xFFFFC107), size: 15),
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Lihat Detail',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(width: 4),
                              Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black87),
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
}

class _GlassChip extends StatelessWidget {
  final String emoji;
  final String label;
  const _GlassChip({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassCircle extends StatelessWidget {
  final Widget child;
  const _GlassCircle({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: child,
    );
  }
}

/// Compact list item card (horizontal image + info).
class HomePoiListCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final double rating;
  final ThemeProvider theme;
  final Color accent;
  final int index;
  final Position? userPosition;

  const HomePoiListCard({
    super.key,
    required this.place,
    required this.rating,
    required this.theme,
    required this.accent,
    required this.index,
    required this.userPosition,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = PoiImageHelper.primaryImageUrl(place);
    final category = (place['category']?.toString().trim().isNotEmpty ?? false)
        ? PoiCategory.normalizeCategory(place['category'])
        : PoiCategory.lainnya;
    String? distanceText;
    if (userPosition != null) {
      final lat = (place['latitude'] as num?)?.toDouble();
      final lng = (place['longitude'] as num?)?.toDouble();
      if (lat != null && lng != null && lat != 0 && lng != 0) {
        final dist = Haversine.distance(
          userPosition!.latitude,
          userPosition!.longitude,
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                            Icon(Icons.near_me_rounded, size: 12, color: accent),
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
                            Icon(Icons.verified_rounded, size: 14, color: accent),
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
}

/// Header "Semua Tempat" / "Hasil Pencarian".
class HomeAllPlacesHeader extends StatelessWidget {
  final ThemeProvider theme;
  final int count;
  final bool hasFilter;
  const HomeAllPlacesHeader({
    super.key,
    required this.theme,
    required this.count,
    required this.hasFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Column(
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
    );
  }
}

/// Empty state.
class HomeEmptyState extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final String searchQuery;
  final bool hasFilter;
  final VoidCallback onClearFilter;

  const HomeEmptyState({
    super.key,
    required this.theme,
    required this.accent,
    required this.searchQuery,
    required this.hasFilter,
    required this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: MediaQuery.of(context).size.height * 0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_outlined, size: 72, color: accent.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              searchQuery.isNotEmpty
                  ? 'Tidak ada hasil untuk\n"$searchQuery"'
                  : 'Belum ada tempat ditemukan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            if (hasFilter)
              GestureDetector(
                onTap: onClearFilter,
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
}

/// Error state (offline / gagal load).
class HomeErrorState extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final VoidCallback onRetry;

  const HomeErrorState({
    super.key,
    required this.theme,
    required this.accent,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
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
              onPressed: onRetry,
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
}

/// Pill bottom nav (5 items, owner dapat tombol + di tengah).
class HomePillBottomNav extends StatelessWidget {
  final ThemeProvider theme;
  final Color accent;
  final int currentIndex;
  final bool isOwner;
  final ValueChanged<int> onTap;

  const HomePillBottomNav({
    super.key,
    required this.theme,
    required this.accent,
    required this.currentIndex,
    required this.isOwner,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
              _PillItem(icon: Icons.home_rounded, index: 0, current: currentIndex, accent: accent, onTap: onTap),
              _PillItem(icon: Icons.map_rounded, index: 1, current: currentIndex, accent: accent, onTap: onTap),
              if (isOwner) _PillAdd(accent: accent, onTap: () => onTap(2)),
              _PillItem(icon: Icons.auto_awesome_rounded, index: 3, current: currentIndex, accent: accent, onTap: onTap),
              _PillItem(icon: Icons.person_rounded, index: 4, current: currentIndex, accent: accent, onTap: onTap),
            ],
          ),
        ),
      ),
    );
  }
}

class _PillItem extends StatelessWidget {
  final IconData icon;
  final int index;
  final int current;
  final Color accent;
  final ValueChanged<int> onTap;
  const _PillItem({
    required this.icon,
    required this.index,
    required this.current,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = index == current;
    return GestureDetector(
      onTap: () => onTap(index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white.withValues(alpha: 0.15) : Colors.transparent,
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
}

class _PillAdd extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;
  const _PillAdd({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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

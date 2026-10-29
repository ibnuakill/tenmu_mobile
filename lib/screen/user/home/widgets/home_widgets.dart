import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../core/theme_provider.dart';
import '../../../../core/places_provider.dart';
import '../../../../core/poi_image_helper.dart';
import '../../../../core/poi_category.dart';
import '../../../../core/haversine.dart';
import '../../detail/poi_detail_screen.dart';
import '../../../../core/lucide_icons.dart';

/// Greeting header (Halo, nama + lokasi + notif).
class HomeGreetingHeader extends StatelessWidget {
  final String userName;
  final String? userLocation;
  final bool isUpdatingLocation;
  final int unreadNotifCount;
  final VoidCallback onTapLocation;
  final VoidCallback onTapNotification;

  const HomeGreetingHeader({
    super.key,
    required this.theme,
    required this.userName,
    required this.userLocation,
    required this.isUpdatingLocation,
    required this.unreadNotifCount,
    required this.onTapLocation,
    required this.onTapNotification,
  });

  final ThemeProvider theme;

  @override
  Widget build(BuildContext context) {
    final firstName = (userName.isEmpty ? 'Pengguna' : userName)
        .split(' ')
        .first;
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
                    'Halo, $firstName 👋',
                    style: TextStyle(
                      fontSize: 26,
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
                        LucideIcon(
                          'map-pin',
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
            child: LucideIcon('bell', color: theme.textPrimary, size: 22),
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
                  color: theme.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.border.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    LucideIcon('search', color: theme.textHint, size: 20),
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
                        child: LucideIcon('x', size: 18, color: theme.textHint),
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
                color: hasActiveFilter
                    ? accent
                    : (theme.isDarkMode ? theme.bgSurface : accent),
                borderRadius: BorderRadius.circular(16),
                border: theme.isDarkMode && !hasActiveFilter
                    ? Border.all(color: theme.border, width: 1)
                    : null,
              ),
              child: LucideIcon(
                'sliders-horizontal',
                color: hasActiveFilter
                    ? Colors.white
                    : (theme.isDarkMode ? theme.textPrimary : Colors.white),
                size: 22,
              ),
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
            onTap: () => onChanged(cat == 'Semua' ? null : cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? (theme.isDarkMode ? theme.textPrimary : accent)
                    : theme.bgSurface,
                borderRadius: BorderRadius.circular(999),
                border: isSelected
                    ? null
                    : Border.all(
                        color: theme.isDarkMode
                            ? theme.border.withValues(alpha: 0.5)
                            : theme.border,
                        width: 1,
                      ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (cat != 'Semua') ...[
                    LucideIcon(
                      PoiCategory.getCategoryLucide(cat),
                      size: 14,
                      color: isSelected
                          ? (theme.isDarkMode ? theme.bgBase : Colors.white)
                          : theme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: isSelected
                          ? (theme.isDarkMode ? theme.bgBase : Colors.white)
                          : theme.textSecondary,
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
              LucideIcon(
                isFallback ? 'clock' : 'star',
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
    final category = PoiCategory.normalizeCategory(
      place['category']?.toString().trim() ?? '',
    );

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PoiDetailScreen(place: place)),
      ),
      child: Container(
        height: 400,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(28)),
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
                  child: LucideIcon('image', size: 48, color: theme.textHint),
                ),
                errorWidget: (_, _, _) => Container(
                  color: theme.bgElevated,
                  child: LucideIcon(
                    'image-off',
                    size: 48,
                    color: theme.textHint,
                  ),
                ),
              )
            else
              Container(
                color: accent.withValues(alpha: 0.15),
                child: LucideIcon(
                  'store',
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
                  _GlassChip(
                    icon: PoiCategory.getCategoryLucide(category),
                    label: category,
                  ),
                  const Spacer(),
                  _GlassCircle(
                    child: const LucideIcon(
                      'heart',
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
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
                        const LucideIcon(
                          'map-pin',
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
                        const LucideIcon(
                          'star',
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
                              LucideIcon(
                                'arrow-right',
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
}

class _GlassChip extends StatelessWidget {
  final String icon;
  final String label;
  const _GlassChip({required this.icon, required this.label});

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
          LucideIcon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 6),
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

/// 2-column grid product-style card.
class HomePoiGridCard extends StatelessWidget {
  final Map<String, dynamic> place;
  final double rating;
  final ThemeProvider theme;
  final Color accent;
  final int index;
  final Position? userPosition;

  const HomePoiGridCard({
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
    final category = PoiCategory.normalizeCategory(
      place['category']?.toString().trim() ?? '',
    );
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

    final isNew = rating == 0;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 350 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (_, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - v)),
          child: child,
        ),
      ),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PoiDetailScreen(place: place)),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: theme.bgSurface,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Image area ──────────────────────────
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 1.0,
                    child: imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            placeholder: (_, _) => Container(
                              color: theme.bgElevated,
                              child: Center(
                                child: LucideIcon(
                                  'image',
                                  color: theme.textHint,
                                  size: 28,
                                ),
                              ),
                            ),
                            errorWidget: (_, _, _) => Container(
                              color: theme.bgElevated,
                              child: Center(
                                child: LucideIcon(
                                  'store',
                                  color: theme.textHint,
                                  size: 28,
                                ),
                              ),
                            ),
                          )
                        : Container(
                            color: theme.bgElevated,
                            child: Center(
                              child: LucideIcon(
                                'store',
                                color: theme.textHint,
                                size: 32,
                              ),
                            ),
                          ),
                  ),
                  // "Baru" badge top-left
                  if (isNew)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Baru!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  // Verified badge top-right
                  if (place['verification_status'] == 'verified')
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: theme.isDarkMode
                              ? theme.bgElevated
                              : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: LucideIcon(
                          'badge-check',
                          size: 16,
                          color: accent,
                        ),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category label — uppercase, semi-bold, clear badge feel
                    Row(
                      children: [
                        LucideIcon(
                          PoiCategory.getCategoryLucide(category),
                          size: 12,
                          color: accent,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            category.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              color: accent,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    // Place name — Bold, dominant hierarchy
                    Text(
                      place['nama_tempat'] ?? 'Tanpa Nama',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: theme.textPrimary,
                        letterSpacing: -0.2,
                        height: 1.25,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    // Rating (Bold) + Distance (Regular) row
                    Row(
                      children: [
                        const LucideIcon(
                          'star',
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
                          const SizedBox(width: 6),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: BoxDecoration(
                              color: theme.textHint.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          LucideIcon(
                            'navigation',
                            size: 11,
                            color: theme.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              distanceText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: theme.textSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
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
      padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(
              'compass',
              size: 72,
              color: accent.withValues(alpha: 0.4),
            ),
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
      padding: EdgeInsets.only(top: MediaQuery.sizeOf(context).height * 0.15),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon('wifi-off', size: 56, color: theme.textHint),
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
              icon: const LucideIcon('refresh-cw'),
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
  final ValueChanged<int> onTap;

  const HomePillBottomNav({
    super.key,
    required this.theme,
    required this.accent,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = theme.isDarkMode;
    final bgColor = isDark ? const Color(0xFF151515) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFE5E7EB);

    // 4 item: Beranda, Peta, AI, Profil.
    // "Tambah tempat" (owner) dipindah ke FAB, "Postingan" dibuka dari strip
    // di beranda + tombol "Lihat semua" — supaya nav tidak lebih dari 5 item.
    final items = <_NavItem>[
      const _NavItem(icon: 'house', label: 'Beranda', index: 0),
      const _NavItem(icon: 'map', label: 'Peta', index: 1),
      const _NavItem(icon: 'sparkles', label: 'AI', index: 3),
      const _NavItem(icon: 'user', label: 'Profil', index: 4),
    ];

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.8)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: items
                .map(
                  (item) => Expanded(
                    child: _NavBarItem(
                      item: item,
                      isActive: currentIndex == item.index,
                      accent: accent,
                      onTap: () => onTap(item.index),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final String icon;
  final String label;
  final int index;
  const _NavItem({
    required this.icon,
    required this.label,
    required this.index,
  });
}

class _NavBarItem extends StatelessWidget {
  final _NavItem item;
  final bool isActive;
  final Color accent;
  final VoidCallback onTap;

  const _NavBarItem({
    required this.item,
    required this.isActive,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isDark = theme.isDarkMode;
    final defaultInactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.4)
        : const Color(0xFF9E9E9E);
    final defaultActiveColor = isDark ? Colors.white : const Color(0xFF1A1A1A);

    final iconColor = isActive
        ? (isDark ? Colors.white : accent)
        : defaultInactiveColor;
    final labelColor = isActive ? defaultActiveColor : defaultInactiveColor;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            width: isActive ? 36 : 0,
            height: 3,
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: isActive ? accent : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          LucideIcon(item.icon, size: 22, color: iconColor),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
              color: labelColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../core/poi_facility.dart';
import '../../../../core/theme_provider.dart';
import '../../review/review_section.dart';

/// Tab content (Detail / Ulasan) — memilih tab via TabController.
class DetailTabContent extends StatelessWidget {
  final TabController tabController;
  final ThemeProvider theme;
  final Map<String, dynamic> place;
  final List<String> imageUrls;
  final void Function(int index) onShowImage;
  final dynamic placeId;

  const DetailTabContent({
    super.key,
    required this.tabController,
    required this.theme,
    required this.place,
    required this.imageUrls,
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
            return _ReviewsTab(theme: theme, placeId: placeId);
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

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
        // About
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

        // Facilities
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

        // Gallery
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
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[index],
                    width: 120,
                    height: 120,
                    fit: BoxFit.cover,
                    errorWidget: (_, _, _) => Container(
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

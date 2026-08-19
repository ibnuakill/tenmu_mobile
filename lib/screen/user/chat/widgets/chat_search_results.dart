import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../../../core/poi_image_helper.dart';
import '../../../../core/theme_provider.dart';
import '../../detail/poi_detail_screen.dart';

/// Daftar hasil pencarian (tappable → detail POI).
class ChatSearchResults extends StatelessWidget {
  final List<Map<String, dynamic>> results;
  final ThemeProvider theme;

  const ChatSearchResults({
    super.key,
    required this.results,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxHeight: 200),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        border: Border(top: BorderSide(color: theme.border)),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: results.length,
        separatorBuilder: (_, _) => Divider(
          height: 1,
          color: theme.border.withValues(alpha: 0.3),
        ),
        itemBuilder: (context, i) => _ResultRow(place: results[i], theme: theme),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final Map<String, dynamic> place;
  final ThemeProvider theme;

  const _ResultRow({required this.place, required this.theme});

  @override
  Widget build(BuildContext context) {
    final name = place['nama_tempat'] ?? '';
    final alamat = place['alamat'] ?? '';
    final imgUrl = PoiImageHelper.primaryImageUrl(place);

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PoiDetailScreen(place: place)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imgUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    )
                  : Container(
                      width: 48,
                      height: 48,
                      color: theme.bgElevated,
                      child: Icon(
                        Icons.image_outlined,
                        color: theme.textHint,
                        size: 20,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    alamat,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: theme.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

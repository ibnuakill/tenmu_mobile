import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/poi_image_helper.dart';
import '../../../../core/theme_provider.dart';
import '../../detail/poi_detail_screen.dart';
import '../../../../core/lucide_icons.dart';

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

  /// Ambil URL gambar dari payload AI (image_urls / gambar_url), dengan
  /// beberapa nama field alternatif sebagai cadangan.
  String? get _imageUrl {
    final direct = PoiImageHelper.primaryImageUrl(place);
    if (direct != null) return direct;
    for (final key in ['foto_url', 'foto', 'thumbnail', 'image']) {
      final v = place[key]?.toString().trim() ?? '';
      if (v.isNotEmpty) return v;
    }
    return null;
  }

  /// Ambil ulang data lengkap tempat dari Supabase sebelum membuka detail.
  ///
  /// Payload `mentioned` dari Edge Function chat-bot hanya berisi field ringkas
  /// (id, nama, alamat, kategori, gambar, koordinat, rating) sehingga deskripsi,
  /// fasilitas, nomor telepon, dan jam buka kosong kalau dipakai langsung.
  Future<void> _openDetail(BuildContext context) async {
    var data = place;
    final id = data['id'];
    if (id != null) {
      for (final table in ['places_with_ratings', 'places']) {
        try {
          final row = await Supabase.instance.client
              .from(table)
              .select()
              .eq('id', id)
              .maybeSingle();
          if (row != null) {
            data = {...data, ...row};
            break;
          }
        } catch (_) {
          // Coba tabel berikutnya; kalau semua gagal, pakai data seadanya.
        }
      }
    }
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PoiDetailScreen(place: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = (place['nama_tempat'] ?? '').toString();
    final alamat = (place['alamat'] ?? '').toString();
    final kategori = (place['kategori'] ?? place['category'] ?? '').toString();
    final rating = place['avg_rating'];
    final imgUrl = _imageUrl;

    return InkWell(
      onTap: () => _openDetail(context),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imgUrl != null
                  ? CachedNetworkImage(
                      imageUrl: imgUrl,
                      width: 52,
                      height: 52,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 150),
                      placeholder: (_, _) => Container(
                        width: 52,
                        height: 52,
                        color: theme.bgElevated,
                        child: Center(
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.6,
                              color: theme.textHint,
                            ),
                          ),
                        ),
                      ),
                      errorWidget: (_, _, _) => _FallbackThumb(theme: theme),
                    )
                  : _FallbackThumb(theme: theme),
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
                    alamat.isEmpty ? 'Alamat belum tersedia' : alamat,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (kategori.isNotEmpty || rating != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (rating != null) ...[
                          Icon(Icons.star_rounded,
                              size: 11, color: theme.btnPrimary),
                          const SizedBox(width: 2),
                          Text(
                            (rating is num)
                                ? rating.toStringAsFixed(1)
                                : rating.toString(),
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (kategori.isNotEmpty)
                          Flexible(
                            child: Text(
                              kategori,
                              style: TextStyle(
                                color: theme.textHint,
                                fontSize: 10,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            LucideIcon('chevron-right', color: theme.textHint, size: 18),
          ],
        ),
      ),
    );
  }
}

class _FallbackThumb extends StatelessWidget {
  final ThemeProvider theme;
  const _FallbackThumb({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      color: theme.bgElevated,
      child: LucideIcon('image', color: theme.textHint, size: 20),
    );
  }
}


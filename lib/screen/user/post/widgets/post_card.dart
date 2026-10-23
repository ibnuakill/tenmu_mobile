import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme_provider.dart';
import '../post_models.dart';
import '../post_provider.dart';
import 'post_comments_sheet.dart';
import '../../../../core/lucide_icons.dart';

/// Satu kartu postingan foto: header penulis, gambar, caption,
/// info tempat, dan rail aksi (like + komentar).
class PostCard extends StatelessWidget {
  final PlacePost post;
  final PostProvider provider;
  final ThemeProvider theme;
  final VoidCallback? onTapPlace;

  const PostCard({
    super.key,
    required this.post,
    required this.provider,
    required this.theme,
    this.onTapPlace,
  });

  String get _imageUrl =>
      Supabase.instance.client.storage.from('posts').getPublicUrl(post.imagePath);

  static String _compact(int n) {
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v < 10 ? 1 : 0)}rb';
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final liked = provider.isLiked(post.id);
    final likes = provider.likeCount(post.id);
    final comments = provider.commentCount(post.id);

    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: penulis + kategori ──
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.bgElevated,
                  backgroundImage: (post.authorAvatar?.isNotEmpty == true)
                      ? NetworkImage(post.authorAvatar!)
                      : null,
                  child: (post.authorAvatar?.isNotEmpty == true)
                      ? null
                      : LucideIcon('user', color: theme.textHint, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _relativeTime(post.createdAt),
                        style: TextStyle(color: theme.textHint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                if (post.placeCategory.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.bgElevated,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: theme.border),
                    ),
                    child: Text(
                      post.placeCategory,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Gambar postingan ──
          AspectRatio(
            aspectRatio: 4 / 3,
            child: CachedNetworkImage(
              imageUrl: _imageUrl,
              fit: BoxFit.cover,
              placeholder: (_, _) => Container(
                color: theme.bgElevated,
                child: Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: theme.textHint),
                ),
              ),
              errorWidget: (_, _, _) => Container(
                color: theme.bgElevated,
                child: LucideIcon('image-off',
                    color: theme.textHint, size: 40),
              ),
            ),
          ),

          // ── Aksi: like + komentar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 4, 12, 0),
            child: Row(
              children: [
                _actionButton(
                  icon: liked
                      ? 'heart'
                      : 'heart',
                  color: liked ? const Color(0xFFFF3B5C) : theme.textPrimary,
                  label: _compact(likes),
                  onTap: () => provider.toggleLike(post),
                ),
                const SizedBox(width: 4),
                _actionButton(
                  icon: 'message-square',
                  color: theme.textPrimary,
                  label: _compact(comments),
                  onTap: () => PostCommentsSheet.show(context, post),
                ),
              ],
            ),
          ),

          // ── Caption ──
          if (post.caption?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
              child: Text(
                post.caption!.trim(),
                style: TextStyle(
                    color: theme.textPrimary, fontSize: 13, height: 1.4),
              ),
            ),

          // ── Info tempat (tap → detail) — hanya jika ditautkan ──
          if (post.hasPlace)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              child: GestureDetector(
                onTap: onTapPlace,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LucideIcon('store',
                        color: theme.textSecondary, size: 15),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        post.placeName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LucideIcon(icon, color: color, size: 22),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'baru saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes} menit lalu';
    if (diff.inHours < 24) return '${diff.inHours} jam lalu';
    if (diff.inDays < 7) return '${diff.inDays} hari lalu';
    return '${t.day}/${t.month}/${t.year}';
  }
}

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme_provider.dart';
import '../post_models.dart';
import '../post_provider.dart';
import 'post_comments_sheet.dart';
import '../../../../core/lucide_icons.dart';

/// Section "Postingan" di halaman detail tempat: galeri foto horizontal,
/// tap → bottom sheet komentar. Ada tombol untuk membuat postingan baru.
class PlacePostsSection extends StatefulWidget {
  final int placeId;
  final String placeName;

  const PlacePostsSection({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  @override
  State<PlacePostsSection> createState() => _PlacePostsSectionState();
}

class _PlacePostsSectionState extends State<PlacePostsSection> {
  late Future<List<PlacePost>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchPlacePosts(widget.placeId);
  }

  void _reload() {
    setState(() => _future = fetchPlacePosts(widget.placeId));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return FutureBuilder<List<PlacePost>>(
      future: _future,
      builder: (context, snapshot) {
        final posts = snapshot.data ?? const <PlacePost>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Row(
                children: [
                  Text(
                    'Postingan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: theme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (posts.isNotEmpty)
                    Text(
                      '${posts.length}',
                      style: TextStyle(
                          color: theme.textSecondary, fontSize: 13),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'Belum ada postingan untuk tempat ini.',
                  style: TextStyle(color: theme.textSecondary, fontSize: 13),
                ),
              )
            else
              SizedBox(
                height: 210,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: posts.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final p = posts[index];
                    return GestureDetector(
                      onTap: () async {
                        await PostCommentsSheet.show(context, p);
                        _reload();
                      },
                      child: _PostThumb(post: p, theme: theme),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PostThumb extends StatelessWidget {
  final PlacePost post;
  final ThemeProvider theme;

  const _PostThumb({required this.post, required this.theme});

  @override
  Widget build(BuildContext context) {
    final url =
        Supabase.instance.client.storage.from('posts').getPublicUrl(post.imagePath);
    return Container(
      width: 160,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.bgSurface,
        border: Border.all(color: theme.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: url,
            fit: BoxFit.cover,
            placeholder: (_, _) => Container(color: theme.bgElevated),
            errorWidget: (_, _, _) => Container(
              color: theme.bgElevated,
              child: LucideIcon('image-off', color: theme.textHint),
            ),
          ),
          // Gradient bawah
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (post.caption?.trim().isNotEmpty == true)
                    Text(
                      post.caption!.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600),
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const LucideIcon('user',
                          color: Colors.white70, size: 12),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          post.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 10.5),
                        ),
                      ),
                      const LucideIcon('message-square',
                          color: Colors.white70, size: 12),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

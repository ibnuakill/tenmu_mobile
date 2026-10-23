import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import '../detail/poi_detail_screen.dart';
import 'post_models.dart';
import 'post_provider.dart';
import 'widgets/post_card.dart';
import 'widgets/post_upload_sheet.dart';
import '../../../core/lucide_icons.dart';

/// Feed "Postingan" — daftar postingan FOTO terkait tempat/potensi lokal.
/// Semua pengguna dapat membuat postingan; interaksi: like + komentar.
class PostFeedScreen extends StatefulWidget {
  const PostFeedScreen({super.key});

  @override
  State<PostFeedScreen> createState() => _PostFeedScreenState();
}

class _PostFeedScreenState extends State<PostFeedScreen> {
  late final PostProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = PostProvider();
    _provider.fetchFeed();
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await _provider.fetchFeed();
  }

  void _openPlace(PlacePost p) {
    final place = p.place;
    if (place == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PoiDetailScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        backgroundColor: theme.bgBase,
        elevation: 0,
        foregroundColor: theme.textPrimary,
        leading: IconButton(
          icon: const LucideIcon('chevron-left'),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Postingan',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 17,
          ),
        ),
        actions: [
          IconButton(
            icon: const LucideIcon('refresh-cw'),
            onPressed: _reload,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final ok = await PostUploadSheet.show(context);
          if (ok && mounted) _reload();
        },
        backgroundColor: theme.btnPrimary,
        foregroundColor: theme.btnLabel,
        icon: const LucideIcon('image-plus'),
        label: const Text('Buat Postingan',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: AnimatedBuilder(
        animation: _provider,
        builder: (context, _) {
          if (_provider.loading && _provider.posts.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: theme.btnPrimary, strokeWidth: 2.5),
            );
          }
          if (_provider.error != null && _provider.posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LucideIcon('image-off',
                      size: 48, color: theme.textHint),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _provider.error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.textSecondary, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const LucideIcon('refresh-cw'),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }
          if (_provider.posts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LucideIcon('images', size: 48, color: theme.textHint),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      'Belum ada postingan.\nJadilah yang pertama membagikan foto tempat menarik!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: theme.textSecondary, fontSize: 13, height: 1.5),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            color: theme.btnPrimary,
            backgroundColor: theme.bgElevated,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: _provider.posts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final post = _provider.posts[index];
                return PostCard(
                  post: post,
                  provider: _provider,
                  theme: theme,
                  onTapPlace: () => _openPlace(post),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../detail/poi_detail_screen.dart';
import 'video_models.dart';
import 'video_provider.dart';
import 'widgets/video_feed_item.dart';

/// Feed video pendek vertikal (gaya TikTok/Shopee Video).
/// Autoplay hanya pada halaman aktif; player lain dijeda.
class VideoFeedScreen extends StatefulWidget {
  const VideoFeedScreen({super.key});

  @override
  State<VideoFeedScreen> createState() => _VideoFeedScreenState();
}

class _VideoFeedScreenState extends State<VideoFeedScreen> {
  late final VideoProvider _provider;
  late final PageController _pageCtrl;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _provider = VideoProvider();
    _pageCtrl = PageController();
    _provider.fetchFeed();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    await _provider.fetchFeed();
    if (mounted) setState(() => _currentIndex = 0);
  }

  void _openPlace(PlaceVideo v) {
    final place = v.place;
    if (place == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PoiDetailScreen(place: place),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _reload,
          ),
        ],
        title: const Text(
          'Video',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _provider,
        builder: (context, _) {
          if (_provider.loading && _provider.videos.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
            );
          }
          if (_provider.error != null && _provider.videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library_outlined, size: 48, color: Colors.white54),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _provider.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Coba Lagi'),
                  ),
                ],
              ),
            );
          }
          if (_provider.videos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.video_library_outlined, size: 48, color: Colors.white54),
                  const SizedBox(height: 12),
                  const Text(
                    'Belum ada video.\nOwner bisa upload video promosi tempatnya.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.5),
                  ),
                ],
              ),
            );
          }

          return PageView.builder(
            controller: _pageCtrl,
            scrollDirection: Axis.vertical,
            itemCount: _provider.videos.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) {
              final video = _provider.videos[index];
              return VideoFeedItem(
                video: video,
                active: index == _currentIndex,
                provider: _provider,
                onTapPlace: () => _openPlace(video),
              );
            },
          );
        },
      ),
    );
  }
}
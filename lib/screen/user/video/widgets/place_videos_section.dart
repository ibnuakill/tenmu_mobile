import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme_provider.dart';
import '../video_models.dart';
import '../video_provider.dart';
import 'video_player_screen.dart';

/// Section "Video Promosi" di halaman detail tempat: thumbnail horizontal,
/// tap → layar player penuh.
class PlaceVideosSection extends StatefulWidget {
  final int placeId;
  final String placeName;

  const PlaceVideosSection({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  @override
  State<PlaceVideosSection> createState() => _PlaceVideosSectionState();
}

class _PlaceVideosSectionState extends State<PlaceVideosSection> {
  late Future<List<PlaceVideo>> _future;

  @override
  void initState() {
    super.initState();
    _future = fetchPlaceVideos(widget.placeId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);

    return FutureBuilder<List<PlaceVideo>>(
      future: _future,
      builder: (context, snapshot) {
        final videos = snapshot.data ?? const <PlaceVideo>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 90,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (videos.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
              child: Text(
                'Video Promosi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 200,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: videos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final v = videos[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerScreen(video: v),
                        ),
                      );
                    },
                    child: _VideoThumb(video: v, theme: theme),
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

class _VideoThumb extends StatelessWidget {
  final PlaceVideo video;
  final ThemeProvider theme;

  const _VideoThumb({required this.video, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 140,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: theme.bgSurface,
        border: Border.all(color: theme.border),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: Colors.black),
          const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 44),
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Row(
              children: [
                const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    '${video.views}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                if (video.caption?.isNotEmpty == true)
                  Icon(Icons.subtitles_outlined, color: Colors.white70, size: 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
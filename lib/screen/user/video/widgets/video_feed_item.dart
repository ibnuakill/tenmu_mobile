import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../video_models.dart';
import '../video_provider.dart';

/// Satu kartu video dalam feed vertikal (gaya TikTok/Shopee Video).
/// Hanya memuat player saat [active] pertama kali true (lazy load),
/// pause saat tidak aktif, dispose saat keluar layar.
class VideoFeedItem extends StatefulWidget {
  final PlaceVideo video;
  final bool active;
  final VideoProvider provider;
  final VoidCallback? onTapPlace;

  const VideoFeedItem({
    super.key,
    required this.video,
    required this.active,
    required this.provider,
    this.onTapPlace,
  });

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  bool _initializing = false;

  /// video_player tanpa plugin Windows/macOS/Linux → fallback tampilan statis.
  static bool get _canPlay {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _videoUrl =>
      Supabase.instance.client.storage.from('videos').getPublicUrl(widget.video.videoPath);

  @override
  void initState() {
    super.initState();
    if (widget.active) _ensureController();
  }

  @override
  void didUpdateWidget(covariant VideoFeedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.video.id != oldWidget.video.id) {
      _disposePlayer();
      if (widget.active) _ensureController();
      return;
    }
    if (widget.active && !oldWidget.active) {
      _play();
    } else if (!widget.active && oldWidget.active) {
      _pause();
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _disposePlayer() {
    _chewieCtrl?.dispose();
    _chewieCtrl = null;
    _videoCtrl?.dispose();
    _videoCtrl = null;
    _initializing = false;
  }

  void _play() {
    final ctrl = _chewieCtrl;
    if (ctrl != null) {
      ctrl.play();
    } else if (!_canPlay) {
      // desktop: hanya placeholder, tidak ada player
    } else {
      _ensureController();
    }
  }

  void _pause() {
    final ctrl = _chewieCtrl;
    if (ctrl != null && ctrl.isPlaying) ctrl.pause();
  }

  Future<void> _ensureController() async {
    if (_videoCtrl != null || _initializing || !_canPlay || !mounted) return;
    _initializing = true;
    setState(() {});

    try {
      final videoCtrl = VideoPlayerController.networkUrl(
        Uri.parse(_videoUrl),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );
      await videoCtrl.initialize();
      if (!mounted) {
        videoCtrl.dispose();
        return;
      }
      final chewie = ChewieController(
        videoPlayerController: videoCtrl,
        autoPlay: true,
        looping: true,
        allowPlaybackSpeedChanging: false,
        allowMuting: true,
        hideControlsTimer: const Duration(seconds: 3),
        showControlsOnInitialize: false,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
      );
      _videoCtrl = videoCtrl;
      _chewieCtrl = chewie;
      _initializing = false;
      if (mounted) setState(() {});
      _videoCtrl!.addListener(_maybeRecordView);
    } catch (_) {
      _initializing = false;
      if (mounted) setState(() {});
    }
  }

  void _maybeRecordView() {
    final ctrl = _videoCtrl;
    if (ctrl != null && ctrl.value.isInitialized && ctrl.value.position > Duration.zero) {
      widget.provider.recordView(widget.video.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.video;
    final liked = widget.provider.isLiked(v.id);
    final likes = widget.provider.likeCount(v.id);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // ── Player / placeholder ──
          if (_chewieCtrl != null)
            Chewie(controller: _chewieCtrl!)
          else if (_initializing || !_canPlay)
            _placeholder()
          else
            _placeholder(),

          // ── Gradient bawah (legibility) ──
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 180,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black87],
                ),
              ),
            ),
          ),

          // ── Info kiri-bawah ──
          Positioned(
            left: 16,
            right: 72,
            bottom: 28,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (v.placeCategory.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      v.placeCategory,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  v.caption?.trim().isEmpty == true ? v.placeName : v.caption!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: widget.onTapPlace,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.storefront_rounded, color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          v.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Rail kanan: like + views ──
          Positioned(
            right: 10,
            bottom: 32,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _railButton(
                  icon: liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: liked ? const Color(0xFFFF3B5C) : Colors.white,
                  label: _compact(likes),
                  onTap: () => widget.provider.toggleLike(v),
                ),
                const SizedBox(height: 18),
                _railButton(
                  icon: Icons.play_circle_outline_rounded,
                  color: Colors.white,
                  label: _compact(v.views),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      color: Colors.black,
      alignment: Alignment.center,
      child: !_canPlay
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.smart_display_outlined,
                  size: 44,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Video tidak didukung di perangkat ini',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            )
          : const CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
    );
  }

  Widget _railButton({
    required IconData icon,
    required Color color,
    required String label,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  static String _compact(int n) {
    if (n >= 1000) {
      final v = n / 1000;
      return '${v.toStringAsFixed(v < 10 ? 1 : 0)}rb';
    }
    return '$n';
  }
}
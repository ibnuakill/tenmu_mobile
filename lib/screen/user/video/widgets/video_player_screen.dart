import 'package:chewie/chewie.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../video_models.dart';

/// Player layar penuh untuk satu video (dibuka dari detail tempat).
/// Desktop (tanpa plugin video) menampilkan pesan statis.
class VideoPlayerScreen extends StatefulWidget {
  final PlaceVideo video;

  const VideoPlayerScreen({super.key, required this.video});

  @override
  State<VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<VideoPlayerScreen> {
  VideoPlayerController? _videoCtrl;
  ChewieController? _chewieCtrl;
  String? _error;

  static bool get _canPlay {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  String get _videoUrl => Supabase.instance.client.storage
      .from('videos')
      .getPublicUrl(widget.video.videoPath);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (!_canPlay) return;
    try {
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(_videoUrl));
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      final chewie = ChewieController(
        videoPlayerController: ctrl,
        autoPlay: true,
        looping: true,
        allowPlaybackSpeedChanging: false,
        allowMuting: true,
        materialProgressColors: ChewieProgressColors(
          playedColor: Colors.white,
          handleColor: Colors.white,
          bufferedColor: Colors.white38,
          backgroundColor: Colors.white24,
        ),
      );
      setState(() {
        _videoCtrl = ctrl;
        _chewieCtrl = chewie;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Gagal memuat video: $e');
    }
  }

  @override
  void dispose() {
    _chewieCtrl?.dispose();
    _videoCtrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.video.placeName,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: _error != null
            ? Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              )
            : _chewieCtrl != null
                ? Chewie(controller: _chewieCtrl!)
                : !_canPlay
                    ? const Text(
                        'Video tidak didukung di perangkat ini.',
                        style: TextStyle(color: Colors.white54),
                      )
                    : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
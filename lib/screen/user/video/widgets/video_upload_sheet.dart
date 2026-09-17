import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme_provider.dart';
import '../video_provider.dart';

/// Bottom sheet upload video promosi (sisi owner).
/// Batasan: durasi ≤ 60s (iOS), ukuran ≤ 20MB, satu video per upload.
class VideoUploadSheet extends StatefulWidget {
  final int placeId;
  final String placeName;

  const VideoUploadSheet({
    super.key,
    required this.placeId,
    required this.placeName,
  });

  /// Helper: tampilkan sheet + kembalikan true jika sukses upload.
  static Future<bool> show(
    BuildContext context, {
    required int placeId,
    required String placeName,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: VideoUploadSheet(placeId: placeId, placeName: placeName),
      ),
    );
    return ok ?? false;
  }

  @override
  State<VideoUploadSheet> createState() => _VideoUploadSheetState();
}

class _VideoUploadSheetState extends State<VideoUploadSheet> {
  final _picker = ImagePicker();
  final _captionCtrl = TextEditingController();
  final _provider = VideoProvider();

  XFile? _picked;
  String? _pickedName;
  double _sizeMb = 0;
  bool _busy = false;

  @override
  void dispose() {
    _captionCtrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    try {
      final file = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(seconds: 60),
      );
      if (file == null) return;
      final bytes = await file.length();
      if (!mounted) return;
      final sizeMb = bytes / (1024 * 1024);
      if (sizeMb > 20) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ukuran video ${sizeMb.toStringAsFixed(1)}MB > 20MB. Pilih yang lebih pendek.',
              style: TextStyle(color: theme.textPrimary),
            ),
            backgroundColor: theme.snackError,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      setState(() {
        _picked = file;
        _pickedName = file.name;
        _sizeMb = sizeMb;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Gagal memilih video.'),
          backgroundColor: theme.snackError,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _submit() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (_picked == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pilih video dulu.'),
          backgroundColor: theme.snackError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final error = await _provider.uploadVideo(
      placeId: widget.placeId,
      video: _picked!,
      caption: _captionCtrl.text.trim().isEmpty ? null : _captionCtrl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error, style: TextStyle(color: theme.textPrimary)),
          backgroundColor: theme.snackError,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Video berhasil diupload!',
          style: TextStyle(color: theme.textPrimary),
        ),
        backgroundColor: theme.snackSuccess,
        behavior: SnackBarBehavior.floating,
      ),
    );
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: theme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Upload Video Promosi',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: theme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.placeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: theme.textSecondary),
          ),
          const SizedBox(height: 16),

          // ── Pilih video ──
          GestureDetector(
            onTap: _busy ? null : _pickVideo,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: theme.border),
              ),
              child: _picked == null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_call_outlined, size: 34, color: theme.btnPrimary),
                        const SizedBox(height: 8),
                        Text(
                          'Ketuk untuk pilih video (≤ 60 detik)',
                          style: TextStyle(fontSize: 12, color: theme.textSecondary),
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: Color(0xFF28A745), size: 34),
                        const SizedBox(height: 8),
                        Text(
                          _pickedName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textPrimary),
                        ),
                        Text(
                          '${_sizeMb.toStringAsFixed(1)} MB',
                          style: TextStyle(fontSize: 11, color: theme.textSecondary),
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _captionCtrl,
            enabled: !_busy,
            maxLength: 80,
            decoration: InputDecoration(
              hintText: 'Caption promosi (opsional)',
              hintStyle: TextStyle(color: theme.textHint, fontSize: 13),
              filled: true,
              fillColor: theme.bgElevated,
              isDense: true,
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            style: TextStyle(fontSize: 13, color: theme.textPrimary),
          ),

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _busy ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.btnPrimary,
                foregroundColor: theme.btnLabel,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Upload',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
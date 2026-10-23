import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme_provider.dart';
import '../post_provider.dart';
import '../../../../core/lucide_icons.dart';

/// Bottom sheet untuk MEMBUAT POSTINGAN (foto) — tersedia untuk semua pengguna.
/// Pengguna memilih tempat, memilih FOTO dari galeri, lalu menulis caption.
class PostUploadSheet extends StatefulWidget {
  const PostUploadSheet({super.key});

  static Future<bool> show(BuildContext context) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: const PostUploadSheet(),
      ),
    );
    return ok ?? false;
  }

  @override
  State<PostUploadSheet> createState() => _PostUploadSheetState();
}

class _PostUploadSheetState extends State<PostUploadSheet> {
  final _picker = ImagePicker();
  final _captionCtrl = TextEditingController();
  final _provider = PostProvider();

  List<Map<String, dynamic>> _places = [];
  bool _loadingPlaces = true;
  int? _selectedPlaceId;
  String? _selectedPlaceName;

  XFile? _picked;
  Uint8List? _pickedBytes;
  String _pickedName = '';
  double _sizeMb = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _captionCtrl.dispose();
    _provider.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    try {
      final data = await Supabase.instance.client
          .from('places')
          .select('id, nama_tempat, category')
          .eq('verification_status', 'verified')
          .order('nama_tempat', ascending: true);
      if (!mounted) return;
      setState(() {
        _places = List<Map<String, dynamic>>.from(data);
        _loadingPlaces = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  Future<void> _pickImage() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    try {
      final file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
      );
      if (file == null) return;
      final raw = await file.readAsBytes();
      if (!mounted) return;
      final sizeMb = raw.length / (1024 * 1024);
      if (sizeMb > 8) {
        _snack('Ukuran foto ${sizeMb.toStringAsFixed(1)}MB > 8MB. Pilih foto lain.',
            theme.snackError);
        return;
      }
      setState(() {
        _picked = file;
        _pickedBytes = raw;
        _pickedName = file.name;
        _sizeMb = sizeMb;
      });
    } catch (_) {
      if (!mounted) return;
      _snack('Gagal memilih foto.', theme.snackError);
    }
  }

  void _snack(String msg, Color color) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _submit() async {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    if (_picked == null) {
      _snack('Pilih foto dulu.', theme.snackError);
      return;
    }
    if ((_captionCtrl.text.trim().isEmpty) && _selectedPlaceId == null) {
      _snack('Isi caption atau pilih tempat (minimal salah satu).', theme.snackError);
      return;
    }
    setState(() => _busy = true);
    final error = await _provider.uploadPost(
      placeId: _selectedPlaceId,
      image: _picked!,
      caption: _captionCtrl.text,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) {
      _snack(error, theme.snackError);
      return;
    }
    _snack('Postingan berhasil diunggah!', theme.snackSuccess);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final bottomPad = MediaQuery.paddingOf(context).bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPad + 16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: theme.border),
      ),
      child: SingleChildScrollView(
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
              'Buat Postingan',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bagikan foto tempat atau potensi lokal di sekitarmu.',
              style: TextStyle(fontSize: 12.5, color: theme.textSecondary),
            ),
            const SizedBox(height: 16),

            // ── Pilih tempat (opsional) ──
            Text(
              'Tempat (opsional)',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: theme.bgElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.border),
              ),
              child: _loadingPlaces
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 14),
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    )
                  : DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedPlaceId,
                        isExpanded: true,
                        dropdownColor: theme.bgElevated,
                        hint: Text(
                          'Pilih tempat (opsional)',
                          style: TextStyle(color: theme.textHint, fontSize: 13),
                        ),
                        icon: LucideIcon('chevron-down',
                            color: theme.textSecondary),
                        items: _places.map((p) {
                          final name = p['nama_tempat'] as String? ?? 'Tempat';
                          return DropdownMenuItem<int>(
                            value: (p['id'] as num).toInt(),
                            child: Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: theme.textPrimary, fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: _busy
                            ? null
                            : (v) {
                                final match = _places.firstWhere(
                                  (p) => (p['id'] as num).toInt() == v,
                                  orElse: () => const {},
                                );
                                setState(() {
                                  _selectedPlaceId = v;
                                  _selectedPlaceName =
                                      match['nama_tempat'] as String?;
                                });
                              },
                      ),
                    ),
            ),
            const SizedBox(height: 14),

            // ── Pilih foto ──
            Text(
              'Foto',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: theme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _busy ? null : _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: theme.bgElevated,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: theme.border),
                ),
                child: _picked == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          LucideIcon('image-plus',
                              size: 34, color: theme.btnPrimary),
                          const SizedBox(height: 8),
                          Text(
                            'Ketuk untuk pilih foto (≤ 8MB)',
                            style: TextStyle(
                                fontSize: 12, color: theme.textSecondary),
                          ),
                        ],
                      )
                    : Stack(
                        fit: StackFit.expand,
                        children: [
                          if (_pickedBytes != null)
                            Image.memory(
                              _pickedBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: theme.bgElevated,
                                child: LucideIcon('image',
                                    color: theme.textHint, size: 34),
                              ),
                            ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              child: Text(
                                '$_pickedName  •  ${_sizeMb.toStringAsFixed(1)} MB',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 14),

            // ── Caption ──
            TextField(
              controller: _captionCtrl,
              enabled: !_busy,
              maxLength: 150,
              maxLines: 3,
              minLines: 2,
              style: TextStyle(fontSize: 13, color: theme.textPrimary),
              cursorColor: theme.btnPrimary,
              decoration: InputDecoration(
                hintText: 'Caption (opsional) — ceritakan tempat ini...',
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
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
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
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Text(
                        _selectedPlaceName == null
                            ? 'Unggah Postingan'
                            : 'Unggah ke $_selectedPlaceName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

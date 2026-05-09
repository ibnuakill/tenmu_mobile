import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';

class EditUmkmScreen extends StatefulWidget {
  final Map<String, dynamic> umkm;

  const EditUmkmScreen({super.key, required this.umkm});

  @override
  State<EditUmkmScreen> createState() => _EditUmkmScreenState();
}

class _EditUmkmScreenState extends State<EditUmkmScreen> {
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingImage = false;

  // Gambar: bisa dari URL lama atau file baru
  File? _newImageFile;
  String? _currentImageUrl;

  @override
  void initState() {
    super.initState();
    // Isi semua field dengan data lama
    _namaController.text = widget.umkm['nama_tempat'] ?? '';
    _alamatController.text = widget.umkm['alamat'] ?? '';
    _deskripsiController.text = widget.umkm['deskripsi'] ?? '';
    _latController.text = widget.umkm['latitude']?.toString() ?? '';
    _lngController.text = widget.umkm['longitude']?.toString() ?? '';
    _currentImageUrl = widget.umkm['gambar_url'];
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _deskripsiController.dispose();
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  // ── Ganti Gambar ────────────────────────────────────────────────────────
  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked == null) return;

    setState(() {
      _newImageFile = File(picked.path);
      _isUploadingImage = true;
    });

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
      await Supabase.instance.client.storage
          .from('umkm_images')
          .upload(fileName, _newImageFile!);

      final url = Supabase.instance.client.storage
          .from('umkm_images')
          .getPublicUrl(fileName);

      setState(() => _currentImageUrl = url);

      if (mounted) _toast('Gambar berhasil diganti! ✅');
    } catch (e) {
      if (mounted) _toast('Gagal mengunggah gambar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  // ── Simpan Perubahan ─────────────────────────────────────────────────────
  Future<void> _updateData() async {
    if (_namaController.text.trim().isEmpty) {
      _toast('Nama tempat tidak boleh kosong!', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client
          .from('umkm')
          .update({
            'nama_tempat': _namaController.text.trim(),
            'alamat': _alamatController.text.trim(),
            'deskripsi': _deskripsiController.text.trim(),
            'latitude': double.tryParse(_latController.text.trim()),
            'longitude': double.tryParse(_lngController.text.trim()),
            'gambar_url': _currentImageUrl, // ← ikut terupdate
          })
          .eq('id', widget.umkm['id']);

      if (mounted) {
        _toast('Data berhasil diperbarui!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _toast('Gagal menyimpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String msg, {bool isError = false}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: TextStyle(color: theme.textPrimary)),
        backgroundColor: isError ? theme.snackError : theme.snackSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError ? theme.snackErrorBorder : theme.snackSuccessBorder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        title: Text(
          'Edit Tempat',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: theme.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PRATINJAU GAMBAR ──────────────────────────────────────────
            _buildImageSection(theme),

            const SizedBox(height: 24),

            // ── FORM CARD ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Nama Tempat', theme),
                  const SizedBox(height: 8),
                  _field(
                    controller: _namaController,
                    hint: 'Nama tempat nongkrong',
                    icon: Icons.storefront_outlined,
                    theme: theme,
                  ),

                  const SizedBox(height: 16),
                  _label('Deskripsi', theme),
                  const SizedBox(height: 8),
                  _field(
                    controller: _deskripsiController,
                    hint: 'Deskripsikan tempat ini...',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                    theme: theme,
                  ),

                  const SizedBox(height: 16),
                  Divider(color: theme.border),
                  const SizedBox(height: 16),

                  _label('Koordinat Lokasi', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _latController,
                          hint: 'Latitude',
                          icon: Icons.my_location,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _field(
                          controller: _lngController,
                          hint: 'Longitude',
                          icon: Icons.my_location,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── TOMBOL SIMPAN ─────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 52,
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: theme.textSecondary,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _updateData,
                      icon: Icon(
                        Icons.check_rounded,
                        color: theme.btnLabel,
                        size: 20,
                      ),
                      label: Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: theme.btnLabel,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.btnPrimary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Seksi Gambar ────────────────────────────────────────────────────────
  Widget _buildImageSection(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Pratinjau gambar
          if (_newImageFile != null)
            // Gambar baru dari galeri
            Image.file(
              _newImageFile!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
            )
          else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty)
            // Gambar lama dari URL
            Stack(
              children: [
                Image.network(
                  _currentImageUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _imagePlaceholder(theme),
                ),
                // Label "Gambar Saat Ini"
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.bgBase.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.border),
                    ),
                    child: Text(
                      'Gambar Saat Ini',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            _imagePlaceholder(theme),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                icon: _isUploadingImage
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.textSecondary,
                        ),
                      )
                    : Icon(
                        Icons.photo_library_outlined,
                        size: 18,
                        color: theme.iconColor,
                      ),
                label: Text(
                  _isUploadingImage
                      ? 'Mengunggah...'
                      : (_currentImageUrl != null
                            ? 'Ganti Gambar'
                            : 'Pilih Gambar dari Galeri'),
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder(ThemeProvider theme) => Container(
    height: 160,
    color: theme.bgElevated,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 40, color: theme.textHint),
          const SizedBox(height: 8),
          Text(
            'Belum ada gambar',
            style: TextStyle(color: theme.textHint, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  // ── Helper Widgets ─────────────────────────────────────────────────────────
  Widget _label(String text, ThemeProvider theme) => Text(
    text,
    style: TextStyle(
      color: theme.textSecondary,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      letterSpacing: 0.5,
    ),
  );

  Widget _field({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    required ThemeProvider theme,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: TextStyle(color: theme.textPrimary, fontSize: 15),
      cursorColor: theme.borderFocus,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: theme.textHint, fontSize: 14),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: theme.iconColor, size: 20)
            : null,
        filled: true,
        fillColor: theme.bgElevated,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.borderFocus, width: 1.5),
        ),
      ),
    );
  }
}

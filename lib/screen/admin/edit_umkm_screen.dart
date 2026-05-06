import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/app_colors.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          msg,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        backgroundColor: isError
            ? AppColors.snackError
            : AppColors.snackSuccess,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: isError
                ? AppColors.snackErrorBorder
                : AppColors.snackSuccessBorder,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: const Text(
          'Edit Tempat',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppColors.bgBase,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── PRATINJAU GAMBAR ──────────────────────────────────────────
            _buildImageSection(),

            const SizedBox(height: 24),

            // ── FORM CARD ─────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.bgSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label('Nama Tempat'),
                  const SizedBox(height: 8),
                  _field(
                    controller: _namaController,
                    hint: 'Nama tempat nongkrong',
                    icon: Icons.storefront_outlined,
                  ),

                  const SizedBox(height: 16),
                  _label('Deskripsi'),
                  const SizedBox(height: 8),
                  _field(
                    controller: _deskripsiController,
                    hint: 'Deskripsikan tempat ini...',
                    icon: Icons.description_outlined,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: AppColors.border),
                  const SizedBox(height: 16),

                  _label('Koordinat Lokasi'),
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
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppColors.textSecondary,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : ElevatedButton.icon(
                      onPressed: _updateData,
                      icon: const Icon(
                        Icons.check_rounded,
                        color: AppColors.btnLabel,
                        size: 20,
                      ),
                      label: const Text(
                        'Simpan Perubahan',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.btnLabel,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.btnPrimary,
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
  Widget _buildImageSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
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
                  errorBuilder: (_, _, _) => _imagePlaceholder(),
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
                      color: AppColors.bgBase.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Text(
                      'Gambar Saat Ini',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            _imagePlaceholder(),

          // Tombol ganti gambar
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                icon: _isUploadingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textSecondary,
                        ),
                      )
                    : const Icon(
                        Icons.photo_library_outlined,
                        size: 18,
                        color: AppColors.iconColor,
                      ),
                label: Text(
                  _isUploadingImage
                      ? 'Mengunggah...'
                      : (_currentImageUrl != null
                            ? 'Ganti Gambar'
                            : 'Pilih Gambar dari Galeri'),
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.border),
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

  Widget _imagePlaceholder() => Container(
    height: 160,
    color: AppColors.bgElevated,
    child: const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 40, color: AppColors.textHint),
          SizedBox(height: 8),
          Text(
            'Belum ada gambar',
            style: TextStyle(color: AppColors.textHint, fontSize: 13),
          ),
        ],
      ),
    ),
  );

  // ── Helper Widgets ─────────────────────────────────────────────────────────
  Widget _label(String text) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textSecondary,
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      cursorColor: AppColors.borderFocus,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textHint, fontSize: 14),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: AppColors.iconColor, size: 20)
            : null,
        filled: true,
        fillColor: AppColors.bgElevated,
        contentPadding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: maxLines > 1 ? 14 : 0,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.borderFocus,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_category.dart';
import '../../core/poi_facility.dart';
import '../../core/poi_image_helper.dart';

class EditPlaceScreen extends StatefulWidget {
  final Map<String, dynamic> place;

  const EditPlaceScreen({super.key, required this.place});

  @override
  State<EditPlaceScreen> createState() => _EditPlaceScreenState();
}

class _EditPlaceScreenState extends State<EditPlaceScreen> {
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _nomorTeleponController = TextEditingController();
  final _jamBukaController = TextEditingController();
  final _jamTutupController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();

  bool _isLoading = false;
  bool _isUploadingImage = false;
  final List<String> _imageUrls = [];
  int _selectedImageIndex = 0;
  String _selectedCategory = PoiCategory.lainnya;
  final Set<String> _selectedFacilities = {};

  @override
  void initState() {
    super.initState();
    _namaController.text = widget.place['nama_tempat'] ?? '';
    _alamatController.text = widget.place['alamat'] ?? '';
    _deskripsiController.text = widget.place['deskripsi'] ?? '';
    _nomorTeleponController.text = widget.place['nomor_telepon'] ?? '';
    _jamBukaController.text = widget.place['jam_buka'] ?? '';
    _jamTutupController.text = widget.place['jam_tutup'] ?? '';
    _latController.text = widget.place['latitude']?.toString() ?? '';
    _lngController.text = widget.place['longitude']?.toString() ?? '';
    _minPriceController.text = (widget.place['min_price'] ?? 0).toString();
    _maxPriceController.text = (widget.place['max_price'] ?? 100000).toString();
    _imageUrls.addAll(PoiImageHelper.extractImageUrls(widget.place));

    final cat = widget.place['category'] ?? PoiCategory.lainnya;
    _selectedCategory = PoiCategory.isValidCategory(cat)
        ? cat
        : PoiCategory.lainnya;

    final fas = widget.place['fasilitas'];
    if (fas is List) {
      _selectedFacilities.addAll(fas.cast<String>());
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _alamatController.dispose();
    _deskripsiController.dispose();
    _nomorTeleponController.dispose();
    _jamBukaController.dispose();
    _jamTutupController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage(
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    if (pickedFiles.isEmpty) return;

    setState(() => _isUploadingImage = true);
    try {
      final uploadedUrls = <String>[];
      for (final picked in pickedFiles) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${picked.name}';
        await Supabase.instance.client.storage
            .from('umkm_images')
            .upload(fileName, File(picked.path));

        uploadedUrls.add(
          Supabase.instance.client.storage
              .from('umkm_images')
              .getPublicUrl(fileName),
        );
      }

      setState(() {
        _imageUrls.addAll(
          uploadedUrls.where((url) => !_imageUrls.contains(url)),
        );
        if (_selectedImageIndex >= _imageUrls.length) {
          _selectedImageIndex = _imageUrls.isEmpty ? 0 : _imageUrls.length - 1;
        }
      });

      if (mounted) {
        _toast('${uploadedUrls.length} gambar berhasil ditambahkan.');
      }
    } catch (e) {
      if (mounted) _toast('Gagal mengunggah gambar: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  void _removeImage(int index) {
    setState(() {
      _imageUrls.removeAt(index);
      if (_imageUrls.isEmpty) {
        _selectedImageIndex = 0;
      } else if (_selectedImageIndex >= _imageUrls.length) {
        _selectedImageIndex = _imageUrls.length - 1;
      }
    });
  }

  void _setPrimaryImage(int index) {
    if (index <= 0 || index >= _imageUrls.length) return;
    setState(() {
      final selected = _imageUrls.removeAt(index);
      _imageUrls.insert(0, selected);
      _selectedImageIndex = 0;
    });
  }

  Future<void> _updateData() async {
    if (_namaController.text.trim().isEmpty) {
      _toast('Nama tempat tidak boleh kosong.', isError: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final minPrice =
          int.tryParse(
            _minPriceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          0;
      final maxPrice =
          int.tryParse(
            _maxPriceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
          ) ??
          100000;

      await Supabase.instance.client
          .from('places')
          .update({
            'owner_id':
                widget.place['owner_id'] ??
                Supabase.instance.client.auth.currentUser?.id,
            'nama_tempat': _namaController.text.trim(),
            'alamat': _alamatController.text.trim(),
            'deskripsi': _deskripsiController.text.trim(),
            'nomor_telepon': _nomorTeleponController.text.trim().isNotEmpty
                ? _nomorTeleponController.text.trim()
                : null,
            'jam_buka': _jamBukaController.text.trim().isNotEmpty
                ? _jamBukaController.text.trim()
                : null,
            'jam_tutup': _jamTutupController.text.trim().isNotEmpty
                ? _jamTutupController.text.trim()
                : null,
            'latitude': double.tryParse(_latController.text.trim()),
            'longitude': double.tryParse(_lngController.text.trim()),
            'gambar_url': _imageUrls.isNotEmpty ? _imageUrls.first : null,
            'image_urls': _imageUrls,
            'category': _selectedCategory,
            'min_price': minPrice,
            'max_price': maxPrice,
            'fasilitas': _selectedFacilities.toList(),
          })
          .eq('id', widget.place['id']);

      if (mounted) {
        _toast('Data berhasil diperbarui.');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _toast('Gagal menyimpan: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toast(String message, {bool isError = false}) {
    final theme = Provider.of<ThemeProvider>(context, listen: false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: theme.textPrimary)),
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
            _buildImageSection(theme),
            const SizedBox(height: 24),
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
                  _label('Alamat Lengkap', theme),
                  const SizedBox(height: 8),
                  _field(
                    controller: _alamatController,
                    hint: 'Contoh: Jl. Merdeka No. 12, Bandung',
                    icon: Icons.location_on_outlined,
                    maxLines: 2,
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
                  _label('Nomor Telepon / WhatsApp', theme),
                  const SizedBox(height: 8),
                  _field(
                    controller: _nomorTeleponController,
                    hint: 'Contoh: 081234567890',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    theme: theme,
                  ),
                  const SizedBox(height: 16),
                  _label('Jam Operasional', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _jamBukaController,
                          hint: '08:00',
                          icon: Icons.schedule_outlined,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _jamTutupController,
                          hint: '22:00',
                          icon: Icons.schedule,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Kategori', theme),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    dropdownColor: theme.bgSurface,
                    style: TextStyle(color: theme.textPrimary, fontSize: 15),
                    decoration: _inputDecoration(
                      hint: 'Pilih kategori',
                      icon: Icons.category_outlined,
                      theme: theme,
                    ),
                    items: PoiCategory.allCategories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          '${PoiCategory.getCategoryEmoji(category)} $category',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  _label('Fasilitas', theme),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: PoiFacility.all.map((f) {
                      final selected = _selectedFacilities.contains(f.id);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selectedFacilities.remove(f.id);
                            } else {
                              _selectedFacilities.add(f.id);
                            }
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.btnPrimary
                                : theme.bgElevated,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected ? theme.btnPrimary : theme.border,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                f.icon,
                                size: 16,
                                color: selected
                                    ? theme.btnLabel
                                    : theme.iconColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? theme.btnLabel
                                      : theme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  _label('Rentang Harga', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _minPriceController,
                          hint: 'Harga minimum',
                          icon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _maxPriceController,
                          hint: 'Harga maksimum',
                          icon: Icons.payments,
                          keyboardType: TextInputType.number,
                          theme: theme,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _label('Koordinat', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _field(
                          controller: _latController,
                          hint: 'Latitude',
                          icon: Icons.my_location_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          ),
                          theme: theme,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _field(
                          controller: _lngController,
                          hint: 'Longitude',
                          icon: Icons.place_outlined,
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
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: theme.textSecondary,
                        strokeWidth: 2,
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

  Widget _buildImageSection(ThemeProvider theme) {
    final previewUrl = _imageUrls.isNotEmpty
        ? _imageUrls[_selectedImageIndex]
        : null;

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
          if (previewUrl != null)
            Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: previewUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) => _imagePlaceholder(theme),
                ),
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
                      _selectedImageIndex == 0
                          ? 'Cover utama'
                          : 'Foto ${_selectedImageIndex + 1}',
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
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Text(
              'Galeri UMKM',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
            child: Text(
              'Foto pertama akan dipakai sebagai cover. Admin bisa menambah foto tempat, menu, dan pricelist.',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
          if (_imageUrls.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: SizedBox(
                height: 88,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imageUrls.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final isSelected = index == _selectedImageIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedImageIndex = index),
                      child: Stack(
                        children: [
                          Container(
                            width: 88,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? theme.borderFocus
                                    : theme.border,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: CachedNetworkImage(
                              imageUrl: _imageUrls[index],
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Row(
                              children: [
                                if (index != 0)
                                  GestureDetector(
                                    onTap: () => _setPrimaryImage(index),
                                    child: _thumbAction(
                                      theme,
                                      icon: Icons.star_outline_rounded,
                                    ),
                                  ),
                                const SizedBox(width: 4),
                                GestureDetector(
                                  onTap: () => _removeImage(index),
                                  child: _thumbAction(
                                    theme,
                                    icon: Icons.close_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: OutlinedButton.icon(
                onPressed: _isUploadingImage ? null : _pickAndUploadImages,
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
                      : 'Tambah Foto Tempat / Menu / Pricelist',
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

  Widget _thumbAction(ThemeProvider theme, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.bgBase.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: theme.textPrimary),
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

  Widget _label(String text, ThemeProvider theme) => Text(
    text,
    style: TextStyle(
      color: theme.textSecondary,
      fontWeight: FontWeight.w600,
      fontSize: 12,
      letterSpacing: 0.5,
    ),
  );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required ThemeProvider theme,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: theme.textHint, fontSize: 14),
      prefixIcon: Icon(icon, color: theme.iconColor, size: 20),
      filled: true,
      fillColor: theme.bgElevated,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
    );
  }

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
      decoration: _inputDecoration(hint: hint, icon: icon, theme: theme)
          .copyWith(
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: maxLines > 1 ? 14 : 0,
            ),
            prefixIcon: maxLines == 1
                ? Icon(icon, color: theme.iconColor, size: 20)
                : null,
          ),
    );
  }
}

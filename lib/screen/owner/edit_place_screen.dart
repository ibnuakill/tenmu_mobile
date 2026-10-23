import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'widgets/place_form_style.dart';
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

  bool _isLoading = false;
  bool _isUploadingImage = false;
  final List<String> _imageUrls = [];
  int _selectedImageIndex = 0;
  String _selectedCategory = PoiCategory.ritel;
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
    _imageUrls.addAll(PoiImageHelper.extractImageUrls(widget.place));

    final rawCat = widget.place['category']?.toString() ?? '';
    final normalized = PoiCategory.normalizeCategory(rawCat);
    _selectedCategory = PoiCategory.allCategories.contains(normalized)
        ? normalized
        : PoiCategory.ritel;

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
        final bytes = await picked.readAsBytes();
        await Supabase.instance.client.storage
            .from('umkm_images')
            .uploadBinary(fileName, bytes,
                fileOptions: FileOptions(contentType: picked.mimeType));

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
      await Supabase.instance.client
          .from('places')
          .update(_buildUpdatePayload())
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

  Map<String, dynamic> _buildUpdatePayload() {
    return {
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
      'fasilitas': _selectedFacilities.toList(),
    };
  }

  void _toast(String message, {bool isError = false}) {
    final theme = const PlaceFormStyle();
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
    final theme = const PlaceFormStyle();
    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: PlaceFormStyle.appBar(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PlaceFormHeader(
              title: 'Edit Tempat',
              subtitle: 'Perbarui data tempat kamu, lalu simpan perubahannya.',
            ),
            const SizedBox(height: 22),
            _buildImageSection(theme),
            const SizedBox(height: 14),

            PlaceSection(
              title: 'Informasi Tempat',
              icon: Icons.storefront_outlined,
              child: Column(
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
                ],
              ),
            ),
            const SizedBox(height: 14),

            PlaceSection(
              title: 'Jam Operasional',
              icon: Icons.access_time,
              child: Row(
                children: [
                  Expanded(
                    child: _field(
                      controller: _jamBukaController,
                      hint: 'Jam buka (08:00)',
                      icon: Icons.schedule_outlined,
                      theme: theme,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _field(
                      controller: _jamTutupController,
                      hint: 'Jam tutup (22:00)',
                      icon: Icons.schedule,
                      theme: theme,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            PlaceSection(
              title: 'Kategori & Fasilitas',
              icon: Icons.category_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: PoiCategory.allCategories
                            .contains(_selectedCategory)
                        ? _selectedCategory
                        : PoiCategory.ritel,
                    dropdownColor: theme.bgSurface,
                    style: TextStyle(color: theme.textPrimary, fontSize: 14.5),
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
                        setState(() {
                          _selectedCategory = value;
                        });
                      }
                    },
                  ),
                  _label('Fasilitas', theme),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
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
                            horizontal: 13,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: selected
                                ? theme.btnPrimary
                                : theme.bgBase,
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
                                size: 15,
                                color: selected
                                    ? theme.btnLabel
                                    : theme.iconColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                f.label,
                                style: TextStyle(
                                  fontSize: 12.5,
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
                ],
              ),
            ),
            const SizedBox(height: 14),

            PlaceSection(
              title: 'Koordinat',
              icon: Icons.my_location_outlined,
              child: Row(
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
            ),
            PlacePrimaryButton(
              label: 'Simpan Perubahan',
              icon: Icons.check_rounded,
              loading: _isLoading,
              onPressed: _updateData,
            ),
          ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  Widget _buildImageSection(PlaceFormStyle theme) {
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

  Widget _thumbAction(PlaceFormStyle theme, {required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.bgBase.withValues(alpha: 0.85),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 14, color: theme.textPrimary),
    );
  }

  Widget _imagePlaceholder(PlaceFormStyle theme) => Container(
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

  Widget _label(String text, PlaceFormStyle theme) => Text(
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
    required PlaceFormStyle theme,
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
    required PlaceFormStyle theme,
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

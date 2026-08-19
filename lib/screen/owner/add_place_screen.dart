import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../../core/theme_provider.dart';
import '../../core/location_permission_helper.dart';
import '../../core/notification_service.dart';
import '../../core/poi_category.dart';
import '../../core/poi_facility.dart';
import '../../core/poi_image_helper.dart';
import '../../core/geocoding_service.dart';

class AddPlaceScreen extends StatefulWidget {
  const AddPlaceScreen({super.key});

  @override
  State<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends State<AddPlaceScreen> {
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _nomorTeleponController = TextEditingController();

  final _searchController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  final _jamBukaController = TextEditingController();
  final _jamTutupController = TextEditingController();

  String _selectedCategory = PoiCategory.lainnya; // Default category
  final Set<String> _selectedFacilities = {};

  bool _isLoading = false;
  bool _isUploadingImage = false;
  final List<String> _imageUrls = [];
  int _selectedImageIndex = 0;

  Future<void> _pickAndUploadImage() async {
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

      for (final pickedFile in pickedFiles) {
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
        final file = File(pickedFile.path);

        await Supabase.instance.client.storage
            .from('umkm_images')
            .upload(fileName, file);

        final imageUrl = Supabase.instance.client.storage
            .from('umkm_images')
            .getPublicUrl(fileName);
        uploadedUrls.add(imageUrl);
      }

      setState(() {
        _imageUrls.addAll(
          uploadedUrls.where((url) => !_imageUrls.contains(url)),
        );
        if (_imageUrls.isNotEmpty && _selectedImageIndex >= _imageUrls.length) {
          _selectedImageIndex = 0;
        }
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gambar berhasil diunggah! ✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengunggah gambar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isUploadingImage = false);
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

  Future<void> _searchLocationOSM() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Masukkan nama tempat atau alamat untuk dicari!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=5',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'TenMuMobileApp/1.0'},
      );

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);

        if (data.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Lokasi tidak ditemukan. Coba kata kunci lain.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }

        if (mounted) {
          final theme = Provider.of<ThemeProvider>(context, listen: false);
          showModalBottomSheet(
            context: context,
            backgroundColor: theme.bgSurface,
            shape: RoundedRectangleBorder(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              side: BorderSide(color: theme.border),
            ),
            builder: (context) {
              return Container(
                padding: const EdgeInsets.all(16),
                color: theme.bgSurface,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: theme.border,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Text(
                      'Pilih Lokasi yang Sesuai',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: theme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: data.length,
                        itemBuilder: (context, index) {
                          final item = data[index];
                          return ListTile(
                            leading: Icon(
                              Icons.location_on_outlined,
                              color: theme.iconColor,
                            ),
                            title: Text(
                              item['name'] ?? 'Lokasi',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              item['display_name'] ?? '',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            onTap: () {
                              setState(() {
                                if (_alamatController.text.isEmpty) {
                                  _alamatController.text = item['display_name'];
                                }
                                if (_namaController.text.isEmpty &&
                                    item['name'] != null &&
                                    item['name'] != '') {
                                  _namaController.text = item['name'];
                                }
                                _latController.text = item['lat'];
                                _lngController.text = item['lon'];
                              });
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Alamat & Koordinat berhasil didapatkan! 📍',
                                    style: TextStyle(color: theme.textPrimary),
                                  ),
                                  backgroundColor: theme.snackSuccess,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: theme.snackSuccessBorder,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        }
      } else {
        throw Exception('Gagal menghubungi server pencarian peta.');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error jaringan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      final accessStatus = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'mengambil lokasi tempat',
      );

      if (accessStatus != LocationAccessStatus.granted) {
        if (mounted && accessStatus == LocationAccessStatus.permissionDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Izin lokasi belum diberikan.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        _latController.text = position.latitude.toString();
        _lngController.text = position.longitude.toString();
      });

      // Reverse geocode otomatis
      _autoFillAddress(position.latitude, position.longitude);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi saat ini berhasil didapatkan! 📍✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mendapatkan lokasi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _autoFillAddress(double lat, double lng) async {
    try {
      final alamat = await GeocodingService.reverse(lat, lng);
      if (alamat != null && mounted) {
        setState(() {
          if (_alamatController.text.isEmpty) {
            _alamatController.text = alamat;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _bukaPetaPilihLokasi() async {
    LatLng center;
    if (_latController.text.isNotEmpty && _lngController.text.isNotEmpty) {
      final lat = double.tryParse(_latController.text);
      final lng = double.tryParse(_lngController.text);
      center = LatLng(lat ?? -6.200000, lng ?? 106.816666);
    } else {
      center = const LatLng(-6.200000, 106.816666);
    }

    LatLng? pickedLocation = center;
    final mapController = MapController();

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Dialog(
              insetPadding: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.7,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 15.0,
                          minZoom: 4,
                          maxZoom: 22,
                          onTap: (tapPos, latlng) {
                            setStateDialog(() {
                              pickedLocation = latlng;
                            });
                            // Pin shown via rebuild with marker
                          },
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.tenmu.app',
                          ),
                          if (pickedLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: pickedLocation!,
                                  width: 40,
                                  height: 40,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 40,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      // My-location button
                      Positioned(
                        right: 16,
                        bottom: 80,
                        child: FloatingActionButton(
                          mini: true,
                          onPressed: () async {
                            try {
                              final accessStatus =
                                  await LocationPermissionHelper.ensureAccess(
                                    context,
                                    featureLabel: 'mengambil lokasi saat ini',
                                  );
                              if (accessStatus !=
                                  LocationAccessStatus.granted) {
                                if (!context.mounted) return;
                                if (accessStatus ==
                                    LocationAccessStatus.permissionDenied) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Izin lokasi belum diberikan.',
                                      ),
                                    ),
                                  );
                                }
                                return;
                              }

                              final position =
                                  await Geolocator.getCurrentPosition(
                                    locationSettings: const LocationSettings(
                                      accuracy: LocationAccuracy.high,
                                    ),
                                  );
                              if (!context.mounted) return;
                              final newLoc = LatLng(
                                position.latitude,
                                position.longitude,
                              );
                              mapController.move(newLoc, 16.0);
                              setStateDialog(() {
                                pickedLocation = newLoc;
                              });
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Gagal mendapatkan lokasi saat ini.',
                                  ),
                                ),
                              );
                            }
                          },
                          backgroundColor: Colors.white,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      // Instruction banner
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 60,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Text(
                            'Sentuh peta pada lokasi yang diinginkan',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      // Confirm button
                      Positioned(
                        bottom: 16,
                        left: 16,
                        right: 16,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context, pickedLocation);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Konfirmasi Lokasi Ini',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Close button
                      Positioned(
                        top: 10,
                        right: 10,
                        child: CircleAvatar(
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.black),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    ).then((result) {
      if (!mounted) return;
      if (result != null && result is LatLng) {
        final latLng = result;
        setState(() {
          _latController.text = latLng.latitude.toString();
          _lngController.text = latLng.longitude.toString();
        });
        _autoFillAddress(latLng.latitude, latLng.longitude);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lokasi berhasil dipilih dari peta! 🗺️✅'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  // FUNGSI SIMPAN DATA YANG SEMPAT HILANG (Lengkap dengan pengunci anti-kosong)
  Future<void> _simpanData() async {
    // Pengunci biar Admin nggak bisa asal simpan kalau koordinat kosong
    if (_namaController.text.isEmpty ||
        _latController.text.isEmpty ||
        _lngController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gagal! Pastikan Nama, Latitude, dan Longitude sudah terisi.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await Supabase.instance.client.from('places').insert({
        'owner_id': Supabase.instance.client.auth.currentUser?.id,
        'nama_tempat': _namaController.text.trim(),
        'alamat': _alamatController.text.trim().isNotEmpty
            ? _alamatController.text.trim()
            : 'Lokasi: ${_latController.text}, ${_lngController.text}',
        'deskripsi': _deskripsiController.text.trim(),
        'gambar_url': _imageUrls.isNotEmpty ? _imageUrls.first : null,
        'image_urls': _imageUrls,
        'latitude': double.tryParse(_latController.text),
        'longitude': double.tryParse(_lngController.text),
        'nomor_telepon': _nomorTeleponController.text.trim().isNotEmpty
            ? _nomorTeleponController.text.trim()
            : null,
        'jam_buka': _jamBukaController.text.trim().isNotEmpty
            ? _jamBukaController.text.trim()
            : null,
        'jam_tutup': _jamTutupController.text.trim().isNotEmpty
            ? _jamTutupController.text.trim()
            : null,
        'category': _selectedCategory,
        'is_featured': false,
        'fasilitas': _selectedFacilities.toList(),
      }).select();

      // Kirim notifikasi ke admin untuk verifikasi
      final insertedId = (result as List).first['id'] as int;
      NotificationService.notifyAdminsNewSubmission(
        placeId: insertedId,
        placeName: _namaController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tempat nongkrong berhasil ditambahkan! 🎉'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ── Helper: Dark Mode TextField ─────────────────────────────────────────
  Widget _darkField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? suffixIcon,
    ValueChanged<String>? onSubmitted,
  }) {
    final theme = Provider.of<ThemeProvider>(context);
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onSubmitted: onSubmitted,
      style: TextStyle(color: theme.textPrimary, fontSize: 15),
      cursorColor: theme.borderFocus,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: theme.textSecondary, fontSize: 13),
        hintText: hint,
        hintStyle: TextStyle(color: theme.textHint, fontSize: 14),
        prefixIcon: maxLines == 1
            ? Icon(icon, color: theme.iconColor, size: 20)
            : null,
        suffixIcon: suffixIcon,
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

  Widget _buildImageSection(ThemeProvider theme) {
    final previewUrl = _imageUrls.isNotEmpty
        ? _imageUrls[_selectedImageIndex]
        : PoiImageHelper.primaryImageUrl({'image_urls': _imageUrls});

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Galeri Foto',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: theme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Foto pertama jadi cover utama. Tambahkan foto tempat, menu, dan pricelist.',
          style: TextStyle(
            fontSize: 12,
            color: theme.textSecondary,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 8),
        if (previewUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Stack(
              children: [
                CachedNetworkImage(
                  imageUrl: previewUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
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
                      color: theme.bgBase.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _selectedImageIndex == 0
                          ? 'Cover utama'
                          : 'Foto ${_selectedImageIndex + 1}',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            height: 180,
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.bgElevated,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: theme.border),
            ),
            child: Center(
              child: Icon(
                Icons.image_outlined,
                size: 50,
                color: theme.textHint,
              ),
            ),
          ),
        if (_imageUrls.isNotEmpty) ...[
          const SizedBox(height: 10),
          SizedBox(
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
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: theme.bgBase.withValues(alpha: 0.85),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.star_outline_rounded,
                                    size: 14,
                                    color: theme.textPrimary,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: theme.bgBase.withValues(alpha: 0.85),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 14,
                                  color: theme.textPrimary,
                                ),
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
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        title: Text(
          'Tambah Tempat Baru',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: theme.bgBase,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.textPrimary),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _darkField(
                  controller: _namaController,
                  label: 'Nama Tempat',
                  hint: 'Contoh: Kopi Kenangan Merdeka',
                  icon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: theme.bgSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.border),
                  ),
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lokasi Tempat',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _darkField(
                        controller: _searchController,
                        label: 'Cari Nama Tempat / Jalan',
                        hint: 'Contoh: Alun-alun Bandung',
                        icon: Icons.search,
                        suffixIcon: IconButton(
                          icon: Icon(Icons.search, color: theme.iconColor),
                          onPressed: _searchLocationOSM,
                          tooltip: 'Cari Lokasi',
                        ),
                        onSubmitted: (_) => _searchLocationOSM(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: ElevatedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _getCurrentLocation,
                                icon: Icon(
                                  Icons.my_location,
                                  size: 16,
                                  color: theme.btnLabel,
                                ),
                                label: Text(
                                  'GPS',
                                  style: TextStyle(
                                    color: theme.btnLabel,
                                    fontSize: 13,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: theme.btnPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  elevation: 0,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 42,
                              child: OutlinedButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : _bukaPetaPilihLokasi,
                                icon: Icon(
                                  Icons.map_outlined,
                                  size: 16,
                                  color: theme.iconColor,
                                ),
                                label: Text(
                                  'Peta Manual',
                                  style: TextStyle(
                                    color: theme.textSecondary,
                                    fontSize: 13,
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
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _darkField(
                              controller: _latController,
                              label: 'Latitude',
                              hint: '-6.917464',
                              icon: Icons.my_location,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                    signed: true,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _darkField(
                              controller: _lngController,
                              label: 'Longitude',
                              hint: '107.619123',
                              icon: Icons.my_location,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
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
                const SizedBox(height: 12),
                _darkField(
                  controller: _alamatController,
                  label: 'Alamat Lengkap',
                  hint: 'Contoh: Jl. Merdeka No. 12, Bandung',
                  icon: Icons.location_on_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                _darkField(
                  controller: _deskripsiController,
                  label: 'Deskripsi Singkat',
                  hint: 'Ceritakan keunikan tempat ini...',
                  icon: Icons.description_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                _darkField(
                  controller: _nomorTeleponController,
                  label: 'Nomor Telepon / WhatsApp',
                  hint: 'Contoh: 081234567890',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                // ── Jam Operasional ──
                Row(
                  children: [
                    Expanded(
                      child: _darkField(
                        controller: _jamBukaController,
                        label: 'Jam Buka',
                        hint: '08:00',
                        icon: Icons.access_time,
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.schedule,
                            color: theme.iconColor,
                            size: 20,
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                _jamBukaController.text =
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _darkField(
                        controller: _jamTutupController,
                        label: 'Jam Tutup',
                        hint: '22:00',
                        icon: Icons.access_time_filled,
                        suffixIcon: IconButton(
                          icon: Icon(
                            Icons.schedule,
                            color: theme.iconColor,
                            size: 20,
                          ),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay.now(),
                            );
                            if (picked != null) {
                              setState(() {
                                _jamTutupController.text =
                                    '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildImageSection(theme),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                    icon: _isUploadingImage
                        ? SizedBox(
                            width: 18,
                            height: 18,
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
                          ? 'Mengunggah Gambar...'
                          : 'Upload Foto Tempat / Menu / Pricelist',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.border),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Divider(color: theme.border),
                ),

                Text(
                  'Kategori',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Dropdown Kategori ──
                DropdownButtonFormField<String>(
                  initialValue: PoiCategory.allCategories.contains(_selectedCategory)
                      ? _selectedCategory
                      : PoiCategory.lainnya,
                  dropdownColor: theme.bgSurface,
                  style: TextStyle(color: theme.textPrimary, fontSize: 15),
                  decoration: InputDecoration(
                    labelText: 'Kategori Tempat',
                    labelStyle: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.category_outlined,
                      color: theme.iconColor,
                      size: 20,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: theme.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: theme.borderFocus,
                        width: 2,
                      ),
                    ),
                  ),
                  items: PoiCategory.allCategories.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Row(
                        children: [
                          Text(PoiCategory.getCategoryEmoji(category)),
                          const SizedBox(width: 8),
                          Text(category),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      if (value != null) _selectedCategory = value;
                    });
                  },
                ),
                const SizedBox(height: 12),

                // ── Fasilitas ──
                const SizedBox(height: 16),
                Text(
                  'Fasilitas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: theme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
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
                          color: selected ? theme.btnPrimary : theme.bgElevated,
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
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _simpanData,
                    icon: _isLoading
                        ? SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.btnLabel,
                            ),
                          )
                        : Icon(
                            Icons.check_rounded,
                            color: theme.btnLabel,
                            size: 20,
                          ),
                    label: Text(
                      'Simpan Data',
                      style: TextStyle(
                        fontSize: 16,
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
        ),
      ),
    );
  }
}

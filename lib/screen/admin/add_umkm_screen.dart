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

class AddUmkmScreen extends StatefulWidget {
  const AddUmkmScreen({super.key});

  @override
  State<AddUmkmScreen> createState() => _AddUmkmScreenState();
}

class _AddUmkmScreenState extends State<AddUmkmScreen> {
  final _namaController = TextEditingController();
  final _alamatController = TextEditingController();
  final _deskripsiController = TextEditingController();
  final _gambarUrlController = TextEditingController();

  final _searchController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  bool _isLoading = false;
  File? _selectedImage;
  bool _isUploadingImage = false;

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );

    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
      _isUploadingImage = true;
    });

    try {
      final fileName =
          '${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';

      // Menggunakan bucket 'umkm_images' di Supabase
      await Supabase.instance.client.storage
          .from('umkm_images')
          .upload(fileName, _selectedImage!);

      final imageUrl = Supabase.instance.client.storage
          .from('umkm_images')
          .getPublicUrl(fileName);

      setState(() {
        _gambarUrlController.text = imageUrl;
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

  Future<void> _bukaPetaPilihLokasi() async {
    // Default location (misal Jakarta)
    LatLng center = const LatLng(-6.200000, 106.816666);

    // Jika sudah ada koordinat, gunakan itu sebagai titik tengah
    if (_latController.text.isNotEmpty && _lngController.text.isNotEmpty) {
      double? lat = double.tryParse(_latController.text);
      double? lng = double.tryParse(_lngController.text);
      if (lat != null && lng != null) {
        center = LatLng(lat, lng);
      }
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
                          onTap: (tapPosition, point) {
                            setStateDialog(() {
                              pickedLocation = point;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.tenmu',
                          ),
                          if (pickedLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: pickedLocation!,
                                  width: 50,
                                  height: 50,
                                  child: const Icon(
                                    Icons.location_on,
                                    color: Colors.red,
                                    size: 50,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
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

                              Position position =
                                  await Geolocator.getCurrentPosition(
                                    locationSettings: const LocationSettings(
                                      accuracy: LocationAccuracy.high,
                                    ),
                                  );
                              if (!context.mounted) return;
                              mapController.move(
                                LatLng(position.latitude, position.longitude),
                                16.0,
                              );
                              setStateDialog(() {
                                pickedLocation = LatLng(
                                  position.latitude,
                                  position.longitude,
                                );
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
                      Positioned(
                        top: 16,
                        left: 16,
                        right: 60, // Hindari tombol close
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
        setState(() {
          _latController.text = result.latitude.toString();
          _lngController.text = result.longitude.toString();
        });
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
      await Supabase.instance.client.from('umkm').insert({
        'nama_tempat': _namaController.text.trim(),
        'alamat': _alamatController.text.trim().isNotEmpty
            ? _alamatController.text.trim()
            : 'Lokasi: ${_latController.text}, ${_lngController.text}',
        'deskripsi': _deskripsiController.text.trim(),
        'gambar_url': _gambarUrlController.text.isNotEmpty
            ? _gambarUrlController.text
            : null,
        'latitude': double.tryParse(_latController.text),
        'longitude': double.tryParse(_lngController.text),
        'is_featured': false,
      });

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
      body: Padding(
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
              _darkField(
                controller: _deskripsiController,
                label: 'Deskripsi Singkat',
                hint: 'Ceritakan keunikan tempat ini...',
                icon: Icons.description_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              const Text(
                'Gambar Tempat',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              if (_selectedImage != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    _selectedImage!,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                )
              else if (_gambarUrlController.text.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    _gambarUrlController.text,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
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
                        : 'Upload Gambar dari Galeri HP',
                    style: TextStyle(color: theme.textSecondary, fontSize: 14),
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
                'Lokasi Maps',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              _darkField(
                controller: _searchController,
                label: 'Cari Nama Tempat / Jalan (Gratis)',
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

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _getCurrentLocation,
                  icon: Icon(Icons.my_location, color: theme.btnLabel),
                  label: Text(
                    'Dapatkan Lokasi Saat Ini (GPS)',
                    style: TextStyle(color: theme.btnLabel),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.btnPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _bukaPetaPilihLokasi,
                  icon: Icon(Icons.map_outlined, color: theme.iconColor),
                  label: Text(
                    'Pilih Manual dari Peta',
                    style: TextStyle(color: theme.textSecondary),
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
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: _darkField(
                      controller: _latController,
                      label: 'Latitude',
                      hint: '-6.917464',
                      icon: Icons.my_location,
                      keyboardType: const TextInputType.numberWithOptions(
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
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
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
    );
  }
}

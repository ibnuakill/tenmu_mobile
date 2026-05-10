import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_compass/flutter_compass.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';
import '../../core/location_permission_helper.dart';

class RouteMapScreen extends StatefulWidget {
  // Opsional: Jika dikasih list UMKM, ini mode "Browse Map"
  final List<Map<String, dynamic>>? umkmList;

  // Opsional: Jika dikasih 1 destinasi, ini mode "Navigasi"
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationName;

  const RouteMapScreen({
    super.key,
    this.umkmList,
    this.destinationLat,
    this.destinationLng,
    this.destinationName,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  final MapController _mapController = MapController();
  Position? _currentPosition;
  List<LatLng> _routePoints = [];
  double? _distanceInKm;
  int? _estimatedTimeInMins;
  bool _isLoading = true;
  String? _errorMessage;

  // Arah kompas (0.0 berarti menghadap Utara)
  double _currentHeading = 0.0;

  // Active UMKM untuk navigasi
  Map<String, dynamic>? _selectedUmkm;
  double? _activeDestLat;
  double? _activeDestLng;
  String? _activeDestName;
  bool _isShowingRoute = false; // ← State untuk membedakan antara "Preview Overlay" dan "Sedang Rute"

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription; // Radar Kompas

  @override
  void initState() {
    super.initState();
    // Setup mode awal
    if (widget.destinationLat != null && widget.destinationLng != null) {
      _activeDestLat = widget.destinationLat;
      _activeDestLng = widget.destinationLng;
      _activeDestName = widget.destinationName;
      _isShowingRoute = true;
    }
    _initLocationAndRoute();
  }

  @override
  void dispose() {
    // Matikan kedua radar (GPS & Kompas) saat keluar halaman agar hemat baterai
    _positionStreamSubscription?.cancel();
    _compassSubscription?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  // True jika OSRM gagal, tampilkan garis lurus sebagai fallback
  bool _useFallback = false;

  Future<void> _initLocationAndRoute() async {
    try {
      final accessStatus = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'melihat rute lokasi',
      );

      if (accessStatus != LocationAccessStatus.granted) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = switch (accessStatus) {
            LocationAccessStatus.serviceDisabled =>
              'GPS belum aktif.\nAktifkan lokasi lalu coba lagi.',
            LocationAccessStatus.permissionDenied =>
              'Izin lokasi belum diberikan.\nIzinkan akses lokasi lalu coba lagi.',
            LocationAccessStatus.permissionDeniedForever =>
              'Izin lokasi ditolak permanen.\nBuka pengaturan aplikasi lalu aktifkan izin lokasi.',
            LocationAccessStatus.granted => null,
          };
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );

      // Jika ada active destination, ambil rute
      if (_activeDestLat != null && _activeDestLng != null) {
        // Coba ambil rute dari OSRM dengan timeout 10 detik
        final osrmPoints = await _fetchOsrmRoute(position);

        if (osrmPoints != null) {
          // OSRM berhasil → tampilkan rute sesungguhnya
          final distanceMeters = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            _activeDestLat!,
            _activeDestLng!,
          );

          setState(() {
            _currentPosition = position;
            _routePoints = osrmPoints;
            _distanceInKm = distanceMeters / 1000;
            _estimatedTimeInMins = ((_distanceInKm! / 30) * 60).round();
            _useFallback = false;
            _isLoading = false;
          });
        } else {
          // OSRM gagal/timeout → fallback ke garis lurus
          _applyFallbackRoute(position);
        }
      } else {
        // Mode Browse Map (tanpa destinasi awal)
        setState(() {
          _currentPosition = position;
          _isLoading = false;
        });
      }

      // Nyalakan Live Tracking & Kompas
      _startLiveTracking();
      _startCompass();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gagal mengambil lokasi GPS.\nPastikan izin lokasi sudah diaktifkan.';
      });
    }
  }

  /// Ambil rute dari OSRM, return null jika gagal atau timeout
  Future<List<LatLng>?> _fetchOsrmRoute(Position position) async {
    if (_activeDestLat == null || _activeDestLng == null) return null;
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${position.longitude},${position.latitude};'
        '${_activeDestLng},${_activeDestLat}'
        '?geometries=geojson',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;
        if (routes.isNotEmpty) {
          final geometry = routes[0]['geometry']['coordinates'] as List;
          return geometry
              .map((coord) => LatLng(coord[1] as double, coord[0] as double))
              .toList();
        }
      }
      return null;
    } catch (_) {
      return null; // timeout atau network error → fallback
    }
  }

  /// Fallback: tampilkan garis lurus + estimasi jarak burung
  void _applyFallbackRoute(Position position) {
    if (_activeDestLat == null || _activeDestLng == null) return;

    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _activeDestLat!,
      _activeDestLng!,
    );

    setState(() {
      _currentPosition = position;
      _routePoints = [
        LatLng(position.latitude, position.longitude),
        LatLng(_activeDestLat!, _activeDestLng!),
      ];
      _distanceInKm = distanceMeters / 1000;
      // Estimasi ~30 km/h berkendara
      _estimatedTimeInMins = ((_distanceInKm! / 30) * 60).round();
      _useFallback = true;
      _isLoading = false;
    });
  }

  void _startLiveTracking() {
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position? newPosition) {
            if (newPosition != null && mounted) {
              setState(() {
                _currentPosition = newPosition;
                if (_activeDestLat != null && _activeDestLng != null) {
                  double remainingDistanceMeters = Geolocator.distanceBetween(
                    newPosition.latitude,
                    newPosition.longitude,
                    _activeDestLat!,
                    _activeDestLng!,
                  );

                  _distanceInKm = remainingDistanceMeters / 1000;
                  _estimatedTimeInMins = ((_distanceInKm! / 30) * 60).round();
                }
              });
            }
          },
        );
  }

  // Fungsi untuk membaca arah putaran HP (Kompas)
  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (mounted && event.heading != null) {
        setState(() {
          _currentHeading = event.heading!;
        });
      }
    });
  }

  void _recenterMap() {
    if (_currentPosition != null) {
      _mapController.move(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final isPreviewing = _selectedUmkm != null && !_isShowingRoute;
    final isNavigating = _isShowingRoute;

    final title = isNavigating
        ? 'Rute ke $_activeDestName'
        : 'Peta Lokasi UMKM';

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        title: Text(
          title,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        backgroundColor: theme.bgBase,
        iconTheme: IconThemeData(color: theme.textPrimary),
        elevation: 0,
        actions: [
          if (isNavigating && widget.umkmList != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Tutup Rute',
              onPressed: () {
                setState(() {
                  _isShowingRoute = false;
                  _routePoints = [];
                });
                _recenterMap();
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.iconColor))
          : _errorMessage != null || _currentPosition == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_off_outlined,
                      size: 64,
                      color: theme.textHint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Lokasi tidak tersedia.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _initLocationAndRoute();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.bgElevated,
                        foregroundColor: theme.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: theme.border),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.tenmu',
                    ),
                    if (isNavigating)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _routePoints,
                            color: _useFallback
                                ? Colors.grey.withAlpha(200)
                                : theme.borderFocus,
                            strokeWidth: _useFallback ? 3.0 : 5.0,
                            pattern: _useFallback
                                ? StrokePattern.dashed(segments: [12, 8])
                                : const StrokePattern.solid(),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        // MARKER UMKM BROWSE
                        if (widget.umkmList != null && !isNavigating)
                          ...widget.umkmList!
                              .where(
                                (u) =>
                                    u['latitude'] != null &&
                                    u['longitude'] != null,
                              )
                              .map((umkm) {
                                return Marker(
                                  point: LatLng(
                                    umkm['latitude'] as double,
                                    umkm['longitude'] as double,
                                  ),
                                  width: 50,
                                  height: 50,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _activeDestLat = umkm['latitude'] as double;
                                        _activeDestLng = umkm['longitude'] as double;
                                        _activeDestName = umkm['nama_tempat'];
                                        _selectedUmkm = umkm;
                                        _isShowingRoute = false; // Overlay preview aktif
                                      });
                                      _mapController.move(
                                        LatLng(_activeDestLat!, _activeDestLng!),
                                        16.0,
                                      );
                                    },
                                    child: Icon(
                                      Icons.location_on,
                                      color: _selectedUmkm?['id'] == umkm['id'] ? theme.btnPrimary : Colors.red,
                                      size: _selectedUmkm?['id'] == umkm['id'] ? 50 : 40,
                                    ),
                                  ),
                                );
                              }),

                        // MARKER USER
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 60,
                          height: 60,
                          child: Transform.rotate(
                            angle: _currentHeading * (pi / 180),
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.blue,
                              size: 40,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 5),
                              ],
                            ),
                          ),
                        ),

                        // MARKER TUJUAN
                        if (isNavigating)
                          Marker(
                            point: LatLng(_activeDestLat!, _activeDestLng!),
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: Colors.red,
                              size: 45,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                // Banner Fallback
                if (_useFallback)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: theme.bgElevated.withAlpha(240),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.withAlpha(120)),
                      ),
                      child: Text(
                        'Server rute tidak tersedia. Menampilkan jarak lurus.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ),
                  ),

                // Button Recenter
                Positioned(
                  right: 16,
                  bottom: (isNavigating ? 140 : 80) + bottomPadding,
                  child: FloatingActionButton(
                    onPressed: _recenterMap,
                    backgroundColor: theme.bgSurface,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: theme.border),
                    ),
                    child: Icon(Icons.my_location, color: theme.iconColor),
                  ),
                ),

                // Info Panel
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 30 + bottomPadding,
                  child: isNavigating
                      ? _buildNavigationInfo(theme)
                      : isPreviewing
                          ? _buildUmkmPreview(theme)
                          : _buildBrowseInfo(theme),
                ),
              ],
            ),
    );
  }

  // --- WIDGET INFO PANELS ---

  Widget _buildUmkmPreview(ThemeProvider theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          )
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row atas: Info UMKM
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Gambar
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _selectedUmkm!['gambar_url'] != null
                      ? Image.network(
                          _selectedUmkm!['gambar_url'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (ctx, err, stack) => Container(
                            width: 60,
                            height: 60,
                            color: theme.bgElevated,
                            child: Icon(Icons.storefront, color: theme.textHint),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: theme.bgElevated,
                          child: Icon(Icons.storefront, color: theme.textHint),
                        ),
                ),
                const SizedBox(width: 16),
                // Text Detail
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedUmkm!['nama_tempat'] ?? 'Tanpa Nama',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: theme.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selectedUmkm!['alamat'] ?? '-',
                        style: TextStyle(fontSize: 12, color: theme.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                // Tombol Close Preview
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedUmkm = null;
                      _activeDestLat = null;
                      _activeDestLng = null;
                      _activeDestName = null;
                    });
                  },
                ),
              ],
            ),
          ),
          // Divider
          Container(height: 1, color: theme.border),
          // Tombol Mulai Rute
          InkWell(
            onTap: () {
              setState(() {
                _isShowingRoute = true;
                _isLoading = true;
              });
              _initLocationAndRoute();
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: theme.btnPrimary,
              alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions, color: theme.btnLabel, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Mulai Rute',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.btnLabel,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget agar kode lebih rapi dan menghindari error braket
  Widget _buildNavigationInfo(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(70), blurRadius: 20),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _infoColumn(
            'Jarak',
            _distanceInKm != null
                ? '${_distanceInKm!.toStringAsFixed(1)} km'
                : '-',
            theme,
          ),
          Container(width: 1, height: 40, color: theme.border),
          _infoColumn(
            'Waktu',
            _estimatedTimeInMins != null ? '$_estimatedTimeInMins mnt' : '-',
            theme,
          ),
        ],
      ),
    );
  }

  Widget _buildBrowseInfo(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: theme.iconColor),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Tap pada marker merah untuk melihat rute.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoColumn(String label, String value, ThemeProvider theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: theme.textPrimary,
          ),
        ),
      ],
    );
  }
}

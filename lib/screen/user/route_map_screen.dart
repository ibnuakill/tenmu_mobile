import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_compass/flutter_compass.dart';
import '../../core/app_colors.dart';
import '../../core/location_permission_helper.dart';

class RouteMapScreen extends StatefulWidget {
  final double destinationLat;
  final double destinationLng;
  final String destinationName;

  const RouteMapScreen({
    super.key,
    required this.destinationLat,
    required this.destinationLng,
    required this.destinationName,
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

  StreamSubscription<Position>? _positionStreamSubscription;
  StreamSubscription<CompassEvent>? _compassSubscription; // Radar Kompas

  @override
  void initState() {
    super.initState();
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

      // Coba ambil rute dari OSRM dengan timeout 10 detik
      final osrmPoints = await _fetchOsrmRoute(position);

      if (osrmPoints != null) {
        // OSRM berhasil → tampilkan rute sesungguhnya
        final distanceMeters = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          widget.destinationLat,
          widget.destinationLng,
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
    try {
      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/'
        '${position.longitude},${position.latitude};'
        '${widget.destinationLng},${widget.destinationLat}'
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
    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.destinationLat,
      widget.destinationLng,
    );

    setState(() {
      _currentPosition = position;
      _routePoints = [
        LatLng(position.latitude, position.longitude),
        LatLng(widget.destinationLat, widget.destinationLng),
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
                double remainingDistanceMeters = Geolocator.distanceBetween(
                  newPosition.latitude,
                  newPosition.longitude,
                  widget.destinationLat,
                  widget.destinationLng,
                );

                _distanceInKm = remainingDistanceMeters / 1000;
                _estimatedTimeInMins = ((_distanceInKm! / 30) * 60).round();
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
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AppBar(
        title: Text(
          'Rute ke ${widget.destinationName}',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        backgroundColor: AppColors.bgBase,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.iconColor),
            )
          : _errorMessage != null || _currentPosition == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.location_off_outlined,
                      size: 64,
                      color: AppColors.textHint,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage ?? 'Lokasi tidak tersedia.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
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
                        backgroundColor: AppColors.bgElevated,
                        foregroundColor: AppColors.textPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: const BorderSide(color: AppColors.border),
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
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _routePoints,
                          // Jika fallback, tampilkan garis abu-abu putus-putus
                          color: _useFallback
                              ? Colors.grey.withValues(alpha: 0.8)
                              : AppColors.borderFocus,
                          strokeWidth: _useFallback ? 3.0 : 5.0,
                          pattern: _useFallback
                              ? StrokePattern.dashed(segments: [12, 8])
                              : StrokePattern.solid(),
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        // MARKER USER: Menggunakan Panah Navigasi & Bisa Berputar!
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 60,
                          height: 60,
                          child: Transform.rotate(
                            // Mengubah derajat (heading) menjadi radian
                            angle: _currentHeading * (pi / 180),
                            child: const Icon(
                              Icons
                                  .navigation, // Ikon panah navigasi ala Google Maps
                              color: Colors.blue,
                              size: 40,
                              shadows: [
                                Shadow(color: Colors.black45, blurRadius: 5),
                              ], // Tambah bayangan biar realistis
                            ),
                          ),
                        ),
                        // MARKER TUJUAN
                        Marker(
                          point: LatLng(
                            widget.destinationLat,
                            widget.destinationLng,
                          ),
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

                // Banner peringatan jika pakai mode fallback (OSRM gagal)
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
                        color: AppColors.bgElevated.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: Colors.orange,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Server rute tidak tersedia. Menampilkan jarak lurus ke tujuan.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                Positioned(
                  right: 16,
                  bottom: 140 + bottomPadding,
                  child: FloatingActionButton(
                    onPressed: _recenterMap,
                    backgroundColor: AppColors.bgSurface,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    child: const Icon(
                      Icons.my_location,
                      color: AppColors.iconColor,
                    ),
                  ),
                ),

                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 30 + bottomPadding,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 16,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.bgSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AppColors.border),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Jarak',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _distanceInKm != null
                                  ? '${_distanceInKm!.toStringAsFixed(1)} km'
                                  : '-',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: AppColors.border,
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Waktu Tempuh',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _estimatedTimeInMins != null
                                  ? '$_estimatedTimeInMins mnt'
                                  : '-',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

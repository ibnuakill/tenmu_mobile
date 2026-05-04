import 'dart:async';
import 'dart:convert';
import 'dart:math'; // Wajib untuk menghitung rotasi (pi)
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_compass/flutter_compass.dart'; // Package kompas baru

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

  Future<void> _initLocationAndRoute() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final startLng = position.longitude;
      final startLat = position.latitude;
      final endLng = widget.destinationLng;
      final endLat = widget.destinationLat;

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$startLng,$startLat;$endLng,$endLat?geometries=geojson',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final routes = data['routes'] as List;

        if (routes.isNotEmpty) {
          final route = routes[0];

          final distanceMeters = route['distance'];
          final durationSeconds = route['duration'];

          final geometry = route['geometry']['coordinates'] as List;
          List<LatLng> points = geometry.map((coord) {
            return LatLng(coord[1], coord[0]);
          }).toList();

          setState(() {
            _currentPosition = position;
            _routePoints = points;
            _distanceInKm = distanceMeters / 1000;
            _estimatedTimeInMins = (durationSeconds / 60).round();
            _isLoading = false;
          });

          // Nyalakan Live Tracking & Kompas
          _startLiveTracking();
          _startCompass();
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal mengambil rute.')));
      }
    }
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
      appBar: AppBar(
        title: Text('Rute ke ${widget.destinationName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
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
                          color: Colors.redAccent,
                          strokeWidth: 5.0, // Ditebalkan sedikit biar jelas
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

                Positioned(
                  right: 16,
                  bottom: 140 + bottomPadding,
                  child: FloatingActionButton(
                    onPressed: _recenterMap,
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: Colors.blue),
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
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
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
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _distanceInKm != null
                                  ? '${_distanceInKm!.toStringAsFixed(1)} km'
                                  : '-',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey[300],
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Waktu Tempuh',
                              style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _estimatedTimeInMins != null
                                  ? '$_estimatedTimeInMins mnt'
                                  : '-',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
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

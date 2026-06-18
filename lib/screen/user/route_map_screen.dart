import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';
import '../../core/location_permission_helper.dart';
import '../../core/poi_category.dart';
import '../../core/poi_image_helper.dart';

// ---------------------------------------------------------------------------
// TravelMode
// ---------------------------------------------------------------------------
enum TravelMode {
  walking,
  motorcycle,
  car;

  String get osrmProfile => switch (this) {
        TravelMode.walking => 'foot',
        TravelMode.motorcycle => 'driving',
        TravelMode.car => 'driving',
      };

  double get speedKmh => switch (this) {
        TravelMode.walking => 5,
        TravelMode.motorcycle => 40,
        TravelMode.car => 30,
      };

  String get label => switch (this) {
        TravelMode.walking => 'Jalan Kaki',
        TravelMode.motorcycle => 'Motor',
        TravelMode.car => 'Mobil',
      };

  String get iconLabel => switch (this) {
        TravelMode.walking => '🚶',
        TravelMode.motorcycle => '🏍️',
        TravelMode.car => '🚗',
      };
}

/// Satu instruksi langkah dari OSRM.
class _RouteStep {
  final String instruction;
  final double distanceM;
  final double lat;
  final double lng;
  bool spoken;

  _RouteStep({
    required this.instruction,
    required this.distanceM,
    required this.lat,
    required this.lng,
    this.spoken = false,
  });
}

class RouteMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? placesList;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationName;

  const RouteMapScreen({
    super.key,
    this.placesList,
    this.destinationLat,
    this.destinationLng,
    this.destinationName,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  // --- Map ---
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;

  // --- Annotations ---
  final List<Circle> _placeCircles = [];
  Circle? _destCircle;
  Line? _routeLine;
  double? _destinationLat;
  double? _destinationLng;
  String? _destinationName;

  // --- GPS & route ---
  Position? _currentPosition;
  List<LatLng> _routePoints = [];
  double? _distanceInKm;
  int? _estimatedTimeInMins;
  double _currentSpeedMs = 0.0;
  double _osrmTotalDistance = 0;
  double _originalStraightDistance = 0;
  bool _isLoading = true;
  String? _errorMessage;
  bool _useFallback = false;

  // --- Route steps (voice guidance) ---
  List<_RouteStep> _steps = [];
  int _lastSpokenStepIndex = -1;
  final FlutterTts _tts = FlutterTts();
  bool _isMuted = false;

  // --- Navigation / selection ---
  Map<String, dynamic>? _selectedPlace;
  bool _isShowingRoute = false;
  TravelMode _travelMode = TravelMode.motorcycle;

  // --- Arrival ---
  bool _hasArrived = false;
  double _totalTripDistanceKm = 0;
  int _totalTripMinutes = 0;

  Color get _routeColor => switch (_travelMode) {
        TravelMode.walking => Colors.green,
        TravelMode.motorcycle => Colors.blue,
        TravelMode.car => Colors.orange,
      };

  double get _currentSpeedKmh => _currentSpeedMs * 3.6;

  StreamSubscription<Position>? _positionStreamSubscription;

  // Auto-reroute
  DateTime _lastReroute = DateTime(2000);
  bool _isRerouting = false;
  static const double _rerouteThresholdM = 60.0;
  static const Duration _rerouteCooldown = Duration(seconds: 15);

  static const Map<String, String> _categoryColors = {
    'Cafe': '#8B4513',
    'Warung': '#E67E22',
    'Restoran': '#E74C3C',
    'Bakery': '#D4A017',
    'Fashion': '#E91E63',
    'Elektronik': '#2E86C1',
    'Farmasi': '#27AE60',
    'Kecantikan': '#8E44AD',
    'Toko': '#F39C12',
    'Lainnya': '#95A5A6',
  };

  // =======================================================================
  // Lifecycle
  // =======================================================================
  @override
  void initState() {
    super.initState();
    _initTts();
    if (widget.destinationLat != null && widget.destinationLng != null) {
      _destinationLat = widget.destinationLat;
      _destinationLng = widget.destinationLng;
      _destinationName = widget.destinationName;
      _isShowingRoute = true;
    }
    _initLocationAndRoute();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _tts.stop();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('id-ID');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  Future<void> _speak(String text) async {
    if (!_isMuted) {
      await _tts.stop();
      await _tts.speak(text);
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
      if (_isMuted) _tts.stop();
    });
  }

  // =======================================================================
  // MapLibre callbacks
  // =======================================================================
  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    controller.onCircleTapped.add(_onCircleTapped);
  }

  void _onStyleLoaded() {
    _styleLoaded = true;
    _syncAnnotations();
  }

  void _onCircleTapped(Circle circle) {
    if (_isShowingRoute || circle.data == null) return;
    final place = circle.data!;
    setState(() {
      _selectedPlace = place;
      _destinationLat = place['latitude'] as double?;
      _destinationLng = place['longitude'] as double?;
      _destinationName = place['nama_tempat'];
      _isShowingRoute = false;
    });
    _syncAnnotations();
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_destinationLat!, _destinationLng!),
        16.0,
      ),
    );
  }

  // =======================================================================
  // Annotations — use Circle (works w/ any style, no sprite dependency)
  // =======================================================================
  Future<void> _syncAnnotations() async {
    if (!_styleLoaded || _mapController == null) return;
    await _clearAnnotations();

    if (widget.placesList != null && !_isShowingRoute) {
      for (final place in widget.placesList!) {
        if (place['latitude'] == null || place['longitude'] == null) continue;
        final lat = place['latitude'] as double;
        final lng = place['longitude'] as double;
        final cat = _resolveCategory(place);
        final isSelected = _selectedPlace?['id'] == place['id'];

        try {
          // Simpan data UMKM via optional Map arg agar bisa dipakai di onTap
          final c = await _mapController!.addCircle(
            CircleOptions(
              geometry: LatLng(lat, lng),
              circleColor: isSelected ? '#3366FF' : (_categoryColors[cat] ?? '#FF4444'),
              circleRadius: isSelected ? 14 : 10,
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 3,
              circleStrokeOpacity: 0.9,
              circleOpacity: 0.9,
            ),
            place, // stored as circle.data
          );
          _placeCircles.add(c);
        } catch (_) {}
      }
    }

    // Destination marker
    if (_destinationLat != null && _destinationLng != null && _isShowingRoute) {
      try {
        _destCircle = await _mapController!.addCircle(
          CircleOptions(
            geometry: LatLng(_destinationLat!, _destinationLng!),
            circleColor: '#FF0000',
            circleRadius: 14,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 4,
            circleStrokeOpacity: 1.0,
            circleOpacity: 1.0,
          ),
        );
      } catch (_) {}
    }

    // Route line
    if (_routePoints.isNotEmpty && _isShowingRoute) {
      try {
        _routeLine = await _mapController!.addLine(
          LineOptions(
            geometry: _routePoints,
            lineColor: _useFallback ? '#888888' : _routeColorHex(),
            lineWidth: _useFallback ? 3.0 : 5.0,
            lineOpacity: _useFallback ? 0.6 : 0.9,
          ),
        );
      } catch (_) {}
    }
  }

  String _routeColorHex() {
    return '#${(_routeColor.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
  }

  Future<void> _clearAnnotations() async {
    try {
      for (final c in _placeCircles) {
        await _mapController?.removeCircle(c);
      }
      _placeCircles.clear();
      if (_destCircle != null) {
        await _mapController?.removeCircle(_destCircle!);
        _destCircle = null;
      }
      if (_routeLine != null) {
        await _mapController?.removeLine(_routeLine!);
        _routeLine = null;
      }
    } catch (_) {}
  }

  // =======================================================================
  // GPS / OSRM
  // =======================================================================
  String _resolveCategory(Map<String, dynamic> place) {
    final category = place['category']?.toString().trim();
    if (category == null || category.isEmpty) return PoiCategory.lainnya;
    return PoiCategory.isValidCategory(category)
        ? category
        : PoiCategory.lainnya;
  }

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

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      _currentPosition = position;

      if (_destinationLat != null && _destinationLng != null) {
        final result = await _fetchFullRoute(position);
        if (result != null && mounted) {
          final (points, distanceMeters, durationSeconds, steps) = result;
          final straightDist = Geolocator.distanceBetween(
            position.latitude, position.longitude,
            _destinationLat!, _destinationLng!,
          );
          setState(() {
            _routePoints = points;
            _osrmTotalDistance = distanceMeters;
            _originalStraightDistance = straightDist;
            _distanceInKm = distanceMeters / 1000;
            _estimatedTimeInMins = (durationSeconds / 60).round();
            _steps = steps;
            _useFallback = false;
            _isLoading = false;
            _hasArrived = false;
          });
          _speakFirstStep();
        } else if (mounted) {
          _applyFallbackRoute(position);
        }
      } else {
        setState(() => _isLoading = false);
      }

      _startLiveTracking();
      if (_styleLoaded) _syncAnnotations();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gagal mengambil lokasi GPS.\nPastikan izin lokasi sudah diaktifkan.';
      });
    }
  }

  /// Fetch full OSRM route including steps for voice guidance.
  Future<(List<LatLng> points, double distanceM, double durationS, List<_RouteStep> steps)?>
      _fetchFullRoute(Position position, {int retry = 1}) async {
    if (_destinationLat == null || _destinationLng == null) return null;
    for (int attempt = 0; attempt <= retry; attempt++) {
      try {
        final profile = _travelMode.osrmProfile;
        final url = Uri.parse(
          'https://router.project-osrm.org/route/v1/$profile/'
          '${position.longitude},${position.latitude};'
          '$_destinationLng,$_destinationLat'
          '?geometries=geojson&overview=full&steps=true&language=en',
        );
        final response = await http.get(url).timeout(const Duration(seconds: 10));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final routes = data['routes'] as List;
          if (routes.isEmpty) continue;
          final route = routes[0] as Map<String, dynamic>;
          final geometry = route['geometry']['coordinates'] as List;
          final points = geometry
              .map((c) => LatLng(c[1] as double, c[0] as double))
              .toList();
          final distance = (route['distance'] as num).toDouble();
          final duration = (route['duration'] as num).toDouble();

          final steps = <_RouteStep>[];
          final legs = route['legs'] as List;
          if (legs.isNotEmpty) {
            final leg = legs[0] as Map<String, dynamic>;
            final rawSteps = leg['steps'] as List;
            for (final s in rawSteps) {
              final maneuver = s['maneuver'] as Map<String, dynamic>;
              final loc = maneuver['location'] as List;
              steps.add(_RouteStep(
                instruction: s['instruction'] ?? '',
                distanceM: (s['distance'] as num).toDouble(),
                lat: loc[1] as double,
                lng: loc[0] as double,
              ));
            }
          }
          return (points, distance, duration, steps);
        }
      } catch (_) {
        // attempt berikutnya
      }
    }
    return null;
  }

  void _speakFirstStep() {
    if (_steps.isNotEmpty) {
      _speak(_steps[0].instruction);
      _steps[0].spoken = true;
      _lastSpokenStepIndex = 0;
    }
  }

  void _applyFallbackRoute(Position position) {
    if (_destinationLat == null || _destinationLng == null) return;
    final m = Geolocator.distanceBetween(
      position.latitude, position.longitude,
      _destinationLat!, _destinationLng!,
    );
    setState(() {
      _currentPosition = position;
      _routePoints = [
        LatLng(position.latitude, position.longitude),
        LatLng(_destinationLat!, _destinationLng!),
      ];
      _osrmTotalDistance = m;
      _originalStraightDistance = m;
      _distanceInKm = m / 1000;
      _estimatedTimeInMins = ((m / 1000) / _travelMode.speedKmh * 60).round();
      _steps = [];
      _useFallback = true;
      _isLoading = false;
    });
    if (_styleLoaded) _syncAnnotations();
  }

  // =======================================================================
  // Live tracking + voice guidance + arrival detection + auto-reroute
  // =======================================================================
  void _startLiveTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (Position? p) {
        if (p == null || !mounted) return;
        setState(() {
          _currentPosition = p;
          _currentSpeedMs = p.speed;
        });

        if (_destinationLat == null || _destinationLng == null || _isRerouting) return;

        final remaining = Geolocator.distanceBetween(
          p.latitude, p.longitude,
          _destinationLat!, _destinationLng!,
        );

        // --- Arrival check ---
        if (!_hasArrived && remaining < 50) {
          _onArrival();
          return;
        }

        // --- Estimate ---
        final ratio = _osrmTotalDistance > 0 && _originalStraightDistance > 0
            ? _osrmTotalDistance / _originalStraightDistance
            : 1.0;
        final road = remaining * ratio;
        setState(() {
          _distanceInKm = road / 1000;
          _estimatedTimeInMins =
              ((road / _travelMode.speedKmh) / 1000 * 60).round();
        });

        // --- Voice guidance (nearest turn ahead) ---
        _checkVoiceGuidance(p);

        // --- Auto-reroute ---
        if (!_useFallback && _routePoints.length > 1) {
          final deviation = _distanceToRoute(
            LatLng(p.latitude, p.longitude),
            _routePoints,
          );
          final now = DateTime.now();
          if (deviation > _rerouteThresholdM &&
              now.difference(_lastReroute) > _rerouteCooldown) {
            _lastReroute = now;
            _doReroute(p);
          }
        }
      },
    );
  }

  void _checkVoiceGuidance(Position p) {
    if (_steps.isEmpty) return;
    // Cari langkah terdekat di depan yang belum diucapkan
    for (int i = 0; i < _steps.length; i++) {
      if (_steps[i].spoken) continue;
      final dist = Geolocator.distanceBetween(
        p.latitude, p.longitude,
        _steps[i].lat, _steps[i].lng,
      );
      if (dist < _steps[i].distanceM.clamp(30, 200)) {
        _speak(_steps[i].instruction);
        _steps[i].spoken = true;
        _lastSpokenStepIndex = i;
        break;
      }
    }
  }

  void _onArrival() {
    setState(() {
      _hasArrived = true;
      _totalTripDistanceKm = _distanceInKm ?? 0;
      _totalTripMinutes = _estimatedTimeInMins ?? 0;
      _distanceInKm = 0;
      _estimatedTimeInMins = 0;
    });
    _tts.stop();
    _speak('Anda telah tiba di $_destinationName. Total jarak '
        '${_totalTripDistanceKm.toStringAsFixed(1)} kilometer, '
        'waktu tempuh $_totalTripMinutes menit.');
  }

  // =======================================================================
  // Auto-reroute helpers
  // =======================================================================
  double _distanceToRoute(LatLng point, List<LatLng> route) {
    double minDist = double.infinity;
    for (int i = 0; i < route.length - 1; i++) {
      final d = _pointToLineDistance(
        point.latitude, point.longitude,
        route[i].latitude, route[i].longitude,
        route[i + 1].latitude, route[i + 1].longitude,
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  double _pointToLineDistance(
      double px, double py,
      double l1x, double l1y,
      double l2x, double l2y) {
    final dx = l2x - l1x;
    final dy = l2y - l1y;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return Geolocator.distanceBetween(px, py, l1x, l1y);
    var t = ((px - l1x) * dx + (py - l1y) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return Geolocator.distanceBetween(
      px, py,
      l1x + t * dx, l1y + t * dy,
    );
  }

  Future<void> _doReroute(Position p) async {
    _isRerouting = true;
    if (!_useFallback) {
      final result = await _fetchFullRoute(p);
      if (result != null && mounted) {
        final (points, distanceMeters, durationSeconds, steps) = result;
        setState(() {
          _routePoints = points;
          _osrmTotalDistance = distanceMeters;
          _distanceInKm = distanceMeters / 1000;
          _estimatedTimeInMins = (durationSeconds / 60).round();
          _steps = steps;
          _hasArrived = false;
        });
        if (_styleLoaded) _syncAnnotations();
        _speakFirstStep();
        _isRerouting = false;
        return;
      }
    }
    _applyFallbackRoute(p);
    _isRerouting = false;
  }

  // =======================================================================
  // Camera
  // =======================================================================
  void _recenterMap() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        16.0,
      ),
    );
  }

  Future<void> _fetchAndSetRoute() async {
    if (_currentPosition == null || _destinationLat == null) return;
    try {
      final result = await _fetchFullRoute(_currentPosition!);
      if (result != null && mounted) {
        final (points, distanceMeters, durationSeconds, steps) = result;
        final straightDist = Geolocator.distanceBetween(
          _currentPosition!.latitude, _currentPosition!.longitude,
          _destinationLat!, _destinationLng!,
        );
        setState(() {
          _routePoints = points;
          _osrmTotalDistance = distanceMeters;
          _originalStraightDistance = straightDist;
          _distanceInKm = distanceMeters / 1000;
          _estimatedTimeInMins = (durationSeconds / 60).round();
          _steps = steps;
          _useFallback = false;
          _isLoading = false;
          _hasArrived = false;
        });
        if (_styleLoaded) _syncAnnotations();
        _speakFirstStep();
      } else if (mounted) {
        _applyFallbackRoute(_currentPosition!);
      }
    } catch (_) {
      if (mounted) _applyFallbackRoute(_currentPosition!);
    }
    if (_styleLoaded) _syncAnnotations();
  }

  // =======================================================================
  // Build
  // =======================================================================
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    final isPreviewing = _selectedPlace != null && !_isShowingRoute;
    final isNavigating = _isShowingRoute;
    final title = isNavigating ? 'Rute ke $_destinationName' : 'Peta Lokasi UMKM';

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
          // Mute toggle (hanya saat navigasi)
          if (isNavigating)
            IconButton(
              icon: Icon(
                _isMuted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                color: theme.textPrimary,
              ),
              tooltip: _isMuted ? 'Aktifkan suara' : 'Matikan suara',
              onPressed: _toggleMute,
            ),
          if (isNavigating && widget.placesList != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Tutup Rute',
              onPressed: () {
                setState(() {
                  _isShowingRoute = false;
                  _routePoints = [];
                  _steps = [];
                  _hasArrived = false;
                });
                _tts.stop();
                _syncAnnotations();
                _recenterMap();
              },
            ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.iconColor))
          : _errorMessage != null || _currentPosition == null
              ? _buildErrorView(theme)
              : Stack(
                  children: [
                    // --- Map ---
                    MapLibreMap(
                      styleString: theme.isDarkMode
                          ? 'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json'
                          : 'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json',
                      initialCameraPosition: CameraPosition(
                        target: LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        ),
                        zoom: 15.0,
                      ),
                      onMapCreated: _onMapCreated,
                      onStyleLoadedCallback: _onStyleLoaded,
                      myLocationEnabled: true,
                      myLocationTrackingMode: MyLocationTrackingMode.tracking,
                      myLocationRenderMode: MyLocationRenderMode.normal,
                      compassEnabled: true,
                      logoEnabled: false,
                      attributionButtonPosition:
                          AttributionButtonPosition.bottomRight,
                      minMaxZoomPreference:
                          const MinMaxZoomPreference(4.0, 22.0),
                      cameraTargetBounds: CameraTargetBounds(
                        LatLngBounds(
                          southwest: const LatLng(-11.0, 94.0),
                          northeast: const LatLng(6.0, 142.0),
                        ),
                      ),
                    ),

                    // --- Fallback banner ---
                    if (_useFallback)
                      Positioned(
                        top: 12, left: 16, right: 16,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.bgElevated.withAlpha(240),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.orange.withAlpha(120)),
                          ),
                          child: Text(
                            'Server rute tidak tersedia. Menampilkan jarak lurus.',
                            style: TextStyle(fontSize: 12, color: theme.textSecondary),
                          ),
                        ),
                      ),

                    // --- Recenter button ---
                    Positioned(
                      right: 16,
                      bottom: 100 + bottomPadding,
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

                    // --- Bottom sheet / panel ---
                    isNavigating
                        ? _buildNavSheet(theme)
                        : Positioned(
                            left: 16, right: 16,
                            bottom: 30 + bottomPadding,
                            child: isPreviewing
                                ? _buildUmkmPreview(theme)
                                : _buildBrowseInfo(theme),
                          ),
                  ],
                ),
    );
  }

  Widget _buildErrorView(ThemeProvider theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 64, color: theme.textHint),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Lokasi tidak tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 14, height: 1.6),
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
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: theme.border),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =======================================================================
  // DraggableScrollableSheet untuk navigasi
  // =======================================================================
  Widget _buildNavSheet(ThemeProvider theme) {
    final collapsedHeight = 120.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        return DraggableScrollableSheet(
          initialChildSize: collapsedHeight / constraints.maxHeight,
          minChildSize: collapsedHeight / constraints.maxHeight,
          maxChildSize: 0.55,
          snap: true,
          snapSizes: [collapsedHeight / constraints.maxHeight, 0.35, 0.55],
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.bgSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(top: BorderSide(color: theme.border)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(60),
                    blurRadius: 15,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: theme.textHint,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Arrival card
                  if (_hasArrived)
                    _buildArrivalCard(theme)

                  // Navigation info (collapsed)
                  else ...[
                    _buildNavInfoCard(theme),

                    Divider(color: theme.border, height: 1),

                    // Travel mode selector
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: TravelMode.values.map((mode) {
                          final isActive = _travelMode == mode;
                          return GestureDetector(
                            onTap: () {
                              if (_travelMode != mode) {
                                setState(() {
                                  _travelMode = mode;
                                  _isLoading = true;
                                });
                                _fetchAndSetRoute();
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: isActive ? theme.btnPrimary : theme.bgElevated,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isActive ? theme.btnPrimary : theme.border,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(mode.iconLabel, style: const TextStyle(fontSize: 16)),
                                  const SizedBox(width: 6),
                                  Text(
                                    mode.label,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                                      color: isActive ? theme.btnLabel : theme.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    Divider(color: theme.border, height: 1),

                    // Next instruction
                    if (_steps.isNotEmpty && _lastSpokenStepIndex >= 0) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                        child: Row(
                          children: [
                            Icon(Icons.turn_slight_right, color: theme.btnPrimary, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                _steps[_lastSpokenStepIndex.clamp(0, _steps.length - 1)].instruction,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Step list
                    ..._steps.asMap().entries.map((entry) {
                      final i = entry.key;
                      final step = entry.value;
                      final done = step.spoken;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                        child: Row(
                          children: [
                            Icon(
                              done ? Icons.check_circle : Icons.circle_outlined,
                              size: 16,
                              color: done ? Colors.green : theme.textHint,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              step.instruction,
                              style: TextStyle(
                                fontSize: 12,
                                color: done ? theme.textHint : theme.textPrimary,
                                decoration: done ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNavInfoCard(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _infoColumn(
            'Jarak',
            _distanceInKm != null ? '${_distanceInKm!.toStringAsFixed(1)} km' : '-',
            theme,
          ),
          Container(width: 1, height: 40, color: theme.border),
          _infoColumn(
            'Waktu',
            _estimatedTimeInMins != null ? _formatEstimate(_estimatedTimeInMins!) : '-',
            theme,
          ),
          Container(width: 1, height: 40, color: theme.border),
          _infoColumn('Kecepatan', '${_currentSpeedKmh.toStringAsFixed(0)} km/h', theme),
        ],
      ),
    );
  }

  // =======================================================================
  // Arrival summary
  // =======================================================================
  Widget _buildArrivalCard(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green.shade700, Colors.teal.shade600],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withAlpha(80),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Anda Telah Tiba!',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _destinationName ?? 'Tujuan',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _arrivalStat(Icons.straighten, '${_totalTripDistanceKm.toStringAsFixed(1)} km', 'Total Jarak', Colors.white),
                Container(height: 30, width: 1, color: Colors.white30),
                _arrivalStat(Icons.timer_outlined, _formatEstimate(_totalTripMinutes), 'Waktu Tempuh', Colors.white),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _isShowingRoute = false;
                    _routePoints = [];
                    _steps = [];
                    _hasArrived = false;
                  });
                  _tts.stop();
                  _syncAnnotations();
                  _recenterMap();
                },
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'Selesai',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _arrivalStat(IconData icon, String value, String label, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color.withAlpha(180), fontSize: 11),
        ),
      ],
    );
  }

  // =======================================================================
  // UMKM Preview
  // =======================================================================
  Widget _buildUmkmPreview(ThemeProvider theme) {
    final imageUrl = PoiImageHelper.primaryImageUrl(_selectedPlace!);
    return Container(
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl != null
                      ? Image.network(imageUrl, width: 60, height: 60, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderImage(theme))
                      : _placeholderImage(theme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_selectedPlace!['nama_tempat'] ?? 'Tanpa Nama',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textPrimary),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(_selectedPlace!['alamat'] ?? '-',
                          style: TextStyle(fontSize: 12, color: theme.textSecondary),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    setState(() {
                      _selectedPlace = null;
                      _destinationLat = null;
                      _destinationLng = null;
                      _destinationName = null;
                    });
                    _syncAnnotations();
                  },
                ),
              ],
            ),
          ),
          Container(height: 1, color: theme.border),
          InkWell(
            onTap: () {
              setState(() { _isShowingRoute = true; _isLoading = true; });
              _initLocationAndRoute();
            },
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
              color: theme.btnPrimary, alignment: Alignment.center,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions, color: theme.btnLabel, size: 20),
                  const SizedBox(width: 8),
                  Text('Mulai Rute', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: theme.btnLabel)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImage(ThemeProvider theme) {
    return Container(
      width: 60, height: 60,
      color: theme.bgElevated,
      child: Icon(Icons.storefront, color: theme.textHint),
    );
  }

  // =======================================================================
  // Browse info
  // =======================================================================
  Widget _buildBrowseInfo(ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.bgSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: theme.iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(child: Text('Tap pada marker untuk melihat detail UMKM.',
              style: TextStyle(color: theme.textPrimary, fontSize: 13, height: 1.4))),
        ],
      ),
    );
  }

  // =======================================================================
  // Helpers
  // =======================================================================
  Widget _infoColumn(String label, String value, ThemeProvider theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(color: theme.textSecondary, fontSize: 12)),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textPrimary)),
      ],
    );
  }

  String _formatEstimate(int mins) {
    if (mins < 1) return '<1 mnt';
    if (mins < 60) return '$mins mnt';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '${h}j ${m}mnt' : '$h jam';
  }
}

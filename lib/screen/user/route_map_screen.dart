import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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
    TravelMode.walking => 'walking',
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
  final MapController _mapController = MapController();

  // --- Annotations ---
  List<Marker> _currentMarkers = [];
  List<Polyline> _currentPolylines = [];
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

  static const Map<String, Color> _categoryColors = {
    'Cafe':             Color(0xFF8B4513),
    'Fashion':          Color(0xFFE91E63),
    'Wisata':           Color(0xFF2196F3),
    'Kuliner':          Color(0xFFE74C3C),
    'Hotel':            Color(0xFF1565C0),
    'Oleh-Oleh':        Color(0xFFFF6F61),
    'UMKM':             Color(0xFF4CAF50),
    'Lainnya':          Color(0xFF95A5A6),
  };

  // =======================================================================
  // Lifecycle
  // =======================================================================
  @override
  void initState() {
    super.initState();
    _setSystemUI();
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
    _mapController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
    );
    super.dispose();
  }

  void _setSystemUI() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        systemNavigationBarColor: Color(0xFF1E1E1E),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  // =======================================================================
  // Tap handler
  // =======================================================================
  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    if (_isShowingRoute) return;
    if (widget.placesList == null) return;
    final tapX = tapPos.global.dx;
    final tapY = tapPos.global.dy;
    Map<String, dynamic>? hitPlace;
    LatLng? hitLatLng;

    for (final place in widget.placesList!) {
      if (place['latitude'] == null || place['longitude'] == null) continue;
      final pLat = place['latitude'] as double;
      final pLng = place['longitude'] as double;
      final screenPoint = _mapController.camera.project(LatLng(pLat, pLng));
      final dx = tapX - screenPoint.x;
      final dy = tapY - screenPoint.y;
      if (dx * dx + dy * dy < 30 * 30) {
        hitLatLng = LatLng(pLat, pLng);
        hitPlace = place;
        break;
      }
    }

    if (hitPlace != null && hitLatLng != null) {
      final place = hitPlace;
      setState(() {
        _selectedPlace = place;
        _destinationLat = place['latitude'] as double?;
        _destinationLng = place['longitude'] as double?;
        _destinationName = place['nama_tempat'];
        _isShowingRoute = false;
      });
      _mapController.move(hitLatLng, 16.0);
    }
  }

  // =======================================================================
  // Build markers & polylines
  // =======================================================================
  void _updateMapState() {
    final markers = <Marker>[];

    // Current position marker
    if (_currentPosition != null) {
      markers.add(
        Marker(
          point: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          width: 24,
          height: 24,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
            ),
            child: const Icon(Icons.my_location, color: Colors.white, size: 14),
          ),
        ),
      );
    }

    // Place markers (browse mode)
    if (widget.placesList != null && !_isShowingRoute) {
      for (final place in widget.placesList!) {
        if (place['latitude'] == null || place['longitude'] == null) continue;
        final lat = place['latitude'] as double;
        final lng = place['longitude'] as double;
        final cat = _resolveCategory(place);
        final isSelected = _selectedPlace?['id'] == place['id'];
        final color = isSelected
            ? const Color(0xFF3366FF)
            : (_categoryColors[cat] ?? const Color(0xFFFF4444));

        markers.add(
          Marker(
            point: LatLng(lat, lng),
            width: isSelected ? 28 : 24,
            height: isSelected ? 28 : 24,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _selectedPlace = place;
                  _destinationLat = lat;
                  _destinationLng = lng;
                  _destinationName = place['nama_tempat'];
                  _isShowingRoute = false;
                });
                _mapController.move(LatLng(lat, lng), 16.0);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Icon(
                  PoiCategory.getCategoryIcon(cat),
                  color: Colors.white,
                  size: isSelected ? 16 : 14,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Destination marker
    if (_destinationLat != null && _destinationLng != null && _isShowingRoute) {
      markers.add(
        Marker(
          point: LatLng(_destinationLat!, _destinationLng!),
          width: 32,
          height: 32,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                ),
              ],
            ),
            child: const Icon(Icons.flag, color: Colors.white, size: 16),
          ),
        ),
      );
    }

    final polylines = <Polyline>[];
    if (_routePoints.isNotEmpty && _isShowingRoute) {
      polylines.add(
        Polyline(
          points: _routePoints,
          color: _useFallback ? const Color(0xFF888888) : _routeColor,
          strokeWidth: _useFallback ? 3.0 : 5.0,
          pattern: _useFallback
              ? StrokePattern.dotted()
              : const StrokePattern.solid(),
        ),
      );
    }

    setState(() {
      _currentMarkers = markers;
      _currentPolylines = polylines;
    });
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
        final result = await _fetchRoute(position);
        if (result != null && mounted) {
          final (points, distanceMeters, durationSeconds) = result;
          setState(() {
            _routePoints = points;
            _osrmTotalDistance = distanceMeters;
            _originalStraightDistance = Geolocator.distanceBetween(
              position.latitude,
              position.longitude,
              _destinationLat!,
              _destinationLng!,
            );
            _distanceInKm = distanceMeters / 1000;
            _estimatedTimeInMins = (durationSeconds / 60).round();
            _useFallback = false;
            _isLoading = false;
            _hasArrived = false;
          });
        } else if (mounted) {
          _applyFallbackRoute(position);
        }
      } else {
        setState(() => _isLoading = false);
      }

      _updateMapState();
      _startLiveTracking();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gagal mengambil lokasi GPS.\nPastikan izin lokasi sudah diaktifkan.';
      });
    }
  }

  /// Fetch OSRM route — returns points, distance, duration.
  Future<(List<LatLng> points, double distanceM, double durationS)?>
  _fetchRoute(Position position, {int retry = 1}) async {
    if (_destinationLat == null || _destinationLng == null) return null;

    String profileUrl(String baseUrl) {
      final profile = _travelMode.osrmProfile;
      if (baseUrl.contains('routing.openstreetmap.de')) {
        final sub = switch (_travelMode) {
          TravelMode.walking => 'foot',
          TravelMode.motorcycle => 'car',
          TravelMode.car => 'car',
        };
        final osmProfile = switch (_travelMode) {
          TravelMode.walking => 'foot',
          TravelMode.motorcycle => 'driving',
          TravelMode.car => 'driving',
        };
        return 'https://routing.openstreetmap.de/routed-$sub/route/v1/$osmProfile';
      }
      return '$baseUrl/$profile';
    }

    const servers = <String>['https://router.project-osrm.org/route/v1', ''];

    for (int i = 0; i < servers.length; i++) {
      final baseUrl = i == 1 ? 'https://routing.openstreetmap.de' : servers[i];

      for (int attempt = 0; attempt <= retry; attempt++) {
        try {
          final url = Uri.parse(
            '${profileUrl(baseUrl)}/'
            '${position.longitude},${position.latitude};'
            '$_destinationLng,$_destinationLat'
            '?geometries=geojson&overview=full',
          );
          final response = await http
              .get(url)
              .timeout(const Duration(seconds: 6));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final code = data['code'] as String?;
            if (code != 'Ok') continue;
            final routes = data['routes'] as List;
            if (routes.isEmpty) continue;
            final route = routes[0] as Map<String, dynamic>;
            final geometry = route['geometry']['coordinates'] as List;
            final points = geometry
                .map((c) => LatLng(c[1] as double, c[0] as double))
                .toList();
            final distance = (route['distance'] as num).toDouble();
            final duration = (route['duration'] as num).toDouble();
            return (points, distance, duration);
          }
        } catch (_) {}
      }
    }
    return null;
  }

  void _applyFallbackRoute(Position position) {
    if (_destinationLat == null || _destinationLng == null) return;
    final m = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _destinationLat!,
      _destinationLng!,
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
      _useFallback = true;
      _isLoading = false;
    });
    _updateMapState();
  }

  // =======================================================================
  // Live tracking + arrival detection + auto-reroute
  // =======================================================================
  void _startLiveTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((
          Position? p,
        ) {
          if (p == null || !mounted) return;
          setState(() {
            _currentPosition = p;
            _currentSpeedMs = p.speed;
          });
          _updateMapState();

          if (_destinationLat == null ||
              _destinationLng == null ||
              _isRerouting) {
            return;
          }

          final remaining = Geolocator.distanceBetween(
            p.latitude,
            p.longitude,
            _destinationLat!,
            _destinationLng!,
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
            _estimatedTimeInMins = ((road / _travelMode.speedKmh) / 1000 * 60)
                .round();
          });

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
        });
  }

  void _onArrival() {
    setState(() {
      _hasArrived = true;
      _totalTripDistanceKm = _distanceInKm ?? 0;
      _totalTripMinutes = _estimatedTimeInMins ?? 0;
      _distanceInKm = 0;
      _estimatedTimeInMins = 0;
    });
  }

  // =======================================================================
  // Auto-reroute helpers
  // =======================================================================
  double _distanceToRoute(LatLng point, List<LatLng> route) {
    double minDist = double.infinity;
    for (int i = 0; i < route.length - 1; i++) {
      final d = _pointToLineDistance(
        point.latitude,
        point.longitude,
        route[i].latitude,
        route[i].longitude,
        route[i + 1].latitude,
        route[i + 1].longitude,
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  double _pointToLineDistance(
    double px,
    double py,
    double l1x,
    double l1y,
    double l2x,
    double l2y,
  ) {
    final dx = l2x - l1x;
    final dy = l2y - l1y;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return Geolocator.distanceBetween(px, py, l1x, l1y);
    var t = ((px - l1x) * dx + (py - l1y) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    return Geolocator.distanceBetween(px, py, l1x + t * dx, l1y + t * dy);
  }

  Future<void> _doReroute(Position p) async {
    _isRerouting = true;
    if (!_useFallback) {
      final result = await _fetchRoute(p);
      if (result != null && mounted) {
        final (points, distanceMeters, durationSeconds) = result;
        setState(() {
          _routePoints = points;
          _osrmTotalDistance = distanceMeters;
          _distanceInKm = distanceMeters / 1000;
          _estimatedTimeInMins = (durationSeconds / 60).round();
          _hasArrived = false;
        });
        _updateMapState();
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
    if (_currentPosition == null) return;
    _mapController.move(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      16.0,
    );
  }

  Future<void> _fetchAndSetRoute() async {
    if (_currentPosition == null || _destinationLat == null) return;
    try {
      final result = await _fetchRoute(_currentPosition!);
      if (result != null && mounted) {
        final (points, distanceMeters, durationSeconds) = result;
        setState(() {
          _routePoints = points;
          _osrmTotalDistance = distanceMeters;
          _originalStraightDistance = Geolocator.distanceBetween(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
            _destinationLat!,
            _destinationLng!,
          );
          _distanceInKm = distanceMeters / 1000;
          _estimatedTimeInMins =
              ((distanceMeters / 1000) / _travelMode.speedKmh * 60).round();
          _useFallback = false;
          _isLoading = false;
          _hasArrived = false;
        });
        _updateMapState();
      } else if (mounted) {
        _applyFallbackRoute(_currentPosition!);
      }
    } catch (_) {
      if (mounted) _applyFallbackRoute(_currentPosition!);
    }
    _updateMapState();
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
    final title = isNavigating
        ? 'Rute ke $_destinationName'
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
          if (isNavigating && widget.placesList != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Tutup Rute',
              onPressed: () {
                setState(() {
                  _isShowingRoute = false;
                  _routePoints = [];
                  _hasArrived = false;
                });
                _updateMapState();
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
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    ),
                    initialZoom: 15.0,
                    minZoom: 4,
                    maxZoom: 22,
                    onTap: _onMapTap,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all,
                    ),
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(
                        const LatLng(-11.0, 94.0),
                        const LatLng(6.0, 142.0),
                      ),
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tenmu.app',
                    ),
                    PolylineLayer(polylines: _currentPolylines),
                    MarkerLayer(markers: _currentMarkers),
                  ],
                ),

                // --- Fallback indicator ---
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
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 16,
                            color: Colors.orange.shade800,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Rute offline — perkiraan jarak lurus',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- Recenter button ---
                Positioned(
                  right: 16,
                  bottom: 140 + bottomPadding,
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
                    ? Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _buildNavSheet(theme),
                      )
                    : Positioned(
                        left: 16,
                        right: 16,
                        bottom: 30 + bottomPadding + 60,
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
    );
  }

  // =======================================================================
  // Navigation bottom sheet (fixed — no scroll)
  // =======================================================================
  Widget _buildNavSheet(ThemeProvider theme) {
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
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 6, bottom: 4),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.textHint,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Arrival card
            if (_hasArrived)
              _buildArrivalCard(theme)
            // Navigation info
            else ...[
              _buildNavInfoCard(theme),
              Divider(color: theme.border, height: 1),

              // Travel mode selector
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
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
                            Text(
                              mode.iconLabel,
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              mode.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: isActive
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isActive
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
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavInfoCard(ThemeProvider theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _infoColumn(
            _useFallback ? 'Lurus' : 'Jarak',
            _distanceInKm != null
                ? '${_distanceInKm!.toStringAsFixed(1)} km'
                : '-',
            theme,
          ),
          Container(width: 1, height: 32, color: theme.border),
          _infoColumn(
            'Waktu',
            _estimatedTimeInMins != null
                ? _formatEstimate(_estimatedTimeInMins!)
                : '-',
            theme,
          ),
          Container(width: 1, height: 32, color: theme.border),
          _infoColumn(
            'Kecepatan',
            '${_currentSpeedKmh.toStringAsFixed(0)} km/h',
            theme,
          ),
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
            const Icon(
              Icons.check_circle_outline,
              color: Colors.white,
              size: 48,
            ),
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
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _arrivalStat(
                  Icons.straighten,
                  '${_totalTripDistanceKm.toStringAsFixed(1)} km',
                  'Total Jarak',
                  Colors.white,
                ),
                Container(height: 30, width: 1, color: Colors.white30),
                _arrivalStat(
                  Icons.timer_outlined,
                  _formatEstimate(_totalTripMinutes),
                  'Waktu Tempuh',
                  Colors.white,
                ),
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
                    _hasArrived = false;
                  });
                  _updateMapState();
                  _recenterMap();
                },
                icon: const Icon(Icons.close, color: Colors.white),
                label: const Text(
                  'Selesai',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white54),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
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
                      ? Image.network(
                          imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _placeholderImage(theme),
                        )
                      : _placeholderImage(theme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPlace!['nama_tempat'] ?? 'Tanpa Nama',
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
                        _selectedPlace!['alamat'] ?? '-',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
                    _updateMapState();
                  },
                ),
              ],
            ),
          ),
          Container(height: 1, color: theme.border),
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

  Widget _placeholderImage(ThemeProvider theme) {
    return Container(
      width: 60,
      height: 60,
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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.touch_app_rounded, color: theme.iconColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tap pada marker untuk melihat detail UMKM.',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
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

  String _formatEstimate(int mins) {
    if (mins < 1) return '<1 mnt';
    if (mins < 60) return '$mins mnt';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '${h}j ${m}mnt' : '$h jam';
  }
}

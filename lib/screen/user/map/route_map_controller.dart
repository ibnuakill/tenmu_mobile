import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';
import '../../../core/location_permission_helper.dart';
import '../../../core/poi_category.dart';

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
}

/// Owns all non-widget state: position, route, markers, GPS stream,
/// compass, arrival, reroute. Notifies on changes that need rebuild.
class RouteMapController extends ChangeNotifier {
  RouteMapController({
    required this.context,
    this.placesList,
    this.initialDestinationLat,
    this.initialDestinationLng,
    this.initialDestinationName,
    this.initialDestinationCategory,
  });

  final BuildContext context;
  final List<Map<String, dynamic>>? placesList;
  final double? initialDestinationLat;
  final double? initialDestinationLng;
  final String? initialDestinationName;
  final String? initialDestinationCategory;

  // --- Map controller (set setelah onMapCreated) ---
  MapLibreMapController? mapController;
  final Completer<MapLibreMapController> mapReady =
      Completer<MapLibreMapController>();
  bool mapStyleLoaded = false;

  // --- GPS & route ---
  Position? currentPosition;
  List<LatLng> routePoints = [];
  double? distanceInKm;
  int? estimatedTimeInMins;
  double _currentSpeedMs = 0.0;
  double osrmTotalDistance = 0;
  double originalStraightDistance = 0;
  bool isLoading = true;
  String? errorMessage;
  bool useFallback = false;

  // --- Selection ---
  Map<String, dynamic>? selectedPlace;
  bool isShowingRoute = false;
  TravelMode travelMode = TravelMode.motorcycle;

  // --- Arrival ---
  bool hasArrived = false;
  double totalTripDistanceKm = 0;
  int totalTripMinutes = 0;

  // --- Compass ---
  StreamSubscription<CompassEvent>? _compassSubscription;
  double compassHeading = 0.0;
  double get currentSpeedKmh => _currentSpeedMs * 3.6;

  // --- Live tracking ---
  StreamSubscription<Position>? _positionStreamSubscription;

  // --- Auto-reroute ---
  DateTime _lastReroute = DateTime(2000);
  bool _isRerouting = false;
  static const double _rerouteThresholdM = 60.0;
  static const Duration _rerouteCooldown = Duration(seconds: 15);

  // --- Destination ---
  double? destinationLat;
  double? destinationLng;
  String? destinationName;
  String? destinationCategory;

  // --- Native symbol refs ---
  final List<Symbol> placeSymbols = [];
  Symbol? currentPosSymbol;
  Symbol? destinationSymbol;
  Line? routeLine;
  bool isUpdatingMarker = false;

  Color get routeColor => switch (travelMode) {
        TravelMode.walking => Colors.green,
        TravelMode.motorcycle => Colors.blue,
        TravelMode.car => Colors.orange,
      };

  // ═══════════════════════════════════════════
  // Bootstrap
  // ═══════════════════════════════════════════

  void bootstrap() {
    if (initialDestinationLat != null && initialDestinationLng != null) {
      destinationLat = initialDestinationLat;
      destinationLng = initialDestinationLng;
      destinationName = initialDestinationName;
      destinationCategory = initialDestinationCategory;
      isShowingRoute = true;
    }
  }

  // ═══════════════════════════════════════════
  // GPS / route
  // ═══════════════════════════════════════════

  Future<void> initLocationAndRoute() async {
    try {
      final accessStatus = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'melihat rute lokasi',
      );
      if (accessStatus != LocationAccessStatus.granted) {
        errorMessage = switch (accessStatus) {
          LocationAccessStatus.serviceDisabled =>
            'GPS belum aktif.\nAktifkan lokasi lalu coba lagi.',
          LocationAccessStatus.permissionDenied =>
            'Izin lokasi belum diberikan.\nIzinkan akses lokasi lalu coba lagi.',
          LocationAccessStatus.permissionDeniedForever =>
            'Izin lokasi ditolak permanen.\nBuka pengaturan aplikasi lalu aktifkan izin lokasi.',
          LocationAccessStatus.granted => null,
        };
        isLoading = false;
        notifyListeners();
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      );
      currentPosition = position;

      if (destinationLat != null && destinationLng != null) {
        final result = await fetchRoute(position);
        if (result != null) {
          final (points, distanceMeters, durationSeconds) = result;
          routePoints = points;
          osrmTotalDistance = distanceMeters;
          originalStraightDistance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            destinationLat!,
            destinationLng!,
          );
          distanceInKm = distanceMeters / 1000;
          estimatedTimeInMins = (durationSeconds / 60).round();
          useFallback = false;
          isLoading = false;
          hasArrived = false;
        } else {
          applyFallbackRoute(position);
        }
        notifyListeners();
      } else {
        isLoading = false;
        notifyListeners();
      }

      try {
        await mapReady.future.timeout(const Duration(seconds: 3));
      } catch (_) {}

      _startLiveTracking();
    } catch (e) {
      isLoading = false;
      errorMessage =
          'Gagal mengambil lokasi GPS.\nPastikan izin lokasi sudah diaktifkan.';
      notifyListeners();
    }
  }

  Future<(List<LatLng> points, double distanceM, double durationS)?>
      fetchRoute(Position position, {int retry = 1}) async {
    if (destinationLat == null || destinationLng == null) return null;

    String profileUrl(String baseUrl) {
      final profile = travelMode.osrmProfile;
      if (baseUrl.contains('routing.openstreetmap.de')) {
        final sub = switch (travelMode) {
          TravelMode.walking => 'foot',
          TravelMode.motorcycle => 'car',
          TravelMode.car => 'car',
        };
        final osmProfile = switch (travelMode) {
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
            '$destinationLng,$destinationLat'
            '?geometries=geojson&overview=full',
          );
          final response = await http.get(url).timeout(const Duration(seconds: 6));
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

  void applyFallbackRoute(Position position) {
    if (destinationLat == null || destinationLng == null) return;
    final m = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      destinationLat!,
      destinationLng!,
    );
    currentPosition = position;
    routePoints = [
      LatLng(position.latitude, position.longitude),
      LatLng(destinationLat!, destinationLng!),
    ];
    osrmTotalDistance = m;
    originalStraightDistance = m;
    distanceInKm = m / 1000;
    estimatedTimeInMins = ((m / 1000) / travelMode.speedKmh * 60).round();
    useFallback = true;
    isLoading = false;
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // Live tracking
  // ═══════════════════════════════════════════

  void _startLiveTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen((p) {
      currentPosition = p;
      _currentSpeedMs = p.speed;

      if (destinationLat == null ||
          destinationLng == null ||
          _isRerouting) {
        return;
      }

      final remaining = Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        destinationLat!,
        destinationLng!,
      );

      if (!hasArrived && remaining < 50) {
        _onArrival();
        return;
      }

      final ratio = osrmTotalDistance > 0 && originalStraightDistance > 0
          ? osrmTotalDistance / originalStraightDistance
          : 1.0;
      final road = remaining * ratio;
      distanceInKm = road / 1000;
      estimatedTimeInMins =
          ((road / travelMode.speedKmh) / 1000 * 60).round();

      if (!useFallback && routePoints.length > 1) {
        final deviation = distanceToRoute(
          LatLng(p.latitude, p.longitude),
          routePoints,
        );
        final now = DateTime.now();
        if (deviation > _rerouteThresholdM &&
            now.difference(_lastReroute) > _rerouteCooldown) {
          _lastReroute = now;
          _doReroute(p);
        }
      }
      notifyListeners();
    });
  }

  void _onArrival() {
    hasArrived = true;
    totalTripDistanceKm = distanceInKm ?? 0;
    totalTripMinutes = estimatedTimeInMins ?? 0;
    distanceInKm = 0;
    estimatedTimeInMins = 0;
    notifyListeners();
  }

  // ═══════════════════════════════════════════
  // Auto-reroute helpers
  // ═══════════════════════════════════════════

  double distanceToRoute(LatLng point, List<LatLng> route) {
    double minDist = double.infinity;
    for (int i = 0; i < route.length - 1; i++) {
      final d = pointToLineDistance(
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

  double pointToLineDistance(
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
    if (!useFallback) {
      final result = await fetchRoute(p);
      if (result != null) {
        final (points, distanceMeters, durationSeconds) = result;
        routePoints = points;
        osrmTotalDistance = distanceMeters;
        distanceInKm = distanceMeters / 1000;
        estimatedTimeInMins = (durationSeconds / 60).round();
        hasArrived = false;
        _isRerouting = false;
        notifyListeners();
        return;
      }
    }
    applyFallbackRoute(p);
    _isRerouting = false;
  }

  // ═══════════════════════════════════════════
  // Travel mode change
  // ═══════════════════════════════════════════

  Future<void> setTravelMode(TravelMode mode) async {
    if (travelMode == mode) return;
    travelMode = mode;
    isLoading = true;
    notifyListeners();
    if (currentPosition == null || destinationLat == null) {
      isLoading = false;
      notifyListeners();
      return;
    }
    final result = await fetchRoute(currentPosition!);
    if (result != null) {
      final (points, distanceMeters, durationSeconds) = result;
      routePoints = points;
      osrmTotalDistance = distanceMeters;
      originalStraightDistance = Geolocator.distanceBetween(
        currentPosition!.latitude,
        currentPosition!.longitude,
        destinationLat!,
        destinationLng!,
      );
      distanceInKm = distanceMeters / 1000;
      estimatedTimeInMins =
          ((distanceMeters / 1000) / travelMode.speedKmh * 60).round();
      useFallback = false;
      isLoading = false;
      hasArrived = false;
      notifyListeners();
    } else if (currentPosition != null) {
      applyFallbackRoute(currentPosition!);
    }
  }

  // ═══════════════════════════════════════════
  // Selection / start route
  // ═══════════════════════════════════════════

  void selectPlace(Map<String, dynamic> place) {
    selectedPlace = place;
    destinationLat = place['latitude'] as double?;
    destinationLng = place['longitude'] as double?;
    destinationName = place['nama_tempat'];
    destinationCategory = _resolveCategory(place);
    isShowingRoute = false;
    notifyListeners();
  }

  void clearSelection() {
    selectedPlace = null;
    destinationLat = null;
    destinationLng = null;
    destinationName = null;
    destinationCategory = null;
    notifyListeners();
  }

  void startRoute() {
    isShowingRoute = true;
    isLoading = true;
    notifyListeners();
    initLocationAndRoute();
  }

  void closeRoute() {
    isShowingRoute = false;
    routePoints = [];
    hasArrived = false;
    notifyListeners();
  }

  void finishTrip() {
    isShowingRoute = false;
    routePoints = [];
    hasArrived = false;
    notifyListeners();
  }

  void retryInit() {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    initLocationAndRoute();
  }

  // ═══════════════════════════════════════════
  // Compass
  // ═══════════════════════════════════════════

  void startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading == null) return;
      double diff = (heading - compassHeading) % 360;
      if (diff > 180) {
        diff -= 360;
      } else if (diff < -180) {
        diff += 360;
      }
      if (diff.abs() < 1.0) return;
      compassHeading = (compassHeading + diff * 0.15) % 360;
      if (compassHeading < 0) compassHeading += 360;
      // Update marker saja, tidak notifyListeners (avoid full rebuild @ 60Hz).
    });
  }

  // ═══════════════════════════════════════════
  // Helpers
  // ═══════════════════════════════════════════

  String _resolveCategory(Map<String, dynamic> place) {
    final c = place['category']?.toString().trim();
    if (c == null || c.isEmpty) return PoiCategory.lainnya;
    return PoiCategory.normalizeCategory(c);
  }

  /// Convert kategori string → safe MapLibre image key
  /// e.g. 'Kuliner & Cafe' → 'marker_kuliner_cafe'
  static String catKey(String cat) {
    return 'marker_${cat.toLowerCase().replaceAll(RegExp(r'[&\s]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '')}';
  }

  String formatEstimate(int mins) {
    if (mins < 1) return '<1 mnt';
    if (mins < 60) return '$mins mnt';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m > 0 ? '${h}j ${m}mnt' : '$h jam';
  }

  String resolveCategory(Map<String, dynamic> place) {
    return _resolveCategory(place);
  }

  Future<void> fitRouteToCamera() async {
    if (routePoints.length < 2 || mapController == null) return;
    try {
      const padding = EdgeInsets.fromLTRB(40, 80, 40, 220);
      await mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: routePoints.first,
            northeast: routePoints.last,
          ),
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        ),
      );
    } catch (_) {
      try {
        await mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(routePoints.first, 14.0),
        );
      } catch (_) {}
    }
  }

  void recenterMap() {
    if (currentPosition == null || mapController == null) return;
    mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(currentPosition!.latitude, currentPosition!.longitude),
        16.0,
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
  }
}

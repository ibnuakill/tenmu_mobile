import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../../core/theme_provider.dart';
import '../../core/location_permission_helper.dart';
import '../../core/poi_category.dart';
import '../../core/poi_image_helper.dart';
import '../../core/maptiler_style.dart';

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
}

class RouteMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>>? placesList;
  final double? destinationLat;
  final double? destinationLng;
  final String? destinationName;

  final String? destinationCategory;

  const RouteMapScreen({
    super.key,
    this.placesList,
    this.destinationLat,
    this.destinationLng,
    this.destinationName,
    this.destinationCategory,
  });

  @override
  State<RouteMapScreen> createState() => _RouteMapScreenState();
}

class _RouteMapScreenState extends State<RouteMapScreen> {
  // --- Map ---
  MapLibreMapController? _mapController;
  final Completer<MapLibreMapController> _mapReady =
      Completer<MapLibreMapController>();
  bool _mapStyleLoaded = false;

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
  StreamSubscription<CompassEvent>? _compassSubscription;
  double _compassHeading = 0.0;

  // Auto-reroute
  DateTime _lastReroute = DateTime(2000);
  bool _isRerouting = false;
  static const double _rerouteThresholdM = 60.0;
  static const Duration _rerouteCooldown = Duration(seconds: 15);

  // --- Native Symbol tracking ---
  final List<Symbol> _placeSymbols = [];
  Symbol? _currentPosSymbol;
  Symbol? _destinationSymbol;
  Line? _routeLine;
  bool _isUpdatingMarker = false;

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
      _destinationCategory = widget.destinationCategory;
      _isShowingRoute = true;
    }
    _initLocationAndRoute();
    _startCompass();
  }

  double? _destinationLat;
  double? _destinationLng;
  String? _destinationName;
  String? _destinationCategory;

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _compassSubscription?.cancel();
    super.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
    );
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

  void _startCompass() {
    _compassSubscription = FlutterCompass.events?.listen((CompassEvent event) {
      if (!mounted) return;
      final heading = event.heading;
      if (heading == null) return;

      // Hitung perbedaan sudut terpendek (shortest angular distance)
      double diff = (heading - _compassHeading) % 360;
      if (diff > 180) {
        diff -= 360;
      } else if (diff < -180) {
        diff += 360;
      }

      // Abaikan noise yang sangat kecil
      if (diff.abs() < 1.0) return;

      // Low-pass filter (smoothing) agar rotasi tidak patah-patah/jumping
      _compassHeading = (_compassHeading + diff * 0.15) % 360;
      if (_compassHeading < 0) _compassHeading += 360;

      // Hindari memanggil setState setiap kali compass update (bisa sampai 60Hz),
      // cukup update marker nativenya saja agar tidak lag UI-nya.
      _drawCurrentPositionMarker();
    });
  }

  // =======================================================================
  // Map callbacks
  // =======================================================================
  void _onMapCreated(MapLibreMapController controller) {
    _mapController = controller;
    if (!_mapReady.isCompleted) _mapReady.complete(controller);
    // Listen to symbol taps via controller stream
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    _mapStyleLoaded = true;
    debugPrint('[MAP] Style loaded — starting marker registration');
    await _registerMarkerImages();
    debugPrint('[MAP] Marker registration done — drawing overlays');
    await _drawAllOverlays();
    debugPrint('[MAP] _drawAllOverlays from onStyleLoaded done');
  }

  // =======================================================================
  // Marker image registration
  // =======================================================================

  // Membangun marker lingkaran dengan Material icon atau SVG asset
  Future<Uint8List> _buildCircleMarkerImage({
    required Color bgColor,
    required int iconCode,
    String? svgAssetPath,
    int size = 100,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final center = Offset(size / 2.0, size / 2.0);
    final radius = size / 2.0 - 4.0;

    // Drop shadow
    canvas.drawCircle(
      Offset(center.dx, center.dy + 3),
      radius,
      Paint()
        ..color = Colors.black.withAlpha(80)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    // Filled circle
    canvas.drawCircle(center, radius, Paint()..color = bgColor);

    // White border
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0,
    );

    bool svgDrawn = false;
    if (svgAssetPath != null) {
      try {
        final svgString = await rootBundle.loadString(svgAssetPath);
        final PictureInfo pictureInfo = await vg.loadPicture(
          SvgStringLoader(svgString),
          null,
        );
        final svgPicture = pictureInfo.picture;
        final svgBounds = pictureInfo.size;

        final targetSize = size * 0.45;
        final scale = targetSize / math.max(svgBounds.width, svgBounds.height);

        canvas.save();
        canvas.translate(
          center.dx - (svgBounds.width * scale) / 2,
          center.dy - (svgBounds.height * scale) / 2,
        );
        canvas.scale(scale, scale);
        canvas.drawPicture(svgPicture);
        canvas.restore();
        svgDrawn = true;
      } catch (e) {
        debugPrint('[MAP] SVG render failed for $svgAssetPath: $e');
        svgDrawn = false;
      }
    }

    if (!svgDrawn) {
      // Material icon glyph fallback
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconCode),
          style: TextStyle(
            fontFamily: 'MaterialIcons',
            fontSize: size * 0.40,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(
        canvas,
        Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
      );
    }

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _registerMarkerImages() async {
    final c = _mapController;
    if (c == null) return;

    // Current position marker (Gmaps style arrow)
    final currentPosImg = await _buildNavArrowImage(
      color: const Color(0xFF4285F4),
      size: 96,
    );
    await c.addImage('marker_current', currentPosImg);

    // Material icon codepoints per kategori
    final Map<String, int> categoryIcons = {
      PoiCategory.wisataBudaya: Icons.landscape_outlined.codePoint,
      PoiCategory.kulinerCafe: Icons.restaurant_outlined.codePoint,
      PoiCategory.olehOlehKerajinan: Icons.palette_outlined.codePoint,
      PoiCategory.penginapanHotel: Icons.hotel_outlined.codePoint,
      PoiCategory.pertokoanUmkm: Icons.storefront_outlined.codePoint,
      PoiCategory.jasaLayanan: Icons.build_outlined.codePoint,
      PoiCategory.lainnya: Icons.place_outlined.codePoint,
    };

    final Map<String, Color> categoryColors = {
      PoiCategory.wisataBudaya: const Color(0xFF4CAF50),
      PoiCategory.kulinerCafe: const Color(0xFFFF7043),
      PoiCategory.olehOlehKerajinan: const Color(0xFF9C27B0),
      PoiCategory.penginapanHotel: const Color(0xFF2196F3),
      PoiCategory.pertokoanUmkm: const Color(0xFFFFC107),
      PoiCategory.jasaLayanan: const Color(0xFF009688),
      PoiCategory.lainnya: const Color(0xFF607D8B),
    };

    for (final cat in PoiCategory.allCategories) {
      final color = categoryColors[cat] ?? const Color(0xFF607D8B);
      final iconCode = categoryIcons[cat] ?? Icons.place_outlined.codePoint;
      final svgPath = PoiCategory.getCategorySvgPath(cat);
      final key = _catKey(cat);
      debugPrint('[MAP] Registering marker: $key (svgPath=$svgPath)');
      try {
        final img = await _buildCircleMarkerImage(
          bgColor: color,
          iconCode: iconCode,
          svgAssetPath: svgPath,
          size: 100,
        );
        await c.addImage(key, img);
        debugPrint('[MAP] Registered OK: $key');
      } catch (e) {
        debugPrint('[MAP] ERROR registering $key: $e');
      }
    }

    // Selected marker
    final selectedImg = await _buildCircleMarkerImage(
      bgColor: const Color(0xFF3366FF),
      iconCode: Icons.star_rounded.codePoint,
      size: 120,
    );
    await c.addImage('marker_selected', selectedImg);

    // Destination marker
    final destImg = await _buildCircleMarkerImage(
      bgColor: const Color(0xFFFF4444),
      iconCode: Icons.flag_rounded.codePoint,
      size: 120,
    );
    await c.addImage('marker_destination', destImg);
  }

  Future<Uint8List> _buildNavArrowImage({
    required Color color,
    int size = 96,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    );
    final center = Offset(size / 2.0, size / 2.0);
    final radius = size / 2.0 - 8;

    final path = Path();
    // Gambar panah gaya navigasi
    path.moveTo(center.dx, center.dy - radius); // Puncak
    path.lineTo(center.dx + radius * 0.7, center.dy + radius * 0.8); // Kanan
    path.lineTo(center.dx, center.dy + radius * 0.3); // Indent tengah bawah
    path.lineTo(center.dx - radius * 0.7, center.dy + radius * 0.8); // Kiri
    path.close();

    // Drop shadow
    final dropShadowPaint = Paint()
      ..color = Colors.black.withAlpha(80)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path.shift(const Offset(0, 4)), dropShadowPaint);

    // Stroke putih tebal (Outline)
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 6.0;
    canvas.drawPath(path, outlinePaint);

    // Fill warna utama
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _drawAllOverlays() async {
    await _drawRoute();
    await _drawPlaceMarkers();
    await _drawCurrentPositionMarker();
    if (_destinationLat != null && _destinationLng != null && _isShowingRoute) {
      await _drawDestinationMarker();
    }
  }

  Future<void> _drawRoute() async {
    final c = _mapController;
    if (c == null || !_mapStyleLoaded) return;

    if (_routeLine != null) {
      try {
        await c.removeLine(_routeLine!);
      } catch (_) {}
      _routeLine = null;
    }

    if (_routePoints.length < 2) return;

    final c32 = _routeColor.toARGB32();
    final colorHex = '#${c32.toRadixString(16).padLeft(8, '0').substring(2)}';

    try {
      _routeLine = await c.addLine(
        LineOptions(
          geometry: _routePoints,
          lineColor: _useFallback ? '#888888' : colorHex,
          lineWidth: _useFallback ? 3.0 : 5.0,
          lineOpacity: 0.9,
        ),
      );
    } catch (_) {}
  }

  Future<void> _drawPlaceMarkers() async {
    final c = _mapController;
    if (c == null || !_mapStyleLoaded) return;

    for (final sym in _placeSymbols) {
      try {
        await c.removeSymbol(sym);
      } catch (_) {}
    }
    _placeSymbols.clear();

    if (widget.placesList == null) return;

    for (final place in widget.placesList!) {
      final isSelected = _selectedPlace?['id'] == place['id'];
      if (_isShowingRoute && !isSelected) continue;
      final rawLat = place['latitude'];
      final rawLng = place['longitude'];
      if (rawLat == null || rawLng == null) continue;
      final lat = (rawLat as num).toDouble();
      final lng = (rawLng as num).toDouble();
      final cat = _resolveCategory(place);
      final imageId = _catKey(cat);

      try {
        final sym = await c.addSymbol(
          SymbolOptions(
            geometry: LatLng(lat, lng),
            iconImage: imageId,
            iconSize: isSelected ? 1.4 : 1.0,
            iconAnchor: 'center',
            zIndex: isSelected ? 2 : 1,
          ),
          {'placeId': place['id']?.toString() ?? ''},
        );
        _placeSymbols.add(sym);
      } catch (_) {}
    }
  }

  Future<void> _drawCurrentPositionMarker() async {
    final c = _mapController;
    if (c == null || !_mapStyleLoaded || _currentPosition == null) return;
    if (_isUpdatingMarker) return;

    _isUpdatingMarker = true;
    try {
      final heading = _currentSpeedKmh > 3.0
          ? _currentPosition!.heading
          : _compassHeading;

      final geometry = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );

      if (_currentPosSymbol != null) {
        // Update posisi & rotasi TANPA hapus symbol → tidak ada frame kosong → tidak kedip
        try {
          await c.updateSymbol(
            _currentPosSymbol!,
            SymbolOptions(
              geometry: geometry,
              iconRotate: heading,
            ),
          );
          return; // sukses update, tidak perlu buat ulang
        } catch (_) {
          // Jika symbol sudah tidak valid (misal setelah style reload), hapus ref-nya
          _currentPosSymbol = null;
        }
      }

      // Buat symbol baru hanya jika belum ada / habis dihapus
      _currentPosSymbol = await c.addSymbol(
        SymbolOptions(
          geometry: geometry,
          iconImage: 'marker_current',
          iconSize: 1.2,
          iconAnchor: 'center',
          iconRotate: heading,
          zIndex: 100,
        ),
      );
    } catch (_) {
    } finally {
      _isUpdatingMarker = false;
    }
  }


  Future<void> _drawDestinationMarker() async {
    final c = _mapController;
    if (c == null || !_mapStyleLoaded) return;

    if (_destinationSymbol != null) {
      try {
        await c.removeSymbol(_destinationSymbol!);
      } catch (_) {}
      _destinationSymbol = null;
    }

    if (_destinationLat == null || _destinationLng == null) return;

    // Normalisasi kategori agar legacy values (misal "Makanan") tetap match
    final rawCat = _destinationCategory ?? '';
    final cat = rawCat.isNotEmpty
        ? PoiCategory.normalizeCategory(rawCat)
        : PoiCategory.lainnya;
    // Use category image if available, otherwise fallback to destination marker
    final imageId = PoiCategory.allCategories.contains(cat)
        ? _catKey(cat)
        : 'marker_destination';

    debugPrint(
      '[MAP] _drawDestinationMarker: rawCat="$rawCat" cat="$cat" imageId="$imageId"',
    );

    try {
      _destinationSymbol = await c.addSymbol(
        SymbolOptions(
          geometry: LatLng(_destinationLat!, _destinationLng!),
          iconImage: imageId,
          iconSize: 1.4,
          iconAnchor: 'center',
          zIndex: 5,
        ),
      );
    } catch (_) {}
  }

  // =======================================================================
  // Symbol tap handler
  // =======================================================================
  /// Convert kategori string → safe MapLibre image key
  /// e.g. 'Kuliner & Cafe' → 'marker_kuliner_cafe'
  static String _catKey(String cat) {
    return 'marker_${cat.toLowerCase().replaceAll(RegExp(r'[&\s]+'), '_').replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '')}';
  }

  void _onSymbolTapped(Symbol symbol) {
    if (_isShowingRoute) return;
    final placeId = symbol.data?['placeId'] as String?;
    if (placeId == null || placeId.isEmpty) return;
    if (widget.placesList == null) return;

    final place = widget.placesList!.firstWhere(
      (p) => p['id']?.toString() == placeId,
      orElse: () => {},
    );
    if (place.isEmpty) return;

    setState(() {
      _selectedPlace = place;
      _destinationLat = place['latitude'] as double?;
      _destinationLng = place['longitude'] as double?;
      _destinationName = place['nama_tempat'];
      _destinationCategory = _resolveCategory(place);
      _isShowingRoute = false;
    });
    _moveCamera(
      LatLng(place['latitude'] as double, place['longitude'] as double),
      16.0,
    );
    _drawPlaceMarkers();
  }

  Future<void> _onMapTap(math.Point<double> point, LatLng latlng) async {
    // Symbol taps handled via onSymbolTapped
  }

  // =======================================================================
  // Camera helpers
  // =======================================================================
  Future<void> _moveCamera(LatLng target, double zoom) async {
    final c = _mapController;
    if (c == null) return;
    try {
      await c.animateCamera(CameraUpdate.newLatLngZoom(target, zoom));
    } catch (_) {}
  }

  void _recenterMap() {
    if (_currentPosition == null) return;
    _moveCamera(
      LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
      16.0,
    );
  }

  Future<void> _fitRouteToCamera() async {
    if (_routePoints.length < 2) return;
    final c = _mapController;
    if (c == null) return;
    try {
      const padding = EdgeInsets.fromLTRB(40, 80, 40, 220);
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: _routePoints.first,
            northeast: _routePoints.last,
          ),
          left: padding.left,
          top: padding.top,
          right: padding.right,
          bottom: padding.bottom,
        ),
      );
    } catch (_) {
      try {
        await c.animateCamera(
          CameraUpdate.newLatLngZoom(_routePoints.first, 14.0),
        );
      } catch (_) {}
    }
  }

  // =======================================================================
  // GPS / OSRM
  // =======================================================================
  String _resolveCategory(Map<String, dynamic> place) {
    final category = place['category']?.toString().trim();
    if (category == null || category.isEmpty) return PoiCategory.lainnya;
    return PoiCategory.normalizeCategory(category);
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

      try {
        await _mapReady.future.timeout(const Duration(seconds: 3));
      } catch (_) {}

      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _drawAllOverlays();
        if (_destinationLat == null || _destinationLng == null) {
          _recenterMap();
        } else {
          _fitRouteToCamera();
        }
      });
      _startLiveTracking();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Gagal mengambil lokasi GPS.\nPastikan izin lokasi sudah diaktifkan.';
      });
    }
  }

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _drawAllOverlays();
      _fitRouteToCamera();
    });
  }

  // =======================================================================
  // Live tracking + arrival detection + auto-reroute
  // =======================================================================
  void _startLiveTracking() {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
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
          _drawCurrentPositionMarker();

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

          if (!_hasArrived && remaining < 50) {
            _onArrival();
            return;
          }

          final ratio = _osrmTotalDistance > 0 && _originalStraightDistance > 0
              ? _osrmTotalDistance / _originalStraightDistance
              : 1.0;
          final road = remaining * ratio;
          setState(() {
            _distanceInKm = road / 1000;
            _estimatedTimeInMins = ((road / _travelMode.speedKmh) / 1000 * 60)
                .round();
          });

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
        await _drawRoute();
        _isRerouting = false;
        return;
      }
    }
    _applyFallbackRoute(p);
    _isRerouting = false;
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
    final title = isNavigating ? 'Rute ke $_destinationName' : 'Peta Lokasi';

    final initialTarget = _currentPosition != null
        ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
        : const LatLng(-6.2088, 106.8456);

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
                _drawAllOverlays();
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
                // --- Base map ---
                MapLibreMap(
                  styleString: MapTilerStyle.hasKey
                      ? MapTilerStyle.url(MapTilerStyle.streets)
                      : 'https://demotiles.maplibre.org/style.json',
                  initialCameraPosition: CameraPosition(
                    target: initialTarget,
                    zoom: 15.0,
                  ),
                  minMaxZoomPreference: const MinMaxZoomPreference(4, 22),
                  myLocationEnabled: false,
                  onMapCreated: _onMapCreated,
                  onStyleLoadedCallback: _onStyleLoaded,
                  onMapClick: _onMapTap,
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

                // --- Compass + Recenter buttons ---
                Positioned(
                  right: 16,
                  bottom: 200 + bottomPadding,
                  child: Column(
                    children: [
                      FloatingActionButton(
                        heroTag: 'compass',
                        onPressed: () async {
                          try {
                            await _mapController?.animateCamera(
                              CameraUpdate.bearingTo(0),
                            );
                          } catch (_) {}
                        },
                        backgroundColor: theme.bgSurface,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.border),
                        ),
                        child: Icon(
                          Icons.explore_outlined,
                          color: theme.btnPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      FloatingActionButton(
                        heroTag: 'recenter',
                        onPressed: _recenterMap,
                        backgroundColor: theme.bgSurface,
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.border),
                        ),
                        child: Icon(Icons.my_location, color: theme.iconColor),
                      ),
                    ],
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
                        bottom: 16 + bottomPadding,
                        child: isPreviewing
                            ? _buildUmkmPreview(theme)
                            : _buildBrowseInfo(theme),
                      ),
              ],
            ),
    );
  }

  // =======================================================================
  // UI builder helpers
  // =======================================================================
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
            if (_hasArrived)
              _buildArrivalCard(theme)
            else ...[
              _buildNavInfoCard(theme),
              Divider(color: theme.border, height: 1),
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
                            Icon(
                              switch (mode) {
                                TravelMode.walking => Icons.directions_walk_rounded,
                                TravelMode.motorcycle => Icons.two_wheeler_rounded,
                                TravelMode.car => Icons.directions_car_rounded,
                              },
                              size: 16,
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
                  _drawAllOverlays();
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
                      ? CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorWidget: (_, _, _) => _placeholderImage(theme),
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
                    _drawPlaceMarkers();
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
              'Tap pada marker untuk melihat detail.',
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
        await _drawRoute();
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => _fitRouteToCamera(),
        );
      } else if (mounted) {
        _applyFallbackRoute(_currentPosition!);
      }
    } catch (_) {
      if (mounted) _applyFallbackRoute(_currentPosition!);
    }
  }
}

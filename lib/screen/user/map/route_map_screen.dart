import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../../../core/theme_provider.dart';
import '../../../core/maptiler_style.dart';
import '../../../core/poi_category.dart';
import 'route_map_controller.dart';
import 'widgets/map_marker_painter.dart';
import 'widgets/map_navigation_sheet.dart';

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
  late final RouteMapController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = RouteMapController(
      context: context,
      placesList: widget.placesList,
      initialDestinationLat: widget.destinationLat,
      initialDestinationLng: widget.destinationLng,
      initialDestinationName: widget.destinationName,
      initialDestinationCategory: widget.destinationCategory,
    );
    _ctrl.bootstrap();
    _ctrl.initLocationAndRoute();
    _ctrl.startCompass();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(systemNavigationBarColor: Colors.transparent),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();

    return Scaffold(
      backgroundColor: theme.bgBase,
      appBar: AppBar(
        title: Text(
          _ctrl.isShowingRoute
              ? 'Rute ke ${_ctrl.destinationName}'
              : 'Peta Lokasi',
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
          if (_ctrl.isShowingRoute && widget.placesList != null)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Tutup Rute',
              onPressed: () {
                _ctrl.closeRoute();
                _drawAllOverlays();
                _ctrl.recenterMap();
              },
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          if (_ctrl.isLoading) {
            return Center(
              child: CircularProgressIndicator(color: theme.iconColor),
            );
          }
          if (_ctrl.errorMessage != null || _ctrl.currentPosition == null) {
            return MapErrorView(
              message: _ctrl.errorMessage,
              onRetry: _ctrl.retryInit,
            );
          }

          final initialTarget = _ctrl.currentPosition != null
              ? LatLng(
                  _ctrl.currentPosition!.latitude,
                  _ctrl.currentPosition!.longitude,
                )
              : const LatLng(-6.2088, 106.8456);

          return Stack(
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

              // --- Fallback banner ---
              if (_ctrl.useFallback)
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: const MapFallbackBanner(),
                ),

              // --- Compass + Recenter FABs ---
              Positioned(
                right: 16,
                bottom:
                    200 + MediaQuery.of(context).padding.bottom,
                child: MapFabStack(controller: _ctrl),
              ),

              // --- Bottom sheet / panel ---
              _buildBottomPanel(theme),
            ],
          );
        },
      ),
    );
  }

  // ═══════════════════════════════════════════
  // Map callbacks
  // ═══════════════════════════════════════════

  void _onMapCreated(MapLibreMapController controller) {
    _ctrl.mapController = controller;
    if (!_ctrl.mapReady.isCompleted) _ctrl.mapReady.complete(controller);
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    _ctrl.mapStyleLoaded = true;
    debugPrint('[MAP] Style loaded — starting marker registration');
    await _registerMarkerImages();
    debugPrint('[MAP] Marker registration done — drawing overlays');
    await _drawAllOverlays();
    if (_ctrl.isShowingRoute) {
      await _ctrl.fitRouteToCamera();
    } else if (_ctrl.currentPosition != null) {
      _ctrl.recenterMap();
    }
    debugPrint('[MAP] _drawAllOverlays from onStyleLoaded done');
  }

  Future<void> _onMapTap(math.Point<double> point, LatLng latlng) async {
    // Symbol taps handled via onSymbolTapped
  }

  void _onSymbolTapped(Symbol symbol) {
    if (_ctrl.isShowingRoute) return;
    final placeId = symbol.data?['placeId'] as String?;
    if (placeId == null || placeId.isEmpty) return;
    if (widget.placesList == null) return;

    final place = widget.placesList!.firstWhere(
      (p) => p['id']?.toString() == placeId,
      orElse: () => {},
    );
    if (place.isEmpty) return;

    _ctrl.selectPlace(place);
    _drawPlaceMarkers();
    _ctrl.recenterMap();
  }

  // ═══════════════════════════════════════════
  // Marker registration
  // ═══════════════════════════════════════════

  Future<void> _registerMarkerImages() async {
    final c = _ctrl.mapController;
    if (c == null) return;

    // Current position marker (Gmaps style arrow)
    final currentPosImg = await MapMarkerPainter.buildNavArrowImage(
      color: const Color(0xFF4285F4),
      size: 96,
    );
    await c.addImage('marker_current', currentPosImg);

    // Material icon codepoints per kategori
    final Map<String, int> categoryIcons = {
      'Wisata Budaya': Icons.landscape_outlined.codePoint,
      'Kuliner & Cafe': Icons.restaurant_outlined.codePoint,
      'Oleh-oleh & Kerajinan': Icons.palette_outlined.codePoint,
      'Penginapan & Hotel': Icons.hotel_outlined.codePoint,
      'Pertokoan & UMKM': Icons.storefront_outlined.codePoint,
      'Jasa & Layanan': Icons.build_outlined.codePoint,
      'Lainnya': Icons.place_outlined.codePoint,
    };

    final Map<String, Color> categoryColors = {
      'Wisata Budaya': const Color(0xFF4CAF50),
      'Kuliner & Cafe': const Color(0xFFFF7043),
      'Oleh-oleh & Kerajinan': const Color(0xFF9C27B0),
      'Penginapan & Hotel': const Color(0xFF2196F3),
      'Pertokoan & UMKM': const Color(0xFFFFC107),
      'Jasa & Layanan': const Color(0xFF009688),
      'Lainnya': const Color(0xFF607D8B),
    };

    for (final cat in PoiCategory.allCategories) {
      final color = categoryColors[cat] ?? const Color(0xFF607D8B);
      final iconCode = categoryIcons[cat] ?? Icons.place_outlined.codePoint;
      final svgPath = PoiCategory.getCategorySvgPath(cat);
      final key = RouteMapController.catKey(cat);
      debugPrint('[MAP] Registering marker: $key (svgPath=$svgPath)');
      try {
        final img = await MapMarkerPainter.buildCircleMarkerImage(
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
    final selectedImg = await MapMarkerPainter.buildCircleMarkerImage(
      bgColor: const Color(0xFF3366FF),
      iconCode: Icons.star_rounded.codePoint,
      size: 120,
    );
    await c.addImage('marker_selected', selectedImg);

    // Destination marker
    final destImg = await MapMarkerPainter.buildCircleMarkerImage(
      bgColor: const Color(0xFFFF4444),
      iconCode: Icons.flag_rounded.codePoint,
      size: 120,
    );
    await c.addImage('marker_destination', destImg);
  }

  // ═══════════════════════════════════════════
  // Overlay drawing
  // ═══════════════════════════════════════════

  Future<void> _drawAllOverlays() async {
    await _drawRoute();
    await _drawPlaceMarkers();
    await _drawCurrentPositionMarker();
    if (_ctrl.destinationLat != null &&
        _ctrl.destinationLng != null &&
        _ctrl.isShowingRoute) {
      await _drawDestinationMarker();
    }
  }

  Future<void> _drawRoute() async {
    final c = _ctrl.mapController;
    if (c == null || !_ctrl.mapStyleLoaded) return;

    if (_ctrl.routeLine != null) {
      try {
        await c.removeLine(_ctrl.routeLine!);
      } catch (_) {}
      _ctrl.routeLine = null;
    }

    if (_ctrl.routePoints.length < 2) return;

    final c32 = _ctrl.routeColor.toARGB32();
    final colorHex = '#${c32.toRadixString(16).padLeft(8, '0').substring(2)}';

    try {
      _ctrl.routeLine = await c.addLine(
        LineOptions(
          geometry: _ctrl.routePoints,
          lineColor: _ctrl.useFallback ? '#888888' : colorHex,
          lineWidth: _ctrl.useFallback ? 3.0 : 5.0,
          lineOpacity: 0.9,
        ),
      );
    } catch (_) {}
  }

  Future<void> _drawPlaceMarkers() async {
    final c = _ctrl.mapController;
    if (c == null || !_ctrl.mapStyleLoaded) return;

    for (final sym in _ctrl.placeSymbols) {
      try {
        await c.removeSymbol(sym);
      } catch (_) {}
    }
    _ctrl.placeSymbols.clear();

    if (widget.placesList == null) return;

    for (final place in widget.placesList!) {
      final isSelected = _ctrl.selectedPlace?['id'] == place['id'];
      if (_ctrl.isShowingRoute && !isSelected) continue;
      final rawLat = place['latitude'];
      final rawLng = place['longitude'];
      if (rawLat == null || rawLng == null) continue;
      final lat = (rawLat as num).toDouble();
      final lng = (rawLng as num).toDouble();
      final cat = _ctrl.resolveCategory(place);
      final imageId = RouteMapController.catKey(cat);

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
        _ctrl.placeSymbols.add(sym);
      } catch (_) {}
    }
  }

  Future<void> _drawCurrentPositionMarker() async {
    final c = _ctrl.mapController;
    if (c == null || !_ctrl.mapStyleLoaded || _ctrl.currentPosition == null) {
      return;
    }
    if (_ctrl.isUpdatingMarker) return;

    _ctrl.isUpdatingMarker = true;
    try {
      final heading = _ctrl.currentSpeedKmh > 3.0
          ? _ctrl.currentPosition!.heading
          : _ctrl.compassHeading;

      final geometry = LatLng(
        _ctrl.currentPosition!.latitude,
        _ctrl.currentPosition!.longitude,
      );

      if (_ctrl.currentPosSymbol != null) {
        try {
          await c.updateSymbol(
            _ctrl.currentPosSymbol!,
            SymbolOptions(
              geometry: geometry,
              iconRotate: heading,
            ),
          );
          return;
        } catch (_) {
          _ctrl.currentPosSymbol = null;
        }
      }

      _ctrl.currentPosSymbol = await c.addSymbol(
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
      _ctrl.isUpdatingMarker = false;
    }
  }

  Future<void> _drawDestinationMarker() async {
    final c = _ctrl.mapController;
    if (c == null || !_ctrl.mapStyleLoaded) return;

    if (_ctrl.destinationSymbol != null) {
      try {
        await c.removeSymbol(_ctrl.destinationSymbol!);
      } catch (_) {}
      _ctrl.destinationSymbol = null;
    }

    if (_ctrl.destinationLat == null || _ctrl.destinationLng == null) return;

    // Normalisasi kategori agar legacy values (misal "Makanan") tetap match
    final rawCat = _ctrl.destinationCategory ?? '';
    final cat = rawCat.isNotEmpty
        ? PoiCategory.normalizeCategory(rawCat)
        : PoiCategory.lainnya;
    // Use category image if available, otherwise fallback to destination marker
    final imageId = PoiCategory.allCategories.contains(cat)
        ? RouteMapController.catKey(cat)
        : 'marker_destination';

    debugPrint(
      '[MAP] _drawDestinationMarker: rawCat="$rawCat" cat="$cat" imageId="$imageId"',
    );

    try {
      _ctrl.destinationSymbol = await c.addSymbol(
        SymbolOptions(
          geometry: LatLng(_ctrl.destinationLat!, _ctrl.destinationLng!),
          iconImage: imageId,
          iconSize: 1.4,
          iconAnchor: 'center',
          zIndex: 5,
        ),
      );
    } catch (_) {}
  }

  // ═══════════════════════════════════════════
  // Bottom panel builder
  // ═══════════════════════════════════════════

  Widget _buildBottomPanel(ThemeProvider theme) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isPreviewing = _ctrl.selectedPlace != null && !_ctrl.isShowingRoute;
    final isNavigating = _ctrl.isShowingRoute;

    return Positioned(
      left: isNavigating ? 0 : 16,
      right: isNavigating ? 0 : 16,
      bottom: isNavigating ? 0 : 16 + bottomPadding,
      child: isNavigating
          ? MapNavigationSheet(controller: _ctrl)
          : isPreviewing
              ? MapUmkmPreview(
                  place: _ctrl.selectedPlace!,
                  onClose: () {
                    _ctrl.clearSelection();
                    _drawPlaceMarkers();
                  },
                  onStartRoute: () {
                    _ctrl.startRoute();
                    _ctrl.initLocationAndRoute();
                  },
                )
              : MapBrowseInfo(),
    );
  }
}
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as mgl;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/maptiler_style.dart';
import '../../../core/poi_category.dart';
import '../../../core/location_permission_helper.dart';
import '../../user/map/widgets/map_marker_painter.dart';

// Quixotic Palette
const _kPrimary      = Color(0xFF1E7A52);
const _kAccentGreen  = Color(0xFF0FA968);
const _kAccentAmber  = Color(0xFFF59E0B);
const _kPageBg       = Color(0xFFF3F4F6);
const _kCardBg       = Color(0xFFFFFFFF);
const _kBorderColor  = Color(0xFFE5E7EB);
const _kTextPrimary  = Color(0xFF111827);
const _kTextSecondary= Color(0xFF6B7280);
const _kTextMuted    = Color(0xFF9CA3AF);
const _kShadow = BoxShadow(color: Color(0x0A000000), blurRadius: 12, offset: Offset(0, 4));

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  // ── Maplibre (Android/iOS/web) ──
  mgl.MapLibreMapController? _mlController;
  bool _mapStyleLoaded = false;
  final List<mgl.Symbol> _mlSymbols = [];
  mgl.Symbol? _mlCurrentPosSymbol;
  bool _isRedrawing = false;

  // ── Flutter map (desktop fallback) ──
  final _fmController = MapController();

  final _searchCtrl = TextEditingController();
  bool _filterVisible = false;
  bool _loading = true;
  bool _locationFailed = false;

  List<Map<String, dynamic>> _places = [];
  Map<String, dynamic>? _selectedPlace;

  static const _fallbackCenter = LatLng(-6.2088, 106.8456);
  static const _defaultZoom = 12.0;

  LatLng? _currentLocation;

  /// maplibre_gl tidak support Windows/macOS/Linux (cuma Android/iOS/web) —
  /// desktop pakai flutter_map + OSM agar tetap tampil.
  bool get _useMaplibre {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  static const _pinColors = {
    'Cafe': Color(0xFF8B4513),
    'Fashion': Color(0xFFE91E63),
    'Wisata': Color(0xFF2196F3),
    'Kuliner': Color(0xFFE74C3C),
    'Hotel': Color(0xFF1565C0),
    'Oleh-Oleh': Color(0xFFFF6F61),
    'UMKM': Color(0xFF1E7A52),
  };

  Color _colorFor(String cat) => _pinColors[cat] ?? _kPrimary;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _fmController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_requestLocation(), _loadPlaces()]);
  }

  Future<void> _requestLocation() async {
    try {
      final access = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'memusatkan peta ke lokasi Anda',
      );
      if (access != LocationAccessStatus.granted) {
        setState(() => _locationFailed = true);
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _locationFailed = false;
      });
      if (_useMaplibre) {
        await _redrawSymbols();
      } else {
        _fmController.move(_currentLocation!, _defaultZoom);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _locationFailed = true);
    }
  }

  Future<void> _loadPlaces() async {
    final client = Supabase.instance.client;
    try {
      final data = await client
          .from('places')
          .select('id, nama_tempat, category, latitude, longitude, verification_status')
          .not('latitude', 'is', null)
          .not('longitude', 'is', null);

      if (!mounted) return;
      setState(() {
        _places = List<Map<String, dynamic>>.from(data);
        _loading = false;
      });
      await _redrawSymbols();
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _recenterToUser() {
    final loc = _currentLocation;
    if (loc != null) {
      if (_useMaplibre) {
        _mlController?.animateCamera(
          mgl.CameraUpdate.newLatLngZoom(
            mgl.LatLng(loc.latitude, loc.longitude),
            15.0,
          ),
        );
      } else {
        _fmController.move(loc, 15.0);
      }
    } else {
      _requestLocation();
    }
  }

  List<Map<String, dynamic>> get _filteredPlaces {
    final q = _searchCtrl.text.toLowerCase().trim();
    if (q.isEmpty) return _places;
    return _places.where((p) {
      final name = (p['nama_tempat'] as String? ?? '').toLowerCase();
      final cat = (p['category'] as String? ?? '').toLowerCase();
      return name.contains(q) || cat.contains(q);
    }).toList();
  }

  /// 'Cafe' → 'pin_cafe'; aman untuk MapLibre image key.
  static String _pinKey(String cat) {
    final slug = cat.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'pin_${slug.isEmpty ? 'lainnya' : slug}';
  }

  // ═══════════════════════════════════════════
  // Maplibre callbacks
  // ═══════════════════════════════════════════

  void _onMapCreated(mgl.MapLibreMapController controller) {
    _mlController = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _onStyleLoaded() async {
    _mapStyleLoaded = true;
    await _registerMarkerImages();
    await _redrawSymbols();
  }

  Future<void> _registerMarkerImages() async {
    final c = _mlController;
    if (c == null) return;

    for (final entry in _pinColors.entries) {
      final cat = entry.key;
      final svgPath = PoiCategory.getCategorySvgPath(cat);
      final img = await MapMarkerPainter.buildCircleMarkerImage(
        bgColor: entry.value,
        iconCode: PoiCategory.getCategoryIcon(cat).codePoint,
        svgAssetPath: svgPath,
        size: 100,
      );
      try {
        await c.addImage(_pinKey(cat), img);
      } catch (_) {}
    }

    final fallbackImg = await MapMarkerPainter.buildCircleMarkerImage(
      bgColor: _kPrimary,
      iconCode: Icons.place_outlined.codePoint,
      svgAssetPath: PoiCategory.getCategorySvgPath('Lainnya'),
      size: 100,
    );
    try {
      await c.addImage('pin_lainnya', fallbackImg);
    } catch (_) {}

    final currentImg = await MapMarkerPainter.buildCircleMarkerImage(
      bgColor: _kPrimary,
      iconCode: Icons.my_location_rounded.codePoint,
      size: 100,
    );
    try {
      await c.addImage('pin_current', currentImg);
    } catch (_) {}
  }

  void _onSymbolTapped(mgl.Symbol symbol) {
    final placeId = symbol.data?['placeId'] as String?;
    if (placeId == null) return;
    final place = _places.where((p) => p['id']?.toString() == placeId).firstOrNull;
    if (place == null) return;
    setState(() => _selectedPlace = place);
    _redrawSymbols();
  }

  Future<void> _redrawSymbols() async {
    final c = _mlController;
    if (c == null || !_mapStyleLoaded || _isRedrawing) return;
    _isRedrawing = true;
    try {
      for (final sym in _mlSymbols) {
        try {
          await c.removeSymbol(sym);
        } catch (_) {}
      }
      _mlSymbols.clear();

      for (final place in _filteredPlaces) {
        final rawLat = place['latitude'];
        final rawLng = place['longitude'];
        if (rawLat == null || rawLng == null) continue;
        final lat = (rawLat as num).toDouble();
        final lng = (rawLng as num).toDouble();
        final cat = place['category'] as String? ?? '';
        final isSelected = _selectedPlace?['id'] == place['id'];

        try {
          final sym = await c.addSymbol(
            mgl.SymbolOptions(
              geometry: mgl.LatLng(lat, lng),
              iconImage: _pinKey(cat),
              iconSize: isSelected ? 1.4 : 1.0,
              iconAnchor: 'center',
              zIndex: isSelected ? 2 : 1,
            ),
            {'placeId': place['id']?.toString() ?? ''},
          );
          _mlSymbols.add(sym);
        } catch (_) {}
      }

      if (_currentLocation != null) {
        final current = mgl.LatLng(
          _currentLocation!.latitude,
          _currentLocation!.longitude,
        );
        if (_mlCurrentPosSymbol != null) {
          try {
            await c.updateSymbol(
              _mlCurrentPosSymbol!,
              mgl.SymbolOptions(geometry: current),
            );
            return;
          } catch (_) {
            _mlCurrentPosSymbol = null;
          }
        }
        try {
          _mlCurrentPosSymbol = await c.addSymbol(
            mgl.SymbolOptions(
              geometry: current,
              iconImage: 'pin_current',
              iconSize: 1.0,
              iconAnchor: 'center',
              zIndex: 100,
            ),
          );
        } catch (_) {}
      }
    } finally {
      _isRedrawing = false;
    }
  }

  // ═══════════════════════════════════════════
  // Flutter map markers (desktop fallback)
  // ═══════════════════════════════════════════

  Marker? get _userLocationMarker {
    final loc = _currentLocation;
    if (loc == null) return null;
    return Marker(
      point: loc,
      width: 28, height: 28,
      child: Container(
        decoration: BoxDecoration(
          color: _kPrimary,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [BoxShadow(color: _kPrimary.withValues(alpha: 0.4), blurRadius: 8)],
        ),
        child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 14),
      ),
    );
  }

  Marker _buildPin(Map<String, dynamic> place, int index) {
    final lat = place['latitude'];
    final lng = place['longitude'];
    if (lat == null || lng == null) {
      return Marker(point: const LatLng(0, 0), child: const SizedBox.shrink());
    }
    final point = LatLng((lat as num).toDouble(), (lng as num).toDouble());
    final isSelected = _selectedPlace?['id'] == place['id'];
    final cat = place['category'] as String? ?? '';
    final color = _colorFor(cat);

    return Marker(
      point: point,
      width: isSelected ? 42 : 34,
      height: isSelected ? 42 : 34,
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlace = place),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: isSelected ? color.withValues(alpha: 0.5) : Colors.black12,
                blurRadius: isSelected ? 12 : 4,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Builder(
            builder: (context) {
              final svgPath = PoiCategory.getCategorySvgPath(cat);
              if (svgPath != null) {
                return Padding(
                  padding: EdgeInsets.all(isSelected ? 7.0 : 5.0),
                  child: SvgPicture.asset(
                    svgPath,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                );
              }
              return Icon(
                PoiCategory.getCategoryIcon(cat),
                size: isSelected ? 18 : 14,
                color: Colors.white,
              );
            },
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kPageBg,
      body: Stack(
        children: [
          // ── MAP ──
          if (_loading)
            Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2.5))
          else if (_useMaplibre)
            mgl.MapLibreMap(
              styleString: MapTilerStyle.hasKey
                  ? MapTilerStyle.url(MapTilerStyle.streets)
                  : 'https://demotiles.maplibre.org/style.json',
              initialCameraPosition: mgl.CameraPosition(
                target: mgl.LatLng(
                  _currentLocation?.latitude ?? _fallbackCenter.latitude,
                  _currentLocation?.longitude ?? _fallbackCenter.longitude,
                ),
                zoom: _defaultZoom,
              ),
              minMaxZoomPreference: const mgl.MinMaxZoomPreference(4, 22),
              myLocationEnabled: false,
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _onStyleLoaded,
              onMapClick: (math.Point<double> point, mgl.LatLng latlng) =>
                  setState(() => _selectedPlace = null),
            )
          else
            Builder(
              builder: (context) {
                final markers = _filteredPlaces
                    .asMap()
                    .entries
                    .map((e) => _buildPin(e.value, e.key))
                    .toList();
                final userMarker = _userLocationMarker;
                if (userMarker != null) markers.insert(0, userMarker);
                return FlutterMap(
                  mapController: _fmController,
                  options: MapOptions(
                    initialCenter: _currentLocation ?? _fallbackCenter,
                    initialZoom: _defaultZoom,
                    minZoom: 4,
                    maxZoom: 22,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
                    onTap: (_, a) => setState(() => _selectedPlace = null),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.tenmu.app',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                );
              },
            ),

          // ── LOCATION FAILED BANNER ──
          if (_locationFailed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 20, right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: _kCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorderColor),
                  boxShadow: const [_kShadow],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: _kAccentAmber),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Lokasi tidak tersedia. Aktifkan GPS.',
                        style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _kTextSecondary)),
                    ),
                  ],
                ),
              ),
            ),

          // ── FLOATING SEARCH ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20, right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _kBorderColor),
                boxShadow: const [_kShadow],
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: _kTextMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) {
                        setState(() {});
                        _redrawSymbols();
                      },
                      decoration: InputDecoration(
                        hintText: 'Cari tempat di peta...',
                        hintStyle: GoogleFonts.plusJakartaSans(color: _kTextMuted, fontSize: 13),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextPrimary),
                    ),
                  ),
                  Container(width: 1, height: 20, color: _kBorderColor),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => setState(() => _filterVisible = !_filterVisible),
                    child: Icon(Icons.tune_rounded, size: 20, color: _kPrimary),
                  ),
                ],
              ),
            ),
          ),

          // ── MAP CONTROLS ──
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.35,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ctrlBtn(
                  Icons.add_rounded,
                  onTap: _zoomIn,
                ),
                const SizedBox(height: 6),
                _ctrlBtn(
                  Icons.remove_rounded,
                  onTap: _zoomOut,
                ),
                const SizedBox(height: 10),
                _ctrlBtn(
                  Icons.my_location_rounded,
                  isPrimary: true,
                  onTap: _recenterToUser,
                ),
              ],
            ),
          ),

          // ── INFO CARD ──
          if (_selectedPlace != null)
            Positioned(
              bottom: 90,
              left: 20,
              right: 20,
              child: _infoCard(),
            ),
        ],
      ),
    );
  }

  void _zoomIn() {
    if (_useMaplibre) {
      _mlController?.animateCamera(mgl.CameraUpdate.zoomIn());
    } else {
      _fmController.move(
        _fmController.camera.center,
        _fmController.camera.zoom + 1,
      );
    }
  }

  void _zoomOut() {
    if (_useMaplibre) {
      _mlController?.animateCamera(mgl.CameraUpdate.zoomOut());
    } else {
      _fmController.move(
        _fmController.camera.center,
        _fmController.camera.zoom - 1,
      );
    }
  }

  Widget _ctrlBtn(
    IconData icon, {
    bool isPrimary = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: isPrimary ? _kPrimary : _kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isPrimary ? _kPrimary : _kBorderColor),
          boxShadow: const [_kShadow],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isPrimary ? Colors.white : _kTextSecondary,
        ),
      ),
    );
  }

  Widget _infoCard() {
    final p = _selectedPlace!;
    final name = p['nama_tempat'] ?? 'Unknown';
    final cat = p['category'] as String? ?? '';
    final status = p['verification_status'] ?? 'unknown';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _kBorderColor),
          boxShadow: const [_kShadow],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _colorFor(cat).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    PoiCategory.getCategoryIcon(cat),
                    color: _colorFor(cat),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _kTextPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: _kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() => _selectedPlace = null);
                    _redrawSymbols();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _kPageBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.close_rounded, size: 16, color: _kTextMuted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status == 'verified'
                        ? _kAccentGreen.withValues(alpha: 0.1)
                        : _kAccentAmber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: status == 'verified'
                          ? _kAccentGreen.withValues(alpha: 0.25)
                          : _kAccentAmber.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    status == 'verified' ? 'Terverifikasi' : 'Menunggu Review',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: status == 'verified' ? _kAccentGreen : _kAccentAmber,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
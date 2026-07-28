import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme_provider.dart';
import '../../core/poi_category.dart';
import '../../core/location_permission_helper.dart';
import 'package:flutter_svg/flutter_svg.dart';

class AdminMapScreen extends StatefulWidget {
  const AdminMapScreen({super.key});

  @override
  State<AdminMapScreen> createState() => _AdminMapScreenState();
}

class _AdminMapScreenState extends State<AdminMapScreen> {
  final _mapController = MapController();
  final _searchCtrl = TextEditingController();
  bool _filterVisible = false;
  bool _loading = true;
  bool _locationFailed = false;

  List<Map<String, dynamic>> _places = [];
  Map<String, dynamic>? _selectedPlace;

  // Default fallback: Jakarta
  static const _fallbackCenter = LatLng(-6.2088, 106.8456);
  static const _defaultZoom = 12.0;

  LatLng? _currentLocation; // user's GPS position

  static const _pinColors = {
    'Cafe': Color(0xFF8B4513),
    'Fashion': Color(0xFFE91E63),
    'Wisata': Color(0xFF2196F3),
    'Kuliner': Color(0xFFE74C3C),
    'Hotel': Color(0xFF1565C0),
    'Oleh-Oleh': Color(0xFFFF6F61),
    'UMKM': Color(0xFF4CAF50),
  };

  Color _colorFor(String cat) => _pinColors[cat] ?? const Color(0xFF95A5A6);

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _mapController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    await Future.wait([_requestLocation(), _loadPlaces()]);
  }

  /// Request GPS permission & get current position.
  /// On failure → keep _fallbackCenter.
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
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _currentLocation = LatLng(pos.latitude, pos.longitude);
        _locationFailed = false;
      });
      // Center map to user location
      _mapController.move(LatLng(pos.latitude, pos.longitude), _defaultZoom);
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
          .select(
            'id, nama_tempat, category, latitude, longitude, verification_status',
          )
          .eq('verification_status', 'verified');
      if (!mounted) return;
      setState(() {
        _places = (data as List).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _recenterToUser() {
    if (_currentLocation != null) {
      _mapController.move(_currentLocation!, _defaultZoom);
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

  Marker? get _userLocationMarker {
    if (_currentLocation == null) return null;
    return Marker(
      point: _currentLocation!,
      width: 28,
      height: 28,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Icon(Icons.navigation, color: Colors.white, size: 16),
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
      width: isSelected ? 40 : 32,
      height: isSelected ? 40 : 32,
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlace = place),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: isSelected ? 3 : 2),
            boxShadow: [
              BoxShadow(
                color: isSelected
                    ? color.withValues(alpha: 0.6)
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: isSelected ? 10 : 4,
                spreadRadius: isSelected ? 2 : 0,
              ),
            ],
          ),
          child: Builder(
            builder: (context) {
              final svgPath = PoiCategory.getCategorySvgPath(cat);
              if (svgPath != null) {
                return Padding(
                  padding: EdgeInsets.all(isSelected ? 6.0 : 4.0),
                  child: SvgPicture.asset(
                    svgPath,
                    colorFilter: const ColorFilter.mode(
                      Colors.white,
                      BlendMode.srcIn,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final markers = _filteredPlaces
        .asMap()
        .entries
        .map((e) => _buildPin(e.value, e.key))
        .toList();
    final userMarker = _userLocationMarker;
    if (userMarker != null) markers.insert(0, userMarker);

    return Scaffold(
      backgroundColor: theme.bgBase,
      body: Stack(
        children: [
          // ── MAP ──
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _currentLocation ?? _fallbackCenter,
                initialZoom: _defaultZoom,
                minZoom: 4,
                maxZoom: 22,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),
                onTap: (_, a) => setState(() => _selectedPlace = null),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.tenmu.app',
                ),
                MarkerLayer(markers: markers),
              ],
            ),

          // ── LOCATION FAILED BANNER ──
          if (_locationFailed)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.bgElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Lokasi tidak tersedia. Aktifkan GPS.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── MOBILE TOP BAR ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                color: theme.bgSurface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  'Admin Dashboard',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),

          // ── FLOATING SEARCH ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 44 + 12,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey.shade800),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 20, color: theme.textHint),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Search MSME...',
                        hintStyle: TextStyle(
                          color: theme.textHint,
                          fontSize: 14,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                      ),
                      style: TextStyle(fontSize: 14, color: theme.textPrimary),
                    ),
                  ),
                  Container(width: 1, height: 20, color: theme.border),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () =>
                        setState(() => _filterVisible = !_filterVisible),
                    child: Icon(Icons.tune, size: 20, color: theme.btnPrimary),
                  ),
                ],
              ),
            ),
          ),

          // ── FILTER PANEL ──
          if (_filterVisible) _filterPanel(theme),

          // ── MAP CONTROLS ──
          Positioned(
            right: 16,
            top: MediaQuery.of(context).size.height * 0.35,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ctrlBtn(
                  Icons.add,
                  theme,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom + 1,
                  ),
                ),
                const SizedBox(height: 4),
                _ctrlBtn(
                  Icons.remove,
                  theme,
                  onTap: () => _mapController.move(
                    _mapController.camera.center,
                    _mapController.camera.zoom - 1,
                  ),
                ),
                const SizedBox(height: 8),
                _ctrlBtn(
                  Icons.my_location,
                  theme,
                  isPrimary: true,
                  onTap: _recenterToUser,
                ),
              ],
            ),
          ),

          // ── INFO CARD ──
          if (_selectedPlace != null)
            Positioned(
              bottom: 100,
              left: 20,
              right: 20,
              child: _infoCard(theme),
            ),
        ],
      ),
    );
  }

  Widget _ctrlBtn(
    IconData icon,
    ThemeProvider theme, {
    bool isPrimary = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: theme.bgElevated.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 18,
          color: isPrimary ? theme.btnPrimary : theme.textSecondary,
        ),
      ),
    );
  }

  Widget _filterPanel(ThemeProvider theme) {
    return Positioned(
      top: 130,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.bgSurface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textPrimary,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _filterVisible = false),
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: theme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'CATEGORY',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  _filterChip('Food & Beverage', true, theme),
                  _filterChip('Retail', false, theme),
                  _filterChip('Services', false, theme),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'RATING',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: theme.textSecondary,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: 4.0,
                      min: 1,
                      max: 5,
                      divisions: 8,
                      activeColor: theme.btnPrimary,
                      onChanged: (_) {},
                    ),
                  ),
                  Text(
                    '4.0+',
                    style: TextStyle(fontSize: 12, color: theme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: theme.btnPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Apply Filters',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.btnLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip(String label, bool active, ThemeProvider theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: active ? theme.btnPrimary : theme.bgElevated,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: active ? Colors.white : theme.textPrimary,
        ),
      ),
    );
  }

  Widget _infoCard(ThemeProvider theme) {
    final p = _selectedPlace!;
    final name = p['nama_tempat'] ?? 'Unknown';
    final cat = p['category'] as String? ?? '';
    final status = p['verification_status'] ?? 'unknown';

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.bgSurface,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _colorFor(cat).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    PoiCategory.getCategoryIcon(cat),
                    color: _colorFor(cat),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: theme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedPlace = null),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.bgElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(
                      Icons.close,
                      size: 16,
                      color: theme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STATUS',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: theme.textHint,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: status == 'verified'
                              ? const Color(0xFF10B981).withValues(alpha: 0.1)
                              : const Color(0xFFF59E0B).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          status == 'verified' ? 'Active' : 'Review',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: status == 'verified'
                                ? const Color(0xFF10B981)
                                : const Color(0xFFF59E0B),
                          ),
                        ),
                      ),
                    ],
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

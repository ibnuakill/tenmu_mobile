import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/geocoding_service.dart';
import '../../../core/location_permission_helper.dart';
import '../../../core/places_provider.dart';
import '../../../core/poi_category.dart';
import '../../../core/user_role.dart';
import '../widgets/sort_filter_widget.dart';

/// State UI home (search, filter, sort, kategori, profil) + aksi-aksi
/// (load profile, load role, GPS, location update). Side-effect ke
/// [PlacesProvider] terjadi via [runQuery] / [runRefresh].
class HomeController extends ChangeNotifier {
  HomeController({required this.context});

  final BuildContext context;

  // ── UI State ──
  String _searchQuery = '';
  Set<String> _selectedCategories = {};
  SortOption _selectedSort = SortOption.terbaru;
  String? _selectedCategoryTab; // null = Semua

  // ── App State ──
  Position? _currentPosition;
  int _currentNavIndex = 0;
  UserRole? _userRole;
  String? _userName;
  String? _userLocation;
  bool _isUpdatingLocation = false;
  int _unreadNotifCount = 0;
  bool _isOwner = false;

  // ── Internal ──
  Timer? _searchDebounce;
  String? _avatarUrl;

  // ── Getters ──
  String get searchQuery => _searchQuery;
  Set<String> get selectedCategories => _selectedCategories;
  SortOption get selectedSort => _selectedSort;
  String? get selectedCategoryTab => _selectedCategoryTab;
  Position? get currentPosition => _currentPosition;
  int get currentNavIndex => _currentNavIndex;
  UserRole? get userRole => _userRole;
  String? get userName => _userName;
  String? get userLocation => _userLocation;
  bool get isUpdatingLocation => _isUpdatingLocation;
  int get unreadNotifCount => _unreadNotifCount;
  String? get avatarUrl => _avatarUrl;
  bool get isOwner => _isOwner;

  // ── Listeners ──
  void Function(int)? onNavIndexChanged;

  // ════════════════════════════════════════════════════════
  // Initial load
  // ════════════════════════════════════════════════════════

  void bootstrap() {
    final user = Supabase.instance.client.auth.currentUser;
    _avatarUrl = user?.userMetadata?['avatar_url'] as String?;
  }

  void onScrollNearEnd(ScrollController controller, PlacesProvider provider) {
    if (!controller.hasClients) return;
    final pos = controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 300) {
      if (provider.hasMore && !provider.isLoadingMore && !provider.isLoading) {
        provider.fetchMore();
      }
    }
  }

  // ════════════════════════════════════════════════════════
  // User profile / role / notif
  // ════════════════════════════════════════════════════════

  Future<void> loadUnreadCount() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final data = await Supabase.instance.client
          .from('notifications')
          .select('id')
          .eq('user_id', user.id)
          .eq('is_read', false);
      _unreadNotifCount = (data as List).length;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> loadUserProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    try {
      final res = await Supabase.instance.client
          .from('profiles')
          .select('full_name, nama, role, city')
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) {
        _userName = _resolveName(user, res);
        _userLocation = res['city'] ?? 'Cirebon';
      } else {
        _userName = _resolveName(user, null);
        _userLocation = 'Cirebon';
      }
    } catch (_) {
      _userName = _resolveName(user, null);
      _userLocation = 'Cirebon';
    }
    notifyListeners();
  }

  String _resolveName(User user, Map<String, dynamic>? res) {
    return res?['full_name'] ??
        res?['nama'] ??
        user.userMetadata?['full_name'] ??
        user.userMetadata?['nama'] ??
        'Pengguna';
  }

  Future<void> loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    final res = await Supabase.instance.client
        .from('profiles')
        .select('role')
        .eq('id', user.id)
        .maybeSingle();
    if (res != null) {
      _userRole = parseUserRole(res['role']);
      _isOwner = _userRole == UserRole.owner;
    }
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  // Location
  // ════════════════════════════════════════════════════════

  Future<void> requestUserLocation() async {
    try {
      final status = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'menampilkan jarak ke lokasi usaha',
      );
      if (status == LocationAccessStatus.granted) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        _currentPosition = pos;
        notifyListeners();

        final address =
            await GeocodingService.reverse(pos.latitude, pos.longitude);
        if (address != null) {
          _userLocation = _shortAddress(address);
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> updateLocationFromGPS(ScaffoldMessengerState messenger) async {
    if (_isUpdatingLocation) return;
    _isUpdatingLocation = true;
    notifyListeners();
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Memperbarui lokasi dari GPS...'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final status = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'memperbarui lokasi saat ini',
      );
      if (status == LocationAccessStatus.granted) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        final address =
            await GeocodingService.reverse(pos.latitude, pos.longitude);
        if (address != null) {
          final short = _shortAddress(address);
          _userLocation = short;
          _currentPosition = pos;
          notifyListeners();
          messenger.showSnackBar(
            SnackBar(
              content: Text('Lokasi diperbarui: $short'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui lokasi'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      _isUpdatingLocation = false;
      notifyListeners();
    }
  }

  String _shortAddress(String address) {
    return address.split(',').take(2).join(',').trim();
  }

  // ════════════════════════════════════════════════════════
  // Query building & debounce
  // ════════════════════════════════════════════════════════

  PlaceQuery buildQuery() {
    final cats = [
      ..._selectedCategories,
      if (_selectedCategoryTab != null && _selectedCategoryTab != 'Semua')
        _selectedCategoryTab!,
    ].map(PoiCategory.normalizeCategory).toList();

    final SortMode sort;
    if (_selectedSort == SortOption.terdekat && _currentPosition != null) {
      sort = SortMode.terdekat;
    } else if (_selectedSort == SortOption.rating) {
      sort = SortMode.rating;
    } else {
      sort = SortMode.terbaru;
    }

    return PlaceQuery(
      search: _searchQuery.toLowerCase().trim(),
      categories: cats,
      sort: sort,
      userLat: _currentPosition?.latitude,
      userLng: _currentPosition?.longitude,
    );
  }

  void scheduleQuery(PlacesProvider provider, {bool immediate = false}) {
    _searchDebounce?.cancel();
    if (immediate) {
      provider.setQuery(buildQuery(), force: true);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      provider.setQuery(buildQuery(), force: true);
    });
  }

  // ════════════════════════════════════════════════════════
  // UI mutations
  // ════════════════════════════════════════════════════════

  void setSearchQuery(String v, PlacesProvider provider) {
    _searchQuery = v.toLowerCase();
    notifyListeners();
    scheduleQuery(provider);
  }

  /// Patch query (tanpa debounce internal) — untuk live update dari text field.
  void patchQuery(String v) {
    _searchQuery = v.toLowerCase();
    notifyListeners();
  }

  void clearSearchQuery(PlacesProvider provider) {
    _searchQuery = '';
    notifyListeners();
    scheduleQuery(provider, immediate: true);
  }

  void setCategories(Set<String> v, PlacesProvider provider) {
    _selectedCategories = v;
    notifyListeners();
    scheduleQuery(provider);
  }

  void setSort(SortOption v, PlacesProvider provider) {
    _selectedSort = v;
    notifyListeners();
    scheduleQuery(provider);
    if (v == SortOption.terdekat && _currentPosition == null) {
      requestLocationForSort(provider);
    }
  }

  void setCategoryTab(String? v, PlacesProvider provider) {
    _selectedCategoryTab = v;
    notifyListeners();
    scheduleQuery(provider, immediate: true);
  }

  void resetFilters(PlacesProvider provider) {
    _searchQuery = '';
    _selectedCategories = {};
    _selectedSort = SortOption.terbaru;
    notifyListeners();
  }

  void setNavIndex(int v) {
    _currentNavIndex = v;
    notifyListeners();
  }

  // ════════════════════════════════════════════════════════
  // GPS for sort
  // ════════════════════════════════════════════════════════

  Future<void> requestLocationForSort(PlacesProvider provider) async {
    try {
      final status = await LocationPermissionHelper.ensureAccess(
        context,
        featureLabel: 'mengurutkan berdasarkan jarak terdekat',
      );
      if (status == LocationAccessStatus.granted) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high),
        );
        _currentPosition = pos;
        notifyListeners();
        scheduleQuery(provider, immediate: true);
      } else {
        _selectedSort = SortOption.terbaru;
        notifyListeners();
      }
    } catch (_) {
      _selectedSort = SortOption.terbaru;
      notifyListeners();
    }
  }

  // ════════════════════════════════════════════════════════
  // Refresh all
  // ════════════════════════════════════════════════════════

  Future<void> refreshAll(PlacesProvider provider) async {
    provider.clearError();
    await provider.setQuery(buildQuery(), force: true);
    await provider.fetchFeatured(force: true);
    await requestUserLocation();
  }

  // ════════════════════════════════════════════════════════
  // Cleanup
  // ════════════════════════════════════════════════════════

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import '../../../../core/poi_image_helper.dart';
import '../../../../core/theme_provider.dart';
import '../route_map_controller.dart';

/// Bottom sheet saat mode navigasi aktif (info card + mode switcher,
/// atau arrival card saat sudah sampai).
class MapNavigationSheet extends StatelessWidget {
  final RouteMapController controller;
  const MapNavigationSheet({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
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
            _SheetHandle(theme: theme),
            if (controller.hasArrived)
              _ArrivalCard(controller: controller)
            else ...[
              _NavInfoCard(controller: controller),
              Divider(color: theme.border, height: 1),
              _TravelModeSelector(controller: controller),
            ],
          ],
        ),
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  final ThemeProvider theme;
  const _SheetHandle({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: theme.textHint,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class _NavInfoCard extends StatelessWidget {
  final RouteMapController controller;
  const _NavInfoCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _InfoColumn(
            label: controller.useFallback ? 'Lurus' : 'Jarak',
            value: controller.distanceInKm != null
                ? '${controller.distanceInKm!.toStringAsFixed(1)} km'
                : '-',
            theme: theme,
          ),
          Container(width: 1, height: 32, color: theme.border),
          _InfoColumn(
            label: 'Waktu',
            value: controller.estimatedTimeInMins != null
                ? controller.formatEstimate(controller.estimatedTimeInMins!)
                : '-',
            theme: theme,
          ),
          Container(width: 1, height: 32, color: theme.border),
          _InfoColumn(
            label: 'Kecepatan',
            value: '${controller.currentSpeedKmh.toStringAsFixed(0)} km/h',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  final String label;
  final String value;
  final ThemeProvider theme;
  const _InfoColumn({
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(color: theme.textSecondary, fontSize: 12),
        ),
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
}

class _TravelModeSelector extends StatelessWidget {
  final RouteMapController controller;
  const _TravelModeSelector({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: TravelMode.values.map((mode) {
          final isActive = controller.travelMode == mode;
          return GestureDetector(
            onTap: () => controller.setTravelMode(mode),
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
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive ? theme.btnLabel : theme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ArrivalCard extends StatelessWidget {
  final RouteMapController controller;
  const _ArrivalCard({required this.controller});

  @override
  Widget build(BuildContext context) {
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
              controller.destinationName ?? 'Tujuan',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ArrivalStat(
                  icon: Icons.straighten,
                  value:
                      '${controller.totalTripDistanceKm.toStringAsFixed(1)} km',
                  label: 'Total Jarak',
                ),
                Container(height: 30, width: 1, color: Colors.white30),
                _ArrivalStat(
                  icon: Icons.timer_outlined,
                  value: controller.formatEstimate(controller.totalTripMinutes),
                  label: 'Waktu Tempuh',
                ),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: controller.finishTrip,
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
}

class _ArrivalStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _ArrivalStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 22),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 11),
        ),
      ],
    );
  }
}

/// Bottom panel saat mode browse (belum ada selected / selectedPlace ada).
class MapBrowseInfo extends StatelessWidget {
  const MapBrowseInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
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
}

/// Bottom card preview POI yang dipilih (sebelum mulai navigasi).
class MapUmkmPreview extends StatelessWidget {
  final Map<String, dynamic> place;
  final VoidCallback onClose;
  final VoidCallback onStartRoute;
  const MapUmkmPreview({
    super.key,
    required this.place,
    required this.onClose,
    required this.onStartRoute,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final imageUrl = PoiImageHelper.primaryImageUrl(place);
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
                          errorWidget: (_, _, _) => _PlaceholderImage(theme: theme),
                        )
                      : _PlaceholderImage(theme: theme),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place['nama_tempat'] ?? 'Tanpa Nama',
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
                        place['alamat'] ?? '-',
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
                  onPressed: onClose,
                ),
              ],
            ),
          ),
          Container(height: 1, color: theme.border),
          InkWell(
            onTap: onStartRoute,
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
}

class _PlaceholderImage extends StatelessWidget {
  final ThemeProvider theme;
  const _PlaceholderImage({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 60,
      height: 60,
      color: theme.bgElevated,
      child: Icon(Icons.storefront, color: theme.textHint),
    );
  }
}

/// Empty/error state (GPS off, izin ditolak, dst.).
class MapErrorView extends StatelessWidget {
  final String? message;
  final VoidCallback onRetry;
  const MapErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off_outlined, size: 64, color: theme.textHint),
            const SizedBox(height: 16),
            Text(
              message ?? 'Lokasi tidak tersedia.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
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
}

/// FAB stack: compass (reset bearing) + recenter.
class MapFabStack extends StatelessWidget {
  final RouteMapController controller;
  const MapFabStack({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    return Column(
      children: [
        FloatingActionButton(
          heroTag: 'compass',
          onPressed: () async {
            try {
              await controller.mapController?.animateCamera(
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
          child: Icon(Icons.explore_outlined, color: theme.btnPrimary),
        ),
        const SizedBox(height: 12),
        FloatingActionButton(
          heroTag: 'recenter',
          onPressed: () {
            if (controller.currentPosition == null) return;
            controller.mapController?.animateCamera(
              CameraUpdate.newLatLngZoom(
                LatLng(
                  controller.currentPosition!.latitude,
                  controller.currentPosition!.longitude,
                ),
                16.0,
              ),
            );
          },
          backgroundColor: theme.bgSurface,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.border),
          ),
          child: Icon(Icons.my_location, color: theme.iconColor),
        ),
      ],
    );
  }
}

/// Top banner saat rute fallback (lurus).
class MapFallbackBanner extends StatelessWidget {
  const MapFallbackBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 16, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Rute offline — perkiraan jarak lurus',
              style: TextStyle(fontSize: 12, color: Colors.orange.shade900),
            ),
          ),
        ],
      ),
    );
  }
}

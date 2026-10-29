import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'theme_provider.dart';

enum LocationAccessStatus {
  granted,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
}

class LocationPermissionHelper {
  static Future<LocationAccessStatus> ensureAccess(
    BuildContext context, {
    required String featureLabel,
  }) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (context.mounted) {
        await _showServiceDisabledDialog(context, featureLabel: featureLabel);
      }
      return LocationAccessStatus.serviceDisabled;
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      return LocationAccessStatus.permissionDenied;
    }

    if (permission == LocationPermission.deniedForever) {
      if (context.mounted) {
        await _showPermissionDeniedForeverDialog(
          context,
          featureLabel: featureLabel,
        );
      }
      return LocationAccessStatus.permissionDeniedForever;
    }

    return LocationAccessStatus.granted;
  }

  static Future<void> _showServiceDisabledDialog(
    BuildContext context, {
    required String featureLabel,
  }) {
    return _showRequiredDialog(
      context,
      icon: Icons.location_off_outlined,
      title: 'Aktifkan Lokasi Dulu',
      body:
          'GPS HP kamu masih nonaktif. Aktifkan lokasi dulu supaya $featureLabel bisa dipakai.',
      actionLabel: 'Aktifkan Sekarang',
      onAction: () => Geolocator.openLocationSettings(),
    );
  }

  static Future<void> _showPermissionDeniedForeverDialog(
    BuildContext context, {
    required String featureLabel,
  }) {
    return _showRequiredDialog(
      context,
      icon: Icons.lock_outline,
      title: 'Izin Lokasi Diperlukan',
      body:
          'Akses lokasi untuk $featureLabel sedang ditolak permanen. Aktifkan izin lokasi dari pengaturan aplikasi.',
      actionLabel: 'Buka Pengaturan',
      onAction: () => Geolocator.openAppSettings(),
    );
  }

  /// Dialog wajib: satu tombol aksi, tanpa opsi "Nanti".
  static Future<void> _showRequiredDialog(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    required String actionLabel,
    required Future<void> Function() onAction,
  }) async {
    final theme = context.read<ThemeProvider>();

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: theme.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: Icon(icon, size: 48, color: theme.btnPrimary),
        title: Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        content: Text(
          body,
          textAlign: TextAlign.center,
          style: TextStyle(color: theme.textSecondary, height: 1.6),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);
                await onAction();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.btnPrimary,
                foregroundColor: theme.btnLabel,
                padding: const EdgeInsets.symmetric(vertical: 14),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

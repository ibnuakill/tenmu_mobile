import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'app_colors.dart';

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
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Aktifkan GPS',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'GPS HP kamu masih nonaktif. Aktifkan lokasi dulu supaya $featureLabel bisa dipakai.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Nanti',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Geolocator.openLocationSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.btnPrimary,
              foregroundColor: AppColors.btnLabel,
              elevation: 0,
            ),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showPermissionDeniedForeverDialog(
    BuildContext context, {
    required String featureLabel,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Izin Lokasi Diperlukan',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          'Akses lokasi untuk $featureLabel sedang ditolak permanen. Aktifkan izin lokasi dari pengaturan aplikasi.',
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Nanti',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await Geolocator.openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.btnPrimary,
              foregroundColor: AppColors.btnLabel,
              elevation: 0,
            ),
            child: const Text('Buka Pengaturan'),
          ),
        ],
      ),
    );
  }
}

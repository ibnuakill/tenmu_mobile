import 'dart:io';

import 'package:flutter/foundation.dart';

import 'app_update_service.dart';

/// Provider state untuk mekanisme in-app update.
///
/// Dipakai lewat `context.watch<AppUpdateProvider>()` untuk reagen UI,
/// dan `context.read<AppUpdateProvider>()` untuk memicu aksi.
class AppUpdateProvider extends ChangeNotifier {
  AppUpdateProvider({AppUpdateService? service})
      : _service = service ?? AppUpdateService();

  final AppUpdateService _service;

  UpdateStatus _status = UpdateStatus.idle;
  AppVersion? _pendingVersion;
  File? _downloadedApk;
  double _progress = 0.0;
  String? _errorMessage;

  UpdateStatus get status => _status;
  AppVersion? get pendingVersion => _pendingVersion;
  double get progress => _progress;
  String? get errorMessage => _errorMessage;
  bool get isUpdateAvailable => _status == UpdateStatus.updateAvailable;
  bool get isBusy =>
      _status == UpdateStatus.checking || _status == UpdateStatus.downloading;
  bool get isMandatory => _pendingVersion?.isMandatory ?? false;

  /// Mengecek versi terbaru di server.
  ///
  /// Mengembalikan rilis yang lebih baru, atau `null` bila sudah up-to-date
  /// maupun pengecekan gagal. Kegagalan jaringan tidak melempar error —
  /// hanya diabaikan diam-diam.
  Future<AppVersion?> checkForUpdate() async {
    if (_status == UpdateStatus.checking) return null;
    _status = UpdateStatus.checking;
    _errorMessage = null;
    notifyListeners();

    final latest = await _service.checkForUpdate();

    if (latest == null) {
      _status = UpdateStatus.idle;
    } else {
      _pendingVersion = latest;
      _status = UpdateStatus.updateAvailable;
    }
    notifyListeners();
    return latest;
  }

  /// Mengunduh APK versi terbaru.
  Future<void> downloadUpdate() async {
    final version = _pendingVersion;
    if (version == null) return;

    _status = UpdateStatus.downloading;
    _progress = 0.0;
    _errorMessage = null;
    notifyListeners();

    try {
      _downloadedApk = await _service.downloadApk(
        version,
        onProgress: (value) {
          _progress = value;
          notifyListeners();
        },
      );
      _status = UpdateStatus.ready;
    } catch (e) {
      _errorMessage = e.toString();
      _status = UpdateStatus.failed;
    }
    notifyListeners();
  }

  /// Membuka installer Android untuk APK yang sudah diunduh.
  Future<void> installUpdate() async {
    final apk = _downloadedApk;
    if (apk == null) return;
    try {
      await _service.installApk(apk);
    } catch (e) {
      _errorMessage = e.toString();
      _status = UpdateStatus.failed;
      notifyListeners();
    }
  }

  /// Menghapus dialog update (dipakai saat user memilih "nanti").
  void dismiss() {
    if (_status == UpdateStatus.updateAvailable) {
      _status = UpdateStatus.idle;
      _pendingVersion = null;
      notifyListeners();
    }
  }

  /// Mengulang proses dari awal (setelah gagal unduh).
  void reset() {
    _status = UpdateStatus.idle;
    _pendingVersion = null;
    _downloadedApk = null;
    _progress = 0.0;
    _errorMessage = null;
    notifyListeners();
  }
}

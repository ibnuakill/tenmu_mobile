import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Model data satu rilis aplikasi yang tersimpan di tabel `app_versions`.
class AppVersion {
  const AppVersion({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    this.changelog = '',
    this.apkSize = 0,
    this.isMandatory = false,
    this.apkVariants = const {},
  });

  factory AppVersion.fromRow(Map<String, dynamic> row) {
    final rawVariants = row['apk_variants'];
    final variants = <String, String>{};
    if (rawVariants is Map) {
      rawVariants.forEach((key, value) {
        if (key is String && value is String) variants[key] = value;
      });
    }
    return AppVersion(
      versionCode: (row['version_code'] as num?)?.toInt() ?? 0,
      versionName: (row['version_name'] as String?) ?? '0.0.0',
      apkUrl: (row['apk_url'] as String?) ?? '',
      changelog: (row['changelog'] as String?) ?? '',
      apkSize: (row['apk_size'] as num?)?.toInt() ?? 0,
      isMandatory: (row['is_mandatory'] as bool?) ?? false,
      apkVariants: variants,
    );
  }

  final int versionCode;
  final String versionName;
  final String apkUrl;
  final String changelog;
  final int apkSize;
  final bool isMandatory;

  /// Peta ABI → URL APK, mis. `arm64-v8a`, `armeabi-v7a`, `x86_64`.
  final Map<String, String> apkVariants;

  /// Offset versionCode yang dipakai Gradle untuk build split-per-abi.
  /// Build `+3` menjadi `2003` (arm64-v8a), `1003` (armeabi-v7a),
  /// `4003` (x86_64).
  static const Map<String, int> abiVersionCodeOffset = {
    'armeabi-v7a': 1000,
    'arm64-v8a': 2000,
    'x86_64': 4000,
  };

  /// Memilih URL APK yang cocok dengan ABI perangkat.
  ///
  /// Kalau tidak ada varian yang cocok, jatuh ke [apkUrl] (APK universal).
  Future<String> resolveApkUrl() async {
    if (apkVariants.isEmpty) return apkUrl;

    final supported = await _deviceAbis();
    for (final abi in supported) {
      final url = apkVariants[abi];
      if (url != null && url.isNotEmpty) return url;
    }
    return apkUrl;
  }

  static Future<List<String>> _deviceAbis() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return info.supportedAbis;
    } catch (_) {
      return const [];
    }
  }
}

/// Status proses pemeriksaan & pengunduhan update.
enum UpdateStatus { idle, checking, updateAvailable, downloading, ready, failed }

/// Layanan in-app updater (sideload, tanpa Play Store).
///
/// Alur:
/// 1. [checkForUpdate] membaca versi terbaru dari tabel `app_versions`
///    lalu membandingkannya dengan `versionCode` aplikasi yang terpasang.
/// 2. [downloadApk] mengunduh file APK ke direktori cache aplikasi.
/// 3. [installApk] membuka installer Android untuk file tersebut.
class AppUpdateService {
  AppUpdateService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// [onProgress] menerima nilai 0.0–1.0 selama unduhan berjalan.
  /// Mengembalikan file APK lokal yang siap dipasang.
  Future<File> downloadApk(
    AppVersion version, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final url = await version.resolveApkUrl();
    final target = File('${dir.path}/tenmu-${version.versionName}.apk');

    final request = http.Request('GET', Uri.parse(url));
    final response = await http.Client().send(request);

    if (response.statusCode != 200) {
      throw Exception('Gagal mengunduh update (HTTP ${response.statusCode}).');
    }

    final total = response.contentLength ?? version.apkSize;
    var received = 0;

    final sink = target.openWrite();
    await for (final chunk in response.stream) {
      received += chunk.length;
      sink.add(chunk);
      if (total > 0) onProgress?.call((received / total).clamp(0.0, 1.0));
    }
    await sink.flush();
    await sink.close();

    return target;
  }

  /// Membuka installer Android untuk file APK yang sudah diunduh.
  Future<void> installApk(File apk) async {
    final result = await OpenFilex.open(
      apk.path,
      type: 'application/vnd.android.package-archive',
    );
    if (result.type != ResultType.done) {
      throw Exception('Tidak bisa membuka installer: ${result.message}');
    }
  }

  /// Mengambil `versionCode` aplikasi yang sedang terpasang.
  ///
  /// Untuk build split-per-abi, Android menambah offset ABI pada
  /// versionCode (mis. build `+3` menjadi 2003 untuk arm64-v8a).
  Future<int> currentVersionCode() async {
    final info = await PackageInfo.fromPlatform();
    return int.tryParse(info.buildNumber) ?? 0;
  }

  /// Mengambil nama versi aplikasi yang terpasang (mis. `1.0.1`).
  Future<String> currentVersionName() async {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  /// Membandingkan dua nomor versi semantik (`1.10.2` > `1.9.9`).
  ///
  /// Mengembalikan nilai negatif bila [a] lebih lama, positif bila [a]
  /// lebih baru, dan 0 bila sama.
  static int compareVersions(String a, String b) {
    final pa = a.split('.');
    final pb = b.split('.');
    final len = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < len; i++) {
      final na = i < pa.length ? int.tryParse(pa[i]) ?? 0 : 0;
      final nb = i < pb.length ? int.tryParse(pb[i]) ?? 0 : 0;
      if (na != nb) return na - nb;
    }
    return 0;
  }

  /// Mengambil rilis terbaru yang aktif dari server.
  Future<AppVersion?> fetchLatestVersion() async {
    final data = await _client
        .from('app_versions')
        .select()
        .eq('is_active', true)
        .order('version_code', ascending: false)
        .limit(1);

    if (data.isEmpty) return null;
    return AppVersion.fromRow(data.first);
  }

  /// Mengecek apakah ada versi yang lebih baru.
  ///
  /// Perbandingan memakai **nama versi** (`1.0.2` > `1.0.1`), bukan
  /// `versionCode`, karena build split-per-abi meng-offset `versionCode`
  /// per ABI (2003/1003/4003) sehingga angka polos tidak bisa dipakai
  /// sebagai pembanding lintas perangkat.
  ///
  /// Mengembalikan null bila sudah up-to-date atau pengecekan gagal.
  Future<AppVersion?> checkForUpdate() async {
    // Updater ini khusus Android (sideload APK). Windows punya installer
    // sendiri, jadi jangan tampilkan dialog update berbasis APK di sana.
    if (!Platform.isAndroid) return null;
    try {
      final latest = await fetchLatestVersion();
      if (latest == null) return null;
      final cmp = compareVersions(
        latest.versionName,
        await currentVersionName(),
      );
      return cmp > 0 ? latest : null;
    } catch (_) {
      return null;
    }
  }
}

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Service for OneSignal push notifications.
///
/// - `init()` — call once after Supabase init (auto-attach).
/// - `attachUser(userId)` / `detachUser()` — call when auth state changes.
/// - `sendNewPlaceNotification(placeId, placeName)` — call from admin after approving.
class NotificationService {
  NotificationService._();

  static final _appId = dotenv.env['ONESIGNAL_APP_ID'] ?? '';
  static final _restApiKey = dotenv.env['ONESIGNAL_REST_API_KEY'] ?? '';

  static bool _sdkInitialized = false;

  /// Initialize OneSignal SDK (one-time). Safe to call multiple times.
  static Future<void> init() async {
    if (_sdkInitialized) return;
    if (_appId.isEmpty) {
      debugPrint('[NotificationService] ONESIGNAL_APP_ID not set in .env');
      return;
    }

    OneSignal.initialize(_appId);

    // Request notification permission
    final result = await OneSignal.Notifications.requestPermission(true);
    debugPrint('[NotificationService] permission: $result');

    _sdkInitialized = true;
  }

  /// Link device to a Supabase user — call on login / session restore.
  static Future<void> attachUser(String userId) async {
    if (_appId.isEmpty) return;
    await OneSignal.login(userId);
    debugPrint('[NotificationService] attached user: $userId');
  }

  /// Unlink device — call on logout.
  static Future<void> detachUser() async {
    if (_appId.isEmpty) return;
    await OneSignal.logout();
    debugPrint('[NotificationService] detached user');
  }

  /// Send push notification to *all* OneSignal subscribers.
  ///
  /// Called after admin approves a new place.
  /// Returns `true` if the API call succeeded.
  static Future<bool> sendNewPlaceNotification({
    required int placeId,
    required String placeName,
  }) async {
    if (_appId.isEmpty || _restApiKey.isEmpty) {
      debugPrint('[NotificationService] OneSignal credentials missing');
      return false;
    }

    final url = Uri.parse('https://onesignal.com/api/v1/notifications');
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'Authorization': 'Basic $_restApiKey',
    };
    final body = jsonEncode({
      'app_id': _appId,
      'included_segments': ['All'],
      'headings': {'en': '🏪 Tempat Baru di TenMu!'},
      'contents': {
        'en': '$placeName sudah terverifikasi dan siap dikunjungi. Yuk lihat!'
      },
      'data': {
        'type': 'new_place',
        'place_id': placeId,
      },
      'priority': 10,
    });

    try {
      final response = await http.post(url, headers: headers, body: body);
      final ok = response.statusCode == 200;
      debugPrint(
        '[NotificationService] send result: ${ok ? "OK" : response.statusCode}'
        ' ${response.body}',
      );
      return ok;
    } catch (e) {
      debugPrint('[NotificationService] send error: $e');
      return false;
    }
  }
}
